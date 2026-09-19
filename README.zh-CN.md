# win-cua

[English](README.md) | **简体中文**

> win-cua = Windows + CUA（Computer-Use Agent，计算机使用体）

让运行在 WSL 中的任何具备 bash 执行权限的 Agent 感知并操作 Windows 宿主机桌面应用。**Windows 侧零安装**：全部通过 `powershell.exe` WSL 互操作与 UI Automation API 完成。后台操作（L1）绝不抢占焦点和鼠标；物理输入（L3）默认仅演练，且必须获得用户明确批准才会执行。

## 安装

### pi
```bash
pi install git:github.com/iluluyu/win-cua
# 或（pi 会递归发现 skills 目录）：
git clone https://github.com/iluluyu/win-cua ~/.pi/agent/skills/win-cua
```

### 任何兼容 Agent Skills 规范的框架
```bash
git clone https://github.com/iluluyu/win-cua ~/win-cua
ln -s ~/win-cua/skills/win-cua .agents/skills/win-cua    # 项目级（在项目根目录执行）
# 或用户级：ln -s ~/win-cua/skills/win-cua ~/.agents/skills/win-cua
```

要求 WSL2 且互操作启用（默认开启）。检测到 PowerShell 7（`pwsh`）时自动使用（单次调用快约 40%），否则回退 Windows PowerShell 5.1。

## 使用

```bash
RUN=./skills/win-cua/scripts/run.sh   # 仓库根目录下执行；pi 安装用户请相应调整路径

# --- 1. 感知（后台，零焦点影响）---
"$RUN" windows                                          # 列出窗口 (pid/exe/标题/坐标)
"$RUN" tree -Name "Notepad" -Interactive                # 可交互控件（-Depth 6：完整树）
"$RUN" text -Name "Notepad" -MaxChars 3000              # 读取文本
"$RUN" screenshot -Window "Notepad"                     # 后台截图（-All：全屏）
"$RUN" geom -ListMonitors                               # 显示器（-Move / -Minimize：不激活窗口）

# --- 2. 操作（后台，零焦点影响）---
"$RUN" act -Name "Settings" -Target "Dark mode" -Action toggle
"$RUN" act -Name "Dialog" -Target "OK" -Action invoke
"$RUN" act -Name "Editor" -Target "Text Editor" -Action setvalue -Value "Hello from WSL"

# --- 3. 物理输入（最后手段，会抢占焦点）---
"$RUN" input -MouseClick -X 100 -Y 200                  # 默认仅演练
"$RUN" input -MouseClick -X 100 -Y 200 -ConfirmPhysical # 需用户明确批准
```

感知 → 操作 → 验证：每次操作后重跑 `tree`/`text`，以 UIA 实际状态为准。所有 L1/L2 脚本均自检并输出 `focus untouched: True`。

## 工作原理

```
WSL Agent ──bash──▶ scripts/run.sh ──interop──▶ powershell.exe -File \\wsl.localhost\...\*.ps1
                                                       │
                                         UIAutomation (COM) / GDI / SendInput
                                                       │
                                             Windows Desktop Apps (zero install)
```

- `run.sh` 将路径转为 Windows UNC 格式（`wslpath -w`）并选择执行引擎：优先使用 pwsh 7，未检测到时使用 Windows PowerShell 5.1。
- 脚本通过 UNC 直接在 WSL 仓库内执行——无需向 Windows 复制任何文件。输出强制为 UTF-8（已验证支持中文标题）；.ps1 源码保持纯 ASCII 以兼容 PS 5.1。
- L1 = .NET UI Automation (COM)；L2 = GDI PrintWindow / SetWindowPos；L3 = Win32 SendInput。

## 安全

- L3 物理输入默认仅演练，未经用户明确批准 + `-ConfirmPhysical` 绝不真实执行。
- 硬性规则（禁止破坏性操作、禁止输入密码/2FA、禁止关闭未保存窗口；锁屏/UAC/管理员应用属系统边界）完整定义在 [SKILL.md](skills/win-cua/SKILL.md)，由 skill 指令强制执行。

## 已知限制

- 每次调用拉起一个 PowerShell 进程（pwsh 7 约 0.6 秒，5.1 约 1 秒）。
- 无障碍树稀疏的应用（Electron 画布、游戏等）回退为截图 + L3 输入。
- Windows 锁屏时截图为纯黑；UIA 查询不受影响。

## 开源协议

[MIT](LICENSE)
