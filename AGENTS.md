# AGENTS.md — Codex 执行规范

本文件面向 Codex 与任何 AI 开发助手：README 回答“项目是什么”，本文件回答“该怎么改代码、哪些事情不能做”。两者不要重复。

## 工作流程

### 第一步：识别模块

判断任务属于哪个模块：

battle / card / character / effect / grid / ai / equipment / items / progression / world / quest / dialogue / ui / save / content

### 第二步：读取局部文档

优先读取 `docs/<模块>/` 下的 README.md → rules.md → architecture.md，而不是扫描整个项目。新建内容优先看 `content/` 目录与 `docs/development/data_guides.md`。

### 第三步：检查依赖

只读取当前模块直接依赖的模块。依赖方向（见 docs/architecture.md）：

World → Quest/Dialogue → Character/Progression → Battle → Card/Effect

底层模块不能反向依赖上层模块（例如 CardSystem 不得调用 WorldManager；战斗结束通过 BattleResult 交给上层处理）。

### 第四步：修改

只修改完成任务所需的最少文件。优先：

- 扩展已有系统，而不是创建平行系统（不要为单张卡牌复制卡牌系统、为单个 NPC 复制任务系统）
- 新增内容通过 `content/` 数据资源完成，而不是修改 `core/`
- 不把具体游戏内容硬编码进核心系统
- 涉及核心系统的修改必须保证现有功能不被破坏

### 第五步：测试

执行对应模块测试（全部必须 `failed=0`）：

```
C:\1\Godot_v4.7.1-stable_win64_console.exe --headless --path C:\游戏 --script tests\<模块>\test_*.gd
```

修改核心系统后还需验证：主场景/战斗场景无头加载无脚本错误、已有卡牌/角色正常、已有存档可读取。

### 第六步：更新文档

如果修改改变了系统行为，同步更新对应 `docs/<模块>/rules.md` 或 `architecture.md`，并追加 `docs/development/changelog.md`。

## 规则变化流程

规则变化时：**先更新规则文档，再修改代码**。例如 buff 结算规则变化 → 先改 docs/battle/rules.md，再改 core/effect/。

## 禁止行为

- 未经明确要求：重构整个项目、修改无关模块、删除现有系统、修改核心游戏规则
- 将大量游戏内容硬编码进 .gd 文件
- 创建重复功能
- 模块之间直接侵入对方内部实现（应通过 Signal / Event / Result Data）
- 未测试就交付核心系统修改

## 目录速查

| 目录 | 内容 |
| --- | --- |
| core/ | 规则与通用系统（脚本） |
| content/ | 具体内容数据（JSON / .tres） |
| world/ | 世界场景 |
| ui/ | 界面逻辑 |
| demo/ | 战斗测试 Demo |
| tests/ | 无头测试 |
| docs/ | 模块文档 |
| assets/ | 美术资源 |
| 编辑器/ | Excel 数据源与内容工具 |