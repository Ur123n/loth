class_name TurnSystem
extends RefCounted

## 行动次序与回合系统（逻辑层）。
## 回合开始时：行动值 = 敏捷 + Random(-8, +8)，按行动值从大到小决定行动次序。
## 玩家与敌怪均可参与行动次序（敏捷/移动力由单位类型决定）。
## 轮次开始时清空所有单位的格挡值（护盾/格挡已统一为格挡，轮次结束消失）。

signal round_started(round_number: int)
signal turn_started(unit: BattleUnit)
signal turn_ended(unit: BattleUnit)

const RANDOM_SPREAD := 8

var units: Array[BattleUnit] = []
var action_order: Array[int] = []       # 行动次序（units 下标，从先到后）
var action_values: Dictionary = {}      # unit -> 行动值
var current_index: int = 0
var round_number: int = 0

var _rng: RandomNumberGenerator


func setup(party_units: Array[BattleUnit], rng: RandomNumberGenerator = null) -> void:
	units = party_units
	_rng = rng if rng != null else RandomNumberGenerator.new()


func start_round() -> void:
	round_number += 1
	action_order.clear()
	action_values.clear()

	for unit in units:
		# 上一轮次的格挡自动消失（护盾与格挡已统一）
		unit.block_value = 0
		unit.refresh_block_display()

	var entries: Array = []
	for i in units.size():
		var unit := units[i]
		var agility: int = unit.get_agility()
		var value: int = agility + unit.get_initiative_bonus() + _rng.randi_range(-RANDOM_SPREAD, RANDOM_SPREAD)
		action_values[unit] = value
		entries.append([value, agility, i])
		unit.remaining_move_points = unit.get_max_move_points()

	# 行动值大者优先；相同则敏捷高者优先，仍相同按下标稳定排序
	entries.sort_custom(func(a, b):
		if a[0] != b[0]:
			return a[0] > b[0]
		if a[1] != b[1]:
			return a[1] > b[1]
		return a[2] < b[2])
	for entry in entries:
		action_order.append(entry[2])

	current_index = 0
	round_started.emit(round_number)
	turn_started.emit(current_unit())


func current_unit() -> BattleUnit:
	if action_order.is_empty():
		return null
	return units[action_order[current_index]]


func current_action_value() -> int:
	var unit := current_unit()
	if unit == null:
		return 0
	return action_values.get(unit, 0)


func end_current_turn() -> void:
	var unit := current_unit()
	if unit == null:
		return
	turn_ended.emit(unit)
	current_index += 1
	if current_index >= action_order.size():
		start_round()
	else:
		turn_started.emit(current_unit())
