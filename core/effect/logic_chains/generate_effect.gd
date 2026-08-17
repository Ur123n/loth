class_name GenerateEffect
extends Resource

## 基础逻辑链：生成牌。
## card_name 非空时生成指定卡的复制；为空时按 pool 随机生成一张
## （攻击 / 行动 / 能力 / 全部）。value = 生成张数；
## pile = 目标牌堆（hand / draw / discard，默认 hand）。

@export var card_name: String = ""
@export var pool: String = ""
@export var value: int = 1
@export var pile: String = "hand"
