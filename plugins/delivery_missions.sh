#!/bin/bash
# =============================================================================
# BTA Plugin: Courier Jobs (Repeatable Delivery Missions)
# =============================================================================
# Name:        delivery_missions.sh
# Version:     1.0.0
# Description: Adds a repeatable courier/delivery job. Accept a contract at the
#              Courier Depot, then use the normal Travel menu to reach the target
#              city before the in-game deadline. Arrive in time -> cash reward.
#              Miss the deadline -> cash penalty. Reuses the city/travel system,
#              the in-game clock (run_clock / game_day / game_hour), and the
#              mission-board UI pattern from for-devs/code_samples/misson.sh.
#
# INSTALL: Drop into plugins/ (auto-sourced on startup).
# MENU INTEGRATION (already added to bta.sh main loop):
#   echo "22. Courier Jobs    |"
#   22) delivery_missions_board;;
#
# LOAD ORDER: plugins load alphabetically. This file ("d...") loads AFTER
# bounty_contracts.sh ("b...") and BEFORE stock_market.sh ("s..."). It therefore
# cooperatively CHAINS the bounty_* save/load hooks and passive_bounty_encounter
# (capture-with-`declare -f`) instead of overwriting them, so the bounty-contract
# and stock-market plugins keep working.
# =============================================================================

[[ -n "${PLUGIN_DELIVERY_LOADED:-}" ]] && return
PLUGIN_DELIVERY_LOADED=1

# ── State ────────────────────────────────────────────────────────────────────
delivery_active="false"
delivery_origin=""
delivery_dest=""
delivery_item=""
delivery_reward=0
delivery_penalty=0
delivery_deadline_abs=0     # game_day*24 + game_hour at which the job expires
delivery_budget_hours=0     # original time budget, kept for display
delivery_completed_count=0
delivery_failed_count=0

_delivery_init() {
    delivery_active="false"
    delivery_origin=""
    delivery_dest=""
    delivery_item=""
    delivery_reward=0
    delivery_penalty=0
    delivery_deadline_abs=0
    delivery_budget_hours=0
    delivery_completed_count=0
    delivery_failed_count=0
}
_delivery_init

# ── Helpers ──────────────────────────────────────────────────────────────────
_delivery_now_abs() { echo $(( game_day * 24 + game_hour )); }

_delivery_clear() {
    delivery_active="false"
    delivery_origin=""
    delivery_dest=""
    delivery_item=""
    delivery_reward=0
    delivery_penalty=0
    delivery_deadline_abs=0
    delivery_budget_hours=0
}

# ── Generate + accept a fresh randomized contract ────────────────────────────
_delivery_make_offer() {
    if [[ "$delivery_active" == "true" ]]; then
        echo "You already have an active courier job. Finish or abandon it first."
        read -r -p "Press Enter..."
        return
    fi

    local -a cities=("Los Santos" "San Fierro" "Las Venturas" "Vice City" "Liberty City" "Blaine County")
    local -a packages=("Sealed Package" "Legal Documents" "Medical Supplies" "Car Parts" "Mystery Crate")

    # Destination: a random city that isn't the current one.
    local dest="$location"
    while [[ "$dest" == "$location" ]]; do
        dest="${cities[RANDOM % ${#cities[@]}]}"
    done

    local item="${packages[RANDOM % ${#packages[@]}]}"
    local budget=$(( RANDOM % 9 + 8 ))        # 8..16 in-game hours
    local reward=$(( RANDOM % 351 + 250 ))    # $250..$600
    (( budget <= 10 )) && reward=$(( reward + 100 ))   # tighter deadlines pay more
    local penalty=$(( reward / 3 ))
    (( penalty < 50 )) && penalty=50

    delivery_active="true"
    delivery_origin="$location"
    delivery_dest="$dest"
    delivery_item="$item"
    delivery_reward="$reward"
    delivery_penalty="$penalty"
    delivery_budget_hours="$budget"
    delivery_deadline_abs=$(( $(_delivery_now_abs) + budget ))

    local dl_day=$(( delivery_deadline_abs / 24 ))
    local dl_hour=$(( delivery_deadline_abs % 24 ))

    clear_screen
    echo -e "\e[1;36m--- Courier Job Accepted ---\e[0m"
    printf " Cargo:      %s\n" "$delivery_item"
    printf " From:       %s\n" "$delivery_origin"
    printf " Deliver to: \e[1;33m%s\e[0m\n" "$delivery_dest"
    printf " Deadline:   within %d hours  (by Day %d, %02d:00)\n" "$delivery_budget_hours" "$dl_day" "$dl_hour"
    printf " Reward:     \e[1;32m\$%d\e[0m   |  Late penalty: \e[1;31m\$%d\e[0m\n" "$delivery_reward" "$delivery_penalty"
    echo "----------------------------------------------"
    echo "Use the Travel menu to drive to $delivery_dest before the deadline."
    play_sfx_mpg "car_start"
    read -r -p "Press Enter..."
}

