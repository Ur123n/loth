class_name BuffData
extends Resource

## buff 数据（数据驱动，由 编辑器/buff创建.xlsx 同步生成）。
## 对应 GDD 第 15 节，并扩展：阵营 / 类型（层数增益、层数持续、持续、即时）/
## 每层持续加成 / 每回合衰减 / 触发后消失 / 触发时机与条件。

@export var buff_name: String = ""
@export var alignment: String = "中立"        # 正面 / 负面 / 中立
@export var buff_type: String = "持续"        # 层数增益 / 层数持续 / 持续 / 即时
@export var value: int = 0                    # 效果强度（每层/每回合）
@export var base_duration: int = 1            # 基础持续时间（回合）
@export var duration_per_stack: int = 0       # 每层持续加成（回合，层数持续型使用）
@export var decay_per_turn: bool = false      # 每回合是否衰减层数
@export var decay_amount: int = 1             # 每回合衰减层数
@export var consumed_on_trigger: bool = false # 触发后是否消失
@export var trigger_timing: String = ""       # 触发时机（回合开始/结束回合/受到攻击时/造成攻击伤害时 等）
@export var trigger_condition: String = ""    # 触发条件
@export var description: String = ""
@export var icon_path: String = ""            # 图标（状态栏小图），res:// 路径
@export var art_path: String = ""             # 主体贴图（res://，留空则用文本/占位）
@export var animation_path: String = ""       # 动画/特效资源（res://）
