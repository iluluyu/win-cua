# win-cua

**English** | [简体中文](README.zh-CN.md)

> win-cua = Windows + CUA (Computer-Use Agent)

Control and inspect Windows desktop applications from inside WSL for any agent with bash access (pi, Claude Code, Codex, ...). Nothing is installed on the Windows host: everything runs through `powershell.exe` WSL interop and the UI Automation API. Background actions (L1) never steal focus or mouse; physical input (L3) is dry-run by default and always requires explicit approval.

## Install

### pi
```bash
pi install git:github.com/iluluyu/win-cua
# or (pi discovers skills recursively):
git clone https://github.com/iluluyu/win-cua ~/.pi/agent/skills/win-cua
```

### Any Agent Skills-compatible harness
```bash
git clone https://github.com/iluluyu/win-cua ~/win-cua
ln -s ~/win-cua/skills/win-cua .agents/skills/win-cua    # project-level (run in your project root)
# or user-level: ln -s ~/win-cua/skills/win-cua ~/.agents/skills/win-cua
```

Requires WSL2 with interop enabled (default). PowerShell 7 (`pwsh`) is used automatically when available (~40% faster per call); falls back to Windows PowerShell 5.1.

## Usage

```bash
RUN=./skills/win-cua/scripts/run.sh   # from repo root; adjust if installed via pi

# --- 1. PERCEIVE (background, zero focus impact) ---
"$RUN" windows                                          # list windows (pid/exe/title/rect)
"$RUN" tree -Name "Notepad" -Interactive                # actionable controls (-Depth 6: full tree)
"$RUN" text -Name "Notepad" -MaxChars 3000              # read text
"$RUN" screenshot -Window "Notepad"                     # background capture (-All: desktop)
"$RUN" geom -ListMonitors                               # displays (-Move / -Minimize: no activation)

# --- 2. ACT (background, zero focus impact) ---
"$RUN" act -Name "Settings" -Target "Dark mode" -Action toggle
"$RUN" act -Name "Dialog" -Target "OK" -Action invoke
"$RUN" act -Name "Editor" -Target "Text Editor" -Action setvalue -Value "Hello from WSL"

# --- 3. PHYSICAL INPUT (last resort, steals focus) ---
"$RUN" input -MouseClick -X 100 -Y 200                  # dry-run by default
"$RUN" input -MouseClick -X 100 -Y 200 -ConfirmPhysical # requires explicit user approval
```

Perceive → Act → Verify: after acting, re-run `tree`/`text`; the UIA state is the source of truth. Every L1/L2 script self-checks and reports `focus untouched: True`.

## How It Works

```
WSL Agent ──bash──▶ scripts/run.sh ──interop──▶ powershell.exe -File \\wsl.localhost\...\*.ps1
                                                       │
                                         UIAutomation (COM) / GDI / SendInput
                                                       │
                                             Windows Desktop Apps (zero install)
```

- `run.sh` converts paths to Windows UNC (`wslpath -w`) and picks the engine: pwsh 7 when present, Windows PowerShell 5.1 otherwise.
- Scripts execute straight from the WSL repo over UNC — nothing is copied to Windows. Output is forced UTF-8 (Chinese titles verified); .ps1 sources stay pure ASCII for PS 5.1 compatibility.
- L1 = .NET UI Automation (COM); L2 = GDI PrintWindow / SetWindowPos; L3 = Win32 SendInput.

## Safety

- L3 physical input is dry-run by default and never runs without explicit user approval + `-ConfirmPhysical`.
- Hard rules (no destructive operations, no passwords/2FA, no closing unsaved work; lock screen/UAC/elevated apps are OS boundaries) live in [SKILL.md](skills/win-cua/SKILL.md) and are enforced by the skill instructions.

## Limitations

- Each call spawns a PowerShell process (~0.6s with pwsh 7, ~1s with 5.1).
- Apps with sparse accessibility trees (Electron canvas, games) fall back to screenshots + L3 input.
- Screenshots are black while Windows is locked; UIA queries still work.

## License

[MIT](LICENSE)
