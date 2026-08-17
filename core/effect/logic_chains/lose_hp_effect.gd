class_name LoseHpEffect
extends Resource

## 基础逻辑链：失去生命。
## 属于“失去生命”（无伤害来源）：无视格挡，不受力量/易伤影响（GDD 第 16 节）。
## target = self（出牌者自身，自损）/ enemy（作用于目标敌人）。

@export var value: int = 1
@export var target: String = "self"
