class_name DefenseEffect
extends Resource

## 基础逻辑链：防御。
## value = 防御数值（格挡，护盾与格挡已统一），获得时累加到格挡值，
## 轮次开始清空，先于生命抵消“受到伤害”（GDD 第 16 节）。

@export var value: int = 1
@export var alt_value: int = 0   # 本回合已移动时替换 value（0=无条件）
@export var target: String = "self"
