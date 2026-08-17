# 架构总览

本文回答：这个项目的代码是如何组织的、模块之间如何协作。

## 1. 总体原则

1. **模块化优先**：每个大型系统有明确的数据 / 逻辑 / UI / 资源 / 文档；模块间通过明确接口通信，禁止依赖另一个系统的内部实现。
2. **系统与内容分离**：
   - `core/` 负责“游戏规则如何运行”（CardSystem / BattleSystem / EffectSystem / CharacterSystem / QuestSystem…）
   - `content/` 负责“游戏中具体存在什么”（鲍德温、某张卡牌、某件装备、某个 NPC…）
   - 新增内容原则上通过数据资源完成，而不是修改核心系统。
3. **数据驱动**：Godot 优先使用 Resource / JSON 描述内容。代码负责规则，数据负责内容。
4. **事件驱动**：跨模块通信优先 Signal / Event / Result Data。
5. **UI 与逻辑分离**：UI 只显示与接收输入；规则判定由 core/ 系统处理。

## 2. 目录职责

| 目录 | 职责 |
| --- | --- |
| `core/battle/` | 战斗状态、回合、行动顺序、单位行动、胜负；敌怪数据类与数据库 |
| `core/card/` | 卡牌数据结构、抽牌/弃牌/费用/荷载、卡组、卡牌执行入口（CardDB） |
| `core/character/` | 角色属性、HP、成长、技能库、队伍管理 |
| `core/effect/` | 通用战斗效果（攻击/防御/移动/buff/抽牌…）与 buff 数据；logic_chains 为组件化效果资源 |
| `core/grid/` | 六边形坐标、距离、邻居、路径搜索、移动、范围计算 |
| `core/ai/` | 敌怪 AI（行为选择） |
| `core/equipment/` | 装备数据结构与装备数据库 |
| `core/items/` | 物品数据结构、物品数据库、背包 |
| `core/progression/` | 道途（PathData/PathDB）、被动（PassiveData）、成长接口 |
| `core/world/` | 大世界逻辑（main 场景脚本、技能光点）、NPC 数据与数据库 |
| `core/save/` | 全局状态与存档（GameState） |
| `core/art/` | 统一美术资源加载器（ArtLoader） |
| `content/` | 具体内容数据：characters / cards / equipment / items / npcs / paths / buffs / enemies / encounters |
| `world/` | 世界场景（map / encounters 的 .tscn） |
| `ui/` | 界面逻辑（battle / cards / character / inventory / common） |
| `demo/` | 战斗测试 Demo（启动器、营地、DemoComposer） |
| `tests/` | 无头自动化测试（battle / card / character） |
| `docs/` | 各模块文档（README / rules / architecture） |
| `assets/` | 美术资源 |

## 3. 依赖方向

推荐依赖方向（上层可依赖下层，下层不得反向依赖上层）：

```
World
  ↓
Quest / Dialogue
  ↓
Character / Progression
  ↓
Battle
  ↓
Card / Effect / Grid / AI
```

示例：战斗结束需要改变剧情时，BattleSystem 只返回 `BattleResult`，由上层（GameManager/QuestSystem/StorySystem）处理，而不是 BattleManager 直接修改 QuestManager 的内部数据。

## 4. 模块接口约定

- 数据库类（CardDB / EnemyDB / NpcDB / EquipDB / BuffDB / ItemDB / PathDB / CardDropDB / EnemyPackDB）为 Autoload 单例，负责把 `content/` 数据解析为 Resource 对象。
- 数据类（CardData / CharacterData / EnemyData / …）只承载数据，不包含业务规则。
- 跨模块状态尽量通过参数 / 返回值 / Signal 传递；全局状态集中在 GameState。

## 5. 内容生产原则

- 新增卡牌：优先用已有 Effect 组合（content/cards/*.json 的 effects 数组）；只有现有 Effect 无法表达时才新增 Effect。
- 新增任务：优先用已有 条件 / Flag / 奖励 / 对话节点；不为一个任务创造新机制。
- 新增角色/装备/NPC/敌怪：优先编辑 Excel 表格（编辑器/）同步生成，或直接写 content/ JSON。

## 6. 测试原则

核心系统逐步建立自动测试，优先覆盖：

- Battle：行动顺序、移动、距离、攻击、死亡、胜负
- Card：抽牌、弃牌、费用、荷载、卡组限制、无限循环限制
- Character：属性、加点、成长、技能学习
- Save：保存、加载、数据完整性

运行方式见 AGENTS.md。