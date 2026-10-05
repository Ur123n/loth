# Battle 架构

## 代码结构

```
core/battle/
├── battle_manager.gd    战斗主流程：回合推进、行动顺序、出牌入口、胜负与战利品
├── battle_map.gd        战斗场景根脚本：地图/敌怪生成、战斗触发、结束后切场景
├── battle_map_data.gd   地图数据（网格尺寸、障碍、出生点）
├── battle_unit.gd       单位（HP/格挡/移动力/位置/存活）
├── turn_system.gd       行动顺序
├── terrain_data.gd      地形数据
├── enemy_data.gd        敌怪数据类（EnemyData）
├── enemy_database.gd    EnemyDB（Autoload）：content/enemies/*.json
└── enemy_pack_database.gd EnemyPackDB（Autoload）：content/encounters/enemy_packs.json
core/effect/
├── effect_system.gd     EffectSystem：效果结算层（卡牌效果 / buff / 通用伤害 / 牌堆辅助）
└── logic_chains/        组件化效果资源（AttackEffect / BuffEffect / DrawEffect …）
core/grid/hex_grid.gd    六边形网格数学（尖顶 odd-r；DEFAULT_SIDE_LENGTH=20）
core/ai/enemy_ai.gd      AI 决策门面：decide / get_action_candidates / evaluate（纯逻辑，可测试）
core/ai/ai_profile.gd    行为档案：统一 7 参数 + 9 个模板 + ai_profile 覆盖（角色→模板推导）
core/ai/goal.gd          战术目标：进攻/集火/保护首领/支援/保持射程/保命
core/ai/action_candidate.gd  行动候选：Action + Target + Position + Parameters
core/ai/condition_evaluator.gd 条件判定（能做 vs 值不值得做）
core/ai/target_selector.gd    目标选择：动态威胁 + TargetPriority + Kill Potential
core/ai/position_evaluator.gd 站位评价：PreferredRange + 危险回避 + 护卫阻挡
core/ai/utility_evaluator.gd  Utility 评分：Base+Target+Position+Context+Personality+Urgency+Random
core/ai/ai_archetype.gd  兼容层（旧名 AiArchetype）
ui/battle/               手牌、血条、行动顺序条、结算面板、AI 决策调试面板
world/encounters/BattleMap.tscn  战斗场景
```

## 类图与数据流（2026-08-17 效果层拆分后）

```
BattleManager（回合流程 / 出牌入口 / 胜负战利品）
   │ 持有并驱动
   ▼
EffectSystem（效果结算：卡牌效果 / buff / 通用伤害 / 牌堆辅助）
   │ 通过 setup() 注入
   ├─ units / RNG / card_lookup
   ├─ battle_log / hp_changed / unit_defeated（信号，转发给 BattleManager 对外接口）
   └─ battle_over_check（单位阵亡 → 回调 BattleManager 判定胜负）
```

数据流：`play_card`（扣费 / 移出手牌）→ `EffectSystem.resolve_effects`（攻击 / 格挡 / buff / 抽弃牌 / 生成复制…）
→ `take_damage` / `lose_hp` / `heal_unit` → 发出 `hp_changed` / `unit_defeated`
→ `BattleMap._on_unit_defeated` 把敌我单位统一转成尸骸并切换尸骸资源
→ `BattleManager._check_battle_over` 只统计非尸骸存活单位。

六边格尺寸由 `HexGrid.DEFAULT_SIDE_LENGTH` 单点定义为 20 px。`BattleMap`、`BattleMapData` 与
`BattleMapView` 的 `tile_size` 仅为兼容旧场景保留命名，语义统一为六边形边长/外接圆半径。

尸骸表现流：`EnemyData` / `CharacterData` 提供 `corpse_art_a_path`、`corpse_art_b_path`；
`BattleUnit.become_corpse()` 按单位名称与格坐标生成稳定选择，加载可用尸骸贴图；若资源尚未交付，
`CharacterVisual.show_corpse_placeholder()` 会隐藏存活图并显示扁平骨堆占位，不修改原图颜色。

## 关键数据流

1. 进入战斗 → `BattleMap._ready()` 读取 GameState（队伍、Demo 模式），生成地图与敌怪。
2. `BattleManager` 管理回合：玩家行动（移动/出牌）→ 效果结算（EffectSystem，见 docs/card）→ 敌怪行动（`EnemyAI.decide()` 决策 + BattleMap 执行）→ 下回合。
3. 战斗结束：结算钱币/经验/战利品，写 GameState；通过 `change_scene_to_file` 返回大世界或 Demo 营地。
   - 正式模式回 `res://world/map/Main.tscn`
   - Demo 模式回 `res://demo/DemoHub.tscn`

## 与 Card / Effect 的协作

