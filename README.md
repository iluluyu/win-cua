# win-cua

**English** | [简体中文](README.zh-CN.md)

A pi skill that allows AI agents running inside WSL to control and inspect Windows desktop applications — **zero installation on the Windows host**, with background L1 actions that **never steal user focus**.

---

## Core Principle: Never Steal User Focus

When an AI agent automates desktop tasks while you are actively working, the single most disruptive behavior is stealing window focus or hijacking the mouse cursor.

`win-cua` is architected from the ground up around a **strict three-layer execution model**. Background, non-disruptive operations are always the default, and physical inputs are strictly protected:

| Layer | Capabilities | Focus Impact | Implementation |
|---|---|---|---|
| **L1 — UIA Background** *(Default)* | Enumerate windows, inspect control trees, read text, invoke buttons, toggle options, trigger menus, set input values | **Zero focus steal** (Verified) | .NET UI Automation COM channel |
| **L2 — Geometry & Screenshot** | Move, resize (`SWP_NOACTIVATE`), minimize windows; background window capture | **Zero focus steal** (Except window restore) | Win32 GDI `PrintWindow` & `SetWindowPos` |
| **L3 — Physical Input** *(Last Resort)* | Physical mouse clicks, drags, cursor movement, keyboard keystrokes | **Steals focus / moves mouse** | Windows `SendInput` API |

> [!IMPORTANT]
> **Focus Verification**: Every L1 and L2 script inspects foreground window state before and after execution, verifying and reporting `focus untouched: True`. The skill instructs the agent to check this flag and stop to investigate if it is ever `False`.
> 
> **L3 Safety Gate**: `input.ps1` runs in dry-run mode by default. It requires both **explicit user approval in chat** and the `-ConfirmPhysical` flag before dispatching real hardware input events.

---

## Installation

### Method 1: Via pi package manager (Recommended)

```bash
pi install git:github.com/iluluyu/win-cua
```
pi automatically discovers `skills/win-cua` through the package manifest (`package.json`).

### Method 2: Manual symlink (Local Development)

Clone the repository and run the install script to symlink the skill:

```bash
git clone https://github.com/iluluyu/win-cua.git
cd win-cua
./skills/win-cua/install.sh
```
*The script creates a symlink to `skills/win-cua` in `~/.pi/agent/skills/win-cua` (or `~/.claude/skills` / `~/.agents/skills`).*

### Requirements
- **OS**: Windows 10 or Windows 11 (Windows 11 recommended) with WSL2.
- **WSL Interop**: Enabled (`/proc/sys/fs/binfmt_misc/WSLInterop` present; enabled by default in WSL).
- **Windows Host**: **Zero installation required**. No Python, Go, Node.js, or background daemons needed on the Windows side.
- **PowerShell Engine** *(optional)*: If PowerShell 7 (`pwsh`) is installed on Windows, win-cua uses it automatically — ~40% faster per invocation (measured ~580ms vs ~995ms). Falls back to built-in Windows PowerShell 5.1 otherwise. Override with the `WIN_CUA_PS` environment variable.

---

## Quick Usage

All commands run from WSL via `run.sh`, following the **Perceive → Act → Verify** pattern. Paths below assume you cloned the repo and are at its root — adjust if the skill was installed via `pi install` (then use the skill directory):

```bash
# ==========================================
# 1. PERCEIVE (L1/L2 - Background, Zero Focus)
# ==========================================

# List top-level windows (PID, process name, window title, bounding rect)
./skills/win-cua/scripts/run.sh windows

# Inspect actionable UI controls only
./skills/win-cua/scripts/run.sh tree -Name "Notepad" -Interactive

# Inspect full UI control tree (up to specified depth)
./skills/win-cua/scripts/run.sh tree -Name "Notepad" -Depth 6

# Read document or field text (supports TextPattern & ValuePattern)
./skills/win-cua/scripts/run.sh text -Name "Notepad" -MaxChars 3000

# Capture background window screenshot without bringing it to the foreground
./skills/win-cua/scripts/run.sh screenshot -Window "Notepad"

# Capture entire desktop
./skills/win-cua/scripts/run.sh screenshot -All

# List connected monitors and display geometry
./skills/win-cua/scripts/run.sh geom -ListMonitors

# Move a window without activating it
./skills/win-cua/scripts/run.sh geom -Move -Name "Notepad" -X 100 -Y 100

# ==========================================
# 2. ACT (L1 - Background, Zero Focus)
# ==========================================

# Toggle a setting or checkbox
./skills/win-cua/scripts/run.sh act -Name "Settings" -Target "Dark mode" -Action toggle

# Click a button or invoke a control
./skills/win-cua/scripts/run.sh act -Name "Dialog" -Target "OK" -Action invoke

# Invoke a menu item (opens it via the accessibility pattern)
./skills/win-cua/scripts/run.sh act -Name "Notepad" -Target "File" -Action invoke

# Set text in an editable field
./skills/win-cua/scripts/run.sh act -Name "Editor" -Target "Text Editor" -Action setvalue -Value "Hello from WSL"

# ==========================================
# 3. PHYSICAL INPUT (L3 - Last Resort, Steals Focus)
# ==========================================

# Dry-run by default (prints intended target and coordinates without moving mouse)
./skills/win-cua/scripts/run.sh input -MouseClick -X 100 -Y 200

# Requires explicit user approval + -ConfirmPhysical flag to execute
./skills/win-cua/scripts/run.sh input -MouseClick -X 100 -Y 200 -ConfirmPhysical
```

---

