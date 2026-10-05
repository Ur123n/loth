# 六边形战棋卡牌 RPG

单人 RPG：以角色塑造、探索、剧情与六边形战棋卡牌战斗为核心。核心体验是 **四人固定小队 + 六边形空间战斗 + 独立角色卡组 + 独立资源 + 玩家自主角色成长**。

**美术规格：俯视 2D · 48×48 像素（1 格 = 1 米）· 黑暗奇幻** —— 见 [docs/art/style_guide.md](docs/art/style_guide.md)；
素材库 `assets/dark48/`，地图管线 [docs/world/map_pipeline.md](docs/world/map_pipeline.md)。

## 当前可玩内容（垂直切片）

- 大世界移动（WASD）、角色切换（↑/↓）、角色面板（Tab）、背包（B）
- 战斗触发点进入六边形战棋卡牌战斗
- 卡牌系统：抽牌/弃牌/费用/荷载、15 种逻辑链效果、条件判断、关键词
- 敌怪与敌方小队、战利品 / 经验 / 钱币
- 道途系统：4 个道途（梦魇行者 / 孢子卫士 / 侠盗 / 解剖学者）、专属初始牌、基础被动
- 装备 / 物品 / NPC 数据（数据驱动，可由 Excel 同步）
- 剧情 / 过场系统（时间轴 + 指令、独立对话与摄像机、触发器、防重复触发）
- 任务系统（无 UI：状态记录在角色/存档，条件满足自动推进，支持分支；编辑器见 docs/quest/editor_guide.md）
- NPC 行动轨迹（时间轴：世界时钟驱动 NPC 按小时移动；编辑器见 编辑器/npc_editor.py）
- 存档（user://savegame.json，v6：含剧情记录 / 任务状态 / 世界时钟）

## 如何运行

| 用途 | 方式 |
| --- | --- |
| 主游戏 | 用 Godot 打开根目录 `project.godot`，或命令行 `--path C:\游戏` |
| 战斗测试 Demo | 双击 `启动战斗测试demo.bat`（独立存档，随机战斗循环） |
| 卡牌编辑器 | 双击 `启动卡牌编辑器.bat`（Python/Tk，无需 Godot） |
| 剧情编辑器 | 双击 `启动剧情检查.bat` 校验剧情数据；`--list` 查看指令目录 |
| 地图编辑器 | 双击 `启动地图编辑器.bat`（Godot 自带 TileMap 编辑器 + 48px 本地素材，见 docs/world/map_pipeline.md） |
| 地图架构第一阶段实验场 | `--path C:\游戏 res://dev/map_pipeline_test/map_pipeline_test.tscn`（Pattern + 大型建筑 + 自由 Prop + Interior + Ghost） |
| 地图管线接入演示 | `--path C:\游戏 res://world/map/MainGodotMap.tscn`（大世界底图换成管线地图「修道院外的荒院」） |
| 任务编辑器 | `python 编辑器/quest_editor.py`（list/validate/new/set/reward/branch） |
| NPC 编辑器 | `python 编辑器/npc_editor.py`（含行动轨迹 schedule 编辑） |
| 表格同步 | 修改 `编辑器/*.xlsx` 后运行 `编辑器/同步表格.bat` |

## 项目结构

```
C:\游戏/
├── project.godot / README.md / AGENTS.md
├── core/      游戏规则与系统（battle/card/character/camera/dialogue/story/effect/grid/ai/equipment/items/progression/world/save/art）
├── content/   具体游戏内容（characters/cards/equipment/items/npcs/paths/buffs/enemies/encounters/stories…）
├── world/     世界场景（map/encounters 等 .tscn）
├── ui/        界面逻辑（battle/cards/character/inventory/dialogue/common）
├── demo/      战斗测试 Demo（场景 + DemoComposer）
├── dev/       独立开发实验场（不替换正式地图）
├── assets/    美术资源
├── maps/      48px Godot TileMap/TileSet 地图管线
├── docs/      文档（architecture + 各模块 rules/architecture + development）
├── tests/     无头自动化测试（battle/card/character/save/story/map）
└── 编辑器/    内容工具（Excel 数据源 + 卡牌编辑器 + 同步脚本）
```

## 架构要点

- **系统与内容分离**：`core/` 是“规则如何运行”，`content/` 是“游戏中存在什么”。新增内容原则上通过数据资源完成，不修改核心系统。
- **数据驱动**：Godot 侧使用 Resource / JSON 数据资源；禁止把大量游戏内容硬编码到 `.gd` 文件中。
- **模块依赖单向**：World → Quest/Dialogue → Character/Progression → Battle → Card/Effect；底层系统不得反向依赖上层。
- **事件驱动**：跨模块通信优先 Signal / Event / Result Data，而不是直接修改其他模块的内部状态。
- **剧情数据驱动**：剧情/过场用 `content/stories/*.json`（时间轴+指令，阻塞/非阻塞），
  直接操作运行中的游戏对象；详细用法见 docs/story/editor_guide.md。
- **UI 与逻辑分离**：UI 只负责显示与输入，规则由 core/ 系统处理。

## 文档导航

- [docs/architecture.md](docs/architecture.md) — 整体架构与模块职责
- docs/battle/、docs/card/、docs/character/、docs/world/ — 各模块 README / rules / architecture
- docs/story/、docs/quest/ — 剧情与任务模块（剧情已实现；任务已实现，含 docs/quest/editor_guide.md）
- docs/world/npc_schedule.md — NPC 行动轨迹（时间轴）说明
- docs/world/map_pipeline.md — 地图制作管线（48px 本地素材 + Godot 地图编辑器）
- docs/art/style_guide.md — **美术风格与设定规格**（48×48 俯视黑暗奇幻：尺寸/色板/视角/氛围）
- docs/art/asset_request.md — 素材需求单（缺素材时怎么提、规格与验收）
- docs/development/ — 路线图、变更日志、已知问题、数据说明
- [AGENTS.md](AGENTS.md) — AI 开发助手执行规范
