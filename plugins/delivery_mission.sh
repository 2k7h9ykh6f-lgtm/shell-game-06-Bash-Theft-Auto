#!/bin/bash
# =============================================================================
# Plugin: Express Courier / Delivery Missions
# File:   plugins/delivery_mission.sh
# Ver:    1.0.0
# Desc:   Adds a repeatable courier mission system. Players accept packages
#         and must deliver them to a target city within a time limit.
#         Success earns cash + respect; failure triggers penalties.
#         Compatible with the plugin hook system (save/load, passive tick).
# License: MIT
#
# INSTALL: Drop into plugins/ (auto-sourced at startup)
# MANUAL STEP: Add to main menu in bta.sh:
#   echo "D.  Courier Jobs    |"
#   'd') show_courier_menu;;
# =============================================================================

[[ -n "${PLUGIN_DELIVERY_LOADED:-}" ]] && return
PLUGIN_DELIVERY_LOADED=1

# =============================================================================
# DELIVERY STATE
# =============================================================================
declare -A delivery_active=()    # Active delivery: dest, package, deadline_*, reward, deposit, start_*
delivery_combo=0                 # Consecutive successes (boosts reward)
delivery_total_completed=0       # Lifetime completed deliveries
delivery_total_failed=0          # Lifetime failed deliveries
delivery_total_earned=0          # Lifetime cash earned

# =============================================================================
# PACKAGE TYPE DEFINITIONS
# Format: "Display Name:Base Pay:Deposit:Hours Grace:Fail Wanted Inc:Difficulty"
#   - Hours Grace: base hours allowed per city hop
#   - Fail Wanted Inc: wanted-level increase on failure (0 for legal cargo)
#   - Difficulty: 1-5 multiplier for reward scaling
# =============================================================================
declare -a DELIVERY_PACKAGE_TYPES=(
    "Medical Supplies:180:60:7:0:1"
    "Legal Documents:220:80:6:0:1"
    "Electronics:380:130:5:0:2"
    "Cash Bundle:550:200:5:1:3"
    "Contraband:750:280:4:1:4"
    "Hot Merchandise:600:220:4:1:3"
    "Suspicious Crate:1100:420:3:2:5"
    "Classified Intel:1400:520:3:2:5"
)

# =============================================================================
# CITY DISTANCE TABLE  (symmetric hop-count between cities)
# Used to compute deadline and reward multiplier.
# =============================================================================
declare -A DELIVERY_CITY_DIST=(
    ["Los Santos|Los Santos"]=0
    ["Los Santos|San Fierro"]=1       ["Los Santos|Las Venturas"]=2
    ["Los Santos|Vice City"]=2        ["Los Santos|Liberty City"]=3
    ["Los Santos|Blaine County"]=1
    ["San Fierro|Los Santos"]=1       ["San Fierro|San Fierro"]=0
    ["San Fierro|Las Venturas"]=1     ["San Fierro|Vice City"]=2
    ["San Fierro|Liberty City"]=2     ["San Fierro|Blaine County"]=1
    ["Las Venturas|Los Santos"]=2     ["Las Venturas|San Fierro"]=1
    ["Las Venturas|Las Venturas"]=0   ["Las Venturas|Vice City"]=2
    ["Las Venturas|Liberty City"]=2   ["Las Venturas|Blaine County"]=1
    ["Vice City|Los Santos"]=2        ["Vice City|San Fierro"]=2
    ["Vice City|Las Venturas"]=2      ["Vice City|Vice City"]=0
    ["Vice City|Liberty City"]=2      ["Vice City|Blaine County"]=3
    ["Liberty City|Los Santos"]=3     ["Liberty City|San Fierro"]=2
    ["Liberty City|Las Venturas"]=2   ["Liberty City|Vice City"]=2
    ["Liberty City|Liberty City"]=0   ["Liberty City|Blaine County"]=2
    ["Blaine County|Los Santos"]=1    ["Blaine County|San Fierro"]=1
    ["Blaine County|Las Venturas"]=1  ["Blaine County|Vice City"]=3
    ["Blaine County|Liberty City"]=2  ["Blaine County|Blaine County"]=0
)

