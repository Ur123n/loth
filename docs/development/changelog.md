# 变更日志

## 2026-08-17　存档扩展设计（待办第 3 项）

- 存档载荷版本化（v4）：新增 battle_trigger_consumed / skill_light_position（触发状态持久化），并预留 flags（剧情 Flag）/ quest_state（任务状态）/ world_state（世界状态）字段，缺省安全。
- load_game() 显式按版本迁移：旧档（<v4）缺失字段自动补默认值，既有字段读取逻辑保留。
- 确认 SaveSystem 唯一入口：全项目仅 game_state.gd 写存档文件；Demo 换档仅改 save_path，不另建持久化通道。
- 新增 tests/save/test_save_roundtrip.gd（26 断言）：v4 保存→加载往返一致；v3 旧档缺省字段可用。
- 更新 docs/architecture.md 的存档模块说明。

## 2026-08-17　拆分 battle_manager.gd（待办第 6 项）

- 新建 core/effect/effect_system.gd（EffectSystem）接管效果结算：卡牌效果（resolve_effects / resolve_attack，含伤害/格挡/pierce/条件）、buff 结算（resolve_buff_* 系列、按触发时机、衰减）、通用伤害（lose_hp / take_damage / heal_unit）、牌堆辅助（抽/弃/消耗/生成/复制/固有牌）。
- battle_manager.gd 瘦身：只保留回合流程、行动顺序、出牌入口、胜负判定、战利品；既有信号与对外接口不变，私有方法保留为转发兼容。
- 全量 13 个无头测试通过（393 断言 / 0 失败）；4 个场景无头加载无错误。
- 更新 docs/battle/architecture.md（类图与数据流）。

## 2026-08-17　装备流程闭环（有舍有得）

- 装备定位落实 GDD 第 14 节：不是单纯的数值提升，而是「有舍有得」的机制修正——每件装备的 mods 既有收益（正修正）也有代价（负修正）。
- 新增 11 种修正类型：属性/生命上限/行动值/荷载容量/移动力/攻击范围/攻击伤害%/防御卡格挡/抽牌/费用/回合开始格挡。
- 6 件装备（铁剑/铁头盔/皮甲/草鞋/铜戒指/长枪）均配置一得一舍；装备创建.xlsx 新增「修正」列并补长枪行，编辑器说明同步。
- 穿脱闭环：背包点击装备穿到当前角色（槽位被占先卸旧装备回背包），装备面板点击卸下回背包；存档 v3 按名称持久化装备，旧档缺省为空。
- 战斗接入：HP/伤害基数/行动顺序/移动力/攻击范围/每回合抽牌与费用/回合开始格挡/防御卡格挡均使用合并后属性与修正。
- 新增 tests/character/test_equipment.gd（50 断言）+ tests/battle/test_equipment_battle.gd（13 断言）；全量 12 个无头测试通过（367 断言 / 0 失败），4 个场景无头加载无错误。

## 2026-08-17　Git 仓库初始化

- 在 `C:\游戏` 初始化 Git 仓库并完成首次提交（630 个文件基线：core/content/ui/world/docs/tests 等）。
- `.gitignore` 确认已忽略 `.godot/`、`android/`，并补充 `__pycache__/`、`*.pyc` 缓存规则；已入库的 pyc 缓存文件移出版本控制。
- docs/development/known_issues.md 的“未初始化 Git 仓库”条目已标记为已处理。

## 2026-08-17　敌人 AI 重构（行为模板 + 评分决策）

- 按《敌人ai重构方案》落地三层决策：行为模板（AiArchetype）→ 战术层（目标选择 + 行动评分）→ 行动层（六边形位置评价）。
- 9 个行为模板：士兵/狂战士/猎人/护卫/刺客/鲁莽/支援/首领/木桩；敌怪数据新增 archetype 字段（Excel“行为模板”列同步）。
- 目标评分 = 威胁（30+力量×2+敏捷+意志）+ 生命/距离/孤立修正 + 可击杀加成；行动评分按性格加权（攻击/接近/追击/撤退/保护/支援/等待）。
- 首领模板（Boss 规则）：不撤退、高威胁/低生命双优先、半血狂暴 +20；使用技能为 SkillSet 预留。
- 新增 AI 调试面板（F4 / 点击敌怪查看目标、候选评分、最终选择与原因）。
- 新增 tests/ai/test_ai_decisions.gd（31 断言）。

## 2026-08-17　模块化重构（core/content/ui/world/docs/tests）

- 将 Godot 工程根目录提升到 `C:\游戏`（原 `战斗系统/`）。
- 目录重组：
  - `scripts/` → `core/`（规则系统）、`ui/`（界面）、`demo/`
  - `data/`、`卡牌/`、`数据/`、`敌怪/` → `content/`（内容数据）
  - `scenes/` → `world/`（地图/遭遇场景）
  - `美术资源/` → `assets/`
  - 根文档 → `docs/`（architecture + 各模块 + development）
- 更新全部 res:// 引用、autoload 配置、编辑器输出路径（sync_tables / card_editor / update_tables）、启动 bat。
- 新增 README.md、AGENTS.md、docs/ 模块文档（battle/card/character/world/story/quest/development）。

- 修复：sync_tables.py 卡牌清理不再误删 conditions.json / card_drops.json（重建了两个被误删的配置）；卡牌编辑器 load_cards() 只加载真卡牌。
- 文档：敌人 AI 重构方案归入 docs/battle/；重构方案归入 docs/development/。
- 验证：10 个无头测试全通过（300 断言 / 0 失败）；4 个场景无头加载无错误。

## 2026-08-12　升级改为自由属性点 + 角色面板加点按钮

- 升级每次获得 1 点自由属性点（不再自动加四项属性）；面板加点点数即时存档。
- 旧档兼容：未消耗属性点随存档保存，旧档缺省为 0。

## 2026-08-12　战斗测试 Demo + 道途系统

- 独立战斗测试 Demo：启动直接进入随机战斗，结算后回修整营地，光点询问是否进入下一场。
- 道途系统：4 道途（梦魇行者/孢子卫士/侠盗/解剖学者）+ 专属初始牌 + 基础被动。
- 敌怪：精英/Boss 分级与战利品表；修复敌怪回合结束 buff 结算。
- 详细记录见 [work_log.md](work_log.md)。
