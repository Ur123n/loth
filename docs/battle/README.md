# Battle 模块

六边形战棋战斗：战斗状态、回合、行动顺序、单位行动、地图与胜负判定，以及敌怪数据与敌方小队。

## 是什么

- **core/battle/** — 战斗规则与实现：`battle_manager.gd`（战斗流程/结算）、`battle_map.gd`（战斗场景入口/地图生成）、`battle_map_data.gd`（地图数据）、`battle_unit.gd`（单位）、`turn_system.gd`（行动顺序）、`terrain_data.gd`（地形）、`enemy_data.gd` / `enemy_database.gd` / `enemy_pack_database.gd`（敌怪与小队）
- **core/grid/** — `hex_grid.gd`：六边形坐标、距离、邻居、寻路
- **core/ai/** — 敌怪 AI（《敌怪ai逻辑.txt》架构）：`enemy_ai.gd`（决策门面）、`ai_profile.gd`（行为档案）、`goal.gd`（战术目标）、`action_candidate.gd`（行动候选）、`condition_evaluator.gd`（条件）、`target_selector.gd`（目标）、`position_evaluator.gd`（站位）、`utility_evaluator.gd`（Utility 评分）、`ai_archetype.gd`（旧名兼容层）
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
| core/ai/enemy_ai.gd | AI 决策门面：decide / get_action_candidates / evaluate（纯逻辑） |
| core/ai/ai_profile.gd | 行为档案：Aggression/Support/Caution/Mobility/Defensiveness/TargetPriority/PreferredRange + 9 个模板 |
| core/ai/goal.gd | 战术目标：进攻/集火/保护首领/支援/保持射程/保命 |
| core/ai/action_candidate.gd | 行动候选：Action + Target + Position + Parameters |
| core/ai/condition_evaluator.gd | 条件：能否使用（与 Utility 分离） |
| core/ai/target_selector.gd | 目标选择：威胁估值 + 目标优先级 + 可击杀 |
| core/ai/position_evaluator.gd | 站位评价：期望距离 + 危险回避 + 护卫阻挡 |
| core/ai/utility_evaluator.gd | Utility 评分：Base+Target+Position+Context+Personality+Urgency+Random |
| core/ai/ai_archetype.gd | 兼容层（旧名 AiArchetype，新代码用 AiProfile） |
| ui/battle/ai_debug_panel.gd | AI 决策调试面板（F4 / 点击敌怪） |
| ui/battle/battle_hand_ui.gd | 手牌显示与出牌输入 |
| ui/battle/party_hp_panel.gd | 队伍血条 |
| ui/battle/turn_order_bar.gd | 行动顺序条 |
| ui/battle/battle_settlement_panel.gd | 战斗结算（钱币/经验/卡牌奖励） |

## 规则与实现文档

- [rules.md](rules.md) — 战斗规则（移动/距离/伤害/格挡/buff/胜负/战利品）
- [architecture.md](architecture.md) — 代码如何实现这些规则