# All valid city names for random destination picking
DELIVERY_ALL_CITIES="Los Santos|San Fierro|Las Venturas|Vice City|Liberty City|Blaine County"

# NPC dialogue snippets keyed by difficulty range
declare -A DELIVERY_NPC_LINES=(
    [1_low]="Hurry up, this ain't gonna deliver itself!"
    [1_high]="Easy run, good warm-up for you."
    [2_low]="Don't scratch the package, got it?"
    [2_high]="Standard run. Don't overthink it."
    [3_low]="The client is watching. Don't screw this up."
    [3_high]="Decent haul. Watch your back out there."
    [4_low]="This one's hot. Move fast, ask no questions."
    [4_high]="Big risk, big reward. You in?"
    [5_low]="If you get caught, you never heard of me."
    [5_high]="One shot. Blow it and you're on your own."
)

# =============================================================================
# HELPER: City distance lookup
# =============================================================================
_delivery_city_distance() {
    local from="$1" to="$2"
    local dist=${DELIVERY_CITY_DIST["${from}|${to}"]:-2}
    echo "$dist"
}

# =============================================================================
# HELPER: Total hours elapsed since delivery started
# Returns an integer = (current_day*24 + current_hour) - (start_day*24 + start_hour)
# =============================================================================
_delivery_hours_elapsed() {
    local now_total=$(( game_day * 24 + game_hour ))
    local start_total=$(( ${delivery_active[start_day]:-0} * 24 + ${delivery_active[start_hour]:-0} ))
    echo $(( now_total - start_total ))
}

# =============================================================================
# HELPER: Hours remaining on the deadline
# =============================================================================
_delivery_hours_remaining() {
    local deadline_total=$(( ${delivery_active[deadline_day]:-0} * 24 + ${delivery_active[deadline_hour]:-0} ))
    local now_total=$(( game_day * 24 + game_hour ))
    echo $(( deadline_total - now_total ))
}

# =============================================================================
# HELPER: Format hours as "Xd Yh"
# =============================================================================
_delivery_format_hours() {
    local total_hours="$1"
    if (( total_hours >= 24 )); then
        printf "%dd %dh" $(( total_hours / 24 )) $(( total_hours % 24 ))
    else
        printf "%dh" "$total_hours"
    fi
}

# =============================================================================
# HELPER: Generate a delivery job
# Populates the global delivery_active associative array.
# =============================================================================
_delivery_generate() {
    # --- pick random package type ---
    local pkg_idx=$(( RANDOM % ${#DELIVERY_PACKAGE_TYPES[@]} ))
    local pkg_raw="${DELIVERY_PACKAGE_TYPES[$pkg_idx]}"

    local pkg_name pkg_base pkg_deposit pkg_grace pkg_wanted pkg_diff
    IFS=':' read -r pkg_name pkg_base pkg_deposit pkg_grace pkg_wanted pkg_diff <<< "$pkg_raw"

    # --- pick random destination different from current city ---
    IFS='|' read -ra _dcities <<< "$DELIVERY_ALL_CITIES"
    local dest="" attempts=0
    while [[ -z "$dest" || "$dest" == "$location" ]] && (( attempts < 20 )); do
        dest="${_dcities[$(( RANDOM % ${#_dcities[@]} ))]}"
        (( attempts++ ))
    done

    # --- compute distance & deadline ---
    local dist
    dist=$(_delivery_city_distance "$location" "$dest")
    (( dist < 1 )) && dist=1
    local deadline_hours=$(( dist * pkg_grace + RANDOM % 3 + 2 ))

    # --- compute reward ---
    local dist_mult reward
    case "$dist" in
        1) dist_mult=100 ;; 2) dist_mult=150 ;; 3) dist_mult=220 ;; *) dist_mult=280 ;;
    esac
    reward=$(( pkg_base + dist_mult * pkg_diff / 2 ))

    # combo bonus (+8 % per streak, capped at +80 %)
    local combo_bonus=$(( delivery_combo * 8 ))
    (( combo_bonus > 80 )) && combo_bonus=80
    reward=$(( reward * (100 + combo_bonus) / 100 ))

    # --- populate state ---
    delivery_active=(
        [dest]="$dest"
        [package]="$pkg_name"
        [reward]="$reward"
        [deposit]="$pkg_deposit"
        [fail_wanted]="$pkg_wanted"
        [difficulty]="$pkg_diff"
        [distance]="$dist"
        [start_day]="$game_day"
        [start_hour]="$game_hour"
        [deadline_hours]="$deadline_hours"
    )

    # Compute absolute deadline (day/hour)
    local abs_hours=$(( game_day * 24 + game_hour + deadline_hours ))
    delivery_active[deadline_day]=$(( abs_hours / 24 ))
    delivery_active[deadline_hour]=$(( abs_hours % 24 ))
}

