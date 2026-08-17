class_name KnockbackEffect
extends Resource

## 基础逻辑链：击退。
## 打出后本回合内，下一次攻击命中敌人时将其沿远离方向推开 value 格
## （由 battle_map 在出牌结算后执行；被阻挡则原地）。

@export var value: int = 1
