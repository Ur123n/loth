# 数据指南（content/ 内容数据）

content/ 存放由 Excel 表格同步生成或编辑器创建的内容数据（JSON / .tres），由各数据库自动加载。新增游戏内容优先改表格/数据，而不是改 core/ 代码：

| 目录 | 数据库 | 来源表格 |
| --- | --- | --- |
| content/equipment/ | EquipDB | 编辑器/装备创建.xlsx |
| content/buffs/ | BuffDB | 编辑器/buff创建.xlsx |
| content/npcs/ | NpcDB | 编辑器/NPC创建.xlsx |
| content/items/ | ItemDB | 编辑器/物品创建.xlsx |
| content/paths/ | PathDB | 编辑器/道途创建.xlsx |
| content/enemies/ | EnemyDB | 编辑器/敌怪创建.xlsx（“行为模板”列 → archetype，AI 行为模板） |
| content/cards/ | CardDB | 卡牌编辑器（启动卡牌编辑器.bat）+ 编辑器/卡牌创建.xlsx |
| content/encounters/ | EnemyPackDB | 编辑器/敌怪小队创建.xlsx |

## 美术资源接口（所有数据统一）

卡牌的美术字段相对 `content/cards/`（CardDB 拼接 res://content/cards/<路径>）；其余库直接填 res:// 路径（Assets 见 assets/README.md）。

每个 JSON 均含三个美术字段（均可留空，留空使用色块/文本占位）：

- `icon` —— 图标（列表/槽位小图），res:// 路径
- `art` —— 主体贴图，res:// 路径
- `animation` —— 动画/动画场景资源，res:// 路径

角色与敌怪另外支持两种死亡资源：

- `corpse_art_a` —— 尸骸 A 主体贴图，res:// 路径
- `corpse_art_b` —— 尸骸 B 主体贴图，res:// 路径

两项可留空；运行时会按单位名称与格坐标稳定选择可用版本。两项都不可用时改用独立尸骸占位形态，
不会把存活主体染灰。角色表与敌怪表可使用“尸骸美术A / 尸骸美术B”列同步这些字段。

修改表格后运行 `编辑器/同步表格.bat` 重新生成 JSON。

## 物品数据（content/items/）

物品是背包/战利品单位，字段：`name` / `description` / `shape`（体积形状：
1x1 / 2x1 / 1x2 / 3x1 / 2x2 / L）/ `value`（价值）/ 美术接口 icon/art/animation。
物品按形状占用背包格子，拾取时检测空位（first-fit）。

## 道途数据（content/paths/）

每个道途一个 JSON：`name` / `character`（归属角色）/ `description` / `passive`
（基础被动：name/description/trigger_timing/value）/ `starter_cards`（专属初始牌卡名数组）/
美术接口 icon/art/animation。角色通过 `CharacterData.get_path()` 获取道途接口。

## buff 列表（2026-08-12，共 7 个）

| buff | 阵营 | 类型 | 触发时机 | 触发后 |
| --- | --- | --- | --- | --- |
| 易伤 | 负面 | 层数持续 | 受到攻击时 | 不消失 |
| 虚弱 | 负面 | 层数持续 | 造成攻击伤害时 | 不消失 |
| 中毒 | 负面 | 层数增益＋层数持续 | 结束回合时 | 不消失 |
| 预抽牌 | 正面 | 层数增益 | 下回合抽牌时 | 消失 |
| 费用预支 | 正面 | 层数增益 | 下回合获得费用时 | 消失 |
| 疗愈 | 正面 | 层数增益 | 下回合角色行动阶段 | 不消失（每次触发层数减一） |
| 预格挡 | 正面 | 层数增益 | 下回合开始时 | 消失 |

战斗数据分类：**失去生命**（无伤害来源，无视格挡，不受力量/易伤影响，如中毒）与
**受到伤害**（有伤害来源，受力量/虚弱/易伤影响，可被格挡抵挡）。护盾与格挡统一为单一“格挡”值，
轮次开始时清空，先于生命抵消受到伤害。

## 敌方小队表（content/encounters/enemy_packs.json）

每支小队由 3~4 只相互配合的敌怪组成，按强度（普通/精英/Boss）分类；
战斗时从符合强度的若干小队中随机抽取一支（EnemyPackDB 提供抽取/展开接口，
DemoComposer 与 battle_map 使用）。来源表格：编辑器/敌怪小队创建.xlsx。

每名成员带小队角色（role：前排 / 近战 / 远程 / 护卫 / 侧翼 / 炮灰 / 首领，首领加 leader 标记），
同一种敌怪可在不同小队担任不同角色。战斗 AI（EnemyAI + battle_map）按角色协同：
全队集火最弱玩家、护卫保护首领、远程保持射程边缘、侧翼停在 2 格外包抄等。

## 敌怪 AI 行为档案（AIProfile）

每只敌怪的行为由 `core/ai/ai_profile.gd` 的 AiProfile 决定（《敌怪ai逻辑.txt》第 4 节），
统一 7 个参数：Aggression（进攻性）/ Support（支援性）/ Caution（谨慎）/
Mobility（机动性）/ Defensiveness（防守性）/ TargetPriority（目标优先级）/
PreferredRange（理想距离）。参数只影响 Utility 评分，不直接规定“必须做什么”。

来源优先级：

1. `敌怪创建.xlsx`「行为模板」列的 archetype 模板（士兵/狂战士/猎人/护卫/刺客/鲁莽/支援/首领/木桩）；
2. 小队角色推导（前排→士兵、近战→狂战士、远程→猎人、护卫→护卫、侧翼→刺客、炮灰→鲁莽、首领→首领）；
3. 旧 `ai` 字段兜底（靠近→士兵、远离→猎人、无→木桩）；
4. `敌怪创建.xlsx`「AI参数」列按敌怪覆盖（JSON 对象字符串，如
   `{"aggression": 80, "target_priority": "lowest_hp"}`，只覆盖给出的参数）。

「技能集」列（JSON 数组）为 ActionSet 预留：敌怪通过数据声明可用 Action，
当前游戏内尚无技能实现，该列留空即可。
