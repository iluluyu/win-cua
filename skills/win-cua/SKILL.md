---
name: win-cua
description: >-
  Control and inspect Windows desktop applications from WSL via pi. Use when the
  user asks to operate, inspect, automate, or read a Windows-side app (not WSL/Linux
  apps): "帮我看/点/打开 Windows 上的某某应用", "check my Windows Notepad/WeChat/Edge",
  "automate that Windows GUI", "computer use", "win-cua". Zero-install: works through
  powershell.exe WSL interop. Layer-1 UIA actions run in the background and do NOT
  steal the user's focus or mouse.
license: MIT
compatibility: WSL2 (Windows 11 recommended) with WSL interop enabled; no Windows-side installation required
---

# win-cua — Windows Computer Use from WSL

You are running in WSL. The user's real desktop is **Windows**. This skill drives
Windows applications through `powershell.exe` interop — **nothing is installed on
the Windows side**.

## The one rule that matters: DO NOT STEAL THE USER'S FOCUS/MOUSE

The user is actively using their machine. Every capability here is layered:

- **L1 — UIA patterns (default, always try first).** Background COM-channel
  operations. No focus, no mouse movement, no window activation. The scripts
  verify and report `focus untouched: True`.
- **L2 — geometry (focus-preserving).** Move/resize (`SWP_NOACTIVATE`),
  minimize, background window capture via `PrintWindow`. Still no focus steal.
- **L3 — physical input (`input.ps1`, LAST RESORT).** Real SendInput mouse/
  keyboard. **Requires explicit user approval in the conversation first** ("I
  need to move your real mouse to X — approve?"), then pass `-ConfirmPhysical`.
  Never run L3 silently. Never while the user may be typing.

## Hard safety rules (never do, at any layer)

1. Never invoke shutdown/restart/sign-out, `Remove-Item`/`rm`-style deletes,
   registry writes, service control, user/password dialogs, or financial/
   payment confirmation buttons without explicit user confirmation.
2. Never type passwords, tokens, or 2FA codes — ask the user to type them.
3. Never close a window with unsaved work (`act -Action close`) without asking.
4. `act -Action setvalue` on any field that looks sensitive (search bars fine,
   password boxes never).
5. The lock screen, UAC prompts, and elevated (admin) apps cannot be driven —
   that is a Windows security boundary. Say so instead of trying workarounds.

## Entry point

Scripts are in this skill's directory. Resolve paths relative to this SKILL.md
(pi loads skills from the package's `skills/win-cua/` directory):

```bash
SKILL_DIR="<this skill's directory>"   # e.g. ~/.pi/agent/git/github.com/iluluyu/win-cua/skills/win-cua
"$SKILL_DIR/scripts/run.sh" windows                 # list top-level windows
```

If the skill directory is unknown, locate it:
`find ~/.pi/agent -type d -name win-cua -path '*skills*' 2>/dev/null`

Perceive → act → verify, always in that order:

```bash
# 1) PERCEIVE (all background, zero focus impact)
"$SKILL_DIR/scripts/run.sh" windows                 # what's open (pid/exe/title/rect)
"$SKILL_DIR/scripts/run.sh" tree -Name "Notepad" -Interactive   # actionable controls only
"$SKILL_DIR/scripts/run.sh" tree -Name "Notepad" -Depth 6       # full tree when needed
"$SKILL_DIR/scripts/run.sh" text -Name "Notepad" -MaxChars 3000 # read document/field text

# 2) ACT (L1, background)
"$SKILL_DIR/scripts/run.sh" act -Name "Notepad" -Target "File" -Action invoke   # buttons, menu items
"$SKILL_DIR/scripts/run.sh" act -Name "Settings" -Target "Dark mode" -Action toggle
"$SKILL_DIR/scripts/run.sh" act -Name "Dialog" -Target "OK" -Action invoke
"$SKILL_DIR/scripts/run.sh" act -Name "Editor" -Target "Text Editor" -Action setvalue -Value "hi"

# 3) VERIFY — re-run tree/text after acting; UIA state is truth, not guesses.
```

Screenshots (L2, no focus impact; note: current default model cannot view
images — use them as artifacts for the user, not for your own perception):

```bash
"$SKILL_DIR/scripts/run.sh" screenshot -Window "Notepad"        # background window capture
"$SKILL_DIR/scripts/run.sh" screenshot -All                      # whole desktop
# output line "READABLE_FROM_WSL: /mnt/c/..." → offer path to the user
```

Geometry (L2): `"$SKILL_DIR/scripts/run.sh" geom -ListMonitors`,
`geom -Move -Name X -X 2560 -Y 100` (no activation), `geom -Minimize -Name X`.

L3 (only after explicit approval): `"$SKILL_DIR/scripts/run.sh" input -MouseClick -X 100 -Y 200`
prints a dry run; add `-ConfirmPhysical` to execute. Coordinates come from the
`rect=(x,y,w,h)` values printed by `tree`/`windows` (element center = usable
click point).

## Practical notes

- `-Name` matches by substring of the window title, case-insensitive. Ambiguous
  matches print candidates — pick `-PidNum` from `windows` output instead.
- If `tree` shows no useful controls, the app may be Electron/Canvas/game-like
  with a sparse accessibility tree → perception falls back to screenshots for
  the user + L3 input for acting (ask approval).
- Chinese window titles work (UTF-8 handled by run.sh).
- Every perception/act script prints `focus untouched: True/False` at the end —
  check it; if it ever says False for an L1 op, stop and investigate.
- Browsers/Edge on Windows: prefer this skill's UIA tree only if the user asks
  about the Windows browser specifically; normal web work stays in agent_browser.
- If the machine is locked or RDP-disconnected, screenshots come back black and
  UIA still works — tell the user instead of retrying.
