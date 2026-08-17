extends SceneTree

## 装备战斗接入无头测试（有舍有得）：
## 铁剑（攻击+20%/防御-2）、长枪（攻击范围+1/伤害-15%）、铁头盔（回合开始格挡3/费用-1）、
## 皮甲（生命+20/移动-1）、草鞋（敏捷+2）、铜戒指（抽牌+1）。
## 运行：godot --headless --path C:\游戏 --script tests\battle\test_equipment_battle.gd

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
	_ensure_autoload("EquipDB", "res://core/equipment/equipment_database.gd")
	_test_sword_attack_and_defense()
	_test_spear_range()
	_test_helmet_turn_start()
	_test_ring_draw()
	_test_armor_hp_and_shoe_agility()


func _make_unit() -> BattleUnit:
	var unit := BattleUnit.new()
	unit.is_enemy = false
	var char_data := CharacterData.new()
	char_data.character_name = "测试者"
	char_data.level = 1
	unit.character_data = char_data
	unit.current_hp = char_data.get_max_hp()
	return unit


func _make_enemy() -> BattleUnit:
	var enemy := BattleUnit.new()
	enemy.is_enemy = true
	enemy.current_hp = 100
	return enemy


func _make_manager(unit: BattleUnit) -> BattleManager:
	var manager := BattleManager.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var units: Array[BattleUnit] = [unit]
	manager.setup(units, rng)
	manager.turn_system.action_order = [0]
	manager.turn_system.current_index = 0
	return manager


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("PASS  ", label)
	else:
		_failed += 1
		print("FAIL  ", label)


func _test_sword_attack_and_defense() -> void:
	var unit := _make_unit()
	var manager := _make_manager(unit)
	unit.character_data.equip_by_name("铁剑")
	var enemy := _make_enemy()
	var attack := AttackEffect.new()
	attack.value = 6
	attack.attack_range = 1
	var card := CardData.new()
	card.card_name = "测试攻击"
	card.effects = [attack]
	manager._resolve_attack(unit, card, attack, enemy)
	_check(enemy.current_hp == 92, "铁剑：攻击伤害+20%（6→8，HP 92）")
	# 防御卡格挡 -2：6 点防御 → 4
	var defend := DefenseEffect.new()
	defend.value = 6
	var defend_card := CardData.new()
	defend_card.card_name = "测试防御"
	defend_card.effects = [defend]
	unit.block_value = 0
	manager._resolve_effects(unit, defend_card)
	_check(unit.block_value == 4, "铁剑：防御卡格挡-2（6→4）")


func _test_spear_range() -> void:
	var unit := _make_unit()
	unit.character_data.equip_by_name("长枪")
	_check(unit.get_attack_range() == 2, "长枪：攻击范围 1+1=2")
	var map = load("res://core/battle/battle_map.gd").new()
	unit.hex_coords = Vector2i(0, 0)
	var enemy := _make_enemy()
	enemy.hex_coords = Vector2i(2, 0)
	var card := CardData.new()
	card.card_name = "测试"
	card.range = 1
	_check(map._target_in_range(unit, enemy, card), "长枪：距离 2 在攻击范围内")
	enemy.hex_coords = Vector2i(3, 0)
	_check(not map._target_in_range(unit, enemy, card), "长枪：距离 3 超出攻击范围")


func _test_helmet_turn_start() -> void:
	var unit := _make_unit()
	var manager := _make_manager(unit)
	unit.character_data.equip_by_name("铁头盔")
	var defend := CardData.new()
	defend.card_name = "防御"
	for i in 6:
		unit.draw_pile.append(defend)
	manager._on_turn_started(unit)
	_check(unit.block_value == 3, "铁头盔：回合开始获得 3 格挡")
	_check(unit.energy == 2, "铁头盔：每回合费用-1（3→2）")


func _test_ring_draw() -> void:
	var unit := _make_unit()
	var manager := _make_manager(unit)
	unit.character_data.equip_by_name("铜戒指")
	var defend := CardData.new()
	defend.card_name = "防御"
	for i in 7:
		unit.draw_pile.append(defend)
	manager._on_turn_started(unit)
	_check(unit.hand.size() == 6, "铜戒指：每回合抽牌+1（5→6）")
	_check(unit.energy == 3, "铜戒指：费用不受影响")


func _test_armor_hp_and_shoe_agility() -> void:
	var unit := _make_unit()
	unit.character_data.equip_by_name("皮甲")
	_check(unit.get_max_hp_value() == 170, "皮甲：生命上限 150+20=170")
	_check(unit.get_max_move_points() == 2, "皮甲：移动力 3-1=2")
	var shoe := _make_unit()
	shoe.character_data.equip_by_name("草鞋")
	_check(shoe.get_agility() == 12, "草鞋：敏捷 10+2=12")
	_check(shoe.get_max_hp_value() == 140, "草鞋：生命上限 150-10=140")


func _ensure_autoload(node_name: String, script_path: String) -> Node:
	var node: Node = root.get_node_or_null(node_name)
	if node == null:
		node = load(script_path).new()
		node.name = node_name
		root.add_child(node)
	return node
