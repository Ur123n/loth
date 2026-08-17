class_name CopyEffect
extends Resource

## 基础逻辑链：复制本牌。
## 把正在打出的这张卡的 value 张复制品加入指定牌堆
## （pile = hand / draw / discard，默认 discard，参考“愤怒”把复制品洗入弃牌堆）。

@export var value: int = 1
@export var pile: String = "discard"
