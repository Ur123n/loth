# 六边形战棋卡牌 RPG

单人 RPG：以角色塑造、探索、剧情与六边形战棋卡牌战斗为核心。核心体验是 **四人固定小队 + 六边形空间战斗 + 独立角色卡组 + 独立资源 + 玩家自主角色成长**。

## 当前可玩内容（垂直切片）

- 大世界移动（WASD）、角色切换（↑/↓）、角色面板（Tab）、背包（B）
- 战斗触发点进入六边形战棋卡牌战斗
- 卡牌系统：抽牌/弃牌/费用/荷载、15 种逻辑链效果、条件判断、关键词
- 敌怪与敌方小队、战利品 / 经验 / 钱币
- 道途系统：4 个道途（梦魇行者 / 孢子卫士 / 侠盗 / 解剖学者）、专属初始牌、基础被动
- 装备 / 物品 / NPC 数据（数据驱动，可由 Excel 同步）
- 存档（user://savegame.json）

## 如何运行

| 用途 | 方式 |
| --- | --- |
| 主游戏 | 用 Godot 打开根目录 `project.godot`，或命令行 `--path C:\游戏` |
| 战斗测试 Demo | 双击 `启动战斗测试demo.bat`（独立存档，随机战斗循环） |
| 卡牌编辑器 | 双击 `启动卡牌编辑器.bat`（Python/Tk，无需 Godot） |
| 表格同步 | 修改 `编辑器/*.xlsx` 后运行 `编辑器/同步表格.bat` |

## 项目结构

```
C:\游戏/
├── project.godot / README.md / AGENTS.md
├── core/      游戏规则与系统（battle/card/character/effect/grid/ai/equipment/items/progression/world/save/art）
├── content/   具体游戏内容（characters/cards/equipment/items/npcs/paths/buffs/enemies/encounters…）
├── world/     世界场景（map/encounters 等 .tscn）
├── ui/        界面逻辑（battle/cards/character/inventory/common）
├── demo/      战斗测试 Demo（场景 + DemoComposer）
├── assets/    美术资源
├── docs/      文档（architecture + 各模块 rules/architecture + development）
├── tests/     无头自动化测试（battle/card/character）
└── 编辑器/    内容工具（Excel 数据源 + 卡牌编辑器 + 同步脚本）
```

## 架构要点

- **系统与内容分离**：`core/` 是“规则如何运行”，`content/` 是“游戏中存在什么”。新增内容原则上通过数据资源完成，不修改核心系统。
- **数据驱动**：Godot 侧使用 Resource / JSON 数据资源；禁止把大量游戏内容硬编码到 `.gd` 文件中。
- **模块依赖单向**：World → Quest/Dialogue → Character/Progression → Battle → Card/Effect；底层系统不得反向依赖上层。
- **事件驱动**：跨模块通信优先 Signal / Event / Result Data，而不是直接修改其他模块的内部状态。
- **UI 与逻辑分离**：UI 只负责显示与输入，规则由 core/ 系统处理。

## 文档导航

- [docs/architecture.md](docs/architecture.md) — 整体架构与模块职责
- docs/battle/、docs/card/、docs/character/、docs/world/ — 各模块 README / rules / architecture
- docs/story/、docs/quest/ — 剧情与任务模块（规划中）
- docs/development/ — 路线图、变更日志、已知问题、数据说明
- [AGENTS.md](AGENTS.md) — AI 开发助手执行规范