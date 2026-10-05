class_name QuestCondition
extends RefCounted

## 任务条件求值（纯逻辑，无 UI 依赖）。
## 条件对象为 JSON 字典，类型见 TYPES；支持 and/or/not 组合。
## 求值上下文 = GameState（flags / quest_state / inventory / money / world_time）。

const TYPES: Array[String] = [
	"always", "flag", "quest_done", "item_count", "coin",
	"npc_talked", "battle_won", "world_time", "and", "or", "not",
]

const CONDITION_FIELDS: Dictionary = {
	"always": [],
	"flag": ["key"],
	"quest_done": ["quest"],
	"item_count": ["item", "count"],
	"coin": ["min"],
	"npc_talked": ["npc"],
	"battle_won": ["count"],
	"world_time": ["gte"],
	"and": ["and"],
	"or": ["or"],
	"not": ["not"],
}


## 求值：condition 满足返回 true。
static func evaluate(condition, gs) -> bool:
	if condition is bool:
		return condition
	if not condition is Dictionary:
		return false
	var type := str(condition.get("type", ""))
	match type:
		"always":
			return true
		"flag":
			return _cmp(gs.get_flag(str(condition.get("key", ""))), condition.get("value", true))
		"quest_done":
			var done: Array = gs.quest_state.get("done", [])
			return done.has(str(condition.get("quest", "")))
		"item_count":
			return _item_count(condition, gs)
		"coin":
			return int(gs.money) >= int(condition.get("min", 1))
		"npc_talked":
			var talked: Array = gs.quest_state.get("talked", [])
			return talked.has(str(condition.get("npc", "")))
		"battle_won":
			return int(gs.quest_state.get("battles_won", 0)) >= int(condition.get("count", 1))
		"world_time":
			return float(gs.world_time) >= float(condition.get("gte", 0.0))
		"and":
			for c in condition.get("and", []):
				if not evaluate(c, gs):
					return false
			return true
		"or":
			for c in condition.get("or", []):
				if evaluate(c, gs):
					return true
			return false
		"not":
			return not evaluate(condition.get("not", {}), gs)
	return false


## 校验条件结构（递归），问题写入 problems，prefix 用于定位。
static func validate(condition, problems: Array[String], prefix: String = "") -> void:
	if condition is bool:
		return
	if not condition is Dictionary:
		problems.append("%s 条件不是对象" % prefix)
		return
	var type := str(condition.get("type", ""))
	if not TYPES.has(type):
		problems.append("%s 未知条件类型：%s" % [prefix, type])
		return
	var fields: Array = CONDITION_FIELDS.get(type, [])
	for f in fields:
		if not condition.has(f):
			problems.append("%s 条件 %s 缺少字段 %s" % [prefix, type, f])
	if type == "and" or type == "or":
		var list = condition.get(type, [])
		if not list is Array:
			problems.append("%s 条件 %s 需要数组" % [prefix, type])
		else:
			for i in list.size():
				validate(list[i], problems, "%s.%s[%d]" % [prefix, type, i])
	elif type == "not":
		validate(condition.get("not", {}), problems, "%s.not" % prefix)


static func _item_count(condition: Dictionary, gs) -> bool:
	var want := int(condition.get("count", 1))
	var have := 0
	for entry in gs.inventory.items:
		var item = entry.get("item")
		if item != null and item.item_name == str(condition.get("item", "")):
			have += 1
	return have >= want


## 宽松相等：布尔/数值/字符串 兼容（剧情 Flag 约定）。
static func _cmp(actual, expected) -> bool:
	if actual is bool or expected is bool:
		return _to_bool(actual) == _to_bool(expected)
	if actual is float or expected is float or actual is int or expected is int:
		return float(actual) == float(expected)
	return actual == expected


## 安全布尔转换（null 视为 false，避免 bool(null) 报错）。
static func _to_bool(v) -> bool:
	if v == null:
		return false
	return bool(v)
