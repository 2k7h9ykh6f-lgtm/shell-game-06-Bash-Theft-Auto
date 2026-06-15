#!/usr/bin/env bash
#
# lang-diff.sh — translation coverage report for Bash Theft Auto
#
# Bash Theft Auto has no key-based message catalog: each language is a full,
# hand-translated copy of the main script (install-languages/<lang>-bta.sh).
# A line "renders as English" to the player when its translated copy still
# contains the original English string verbatim.
#
# This DEV-ONLY tool compares a translated copy against the English source
# (bta.sh) and lists every user-facing line that is still untranslated — the
# practical equivalent of a "missing-key list". It is read-only: it never
# modifies bta.sh, the language files, or install-lang.sh.
#
# Usage:
#   ./for-devs/lang-diff.sh <lang|path> [--source <bta.sh>]
#
#   <lang>   one of: ar cz pl ru sk   (en is the source — nothing to diff)
#   <path>   or a direct path to any *-bta.sh copy
#   --source override the English source (default: ../bta.sh)
#
# Examples:
#   ./for-devs/lang-diff.sh cz
#   ./for-devs/lang-diff.sh ru
#   ./for-devs/lang-diff.sh install-languages/pl-bta.sh --source bta.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LANG_DIR="$REPO_ROOT/install-languages"

SOURCE="$REPO_ROOT/bta.sh"
TARGET=""

usage() {
    sed -n '2,28p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

# --- resolve a language code to its translated file (names are inconsistent) ---
resolve_lang() {
    case "$1" in
        ar) echo "$LANG_DIR/arabic-bta.sh" ;;
        cz) echo "$LANG_DIR/cz-bta.sh" ;;
        pl) echo "$LANG_DIR/pl-bta.sh" ;;
        ru) echo "$LANG_DIR/ru-bta.sh" ;;
        sk) echo "$LANG_DIR/sk-bta.sh" ;;
        en) echo "__EN__" ;;
        *)  echo "" ;;
    esac
}

# --- parse args ---
[[ $# -eq 0 ]] && usage 1
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage 0 ;;
        --source)  SOURCE="${2:?--source needs a path}"; shift 2 ;;
        -*)        echo "Unknown option: $1" >&2; usage 1 ;;
        *)
            if [[ -z "$TARGET" ]]; then
                if [[ -f "$1" ]]; then
                    TARGET="$1"
                else
                    resolved="$(resolve_lang "$1")"
                    if [[ "$resolved" == "__EN__" ]]; then
                        echo "en is the source language — nothing to compare."
                        exit 0
                    elif [[ -n "$resolved" ]]; then
                        TARGET="$resolved"
                    else
                        echo "Unknown language/file: $1" >&2
                        echo "Known languages: ar cz pl ru sk" >&2
                        exit 1
                    fi
                fi
            else
                echo "Unexpected extra argument: $1" >&2
                usage 1
            fi
            shift
            ;;
    esac
done

[[ -z "$TARGET" ]] && { echo "No language/file given." >&2; usage 1; }
[[ -f "$SOURCE" ]] || { echo "Source not found: $SOURCE" >&2; exit 1; }
[[ -f "$TARGET" ]] || { echo "Target not found: $TARGET" >&2; exit 1; }

echo "Comparing $(basename "$TARGET")  against  $(basename "$SOURCE")"
echo

