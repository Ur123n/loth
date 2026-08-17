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
core/grid/hex_grid.gd    六边形网格数学（坐标/距离/邻居/寻路）
core/ai/enemy_ai.gd      AI 决策引擎：目标选择 / 行动评分 / 位置评价（纯逻辑，可测试）
core/ai/ai_archetype.gd  行为模板（性格参数、角色→模板推导、Boss 规则）
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
→ `take_damage` / `lose_hp` / `heal_unit` → 发出 `hp_changed` / `unit_defeated` → `BattleManager._check_battle_over`。

## 关键数据流

1. 进入战斗 → `BattleMap._ready()` 读取 GameState（队伍、Demo 模式），生成地图与敌怪。
2. `BattleManager` 管理回合：玩家行动（移动/出牌）→ 效果结算（EffectSystem，见 docs/card）→ 敌怪行动（`EnemyAI.decide()` 决策 + BattleMap 执行）→ 下回合。
3. 战斗结束：结算钱币/经验/战利品，写 GameState；通过 `change_scene_to_file` 返回大世界或 Demo 营地。
   - 正式模式回 `res://world/map/Main.tscn`
   - Demo 模式回 `res://demo/DemoHub.tscn`

## 与 Card / Effect 的协作

- BattleManager 不直接实现卡牌效果：卡牌效果由 core/card/ 解析、core/effect/ 的逻辑链 Resource 承载，结算统一由 EffectSystem（`resolve_effects` / `resolve_attack`）执行。
- buff 结算集中在 EffectSystem（`resolve_buff_*` 系列、按触发时机结算、buff 触发 / 衰减），buff 数据来自 BuffDB。
- BattleManager 仅保留回合流程 / 行动顺序 / 出牌入口 / 胜负战利品；为兼容既有测试与调用方，私有方法保留为转发（行为与拆分前一致）。

## Demo 接入

- GameState.demo_mode=true 时，BattleMap 使用随机地图种子与随机敌怪构成（DemoComposer），结算后回 DemoHub。
- Demo 使用独立存档 user://demo_save.json，不影响正式档。

## AI 决策引擎（《敌人ai重构方案》已实施）

三层决策，全部在 `core/ai/enemy_ai.gd`（纯逻辑，无场景依赖，可无头测试）：

1. **行为模板层**（`AiArchetype`）：按 `enemy_data.archetype` > 小队角色 > 旧 ai 字段 > 士兵 解析。
2. **战术层**（`EnemyAI.decide`）：
   - `select_target`：护卫→攻击靠近首领的玩家；其余按威胁评分（威胁 + 低生命/距离/孤立修正 + 可击杀 +50）。
   - `_score_actions`：攻击/接近/追击/撤退/保护/支援/等待 逐项评分（性格加权；首领半血狂暴 +20；使用技能为 SkillSet 预留），取最高分。
3. **行动层**（`_plan_move`）：对选定行为在移动力内做六边形位置评价（期望站位距离 + 危险回避），返回路径。

执行与调试：
- `battle_map._execute_ai_decision`：沿路径移动（进入攻击范围即停），随后按行动类型攻击；结果写入 `_last_ai_decisions`。
- `ui/battle/ai_debug_panel.gd`：F4 或点击场上敌怪，查看“目标 / 候选行动评分 / 最终选择 / 原因”。
- Boss（首领模板）拥有专属规则：不撤退、高威胁/低生命双优先、半血狂暴；更复杂的每 Boss 阶段脚本为后续扩展（SkillSet / BossController）。

## 已知边界

- 正式流程目前只有大世界战斗触发点一处（main.gd），敌怪由场景/触发配置；随机遭遇尚未实现（见 docs/development/known_issues.md）。
- 敌怪暂无技能（SkillSet 预留：`使用技能` 行动评分恒为 0）；支援模板的治疗、每 Boss 专属阶段脚本待后续实施。
