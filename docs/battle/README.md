# Battle 模块

六边形战棋战斗：战斗状态、回合、行动顺序、单位行动、地图与胜负判定，以及敌怪数据与敌方小队。

## 是什么

- **core/battle/** — 战斗规则与实现：`battle_manager.gd`（战斗流程/结算）、`battle_map.gd`（战斗场景入口/地图生成）、`battle_map_data.gd`（地图数据）、`battle_unit.gd`（单位）、`turn_system.gd`（行动顺序）、`terrain_data.gd`（地形）、`enemy_data.gd` / `enemy_database.gd` / `enemy_pack_database.gd`（敌怪与小队）
- **core/grid/** — `hex_grid.gd`：六边形坐标、距离、邻居、寻路
- **core/ai/** — `enemy_ai.gd`（决策引擎：目标/行动评分/位置评价）、`ai_archetype.gd`（行为模板）
- **world/encounters/BattleMap.tscn** — 战斗场景
- **ui/battle/** — 手牌、队伍血条、行动顺序、战斗结算界面、AI 决策调试面板
- **content/enemies/、content/encounters/** — 敌怪与敌方小队数据

## 文件地图

| 文件 | 职责 |
| --- | --- |
| core/battle/battle_manager.gd | 战斗主流程：出牌、效果结算、buff、死亡、胜负、战利品 |
| core/battle/battle_map.gd | 场景入口：生成地图/敌怪、进入与退出战斗 |
| core/battle/battle_unit.gd | 单位属性、位置、格挡/生命/移动力 |
| core/battle/turn_system.gd | 行动顺序（敏捷排序） |
| core/grid/hex_grid.gd | 六边形网格数学 |
| core/ai/enemy_ai.gd | 敌怪 AI 模式 |
| core/ai/ai_archetype.gd | 行为模板（性格参数 + 角色推导） |
| ui/battle/ai_debug_panel.gd | AI 决策调试面板（F4 / 点击敌怪） |
| ui/battle/battle_hand_ui.gd | 手牌显示与出牌输入 |
| ui/battle/party_hp_panel.gd | 队伍血条 |
| ui/battle/turn_order_bar.gd | 行动顺序条 |
| ui/battle/battle_settlement_panel.gd | 战斗结算（钱币/经验/卡牌奖励） |

## 规则与实现文档

- [rules.md](rules.md) — 战斗规则（移动/距离/伤害/格挡/buff/胜负/战利品）
- [architecture.md](architecture.md) — 代码如何实现这些规则
