extends SceneTree

## 条件判断系统无头测试：
## - 各条件类型求值（手牌/费用/移动/生命百分比/敌人数量/上一张牌词条/取反）
## - 条件不满足时跳过该效果，满足时执行
## 运行：godot --headless --path C:\游戏 --script tests\card\test_conditions.gd

var _passed := 0
var _failed := 0
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_run_all()
	print("RESULT: passed=%d failed=%d" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
	return true


func _run_all() -> void:
	_test_hand_energy()
	_test_moved_hp()
	_test_enemies_in_range()
	_test_negate_and_last_keyword()
	_test_skip_effect()


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("PASS  ", label)
	else:
		_failed += 1
		print("FAIL  ", label)


func _make_unit() -> BattleUnit:
	var unit := BattleUnit.new()
	unit.is_enemy = false
	var data := CharacterData.new()
	data.character_name = "条件测试"
	unit.character_data = data
	unit.current_hp = 100
	return unit


func _make_manager(unit: BattleUnit, extra: Array = []) -> BattleManager:
	var units: Array[BattleUnit] = [unit]
	for e in extra:
		units.append(e)
	var manager := BattleManager.new()
	manager.setup(units, RandomNumberGenerator.new())
	manager.turn_system.action_order = []
	for i in units.size():
		manager.turn_system.action_order.append(i)
	manager.turn_system.current_index = 0
	return manager


func _make_effect(condition: Dictionary = {}) -> AttackEffect:
	var effect := AttackEffect.new()
	effect.value = 5
	effect.attack_range = 1
	if not condition.is_empty():
		effect.set_meta("condition", condition)
	return effect


func _test_hand_energy() -> void:
	var unit := _make_unit()
	var manager := _make_manager(unit)
	unit.hand = [CardData.new(), CardData.new()]
	unit.energy = 3
	_check(manager._effect_condition_met(unit, _make_effect({"type": "hand_size_at_least", "count": 2})), "手牌2张：手牌不少于2")
	_check(not manager._effect_condition_met(unit, _make_effect({"type": "hand_size_at_least", "count": 3})), "手牌2张：手牌不少于3不满足")
	_check(manager._effect_condition_met(unit, _make_effect({"type": "energy_at_least", "value": 3})), "费用3：费用不少于3")
	_check(not manager._effect_condition_met(unit, _make_effect({"type": "energy_at_least", "value": 4})), "费用3：费用不少于4不满足")


func _test_moved_hp() -> void:
	var unit := _make_unit()
	var manager := _make_manager(unit)
	unit.moved_this_turn = true
	unit.current_hp = 40
	_check(manager._effect_condition_met(unit, _make_effect({"type": "moved_this_turn"})), "本回合已移动")
	_check(not manager._effect_condition_met(unit, _make_effect({"type": "not_moved_this_turn"})), "已移动时“未移动”不满足")
	_check(manager._effect_condition_met(unit, _make_effect({"type": "hp_below_pct", "pct": 50})), "生命40/150：低于50%")
	_check(not manager._effect_condition_met(unit, _make_effect({"type": "hp_below_pct", "pct": 20})), "生命40/150：不低于20%")


func _test_enemies_in_range() -> void:
	var unit := _make_unit()
	unit.hex_coords = Vector2i(3, 3)
	var enemy := BattleUnit.new()
	enemy.is_enemy = true
	enemy.configure_enemy(EnemyData.new())
	enemy.hex_coords = Vector2i(3, 4)   # 相邻（距离1）
	var manager := _make_manager(unit, [enemy])
	_check(manager._effect_condition_met(unit, _make_effect({"type": "enemies_in_range", "count": 1})), "1名敌人在攻击范围内")
	_check(not manager._effect_condition_met(unit, _make_effect({"type": "enemies_in_range", "count": 2})), "2名敌人在攻击范围内不满足")
	_check(manager._effect_condition_met(unit, _make_effect({"type": "enemies_alive_at_least", "count": 1})), "场上敌人不少于1")


func _test_negate_and_last_keyword() -> void:
	var unit := _make_unit()
	var manager := _make_manager(unit)
	unit.moved_this_turn = false
	_check(manager._effect_condition_met(unit, _make_effect({"type": "moved_this_turn", "negate": true})), "取反：未移动满足“非已移动”")
	var dream := CardData.new()
	dream.card_name = "沉梦之拥"
	dream.dream = true
	unit.last_played_card = dream
	_check(manager._effect_condition_met(unit, _make_effect({"type": "last_card_keyword", "keyword": "沉梦"})), "上一张牌带「沉梦」")
	_check(not manager._effect_condition_met(unit, _make_effect({"type": "last_card_keyword", "keyword": "幻梦"})), "上一张牌不带「幻梦」")


func _test_skip_effect() -> void:
	var unit := _make_unit()
	var enemy := BattleUnit.new()
	enemy.is_enemy = true
	enemy.configure_enemy(EnemyData.new())
	enemy.current_hp = 100
	enemy.hex_coords = Vector2i(3, 4)
	unit.hex_coords = Vector2i(3, 3)
	var manager := _make_manager(unit, [enemy])
	var conditional := _make_effect({"type": "energy_at_least", "value": 99})
	var normal := _make_effect({})
	var card := CardData.new()
	card.card_name = "条件测试卡"
	card.effects = [conditional, normal]
	manager._resolve_effects(unit, card, enemy)
	_check(enemy.current_hp == 95, "条件不满足的效果被跳过，仅执行无条件效果（5伤）")