- BattleManager 不直接实现卡牌效果：卡牌效果由 core/card/ 解析、core/effect/ 的逻辑链 Resource 承载，结算统一由 EffectSystem（`resolve_effects` / `resolve_attack`）执行。
- buff 结算集中在 EffectSystem（`resolve_buff_*` 系列、按触发时机结算、buff 触发 / 衰减），buff 数据来自 BuffDB。
  攻击类时机（受到攻击时 / 造成攻击伤害时）经伤害修正钩子 `_apply_damage_modifiers` 与回合类时机共用时机匹配，
  在 `take_damage`（易伤 +50%）/ `resolve_attack`（虚弱 -25%）中结算；
  各 buff 行为按名称注册为函数（`_trigger_handlers` / `_damage_modifier_handlers` /
  `_draw_bonus_handlers` / `_energy_bonus_handlers`），结算代码不再散落 buff 名称 match。
- BattleManager 仅保留回合流程 / 行动顺序 / 出牌入口 / 胜负战利品；为兼容既有测试与调用方，私有方法保留为转发（行为与拆分前一致）。

## Demo 接入

- GameState.demo_mode=true 时，BattleMap 使用随机地图种子与随机敌怪构成（DemoComposer），结算后回 DemoHub。
- Demo 使用独立存档 user://demo_save.json，不影响正式档。

## AI 决策引擎（《敌怪ai逻辑.txt》已实施）

按文档重构为分层架构，全部在 `core/ai/`（纯逻辑，无场景依赖，可无头测试）：

1. **行为档案层**（`AiProfile`，core/ai/ai_profile.gd）：统一 7 个行为参数
   Aggression / Support / Caution / Mobility / Defensiveness / TargetPriority / PreferredRange，
   内置 9 个模板（士兵/狂战士/猎人/护卫/刺客/鲁莽/支援/首领/木桩）。
   解析优先级：`enemy_data.archetype` > 小队角色推导 > 旧 ai 字段 > 士兵，
   最后叠加 `enemy_data.ai_profile`（Excel「AI参数」列）的按敌怪覆盖。
2. **战术目标层**（`AiGoal`）：进攻玩家 / 集火可击杀 / 保护首领 / 支援受伤友军 /
   保持射程 / 保命 / 无 AI。Goal 决定 Utility 大方向，不直接规定唯一行动。
3. **条件层**（`AiConditionEvaluator`）：回答“能不能做”（射程、能否移动、护卫/支援前提、
   性格是否撤退），与 Utility 分离；条件不满足的行动只保留 0 分壳候选并写明被拒原因。
4. **候选层**（`ActionCandidate`）：决策单位 = Action + Target + Position + Parameters；
   每个候选携带 Utility 分项（components），供调试面板解释。
5. **目标层**（`AiTargetSelector`）：动态威胁估值（力量/敏捷/意志 + 装备伤害修正 + 易伤状态），
   按 TargetPriority（最近/低生命/高威胁/孤立/后排/可击杀/均衡）评分，
   并叠加 Kill Potential（可直接击杀 +45~50，防止 AI 放弃眼前必杀）。
6. **位置层**（`AiPositionEvaluator`）：移动力内对可达格评分——偏离 PreferredRange 扣分、
   谨慎型回避玩家相邻格、护卫围绕首领并靠近最近玩家阻挡；返回最佳格 + 路径 + 位置分。
7. **评分层**（`AiUtilityEvaluator`）：
   Utility = Base + Target + Position + Context + Personality + Urgency + Random；
   随机变化仅在传入 RNG 时生效（±6，battle_map 每场战斗一个种子），
   且必杀机会（Kill Potential 分项差距）不会被随机覆盖。
8. **门面**（`EnemyAI`）：`get_action_candidates(battle_state)` → `evaluate(candidates)` →
   决策字典（action/action_key/goal/target/move_cell/path/score/candidates/explain）；
   `decide()` 保留旧签名（可加可选 rng 参数）供 battle_map 调用。

执行与调试：
- `battle_map._execute_ai_decision`：沿路径移动（进入攻击范围即停），随后按行动类型执行；
  攻击经 `BattleManager.enemy_attack` → `EffectSystem.take_damage`，AI 不直接修改任何战斗数据
  （对应文档“AI → ActionSystem → EffectSystem → BattleState”的现有落地形态）。
- `ui/battle/ai_debug_panel.gd`：F4 或点击场上敌怪，查看“Goal / 目标 / 候选行动评分（含
  Base/Target/Position/Context/Personality/Urgency/Random 分项）/ 最终选择 / 原因”。
- Boss（首领模板）拥有专属规则：不撤退、半血狂暴 +20；更复杂的每 Boss 阶段脚本为后续扩展
  （SkillSet / BossController，仍必须经 ActionSystem/EffectSystem 执行）。

## 已知边界

- 正式流程目前只有大世界战斗触发点一处（main.gd），敌怪由场景/触发配置；随机遭遇尚未实现（见 docs/development/known_issues.md）。
- 敌怪暂无技能（SkillSet 预留：`enemy_data.skills` 数据字段已就位，`使用技能` 行动评分恒为 0，
  待技能接入 ActionSystem）；支援模板目前以“贴近受伤友军”表达，治疗/增益技能待 SkillSet 落地。
- Triggers / Passive 按文档第 23-24 节应走现有 Trigger/Status/Effect 系统（buff 已接入
  EffectSystem），不作为 EnemyAI 的一部分实现。
