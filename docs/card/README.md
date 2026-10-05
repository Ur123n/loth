# Card 模块

卡牌数据结构、抽牌/弃牌/费用/荷载、卡组与卡牌执行入口。

## 是什么

- **core/card/** — `card_database.gd`（CardDB，Autoload：加载 content/cards/*.json）、`card_data.gd`（CardData 资源）、`card_drop_database.gd`（Demo 卡牌掉落表）
- **core/effect/logic_chains/** — 组件化效果资源（AttackEffect / MoveEffect / DefenseEffect / BuffEffect / DrawEffect …）
- **content/cards/** — 卡牌数据（JSON，由卡牌编辑器生成）、conditions.json、card_drops.json、card_faces/（卡面图）
- **content/cards/mechanics.json** — 重制卡牌可复用机制、参数模板和实现索引
- **ui/cards/** — 卡牌网格、详情弹窗、奖励选择界面

## 文件地图

| 文件 | 职责 |
| --- | --- |
| core/card/card_database.gd | 解析卡牌 JSON → CardData + 效果资源；中文描述生成 |
| core/card/card_data.gd | 卡牌数据结构（费用/荷载/类型/目标/关键词/效果） |
| core/card/card_drop_database.gd | 读取 content/cards/card_drops.json（Demo 奖励池） |
| core/effect/logic_chains/*.gd | 每种逻辑链一个 Resource 类，class_name 全局可用 |
| content/cards/*.json | 卡牌内容数据 |
| content/cards/conditions.json | 条件类型配置（编辑器与结算共用） |

## 规则与实现文档

- [rules.md](rules.md) — 卡牌数据字段、关键词、逻辑链、条件判断、卡组规则
- [architecture.md](architecture.md) — 数据 → Resource 的解析链路
- [redesign_draft.md](redesign_draft.md) — 卡牌系统重设计草案（历史设计文档）
