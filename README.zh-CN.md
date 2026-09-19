# win-cua

[English](README.md) | **简体中文**

让运行在 WSL 中的 Agent 感知并操作 Windows 宿主机桌面应用的 pi skill —— **Windows 侧零安装**，后台 L1 操作**绝不抢占用户焦点**。

---

## 核心设计理念：绝不抢占用户焦点

当 AI Agent 在后台自动化操作桌面任务时，最糟糕的体验莫过于突然抢走窗口焦点或劫持鼠标光标。

`win-cua` 核心围绕**严格的三层能力模型**设计，默认采用无干扰的后台操作，并对物理级输入实施严格防护：

| 层级 | 能力范围 | 焦点影响 | 实现原理 |
|---|---|---|---|
| **L1 — UIA 后台** *(默认首选)* | 枚举窗口、读取控件树、提取文本、点击按钮、切换开关、展开菜单、设置输入值 | **零焦点干扰**（已实测） | .NET UI Automation COM 通道 |
| **L2 — 几何与截图** | 移动、缩放（`SWP_NOACTIVATE`）、最小化窗口、后台窗口截图 | **零焦点干扰**（窗口 Restore 除外） | Win32 GDI `PrintWindow` 与 `SetWindowPos` |
| **L3 — 物理输入** *(最后手段)* | 真实鼠标点击、拖拽、光标移动、键盘按键模拟 | **抢占焦点 / 移动光标** | Windows `SendInput` API |

> [!IMPORTANT]
> **焦点状态自检**：每个 L1 和 L2 脚本在执行前后均会校验前台窗口，并输出 `focus untouched: True`。SKILL 会指示 Agent 检查该标志，一旦为 `False` 立即停止操作并进行排查。
> 
> **L3 安全防线**：`input.ps1` 默认仅为 dry-run 演练模式。必须经过**对话中明确征得用户批准**并显式传入 `-ConfirmPhysical` 参数后方可执行真实物理输入。

---

## 安装说明

### 方式 1：通过 pi 包管理器安装（推荐）

```bash
pi install git:github.com/iluluyu/win-cua
```
pi 将通过项目清单（`package.json`）自动识别并加载 `skills/win-cua`。

### 方式 2：手动软链接（本地开发）

克隆代码仓库并运行安装脚本建立软链接：

```bash
git clone https://github.com/iluluyu/win-cua.git
cd win-cua
./skills/win-cua/install.sh
```
*该脚本会将 `skills/win-cua` 链接至 `~/.pi/agent/skills/win-cua`（或 `~/.claude/skills` / `~/.agents/skills`）。*

### 运行环境要求
- **操作系统**：Windows 10 或 Windows 11（推荐 Windows 11）+ WSL2。
- **WSL 互操作性（Interop）**：已启用（`/proc/sys/fs/binfmt_misc/WSLInterop` 存在，WSL 默认已启用）。
- **Windows 宿主机**：**零依赖**。无需在 Windows 侧安装 Python、Go、Node.js 或任何第三方常驻服务。
- **PowerShell 引擎**（可选）：若 Windows 侧装有 PowerShell 7（`pwsh`），win-cua 会自动优先使用 —— 单次调用提速约 40%（实测 ~580ms 对比 ~995ms）。未安装时自动回退到系统自带的 Windows PowerShell 5.1，也可通过 `WIN_CUA_PS` 环境变量手动指定。

---

## 快速使用

所有指令均在 WSL 中通过 `run.sh` 执行，遵循 **感知 (Perceive) → 操作 (Act) → 验证 (Verify)** 规范。以下路径假定你已 clone 仓库并位于仓库根目录（若通过 `pi install` 安装，请相应调整为 skill 目录路径）：

