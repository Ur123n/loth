class_name AddToDrawEffect
extends Resource

## 基础逻辑链：将指定卡牌的复制加入抽牌堆。
## card_name = 卡牌名；value = 加入张数；
## position = "shuffle"（洗入抽牌堆，随机位置）/ "top"（置于抽牌堆顶部，之后先抽到）。

@export var card_name: String = ""
@export var value: int = 1
@export var position: String = "shuffle"
