---
name: win-cua
description: >-
  Control and inspect Windows desktop applications from inside WSL. Use when the
  user asks to operate, inspect, automate, or read a Windows-side app (not WSL/Linux
  apps): "帮我看/点/打开 Windows 上的某某应用", "check my Windows Notepad/WeChat/Edge",
  "automate that Windows GUI", "computer use", "win-cua". Zero-install: works through
  powershell.exe WSL interop. Layer-1 UIA actions run in the background and do NOT
  steal the user's focus or mouse.
compatibility: WSL2 (Windows 11 recommended) with WSL interop enabled; no Windows-side installation required
---

# win-cua — Windows Computer Use from WSL

win-cua = Windows + CUA (Computer-Use Agent).
A skill for any agent running inside WSL with bash access (any Agent Skills compatible harness) to drive Windows applications via `powershell.exe` interop — nothing installed on Windows.

## Three-layer execution model (Never steal user focus/mouse)
- **L1 — UIA patterns (default, always try first)**: Background COM operations. Never steals focus or mouse. Reports `focus untouched: True`.
- **L2 — geometry**: Move/resize (`SWP_NOACTIVATE`), minimize, background window capture (`PrintWindow`). Never steals focus.
- **L3 — physical input (last resort)**: Real SendInput. **Requires explicit user approval in conversation first** + `-ConfirmPhysical`.

## Hard safety rules (never do, at any layer)
1. Never invoke shutdown/restart/sign-out, `Remove-Item`/`rm`-style deletes, registry writes, service control, user/password dialogs, or financial/payment confirmation buttons without explicit user confirmation.
2. Never type passwords, tokens, or 2FA codes — ask the user to type them.
3. Never close a window with unsaved work (`act -Action close`) without asking.
4. Never `act -Action setvalue` on any field that looks sensitive (search bars fine, password boxes never).
5. The lock screen, UAC prompts, and elevated (admin) apps cannot be driven — that is a Windows security boundary. Say so instead of trying workarounds.

## Entry point & commands
```bash
SKILL_DIR="<this-skill-dir>" # e.g. .agents/skills/win-cua (project) or ~/.agents/skills/win-cua
# Locate if unknown: find ~ -maxdepth 5 -type d -name win-cua -path '*skills*' 2>/dev/null
RUN="$SKILL_DIR/scripts/run.sh"

# 1) Perceive (L1/L2 background, zero focus impact)
"$RUN" windows                                    # list open windows (pid/exe/title/rect)
"$RUN" tree -Name "Notepad" -Interactive          # actionable controls (-Depth 6 goes deeper; default 4)
"$RUN" text -Name "Notepad" -MaxChars 3000        # read document/field text
"$RUN" screenshot -Window "Notepad"               # background capture (-All desktop / -Region "x,y,w,h" / -Out <path>)
"$RUN" geom -ListMonitors                         # geometry (-Move -X/-Y/-W/-H / -Minimize / -Restore)

# 2) Act (L1 background). Actions: invoke|toggle|expand|collapse|select|setvalue|close;
#    -ControlType <type> (e.g. Button) narrows the target search.
"$RUN" act -Name "Notepad" -Target "File" -Action invoke
"$RUN" act -Name "Settings" -Target "Dark mode" -Action toggle
"$RUN" act -Name "Editor" -Target "Text Editor" -Action setvalue -Value "hi"

# 3) Verify: re-run tree/text after acting; UIA state is truth.
# L3 (last resort, explicit approval required; dry-run until -ConfirmPhysical):
#   "$RUN" input -MouseClick -X 100 -Y 200 -ConfirmPhysical   # -Keys uses SendKeys syntax, e.g. "^s"
```

## Practical notes
- Ambiguous `-Name` prints candidates → use `-PidNum` from `windows` output instead
  (accepted by all window-targeting commands: act/tree/text/geom/screenshot).
- Sparse accessibility trees (Electron/Canvas/games) → fall back to screenshot + L3 (ask approval).
- Chinese window titles work (UTF-8 handled automatically).
- Check `focus untouched: True` in output; if False for an L1 action, stop and investigate.
  (`windows` prints a `foreground:` line instead; `geom -Restore` is the one L2 action that
  activates the window on purpose — it reports False by design.)
