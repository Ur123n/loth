class_name BuffEffect
extends Resource

## 基础逻辑链：给予 buff。
## target = 对象（self / ally / enemy）；buff_type = 种类；
## duration = 持续时间（回合数）；stacks = 初始层数（可为负，如“肾上腺素透支”=-2）。
## 具体触发时机/层数规则由 编辑器/buff创建.xlsx 中的 buff 数据决定。

@export var target: String = "self"
@export var buff_type: String = ""
@export var duration: int = 0
@export var stacks: int = 1
