class_name DrawEffect
extends Resource

## 基础逻辑链：抽牌。
## value = 抽取张数；从抽牌堆抽牌，抽牌堆为空时自动把弃牌堆洗回。
## 受手牌上限约束（达到上限后停止抽取）。

@export var value: int = 1
