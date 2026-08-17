extends SceneTree

## 道途被动与条件效果无头测试：
## 孢子怪力（移动力2/1.25倍/自带1护甲）、先下手为强（首回合抽2+移动+1）、
## 药理精通（对中毒敌人额外伤害）、条件效果（本回合移动过：夹击13/坚守7）。
## 运行：godot --headless --path C:\游戏 --script tests\character\test_passives.gd

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
	_ensure_autoload("PathDB", "res://core/progression/path_database.gd")
	_test_baozi_guaili()
	_test_xianxianshouwei()
	_test_yaoli_jingtong()
	_test_condition_effects()


func _make_unit(path_name: String) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.is_enemy = false
	var char_data := CharacterData.new()
	char_data.character_name = "测试者"
	char_data.path_name = path_name
	char_data.level = 1
	unit.character_data = char_data
	unit.current_hp = 100
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


func _test_baozi_guaili() -> void:
	var unit := _make_unit("孢子卫士")
	var manager := _make_manager(unit)
	_check(unit.get_max_move_points() == 2, "孢子怪力：每回合移动力为 2")
	# 1.25 倍伤害：6 → ceil(7.5) = 8
	var enemy := _make_enemy()
	var attack := AttackEffect.new()
	attack.value = 6
	attack.attack_range = 1
	var card := CardData.new()
	card.card_name = "测试攻击"
	card.effects = [attack]
	manager._resolve_attack(unit, card, attack, enemy)
	_check(enemy.current_hp == 92, "孢子怪力：伤害 1.25 倍（6→8）")
	# 回合开始自带 1 护甲
	unit.block_value = 0
	manager._resolve_passives_by_timing(unit, "回合开始")
	_check(unit.block_value == 1, "孢子怪力：回合开始获得 1 点护甲")


func _test_xianxianshouwei() -> void:
	var unit := _make_unit("侠盗")
	var manager := _make_manager(unit)
	manager.turn_system.round_number = 1
	var defend := CardData.new()
	defend.card_name = "防御"
	for i in 15:
		unit.draw_pile.append(defend)
	manager._on_turn_started(unit)
	_check(unit.hand.size() == 7, "先下手为强：首回合额外抽 2 张（5+2=7）")
	_check(unit.remaining_move_points == 4, "先下手为强：首回合移动力 +1（3+1=4）")


func _test_yaoli_jingtong() -> void:
	var unit := _make_unit("解剖学者")
	var manager := _make_manager(unit)
	var attack := AttackEffect.new()
	attack.value = 6
	attack.attack_range = 1
	var card := CardData.new()
	card.card_name = "测试攻击"
	card.effects = [attack]
	# 未中毒：无加成
	var enemy1 := _make_enemy()
	manager._resolve_attack(unit, card, attack, enemy1)
	_check(enemy1.current_hp == 94, "药理精通：未中毒敌人无额外伤害")
	# 中毒：额外 1 点（Lv1 → 1 + 0）
	var enemy2 := _make_enemy()
	enemy2.buffs.append({
		"name": "中毒", "stacks": 1, "duration": 3, "value": 0, "data": null,
	})
	manager._resolve_attack(unit, card, attack, enemy2)
	_check(enemy2.current_hp == 93, "药理精通：中毒敌人额外 1 点伤害（Lv1）")


func _test_condition_effects() -> void:
	var unit := _make_unit("")
	var manager := _make_manager(unit)
	# 夹击：移动过 13，否则 8
	var enemy1 := _make_enemy()
	var jia_ji := AttackEffect.new()
	jia_ji.value = 8
	jia_ji.alt_value = 13
	var card := CardData.new()
	card.card_name = "夹击"
	card.effects = [jia_ji]
	unit.moved_this_turn = false
	manager._resolve_attack(unit, card, jia_ji, enemy1)
	_check(enemy1.current_hp == 92, "夹击：未移动 8 伤")
	var enemy2 := _make_enemy()
	unit.moved_this_turn = true
	manager._resolve_attack(unit, card, jia_ji, enemy2)
	_check(enemy2.current_hp == 87, "夹击：本回合已移动 13 伤")
	# 坚守：移动过 7 防，否则 10 防
	var jian_shou := DefenseEffect.new()
	jian_shou.value = 10
	jian_shou.alt_value = 7
	var defense_card := CardData.new()
	defense_card.card_name = "坚守"
	defense_card.effects = [jian_shou]
	unit.block_value = 0
	manager._resolve_effects(unit, defense_card, null)
	_check(unit.block_value == 7, "坚守：本回合已移动 7 防")
	unit.moved_this_turn = false
	unit.block_value = 0
	manager._resolve_effects(unit, defense_card, null)
	_check(unit.block_value == 10, "坚守：未移动 10 防")


func _ensure_autoload(node_name: String, script_path: String) -> Node:
	var node: Node = root.get_node_or_null(node_name)
	if node == null:
		node = load(script_path).new()
		node.name = node_name
		root.add_child(node)
	return node