# =============================================================================
# MAIN MENU: Courier Jobs
# =============================================================================
show_courier_menu() {
    run_clock 0
    while true; do
        clear_screen
        echo "============================================="
        echo "       EXPRESS COURIER SERVICES"
        echo "============================================="
        printf " City: %-18s | Cash: \$%d\n" "$location" "$cash"

        if [[ -n "${delivery_active[dest]:-}" ]]; then
            local hrs_left
            hrs_left=$(_delivery_hours_remaining)
            local status_color="\e[1;32m"
            (( hrs_left <= 4 )) && status_color="\e[1;33m"
            (( hrs_left <= 0 )) && status_color="\e[1;31m"
            printf " Active Run: %-15s -> %b%s%b  (%s left)\n" \
                "${delivery_active[package]}" \
                "$status_color" "${delivery_active[dest]}" "\e[0m" \
                "$(_delivery_format_hours "$hrs_left")"
        else
            echo " Active Run: None"
        fi

        printf " Streak: %d  |  Completed: %d  |  Failed: %d\n" \
            "$delivery_combo" "$delivery_total_completed" "$delivery_total_failed"
        echo "============================================="
        echo ""
        echo " 1. Find a Delivery Job"
        if [[ -n "${delivery_active[dest]:-}" ]]; then
            echo " 2. Check Delivery Status"
            echo " 3. Abandon Delivery (forfeit deposit)"
        fi
        echo ""
        echo " B. Back"
        echo "============================================="
        read -r -p "Choice: " courier_choice

        case "${courier_choice,,}" in
            1) _delivery_accept_flow ;;
            2) [[ -n "${delivery_active[dest]:-}" ]] && _delivery_status_flow ;;
            3) [[ -n "${delivery_active[dest]:-}" ]] && _delivery_abandon_flow ;;
            'b') return ;;
            *) sleep 0.5 ;;
        esac
    done
}

