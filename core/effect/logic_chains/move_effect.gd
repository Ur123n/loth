class_name MoveEffect
extends Resource

## 基础逻辑链：移动。
## distance = 移动距离（格），遵循 GDD 第 3 节移动规则。

@export var distance: int = 1
@export var target: String = "self"
