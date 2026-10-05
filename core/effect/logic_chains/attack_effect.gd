class_name AttackEffect
extends Resource

## 基础逻辑链：攻击。
## value = 攻击卡面板数值；attack_range = 攻击范围（六边形距离）；
## pierce = 无视护甲（护盾与格挡已统一为格挡，pierce 时直接扣生命）。
## 攻击伤害属于“受到伤害”：有伤害来源，经力量倍率与虚弱修正后，
## 受易伤放大、可被格挡抵消（pierce 时跳过格挡）。

@export var value: int = 1
@export var attack_range: int = 1
@export var pierce: bool = false
@export var alt_value: int = 0   # 本回合已移动时替换 value（0=无条件）
@export var alt_condition: String = "moved_this_turn"