# =============================================================================
# FLOW: Accept a new delivery
# =============================================================================
_delivery_accept_flow() {
    if [[ -n "${delivery_active[dest]:-}" ]]; then
        echo "You already have an active delivery! Finish or abandon it first."
        read -r -p "Press Enter..."
        return
    fi

    # Generate a random job offer
    _delivery_generate

    clear_screen
    echo "============================================="
    echo "     NEW DELIVERY JOB AVAILABLE"
    echo "============================================="
    echo ""

    local diff="${delivery_active[difficulty]}"
    local stars=""
    for (( i = 0; i < diff; i++ )); do stars+="*"; done

    printf "  Package:    %s\n" "${delivery_active[package]}"
    printf "  Risk:       %s (%d/5)\n" "$stars" "$diff"
    printf "  Destination: %s\n" "${delivery_active[dest]}"
    printf "  Distance:   %d cit%s\n" "${delivery_active[distance]}" \
        "$( (( ${delivery_active[distance]} > 1 )) && echo 'ies' || echo 'y' )"
    printf "  Deadline:   %s\n" "$(_delivery_format_hours "${delivery_active[deadline_hours]}")"
    printf "  Reward:     \$%d\n" "${delivery_active[reward]}"
    printf "  Deposit:    \$%d (forfeited on failure)\n" "${delivery_active[deposit]}"

    local fw="${delivery_active[fail_wanted]}"
    if (( fw > 0 )); then
        printf -v _wline "  On Failure: Lose deposit + wanted level +%d" "$fw"
        printf "\e[1;31m%s\e[0m\n" "$_wline"
    else
        echo "  On Failure: Lose deposit only (legal cargo)"
    fi

    echo ""
    printf '  Dispatcher: "%s"\n' "${DELIVERY_NPC_LINES[${diff}_low]}"
    echo ""
    echo "============================================="

    # Cash check
    if (( cash < delivery_active[deposit] )); then
        echo "You don't have enough cash for the deposit (\$${delivery_active[deposit]})."
        delivery_active=()
        read -r -p "Press Enter..."
        return
    fi

    read -r -p "Accept this delivery? (y/n): " accept_choice
    if [[ "${accept_choice,,}" == "y" ]]; then
        cash=$(( cash - delivery_active[deposit] ))
        echo ""
        echo -e "\e[1;36m*** DELIVERY ACCEPTED ***\e[0m"
        printf "Package: %s -> %s\n" "${delivery_active[package]}" "${delivery_active[dest]}"
        printf "Deadline: %s | Deposit deducted: \$%d\n" \
            "$(_delivery_format_hours "${delivery_active[deadline_hours]}")" \
            "${delivery_active[deposit]}"
        echo ""
        echo "Travel to ${delivery_active[dest]} and check your delivery status to complete!"
        play_sfx_mpg "win"
    else
        echo "Delivery declined."
        delivery_active=()
    fi
    read -r -p "Press Enter..."
}

# =============================================================================
# FLOW: Check delivery status / attempt completion
# =============================================================================
_delivery_status_flow() {
    clear_screen
    echo "============================================="
    echo "     DELIVERY STATUS"
    echo "============================================="

    local hrs_left hrs_elapsed
    hrs_left=$(_delivery_hours_remaining)
    hrs_elapsed=$(_delivery_hours_elapsed)

    printf "  Package:     %s\n" "${delivery_active[package]}"
    printf "  Destination: %s\n" "${delivery_active[dest]}"
    printf "  Current:     %s\n" "$location"
    printf "  Time Used:   %s\n" "$(_delivery_format_hours "$hrs_elapsed")"
    printf "  Time Left:   %s\n" "$(_delivery_format_hours "$hrs_left")"
    printf "  Reward:      \$%d\n" "${delivery_active[reward]}"
    echo "============================================="

    # --- deadline expired? ---
    if (( hrs_left <= 0 )); then
        echo ""
        echo -e "\e[1;31m*** DEADLINE EXPIRED! ***\e[0m"
        echo "You failed to deliver on time!"
        _delivery_fail
        read -r -p "Press Enter..."
        return
    fi

    # --- arrived at destination? ---
    if [[ "$location" == "${delivery_active[dest]}" ]]; then
        echo ""
        echo -e "\e[1;32m*** You are at the destination! ***\e[0m"
        echo ""
        read -r -p "Deliver the package now? (y/n): " deliver_choice
        if [[ "${deliver_choice,,}" == "y" ]]; then
            _delivery_complete
            read -r -p "Press Enter..."
        fi
        return
    fi

    # --- still en route ---
    echo ""
    echo "You need to travel to ${delivery_active[dest]} to complete this delivery."
    echo "Use the Travel option from the main menu to get there."
    local dist_remaining
    dist_remaining=$(_delivery_city_distance "$location" "${delivery_active[dest]}")
    printf "Approx. %d more cit%s to go. Each city hop costs ~4 hours.\n" \
        "$dist_remaining" "$( (( dist_remaining > 1 )) && echo 'ies' || echo 'y' )"
    read -r -p "Press Enter..."
}

