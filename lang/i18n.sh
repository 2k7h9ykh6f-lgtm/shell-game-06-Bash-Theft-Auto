#!/bin/bash
# =============================================================================
# BTA Internationalization (i18n) Module
# =============================================================================
# Provides:
#   - _() translation function with fallback to English
#   - Automatic language detection from BTA_LANG env or config file
#   - Missing key tracking and reporting in debug mode
#   - Graceful degradation: returns the key itself if not found anywhere
#
# Usage:
#   Source this file after BASEDIR is set in bta.sh:
#     source "$BASEDIR/lang/i18n.sh"
#     _i18n_init
#
#   Then use in code:
#     echo "$(_ "menu_travel")"          # Simple string
#     printf "$(_ "death_respect_loss")" "$respect_loss"  # With format args
#
# Configuration:
#   BTA_LANG=ru  (env var, highest priority)
#   ~/.bta/lang  (config file, second priority)
#   Default: en
#
# Debug mode (BTA_DEBUG=1):
#   - Logs every missing key to bta_debug.log
#   - Tracks all missing keys in _i18n_missing_keys associative array
#   - Call _i18n_report to print summary (done automatically on cleanup)
# =============================================================================

# --- Configuration ---
# Language directory (relative to BASEDIR, set before sourcing this file)
_i18n_lang_dir="${BASEDIR:-.}/lang"

# Default language (fallback target)
_i18n_default_lang="en"

# Track missing keys: ["lang:key"]="count"
declare -gA _i18n_missing_keys=() 2>/dev/null || true

# Track all lookups for stats
_i18n_total_lookups=0
_i18n_fallback_count=0

# =============================================================================
# _i18n_resolve_lang — Determine the active language
# =============================================================================
# Priority: BTA_LANG env > ~/.bta/lang config > default (en)
# Normalizes to lowercase, validates against available files.
# =============================================================================
_i18n_resolve_lang() {
    local lang=""

    # 1. Environment variable (highest priority)
    if [[ -n "${BTA_LANG:-}" ]]; then
        lang="${BTA_LANG,,}"  # lowercase
    fi

    # 2. Config file
    if [[ -z "$lang" ]] && [[ -f "$HOME/.bta/lang" ]]; then
        lang="$(< "$HOME/.bta/lang")"
        lang="${lang%%[[:space:]]*}"  # strip whitespace
        lang="${lang,,}"
    fi

    # 3. Default
    if [[ -z "$lang" ]]; then
        lang="$_i18n_default_lang"
    fi

    # Validate: language file must exist (unless it's English, which is built-in)
    if [[ "$lang" != "en" ]] && [[ ! -f "$_i18n_lang_dir/${lang}.sh" ]]; then
        if [[ "${BTA_DEBUG:-0}" == "1" ]] && [[ -n "${BTA_DEBUG_LOG:-}" ]]; then
            echo "[i18n] Language file not found: ${lang}.sh — falling back to English" >> "$BTA_DEBUG_LOG"
        fi
        lang="en"
    fi

    BTA_LANG="$lang"
}

# =============================================================================
# _i18n_init — Load language files (call once at startup)
# =============================================================================
# Always loads English first (as base), then loads the target language on top.
# This ensures LANG_EN is always available for fallback.
# =============================================================================
_i18n_init() {
    # Resolve which language to use
    _i18n_resolve_lang

    # Always load English as the base (fallback)
    local en_file="$_i18n_lang_dir/en.sh"
    if [[ -f "$en_file" ]]; then
        source "$en_file"
    else
        # Critical: no English file means no translations at all
        echo "[i18n] WARNING: English language file not found at $en_file" >&2
        echo "[i18n] Translations will be unavailable; keys will be shown as-is." >&2
        return 1
    fi

    # Load target language (if not English)
    if [[ "$BTA_LANG" != "en" ]]; then
        local lang_file="$_i18n_lang_dir/${BTA_LANG}.sh"
        if [[ -f "$lang_file" ]]; then
            source "$lang_file"
            if [[ "${BTA_DEBUG:-0}" == "1" ]] && [[ -n "${BTA_DEBUG_LOG:-}" ]]; then
                echo "[i18n] Loaded language: $BTA_LANG (with English fallback)" >> "$BTA_DEBUG_LOG"
            fi
        fi
    else
        if [[ "${BTA_DEBUG:-0}" == "1" ]] && [[ -n "${BTA_DEBUG_LOG:-}" ]]; then
            echo "[i18n] Loaded language: en (default)" >> "$BTA_DEBUG_LOG"
        fi
    fi

    return 0
}

