---
name: studio-smoke-check
description: 用 Windows PowerShell 验证《采邑春秋》的 Godot 资源导入、GDScript 解析和主场景启动，区分自动冒烟与人工玩法验证。
---

# Godot 冒烟检查

1. 按根目录 `project.godot` 的 `config/features` 选用匹配的 Godot 控制台版。从仓库根目录用 PowerShell 7.4 或更新版本运行以下命令。引擎路径按 `-Godot`、本地 `.godot-mcp.json`、`GODOT_PATH`、PATH 的顺序查找。

   ```powershell
   & ./.agents/skills/studio-smoke-check/scripts/Test-GodotSmoke.ps1
   ```

2. 分别报告导入、`scripts/` 下脚本加载和主场景启动的结果，保留关键警告或错误。缺引擎、进程失败或日志含错误时，将对应步骤标成待验证或失败。
3. 对相关玩法运行已有自动测试。对于界面或交互，在 Godot 中按 F5，按故事的验收条件操作，或从 `REFACTORING_CHECKLIST.md` 选取当前任务相关的检查。记录实际观察结果和未执行项。

使用 `-Scenario` 可在各自的临时存档环境执行 `tests/` 下的回归。参数填写脚本名，例如 `-Scenario irrigation-state,irrigation-flow`。