# ── Settle the active job (success / failure). Prints ONLY when it settles. ──
_delivery_check() {
    [[ "$delivery_active" == "true" ]] || return 0

    local now_abs; now_abs=$(_delivery_now_abs)

    # SUCCESS: in the destination city, on or before the deadline.
    if [[ "$location" == "$delivery_dest" ]] && (( now_abs <= delivery_deadline_abs )); then
        local reward="$delivery_reward"
        cash=$(( cash + reward ))
        delivery_completed_count=$(( delivery_completed_count + 1 ))
        clear_screen
        echo -e "\e[1;32m*** DELIVERY COMPLETE ***\e[0m"
        printf " You dropped off the %s in %s on time.\n" "$delivery_item" "$delivery_dest"
        printf " Payment received: \e[1;32m\$%d\e[0m\n" "$reward"
        play_sfx_mpg "cash_register"
        play_sfx_mpg "win"
        award_respect $(( RANDOM % 16 + 10 ))   # 10..25 respect
        _delivery_clear
        read -r -p "Press Enter..."
        return 0
    fi

    # FAILURE: deadline passed and the cargo was not delivered.
    if (( now_abs > delivery_deadline_abs )); then
        local penalty="$delivery_penalty"
        cash=$(( cash - penalty ))
        (( cash < 0 )) && cash=0
        delivery_failed_count=$(( delivery_failed_count + 1 ))
        player_respect=$(( player_respect - 10 ))
        (( player_respect < 0 )) && player_respect=0
        clear_screen
        echo -e "\e[1;31m*** DELIVERY FAILED ***\e[0m"
        printf " The %s for %s didn't arrive in time. The client is furious.\n" "$delivery_item" "$delivery_dest"
        printf " Penalty: \e[1;31m-\$%d\e[0m   (and you lost 10 Respect)\n" "$penalty"
        play_sfx_mpg "lose"
        play_sfx_mpg "police_siren"
        _delivery_clear
        read -r -p "Press Enter..."
        return 0
    fi

    return 0
}

# ── Abandon the current job ──────────────────────────────────────────────────
_delivery_abandon() {
    [[ "$delivery_active" == "true" ]] || return
    read -r -p "Abandon the current courier job? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        _delivery_clear
        player_respect=$(( player_respect - 5 ))
        (( player_respect < 0 )) && player_respect=0
        echo "Job abandoned. You lost 5 Respect."
        read -r -p "Press Enter..."
    fi
}

# ── Main board (menu entry point) ────────────────────────────────────────────
delivery_missions_board() {
    run_clock 1
    while true; do
        _delivery_check          # settle first so the board is always up to date
        clear_screen
        echo -e "\e[1;33m--- Courier Depot ($location) ---\e[0m"
        printf " Completed: %d   |   Failed: %d\n" "$delivery_completed_count" "$delivery_failed_count"
        echo "=============================================="
        if [[ "$delivery_active" == "true" ]]; then
            local now_abs; now_abs=$(_delivery_now_abs)
            local remaining=$(( delivery_deadline_abs - now_abs ))
            (( remaining < 0 )) && remaining=0
            local dl_day=$(( delivery_deadline_abs / 24 ))
            local dl_hour=$(( delivery_deadline_abs % 24 ))
            echo -e " Active job: \e[1;36m$delivery_item\e[0m"
            printf "   Deliver to: \e[1;33m%s\e[0m\n" "$delivery_dest"
            printf "   Deadline:   Day %d, %02d:00   (\e[1;33m%dh left\e[0m)\n" "$dl_day" "$dl_hour" "$remaining"
            printf "   Reward: \e[1;32m\$%d\e[0m  |  Late penalty: \e[1;31m\$%d\e[0m\n" "$delivery_reward" "$delivery_penalty"
            echo "----------------------------------------------"
            echo " Travel to the destination city to complete it."
            echo "=============================================="
            echo " 1. Abandon current job"
            echo " B. Back"
            read -r -p "Choice: " choice
            case "$choice" in
                1) _delivery_abandon;;
                'b'|'B') return;;
                *) echo "Invalid."; sleep 1;;
            esac
        else
            echo " No active job. A fresh contract is ready when you are."
            echo "=============================================="
            echo " 1. Accept a new courier job"
            echo " B. Back"
            read -r -p "Choice: " choice
            case "$choice" in
                1) _delivery_make_offer;;
                'b'|'B') return;;
                *) echo "Invalid."; sleep 1;;
            esac
        fi
    done
}

