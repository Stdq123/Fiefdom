# 采邑春秋 · Fiefdom

在井田上耕作和纳贡，招募门客，扩张封地，并决定是否接受初税亩改革。

## Windows 1.0

解压 `Fiefdom-1.0.0-Windows-x64.zip` 后双击 `Fiefdom.exe`。可从新档走到传统或改革结局。启动、操作和存档说明随包附带。 [Windows 操作说明](docs/Windows试玩说明.txt)

用 Godot 4.7.2 打开 `project.godot` 后按 F5 可运行源码。场景在 `scenes/`，玩法脚本在 `scripts/`，数值配置在 `resources/BalanceData.tres`。

在 PowerShell 7.4 或更新版本中，安装 Godot 4.7.2 的 [官方导出模板](https://godotengine.org/download/archive/4.7.2-stable/) 后运行以下命令。脚本验证解压后的游戏并把 ZIP 写入 `build/`。

```powershell
& ./tools/Build-Windows.ps1
```

脚本默认从 `.godot-mcp.json`、`GODOT_PATH` 或 PATH 查找 Godot 控制台程序。可以用 `-Godot` 指定程序，或用 `-TemplatesDirectory` 指定包含 `windows_release_x86_64.exe` 和 `icudt_godot.dat` 的 `4.7.2.stable` 模板目录。

同一源码、引擎和 PowerShell 环境下，两次干净构建的 ZIP SHA-256 一致。导出保留文本场景和资源，ZIP 使用固定的条目顺序和时间戳。 [Godot 导出设置](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-editor-export-convert-text-resources-to-binary)

以下命令在临时目录用解压出的正式程序验证两条新档路线、战败恢复和 90 秒连续运行。`-Capture` 在隔离的 Windows 桌面采集 1920×1080 和 1024×768 画面，其余检查使用无窗口模式。用 `-LegacyPackage` 传入已有的 0.1.x ZIP，还可以在旧版本中生成存档，再由 1.0 读取。日志、截图和校验清单写入 `build/Fiefdom-1.0.0-Windows-x64-verification/`。 [1.0 执行清单](tasks/todo.md)

```powershell
& ./tools/Test-WindowsRelease.ps1 -Package ./build/Fiefdom-1.0.0-Windows-x64.zip -Capture -Soak
```

## Codex 工作室

从项目根目录打开 Codex，新建会话后输入 `$studio-start`，即可盘点当前进度。也可以直接说「用 `$studio-dev-story` 实现……」。`project.yaml` 采用轻量流程，例行实现和验证直接推进，玩法方向或交付范围需要决策时由你决定。

| Codex 技能 | 对应的 Game Studios 工作流 | 用途 |
| --- | --- | --- |
| `$studio-start` | `/start`、`/project-stage-detect`、`/next-step` | 接手已有项目，找出下一项可验收工作 |
| `$studio-quick-design` | `/quick-design` | 定义规则或数值的变化与验收条件 |
| `$studio-dev-story` | `/dev-story` | 实现并验证一条故事 |
| `$studio-smoke-check` | `/smoke-check` | 导入、解析 GDScript 并启动主场景 |
| `$studio-story-done` | `/story-done` | 用运行证据逐项验收 |

需要分工时，可以请 Codex 调用 `.codex/agents/` 中的 `studio-systems-designer`、`studio-godot-gdscript` 或 `studio-qa-lead`。工作室流程使用仓库里的设计和 GDScript 目录，并由 Codex 直接执行验证步骤。

本适配源自 [Claude Code Game Studios 1.3.0](https://github.com/Donchitos/Claude-Code-Game-Studios/tree/abc0de79d6ceb0b5d7aa693945849b3937afbe6a)。上游授权见 [MIT 许可证](.agents/LICENSE-CCGS.txt)。

### Windows 冒烟检查

在 PowerShell 7.4 或更新版本中运行。可以指定当前项目使用的 Godot 控制台程序。

```powershell
& ./.agents/skills/studio-smoke-check/scripts/Test-GodotSmoke.ps1 -Godot 'D:/Program Files/godot/Godot_v4.7.2-stable_win64_console.exe'
```

脚本也接受本地 `.godot-mcp.json`、`GODOT_PATH` 或 PATH 中的 `godot`。检查使用项目副本和独立存档目录。界面、实际操作和手感按任务另行在编辑器里验证。

### Godot MCP

信任项目后，Codex 从本地 `.codex/config.toml` 读取 `godot-ultimate` 的启动配置。换机器或目录时，将 `.codex/config.example.toml` 复制为 `.codex/config.toml`，把 `cwd` 改为包含 `project.godot` 的绝对路径。这个路径供桌面端后台进程定位项目。

MCP 需要 PATH 中的 Node.js 和 `godot-mcp-ultimate/` 的本地检出。目录为空时，从 [Godot MCP Ultimate](https://github.com/Sharks820/godot-mcp-ultimate) 克隆到该目录，再检出本仓库 `git rev-parse HEAD:godot-mcp-ultimate` 显示的提交。构建命令如下。

```powershell
npm --prefix ./godot-mcp-ultimate ci --ignore-scripts
npm --prefix ./godot-mcp-ultimate run build
```

在项目根目录创建本地 `.godot-mcp.json`，填写自己的 Godot 路径。新开 Codex 会话后，可用 `godot_env_doctor` 检查连接。LSP 工具需要在 Godot 编辑器中打开本项目并使用相同端口。工作流和 PowerShell 冒烟检查可以独立运行。

```json
{
  "godotPath": "D:/Program Files/godot/Godot_v4.7.2-stable_win64_console.exe",
  "lspPort": 6005
}
```
