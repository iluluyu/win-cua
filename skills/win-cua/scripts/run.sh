#!/usr/bin/env bash
# run.sh - WSL-side entry point for win-cua PowerShell scripts.
# Usage: run.sh <script> [args...]  e.g. run.sh tree -Name Notepad -Interactive
# Scripts: windows tree text act screenshot geom input (input is dry-run unless -ConfirmPhysical)
set -euo pipefail

SCRIPT_NAME="${1:-help}"
[[ $# -gt 0 ]] && shift

if [[ ! "$SCRIPT_NAME" =~ ^[a-z]+$ ]]; then
    echo "win-cua: invalid script name '$SCRIPT_NAME'"
    exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PS1_FILE="$REPO_DIR/scripts/ps/${SCRIPT_NAME}.ps1"

if [[ ! -f "$PS1_FILE" ]]; then
    echo "win-cua: unknown script '$SCRIPT_NAME'"
    echo "available: $(ls "$REPO_DIR/scripts/ps/" | sed 's/\.ps1$//' | grep -v '^common$' | tr '\n' ' ')"
    exit 1
fi

WIN_PATH="$(wslpath -w "$PS1_FILE")"
TIMEOUT="${WIN_CUA_TIMEOUT:-90}"

# Engine: pwsh 7 preferred (~40% faster, verified ~580ms vs ~995ms); falls back to 5.1.
# Override with WIN_CUA_PS. UIA/WinForms/PInvoke verified on both engines.
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
