#!/usr/bin/env bash
# run.sh - WSL-side entry point for win-cua PowerShell scripts.
# Usage (from anywhere, typically the skill directory): <path-to>/run.sh <script-name> [args...]
#   run.sh windows
#   run.sh tree -Name Notepad -Interactive
#   run.sh text -Name "wheeltest" -MaxChars 500
#   run.sh act -Name Settings -Target "Dark mode" -Action toggle
#   run.sh screenshot -Window Notepad
#   ./run.sh geom -ListMonitors
#   ./run.sh input -MouseClick -X 100 -Y 200   # dry run unless -ConfirmPhysical
set -euo pipefail

SCRIPT_NAME="${1:-help}"
[[ $# -gt 0 ]] && shift

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PS1_FILE="$REPO_DIR/scripts/ps/${SCRIPT_NAME}.ps1"

if [[ ! -f "$PS1_FILE" ]]; then
    echo "win-cua: unknown script '$SCRIPT_NAME'"
    echo "available: $(ls "$REPO_DIR/scripts/ps/" | sed 's/\.ps1$//' | tr '\n' ' ')"
    exit 1
fi

WIN_PATH="$(wslpath -w "$PS1_FILE")"
TIMEOUT="${WIN_CUA_TIMEOUT:-90}"

# Engine selection: pwsh 7 is ~40% faster per invocation (verified: ~580ms vs ~995ms).
# Preference: $WIN_CUA_PS env > pwsh.exe on PATH > known install path > powershell.exe (5.1).
PS_ENGINE="${WIN_CUA_PS:-}"
if [[ -z "$PS_ENGINE" ]]; then
    if command -v pwsh.exe >/dev/null 2>&1; then
        PS_ENGINE="pwsh.exe"
    elif [[ -x "/mnt/c/Program Files/PowerShell/7/pwsh.exe" ]]; then
        PS_ENGINE="/mnt/c/Program Files/PowerShell/7/pwsh.exe"
    else
        PS_ENGINE="powershell.exe"
    fi
fi

# powershell.exe/pwsh.exe inherits a UNC cwd from WSL; some cmdlets warn about it.
# Harmless, but we silence it by not relying on cwd anywhere.
OUT="$(timeout "$TIMEOUT" "$PS_ENGINE" -NoProfile -ExecutionPolicy Bypass \
      -File "$WIN_PATH" "$@" 2>&1 | tr -d '\r')" || RC=$? || true
RC="${RC:-0}"
echo "$OUT"

# Convert SAVED: C:\... lines to /mnt/c/... so the agent can `read` the file directly
echo "$OUT" | { grep '^SAVED: ' || true; } | sed 's|^SAVED: ||' | while read -r p; do
    WSL_P="${p//\\//}"
    drive="${WSL_P:0:1}"; drive="${drive,,}"
    echo "READABLE_FROM_WSL: /mnt/$drive${WSL_P:2}"
done

exit "$RC"