```bash
# ==========================================
# 1. 感知阶段 (L1/L2 - 后台执行，零焦点影响)
# ==========================================

# 列出所有顶层窗口（PID、进程名、窗口标题、坐标尺寸）
./skills/win-cua/scripts/run.sh windows

# 仅检查可交互控件树
./skills/win-cua/scripts/run.sh tree -Name "Notepad" -Interactive

# 查看完整控件树（指定递归深度）
./skills/win-cua/scripts/run.sh tree -Name "Notepad" -Depth 6

# 读取文档或输入框文本（支持 TextPattern 与 ValuePattern）
./skills/win-cua/scripts/run.sh text -Name "Notepad" -MaxChars 3000

# 后台截取指定窗口（无需激活或置顶窗口）
./skills/win-cua/scripts/run.sh screenshot -Window "Notepad"

# 截取完整桌面
./skills/win-cua/scripts/run.sh screenshot -All

# 列出所有显示器及几何参数
./skills/win-cua/scripts/run.sh geom -ListMonitors

# 移动窗口且不激活
./skills/win-cua/scripts/run.sh geom -Move -Name "Notepad" -X 100 -Y 100

# ==========================================
# 2. 操作阶段 (L1 - 后台执行，零焦点影响)
# ==========================================

# 切换开关或复选框状态
./skills/win-cua/scripts/run.sh act -Name "Settings" -Target "Dark mode" -Action toggle

# 点击按钮或调用控件
./skills/win-cua/scripts/run.sh act -Name "Dialog" -Target "OK" -Action invoke

# 通过无障碍模式调用菜单项（会打开菜单）
./skills/win-cua/scripts/run.sh act -Name "Notepad" -Target "File" -Action invoke

# 设置可编辑文本框内容
./skills/win-cua/scripts/run.sh act -Name "Editor" -Target "Text Editor" -Action setvalue -Value "Hello from WSL"

# ==========================================
# 3. 物理输入 (L3 - 最后手段，会抢占焦点)
# ==========================================

# 默认仅演练打印目标（dry-run，不发生真实输入）
./skills/win-cua/scripts/run.sh input -MouseClick -X 100 -Y 200

# 需用户明确同意后，添加 -ConfirmPhysical 执行真实物理输入
./skills/win-cua/scripts/run.sh input -MouseClick -X 100 -Y 200 -ConfirmPhysical
```

---

## 安全准则

`win-cua` 制定了严格的安全边界，保护用户系统安全与数据隐私：

1. **严禁执行破坏性操作**：未经用户在会话中明确批准，绝不调用系统关机/重启/注销、文件删除（`rm`/`Remove-Item`）、注册表写入、系统服务更改、用户凭据/密码窗口或任何金融支付确认按钮。
2. **严禁录入敏感凭据**：绝不输入密码、Token 密钥或二次验证码（2FA）。此类凭据须明确提示用户自行输入。
3. **防止数据丢失**：若窗口存在未保存工作，未经用户许可严禁调用 `act -Action close` 关闭窗口。
4. **敏感输入框防护**：仅对非敏感字段（如搜索框、文档编辑器）执行 `act -Action setvalue`，严禁向密码框等敏感输入区设值。
5. **系统安全边界**：Windows 锁屏界面、UAC 提权确认框及管理员权限（Elevated）应用属于系统硬性安全隔离区，无法穿透操作。遇到此类场景须明确告知用户，不得尝试绕过。
6. **L3 强制安全门禁**：`input.ps1` 默认处于演练（dry-run）状态，严禁未经用户知情与授权静默执行物理鼠标键盘操作。

---

## 工作原理

```
pi (WSL) ──bash──▶ scripts/run.sh ──interop──▶ powershell.exe -File \\wsl.localhost\...\*.ps1
                                                        │
                                          UIAutomation (COM) / GDI / SendInput
                                                        │
                                              Windows 桌面应用（零安装）
```

