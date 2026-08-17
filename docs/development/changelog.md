# 变更日志

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