# The awk program below extracts the *executed* prose strings (what echo/printf
# actually prints) from each file. It is comment-aware and variable-aware so it
# ignores trailing "# English" comments, pure $variables, and color codes.
#
# Pass 1 (source): collect the set of English prose strings.
# Pass 2 (target): flag any output line whose prose string is still in that set.
# A single quote is injected as `sq` so the program text needs no apostrophes.
awk -v sq="'" -v fname="$(basename "$TARGET")" '
# Remove $(...), ${...}, $name and \escape / ANSI codes before judging "prose".
function strip_vars(s,   t) {
    t = s
    gsub(/\$\([^)]*\)/, "", t)
    gsub(/\$\{[^}]*\}/, "", t)
    gsub(/\$[A-Za-z_][A-Za-z0-9_]*/, "", t)
    gsub(/\\[0-9][0-9][0-9]/, "", t)
    gsub(/\\x[0-9A-Fa-f][0-9A-Fa-f]/, "", t)
    gsub(/\\[a-zA-Z]/, "", t)
    gsub(/%[-+ #0-9.*]*[diouxXeEfgGaAcsbq%]/, "", t)   # printf format specifiers
    return t
}

# Prose = at least two real letters once variables/escapes/formats are removed.
function is_prose(s,   t) {
    if (s ~ /:\/\//) return 0            # URLs are never translatable
    t = strip_vars(s)
    gsub(/[^A-Za-z]/, "", t)
    return (length(t) >= 2)
}

# Treat a line as user-facing only when echo/printf is at a real command
# position (start of line, or after ; { then do else) — never when it appears
# inside $( ), $(( )), or the right-hand side of an assignment.
function is_output_line(line) {
    if (line ~ /^[[:space:]]*(echo|printf)([[:space:]]|$)/) return 1
    if (line ~ /[;{][[:space:]]*(echo|printf)([[:space:]]|$)/) return 1
    if (line ~ /(^|[^A-Za-z0-9_])(then|do|else)[[:space:]]+(echo|printf)([[:space:]]|$)/) return 1
    if (line ~ /^[[:space:]]*read[[:space:]]/ && line ~ /-p/) return 1
    return 0
}

# Walk one line char-by-char, tracking quote state, capturing each quoted
# literal. Stops at an unquoted "#" (a real shell comment). mode "en" fills the
# source set; mode "tr" flags target lines whose literal is still English.
function scan(line, mode,   i, n, ch, prev, inq, q, buf, c2, depth) {
    if (!is_output_line(line)) return
    n = length(line); inq = 0; q = ""; buf = ""; prev = ""
    for (i = 1; i <= n; i++) {
        ch = substr(line, i, 1)
        if (inq) {
            # consume a balanced $( ... ) as one unit so its inner quotes do
            # not prematurely close the surrounding string literal
            if (ch == "$" && substr(line, i+1, 1) == "(") {
                depth = 1; buf = buf "$("; i += 2
                while (i <= n && depth > 0) {
                    c2 = substr(line, i, 1)
                    if (c2 == "(") depth++
                    else if (c2 == ")") depth--
                    buf = buf c2; i++
                }
                i--; prev = ")"; continue
            }
            if (ch == "\\") { buf = buf ch substr(line, i+1, 1); i++; prev = ""; continue }
            if (ch == q) {
                if (is_prose(buf)) {
                    if (mode == "en") {
                        if (!(buf in en)) { en[buf] = 1; ne++ }
                    } else if ((buf in en) && !(FNR in shown)) {
                        shown[FNR] = 1; u++
                        disp = $0
                        sub(/^[ \t]+/, "", disp)
                        if (length(disp) > 100) disp = substr(disp, 1, 100) "..."
                        printf("  L%-6d %s\n", FNR, disp)
                    }
                }
                inq = 0; q = ""; buf = ""; prev = ch; continue
            }
            buf = buf ch; prev = ch; continue
        } else {
            if (ch == "\"" || ch == sq) { inq = 1; q = ch; buf = ""; prev = ch; continue }
            if (ch == "#" && (prev == "" || prev == " " || prev == "\t")) break
            prev = ch
        }
    }
}

FNR == NR { scan($0, "en"); next }   # first file = English source
          { scan($0, "tr")       }   # second file = translated copy

END {
    if (u == 0)
        printf("[%s] fully translated — 0 untranslated lines / %d translatable strings in source\n", fname, ne)
    else
        printf("\n[%s] %d untranslated line(s) / %d translatable strings in source\n", fname, u, ne)
}
' "$SOURCE" "$TARGET"