# =============================================================================
# LOGIC: Delivery complete (success)
# =============================================================================
_delivery_complete() {
    local reward=${delivery_active[reward]}
    local deposit=${delivery_active[deposit]}
    local pkg="${delivery_active[package]}"
    local dest="${delivery_active[dest]}"

    # Respect scales with difficulty
    local respect_gain=$(( delivery_active[difficulty] * 8 + delivery_combo * 3 + 5 ))

    # Small random tip bonus (10 % chance for 25 % extra)
    local tip=0
    if (( RANDOM % 100 < 10 )); then
        tip=$(( reward / 4 ))
        reward=$(( reward + tip ))
    fi

    # Return deposit + reward
    cash=$(( cash + deposit + reward ))

    (( delivery_combo++ ))
    (( delivery_total_completed++ ))
    (( delivery_total_earned += reward ))

    clear_screen
    echo "============================================="
    echo -e "  \e[1;32m*** DELIVERY COMPLETE! ***\e[0m"
    echo "============================================="
    printf "  Package:     %s\n" "$pkg"
    printf "  Delivered to: %s\n" "$dest"
    echo "---------------------------------------------"
    printf "  Reward:      +\$%d\n" "$reward"
    (( tip > 0 )) && printf "  Tip Bonus:   +\$%d\n" "$tip"
    printf "  Deposit Back: +\$%d\n" "$deposit"
    printf "  Respect:     +%d\n" "$respect_gain"
    printf "  Streak:      %d deliveries\n" "$delivery_combo"
    echo "============================================="

    award_respect "$respect_gain"
    play_sfx_mpg "cash_register"

    delivery_active=()
}

# =============================================================================
# LOGIC: Delivery failed (timeout / abandoned)
# =============================================================================
_delivery_fail() {
    local deposit=${delivery_active[deposit]}
    local fail_wanted=${delivery_active[fail_wanted]}
    local pkg="${delivery_active[package]}"

    # Respect loss scales with difficulty
    local respect_loss=$(( delivery_active[difficulty] * 4 + 5 ))

    (( delivery_total_failed++ ))
    delivery_combo=0

    clear_screen
    echo "============================================="
    echo -e "  \e[1;31m*** DELIVERY FAILED! ***\e[0m"
    echo "============================================="
    printf "  Package:       %s\n" "$pkg"
    printf "  Deposit Lost:  -\$%d\n" "$deposit"
    printf "  Respect Lost:  -%d\n" "$respect_loss"
    if (( fail_wanted > 0 )); then
        printf "  Wanted Level:  +%d (suspicious cargo!)\n" "$fail_wanted"
        wanted_level=$(( wanted_level + fail_wanted ))
        (( wanted_level > 5 )) && wanted_level=5
    fi
    printf "  Streak Reset:  0\n"
    echo "============================================="

    player_respect=$(( player_respect - respect_loss ))
    (( player_respect < 0 )) && player_respect=0

    play_sfx_mpg "lose"

    delivery_active=()
}

# =============================================================================
# FLOW: Abandon delivery voluntarily
# =============================================================================
_delivery_abandon_flow() {
    clear_screen
    echo "============================================="
    echo "     ABANDON DELIVERY"
    echo "============================================="
    printf "  Package:  %s\n" "${delivery_active[package]}"
    printf "  Dest:     %s\n" "${delivery_active[dest]}"
    printf "  Deposit:  \$%d (will be forfeited)\n" "${delivery_active[deposit]}"
    if (( ${delivery_active[fail_wanted]} > 0 )); then
        printf "  Wanted:   +%d (suspicious cargo penalty)\n" "${delivery_active[fail_wanted]}"
    fi
    echo "  Streak will reset to 0."
    echo "============================================="
    read -r -p "Are you sure you want to abandon this delivery? (y/n): " confirm
    if [[ "${confirm,,}" == "y" ]]; then
        echo "You dump the package in a back alley..."
        _delivery_fail
    else
        echo "Delivery kept active."
    fi
    read -r -p "Press Enter..."
}