1. **WSL Interop 互操作**：WSL bash 执行 `run.sh`，利用 `wslpath -w` 将脚本路径无缝转换为 Windows UNC 格式（`\\wsl.localhost\<distro>\...`）。
2. **无侵入原生调用**：直接调用 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File <UNC路径>` 执行，无需向 Windows 文件系统复制任何脚本或二进制文件。
3. **编码与兼容保障**：
   - 标准输出强制设置为 UTF-8（`[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`），完美支持中文窗口标题与非 ASCII 文本解析。
   - 所有 `.ps1` 源码均采用纯 ASCII 字符编写，彻底规避 PowerShell 5.1 将无 BOM 的 UTF-8 误按 ANSI 读取的问题。
4. **底层技术栈**：
   - **L1**：基于 .NET `UIAutomationClient` / COM 接口（`AutomationElement`、`InvokePattern`、`ValuePattern`、`TextPattern`、`TogglePattern` 等）。
   - **L2**：基于 Win32 GDI `PrintWindow`（flag 2 / `PW_RENDERFULLCONTENT`）与 `SetWindowPos`（`SWP_NOACTIVATE`）。
   - **L3**：基于 Win32 `SendInput` API 派发硬件输入事件。

---

## 已验证特性（2026-09）

在 Windows 11（Build 26100）+ WSL2 环境下完成完整实测验证：

- ✅ **零焦点干扰验证**：所有 L1 控件树遍历、文本读取及 L2 后台截图均实测输出 `focus untouched: True`，用户当前前台活动窗口不受任何影响。
- ✅ **长文本后台读取**：实测支持在后台完整读取 24,000+ 字符长文本（如记事本大文件，通过 `TextPattern` / `ValuePattern`）。
- ✅ **后台窗口截图**：通过 `PrintWindow` 成功截取被遮挡或后台运行的窗口（实测 Chromium 核心应用与原生窗口均可用），无需将窗口置顶。
- ✅ **UTF-8 与中文支持**：中文窗口标题及控件名称正常识别解析并输出，无乱码。
- ✅ **进程名称解析**：部分系统下 `AutomationElement.ProcessNameProperty` 返回 null，统一优化为 `ProcessIdProperty` 配合 `Get-Process` 精确获取。
- ✅ **PowerShell 7 加速**：实测 `pwsh` 7.6.6 下 UIA、WinForms、P/Invoke 均正常工作，单次调用耗时从 ~995ms 降至 ~580ms（提速约 40%）；无 pwsh 时自动回退 Windows PowerShell 5.1，完全兼容。
- ⚠️ **模型多模态说明**：搭配纯文本 LLM（如 glm-5.3）使用时，环境感知以 UIA 文本树为主；截图保存至 `/mnt/c/...` 路径，作为供用户查阅的证据产物。

---

## 已知限制

- **冷启动开销**：每次调用需拉起一个 PowerShell 进程（pwsh 7 约 0.6 秒，Windows PowerShell 5.1 约 1 秒）。
- **UI 树稀疏应用**：基于 Electron、自绘 Canvas 或游戏引擎开发的应用可能仅暴露极少甚至空白的无障碍树；此时感知需回退至截图，操作需回退至 L3 物理输入（需用户审批）。
- **锁屏与无头会话**：当 Windows 处于锁屏状态或 RDP 远程桌面断开连接时，截图将返回纯黑画面（L1 UIA 仍可查询，但无法进行视觉捕获）。

---

## 方案对比：win-cua vs. windows-mcp-server

| 特性维度 | `win-cua`（本项目） | `deploymenttheory/windows-mcp-server` |
|---|---|---|
| **架构形态** | 无状态、按需调用的 `powershell.exe` interop | Windows 侧常驻后台 MCP 服务进程 |
| **Windows 安装成本** | **零安装**（Windows 宿主机完全无需安装任何软件） | 需在 Windows 侧安装依赖、配置运行环境与后台服务维护 |
| **调用响应延迟** | 每次调用存在 ~0.6s（pwsh 7）冷启动耗时 | 极低延迟（<100ms） |
| **焦点保护** | 严格的 L1/L2/L3 分层模型，附带 `focus untouched` 校验 | 视具体工具实现而定 |
| **适用场景** | WSL 优先的 Agent 日常开发、个人环境、零负担开箱即用 | 高频批量自动化、企业级操作审计链、需硬件级紧急开关（kill-switch）场景 |

---

## 开源协议

本项目采用 [MIT](LICENSE) 协议开源。