## Safety Guidelines

`win-cua` enforces strict safety boundaries to protect user system stability and privacy:

1. **Destructive Actions Prohibited**: Never invoke system shutdown, reboot, sign-out, file deletions (`rm` / `Remove-Item`), registry writes, service modifications, user credential/password dialogs, or financial/payment confirmation buttons without explicit user confirmation.
2. **No Sensitive Data Entry**: Never type passwords, access tokens, API keys, or 2FA codes. Always prompt the user to enter them directly.
3. **Prevent Data Loss**: Never close windows containing unsaved work (`act -Action close`) without explicit user permission.
4. **Field Sensitivity**: Only use `act -Action setvalue` on non-sensitive input fields (e.g., search bars, text documents); never on password or credential inputs.
5. **OS Security Boundaries**: The Windows lock screen, UAC elevation prompts, and elevated (administrator) applications are protected OS boundaries. The agent must acknowledge this limitation rather than attempting workarounds.
6. **L3 Guardrail**: `input.ps1` runs in dry-run mode by default. Physical mouse or keyboard input must never run silently.

---

## How It Works

```
pi (WSL) ──bash──▶ scripts/run.sh ──interop──▶ powershell.exe -File \\wsl.localhost\...\*.ps1
                                                        │
                                          UIAutomation (COM) / GDI / SendInput
                                                        │
                                              Windows Desktop Apps (Zero Install)
```

1. **WSL Interop**: WSL bash calls `run.sh`, which converts script paths into Windows UNC paths (`\\wsl.localhost\<distro>\...`) using `wslpath -w`. `run.sh` auto-selects the PowerShell engine: `pwsh.exe` (7+) when available, otherwise `powershell.exe` (5.1); override with `WIN_CUA_PS`.
2. **Native Host Execution**: PowerShell runs directly via `powershell.exe -NoProfile -ExecutionPolicy Bypass -File <UNC_path>`. No scripts or binaries need to be copied onto the Windows filesystem.
3. **Encoding & Compatibility**:
   - Standard output is explicitly set to UTF-8 (`[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`), ensuring flawless handling of non-ASCII and Chinese window titles.
   - All `.ps1` script source files use pure ASCII characters to prevent PowerShell 5.1 from misinterpreting UTF-8 files without BOM as ANSI.
4. **Underlying Technologies**:
   - **L1**: Interacts via .NET `UIAutomationClient` / COM interfaces (`AutomationElement`, `InvokePattern`, `ValuePattern`, `TextPattern`, `TogglePattern`).
   - **L2**: Uses Win32 GDI `PrintWindow` (flag 2 / `PW_RENDERFULLCONTENT`) and `SetWindowPos` (`SWP_NOACTIVATE`).
   - **L3**: Uses Win32 `SendInput` API for synthesized input events.

---

## Verified Behaviors (2026-09)

Tested and verified on Windows 11 (Build 26100) with WSL2:

- ✅ **Zero Focus Disruption**: `focus untouched: True` verified across all L1 control tree dumps, text reads, and L2 background captures. The active user window remains untouched.
- ✅ **Deep Text Extraction**: Background text reading verified up to 24,000+ characters (e.g., extracting entire Notepad documents via `TextPattern` / `ValuePattern`).
- ✅ **Background Capture**: `PrintWindow` captures background and obscured windows cleanly without activation (verified with Chromium-based interfaces and native desktop apps).
- ✅ **UTF-8 & CJK Support**: Chinese window titles and UI element names correctly parsed and output without encoding corruption.
- ✅ **Process Resolution**: `AutomationElement.ProcessNameProperty` can return null on certain Windows configurations; resolved reliably using `ProcessIdProperty` paired with `Get-Process`.
- ✅ **PowerShell 7 Acceleration**: `pwsh` 7.6.6 verified — UIA, WinForms, and P/Invoke all work; per-invocation latency drops from ~995ms to ~580ms (~40% faster). Windows PowerShell 5.1 remains a fully supported fallback.
- ⚠️ **Model Multimodality Note**: When paired with text-only LLMs (e.g., glm-5.3), UI perception relies primarily on UIA text trees; screenshots are saved to `/mnt/c/...` as visual artifacts for user inspection.

---

## Limitations

- **Process Cold-Start**: Each command spawns a PowerShell process (~0.6s with pwsh 7, ~1s with Windows PowerShell 5.1).
- **Sparse UIA Trees**: Applications built with Electron, custom canvas rendering, or game engines may expose minimal accessibility elements. In such cases, perception falls back to screenshots and L3 physical input (subject to user confirmation).
- **Locked Screen / Headless**: When Windows is locked or RDP is disconnected, screenshots render black. L1 UIA queries still function, but visual inspection is unavailable.

---

## Comparison: win-cua vs. windows-mcp-server

| Dimension | `win-cua` (This Skill) | `deploymenttheory/windows-mcp-server` |
|---|---|---|
| **Architecture** | Stateless on-demand `powershell.exe` interop | Resident background MCP server process on Windows |
| **Windows Installation** | **Zero install** (Nothing installed on Windows host) | Requires installation, runtime setup, and maintenance on Windows |
| **Invocation Latency** | ~1–2s per command (cold start) | Near-instantaneous (<100ms) |
| **Focus Safety** | Strict L1/L2/L3 layering with `focus untouched` checks | Varies by tool implementation |
| **Best For** | WSL-native agent workflows, personal development, zero-friction setup | High-frequency bulk automation, enterprise audit logging, dedicated kill-switches |

---

## License

[MIT](LICENSE)