# ── Passive tick: auto-settle on arrival / deadline every main-loop iteration ─
_delivery_tick() {
    _delivery_check
}

# Chain onto any existing passive_bounty_encounter (from bounty_contracts.sh).
_delivery_prev_passive="$(declare -f passive_bounty_encounter)"
if [[ -n "$_delivery_prev_passive" ]]; then
    eval "${_delivery_prev_passive/passive_bounty_encounter/_delivery_orig_passive}"
fi
unset _delivery_prev_passive
passive_bounty_encounter() {
    _delivery_tick
    command -v _delivery_orig_passive >/dev/null 2>&1 && _delivery_orig_passive
}

# ── Save / Load (scalar state) — chain the bounty_* hook slot cooperatively ──
_delivery_save() {
    local save_path="$BASEDIR/$SAVE_DIR"
    mkdir -p "$save_path" 2>/dev/null
    {
        echo "delivery_active@@@${delivery_active}"
        echo "delivery_origin@@@${delivery_origin}"
        echo "delivery_dest@@@${delivery_dest}"
        echo "delivery_item@@@${delivery_item}"
        echo "delivery_reward@@@${delivery_reward}"
        echo "delivery_penalty@@@${delivery_penalty}"
        echo "delivery_deadline_abs@@@${delivery_deadline_abs}"
        echo "delivery_budget_hours@@@${delivery_budget_hours}"
        echo "delivery_completed_count@@@${delivery_completed_count}"
        echo "delivery_failed_count@@@${delivery_failed_count}"
    } > "$save_path/delivery.sav"
}

_delivery_load() {
    local save_path="$BASEDIR/$SAVE_DIR"
    _delivery_init
    [[ -f "$save_path/delivery.sav" ]] || return
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue
        local key="${line%%@@@*}"; local value="${line#*@@@}"
        case "$key" in
            "delivery_active") delivery_active="$value";;
            "delivery_origin") delivery_origin="$value";;
            "delivery_dest") delivery_dest="$value";;
            "delivery_item") delivery_item="$value";;
            "delivery_reward") delivery_reward="$value";;
            "delivery_penalty") delivery_penalty="$value";;
            "delivery_deadline_abs") delivery_deadline_abs="$value";;
            "delivery_budget_hours") delivery_budget_hours="$value";;
            "delivery_completed_count") delivery_completed_count="$value";;
            "delivery_failed_count") delivery_failed_count="$value";;
        esac
    done < "$save_path/delivery.sav"
}

_delivery_prev_save="$(declare -f bounty_save_extra)"
if [[ -n "$_delivery_prev_save" ]]; then
    eval "${_delivery_prev_save/bounty_save_extra/_delivery_orig_save}"
fi
unset _delivery_prev_save
bounty_save_extra() {
    command -v _delivery_orig_save >/dev/null 2>&1 && _delivery_orig_save
    _delivery_save
}

_delivery_prev_load="$(declare -f bounty_load_extra)"
if [[ -n "$_delivery_prev_load" ]]; then
    eval "${_delivery_prev_load/bounty_load_extra/_delivery_orig_load}"
fi
unset _delivery_prev_load
bounty_load_extra() {
    command -v _delivery_orig_load >/dev/null 2>&1 && _delivery_orig_load
    _delivery_load
}

echo "[Plugin] Courier Jobs (delivery missions) loaded."
