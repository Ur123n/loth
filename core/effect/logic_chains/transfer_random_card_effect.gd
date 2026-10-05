class_name TransferRandomCardEffect
extends Resource

## 从来源牌区不重复随机选择实体牌，转移至目标牌区。
@export var source: String = "discard"
@export var destination: String = "draw"
@export var exclude_card_type: String = ""
@export var position: String = "top"
@export var count: int = 1
