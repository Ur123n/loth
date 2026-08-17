class_name DiscardEffect
extends Resource

## 基础逻辑链：弃牌。
## value = 弃牌张数；mode = "random"（随机弃 value 张）/ "all"（弃掉全部手牌）。
## 弃掉的牌进入弃牌堆；手牌不足时按实际数量弃掉。

@export var value: int = 1
@export var mode: String = "random"