# =============================================================================
# PASSIVE TICK: Check deadline every game tick
# Hooks into passive_bounty_encounter (chains with other plugins).
# =============================================================================
_delivery_mission_tick() {
    [[ -z "${delivery_active[dest]:-}" ]] && return

    local hrs_left
    hrs_left=$(_delivery_hours_remaining)

    # Auto-fail on expiry (player is notified on next courier menu visit)
    if (( hrs_left <= 0 )); then
        _delivery_fail
        return
    fi

    # Urgency warning at 3 hours remaining
    if (( hrs_left <= 3 && hrs_left > 0 )); then
        echo -e "\e[1;33m[COURIER] Your ${delivery_active[package]} delivery deadline is approaching! ($(_delivery_format_hours "$hrs_left") left)\e[0m"
    fi
}

# --- Chain into passive_bounty_encounter without breaking other plugins ---
if command -v passive_bounty_encounter &>/dev/null; then
    eval "_orig_passive_bounty_$(declare -f passive_bounty_encounter)"
    passive_bounty_encounter() {
        _delivery_mission_tick
        _orig_passive_bounty_passive_bounty_encounter
    }
else
    passive_bounty_encounter() {
        _delivery_mission_tick
    }
fi

# =============================================================================
# SAVE / LOAD  (hooks into delivery_save_extra / delivery_load_extra)
# These hooks must be called from bta.sh's save_game() and load_game().
# =============================================================================
delivery_save_extra() {
    local save_path="$BASEDIR/$SAVE_DIR"
    mkdir -p "$save_path"

    # Scalar stats
    {
        echo "delivery_combo@@@${delivery_combo}"
        echo "delivery_total_completed@@@${delivery_total_completed}"
        echo "delivery_total_failed@@@${delivery_total_failed}"
        echo "delivery_total_earned@@@${delivery_total_earned}"
    } > "$save_path/delivery_stats.sav"

    # Active delivery (may be empty)
    if [[ -n "${delivery_active[dest]:-}" ]]; then
        {
            for key in "${!delivery_active[@]}"; do
                echo "${key}@@@${delivery_active[$key]}"
            done
        } > "$save_path/delivery_active.sav"
    else
        : > "$save_path/delivery_active.sav"
    fi
}

delivery_load_extra() {
    local save_path="$BASEDIR/$SAVE_DIR"

    # Reset to defaults
    delivery_active=()
    delivery_combo=0
    delivery_total_completed=0
    delivery_total_failed=0
    delivery_total_earned=0

    # Restore stats
    if [[ -f "$save_path/delivery_stats.sav" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -z "$line" ]] && continue
            local key="${line%%@@@*}"; local value="${line#*@@@}"
            case "$key" in
                "delivery_combo")             delivery_combo="$value" ;;
                "delivery_total_completed")   delivery_total_completed="$value" ;;
                "delivery_total_failed")      delivery_total_failed="$value" ;;
                "delivery_total_earned")      delivery_total_earned="$value" ;;
            esac
        done < "$save_path/delivery_stats.sav"
    fi

    # Restore active delivery
    if [[ -f "$save_path/delivery_active.sav" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -z "$line" ]] && continue
            local key="${line%%@@@*}"; local value="${line#*@@@}"
            delivery_active["$key"]="$value"
        done < "$save_path/delivery_active.sav"
    fi
}

echo "[Plugin] Express Courier delivery system loaded."
