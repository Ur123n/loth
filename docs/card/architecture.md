# Card 架构

## 数据 → Resource 解析链路

1. `CardDB.load_all()`（Autoload，`_ready()` 时执行）遍历 `content/cards/*.json`。
2. 每张卡 JSON 解析为 `CardData`：顶层字段（费用/荷载/类型/关键词/美术）直接映射；`effects` 数组交给 `_parse_effect()`。
3. `_parse_effect()` 按 `logic` 字符串匹配创建对应逻辑链 Resource（`AttackEffect.new()` 等），并写入参数；若有 `condition`，存入效果的 meta（`effect.set_meta("condition", …)`）。
4. 逻辑链类位于 `core/effect/logic_chains/`，全部带 `class_name`，因此 CardDB 可直接引用类型而无需路径 preload。

## 类关系

```
CardDatabase (Autoload, Node)
  └── cards: Array[CardData]
        └── effects: Array[Resource]  ← AttackEffect / MoveEffect / DefenseEffect /
                                        BuffEffect / DrawEffect / DiscardEffect /
                                        AddToHandEffect / AddToDrawEffect /
                                        AddToDiscardEffect / GenerateEffect / CopyEffect /
                                        LoseHpEffect / GainEnergyEffect / FlankEffect /
                                        KnockbackEffect
```

## 描述生成

`CardDatabase.describe_card(card)` 用静态方法把 effects 与关键词翻译为中文文本（技能库/提示界面用）。条件会生成“如果…，则 ”前缀。

## 结算位置

CardDB 只负责数据解析与查询；**卡牌结算在 BattleManager**（玩家出牌 → 按 effects 顺序调用 BattleManager 结算接口）。效果逻辑链是纯数据 Resource，不包含结算代码 —— 结算规则集中在 BattleManager 与 EffectSystem 相关函数中。

## 掉落表

- `CardDropDB` 读取 `content/cards/card_drops.json`（Demo 敌怪专用卡牌掉落表，正式战斗暂不使用）。
- 奖励界面：`ui/cards/card_reward_panel.gd`。

## 编辑器联动

- 卡牌 JSON 由 `编辑器/CardEditor/card_editor.py` 生成/编辑（双击 `启动卡牌编辑器.bat`）。
- 编辑器读取 `content/cards/conditions.json` 作为条件类型下拉，读取 `content/buffs/*.json` 作为 buff 下拉。
- 卡面图复制到 `content/cards/card_faces/`。