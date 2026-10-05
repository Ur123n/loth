class_name InspectTopCardsEffect
extends Resource

## 暂存抽牌堆顶部实体，依次选择去向并安排剩余牌序。
@export var count: int = 0
@export var pick_to_hand: bool = false
@export var pick_to_discard: int = 0
@export var reorder_remaining: bool = true
