# AGENTS.md

- 默认终端是 PowerShell。文本文件使用 UTF-8。
- 本机已安装 Postman CLI，可用于 API 工程任务。

## 《采邑春秋》

- 这是现有的 Godot 4 / GDScript 游戏。仓库根目录的 `project.godot` 定义引擎版本、启动场景和 Autoload。代码在 `scripts/`，场景在 `scenes/`，资源在 `resources/` 和 `assets/`。
- 按任务读取 `docs/game_design/` 的对应设计。用脚本、场景和运行结果核对实现进度。`REFACTORING_CHECKLIST.md` 存在时，用它核对正在进行的 UI 和数值重构。
- 修改玩法时，核对井田的公私田产出、日推进和存档兼容性。共享游戏状态沿用 `Global`，跨系统通知沿用 `GameEvents`，数值改动优先检查 `BalanceData` 和现有 Resource。

## Codex 工作室流程

- `project.yaml` 记录 Game Studios 的项目配置。用 `$studio-start` 盘点已有工作，或用 `$studio-dev-story` 接手明确的功能。完整入口见 [README.md](README.md#codex-工作室)。
- 运行验证使用 `$studio-smoke-check`。PowerShell 脚本在临时副本中导入、解析脚本并启动主场景，同时隔离编辑器缓存和 `user://`。涉及界面、交互或手感时，另记实机验证结果。
- 当前会话负责协调。用户明确要求分工时，可使用 `.codex/agents/` 中的系统设计、Godot 和 QA 角色，并汇总各自的证据。
