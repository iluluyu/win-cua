#!/usr/bin/env bash
# install.sh - for local development: link this skill into a skill directory pi scans.
# End users normally install via:  pi install git:github.com/iluluyu/win-cua
# (pi auto-discovers skills/win-cua/SKILL.md from the package manifest)
set -euo pipefail

SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # .../win-cua/skills/win-cua

# candidate skill dirs pi scans (first existing wins)
for BASE in "${HOME}/.pi/agent/skills" "${HOME}/.claude/skills" "${HOME}/.agents/skills"; do
    if [ -d "$(dirname "$BASE")" ]; then
        mkdir -p "$BASE"
        ln -sfn "$SKILL_ROOT" "$BASE/win-cua"
        echo "installed: $BASE/win-cua -> $SKILL_ROOT"
        echo "done. restart pi sessions to load the new skill."
        exit 0
    fi
done
echo "no known skill directory found; create ~/.pi/agent/skills manually" >&2
exit 1
