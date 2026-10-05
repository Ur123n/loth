class_name ActionCandidate
extends RefCounted

## 行动候选（《敌怪ai逻辑.txt》第 5 节）。
##
## AI 的实际决策单位不是 Action，而是 Action + Target + Position + Parameters：
## 例如 Attack → 攻击骑士 / 攻击法师 是两个不同候选；Move → 六边形 A / B / C 也是多个候选。
## 每个候选携带 Utility 分项（components），供调试面板解释“为什么选它/不选它”。

var action_key: String = ""      # attack / approach / chase / retreat / protect / support / skill / wait
var label: String = ""           # 展示名（攻击/接近/追击/撤退/保护/支援/使用技能/等待）
var target: BattleUnit = null    # 攻击目标（无目标行动为 null）
var move_cell: Vector2i = Vector2i(-1, -1)   # 期望站位（无可移动目标格时等于当前位置）
var path: Array[Vector2i] = []               # 到 move_cell 的路径（不含起点）
var params: Dictionary = {}      # 附加参数：锚点 / 期望距离 / 位置分 / 条件结果等
var components: Dictionary = {}  # Utility 分项 {base,target,position,context,personality,urgency,random}
var score: int = 0               # 总分 = 各分项之和
var reason: String = ""          # 可读的评分原因


func _init(p_action_key: String = "", p_label: String = "", p_target: BattleUnit = null) -> void:
	action_key = p_action_key
	label = p_label
	target = p_target


## 汇总为决策字典中的候选条目（供调试面板与兼容接口读取）。
func summarize() -> Dictionary:
	return {
		"action": label,
		"action_key": action_key,
		"score": score,
		"reason": reason,
		"components": components,
		"target": target,
		"move_cell": move_cell,
		"path": path,
	}