# =============================================================================
# _() — Main translation function
# =============================================================================
# Looks up a key in the current language. Falls back to English if missing.
# Returns the key itself as a last resort (so the UI is never blank).
#
# Usage:
#   echo "$(_ "menu_travel")"
#   printf "$(_ "death_respect_loss")" "$amount"
# =============================================================================
_() {
    local key="$1"
    (( _i18n_total_lookups++ )) 2>/dev/null || true

    # Build the variable name for the current language's associative array
    local lang_upper="${BTA_LANG^^}"
    local lang_var="LANG_${lang_upper}"

    # Check if the current language array exists and has this key
    if [[ "$BTA_LANG" != "en" ]]; then
        # Use eval to safely check associative array membership
        if eval "[[ -n \"\${${lang_var}[\"$key\"]+isset}\" ]]"; then
            eval "printf '%s' \"\${${lang_var}[\"$key\"]}\""
            return 0
        fi

        # --- FALLBACK: key missing in current language ---
        (( _i18n_fallback_count++ )) 2>/dev/null || true

        # Log to debug file
        if [[ "${BTA_DEBUG:-0}" == "1" ]] && [[ -n "${BTA_DEBUG_LOG:-}" ]]; then
            echo "[i18n] Missing key '${key}' in lang '${BTA_LANG}' — using English fallback" >> "$BTA_DEBUG_LOG"
        fi

        # Track missing key for end-of-session report
        local track_key="${BTA_LANG}:${key}"
        _i18n_missing_keys["$track_key"]=$(( ${_i18n_missing_keys["$track_key"]:-0} + 1 ))
    fi

    # Fall back to English
    if [[ -n "${LANG_EN[$key]+isset}" ]]; then
        printf '%s' "${LANG_EN[$key]}"
        return 0
    fi

    # Last resort: return the key itself (so the UI shows something)
    if [[ "${BTA_DEBUG:-0}" == "1" ]] && [[ -n "${BTA_DEBUG_LOG:-}" ]]; then
        echo "[i18n] CRITICAL: key '${key}' not found in ANY language file" >> "$BTA_DEBUG_LOG"
    fi
    printf '%s' "$key"
    return 1
}

# =============================================================================
# _i18n_report — Print summary of missing keys (for debug mode)
# =============================================================================
# Called automatically during cleanup when BTA_DEBUG=1.
# Prints a deduplicated list of all missing keys with hit counts.
# =============================================================================
_i18n_report() {
    [[ "${BTA_DEBUG:-0}" != "1" ]] && return 0
    [[ -z "${BTA_DEBUG_LOG:-}" ]] && return 0

    local report_file="$BTA_DEBUG_LOG"

    {
        printf '\n%s\n' "$(printf '=%.0s' {1..60})"
        printf '  i18n MISSING KEYS REPORT\n'
        printf '%s\n' "$(printf '=%.0s' {1..60})"
        printf ' Language:      %s\n' "$BTA_LANG"
        printf ' Total lookups: %d\n' "$_i18n_total_lookups"
        printf ' Fallbacks:     %d\n' "$_i18n_fallback_count"
        printf ' Unique missing keys: %d\n' "${#_i18n_missing_keys[@]}"
        printf '%s\n' "$(printf -- '-%.0s' {1..60})"

        if (( ${#_i18n_missing_keys[@]} > 0 )); then
            printf ' %-40s %s\n' "KEY" "HITS"
            printf ' %-40s %s\n' "---" "----"
            # Sort by key name for readability
            local sorted_keys=()
            while IFS= read -r k; do
                sorted_keys+=("$k")
            done < <(printf '%s\n' "${!_i18n_missing_keys[@]}" | sort)

            for k in "${sorted_keys[@]}"; do
                printf ' %-40s %d\n' "$k" "${_i18n_missing_keys[$k]}"
            done
        else
            printf ' (no missing keys — all translations present!)\n'
        fi

        printf '%s\n' "$(printf '=%.0s' {1..60})"
    } >> "$report_file"
}

# =============================================================================
# _i18n_set_lang — Change language at runtime
# =============================================================================
# Useful for a future in-game language switcher.
# Usage: _i18n_set_lang "ru"
# =============================================================================
_i18n_set_lang() {
    local new_lang="${1,,}"
    if [[ -f "$_i18n_lang_dir/${new_lang}.sh" ]]; then
        # Reset missing keys tracker
        _i18n_missing_keys=()
        _i18n_fallback_count=0
        _i18n_total_lookups=0

        BTA_LANG="$new_lang"
        source "$_i18n_lang_dir/${new_lang}.sh"

        if [[ "${BTA_DEBUG:-0}" == "1" ]] && [[ -n "${BTA_DEBUG_LOG:-}" ]]; then
            echo "[i18n] Language changed to: $new_lang" >> "$BTA_DEBUG_LOG"
        fi
        return 0
    else
        echo "[i18n] Language file not found: ${new_lang}.sh" >&2
        return 1
    fi
}

# =============================================================================
# _i18n_available_langs — List all available language codes
# =============================================================================
_i18n_available_langs() {
    local langs=()
    for f in "$_i18n_lang_dir"/*.sh; do
        [[ -f "$f" ]] || continue
        local name
        name="$(basename "$f" .sh)"
        [[ "$name" == "i18n" ]] && continue  # skip the loader itself
        langs+=("$name")
    done
    printf '%s\n' "${langs[@]}"
}
