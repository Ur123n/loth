class_name PassiveData
extends Resource

## 基础被动（道途接口的一部分）。
## 触发时机（trigger_timing）：回合开始 / 结束回合 / 造成攻击伤害时 / 抽牌时 等；
## 具体数值由 value 承载，BattleManager 在对应时机结算。

@export var passive_name: String = ""
@export var description: String = ""
@export var trigger_timing: String = ""
@export var value: int = 0
