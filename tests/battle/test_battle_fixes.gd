extends SceneTree

## 本次测试整理新增的回归测试：
## - 层数持续型 buff 首次施加时持续时间按层数扩展（中毒 3 层 → 3 回合）
## - 叠层无上限（8 + 5 → 13）
## - 先下手为强：首回合额外抽 2 张 + 移动力 +1
## - 倒地单位跳过行动（GDD 第 17 节）
## 运行：godot --headless --path C:\游戏 --script tests\battle\test_battle_fixes.gd

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
	_ensure_path_db()
	_test_buff_duration_scaling()
	_test_poison_decay_after_damage()
	_test_healing_cap_and_end_turn()
	_test_buff_stack_unlimited()
	_test_first_strike_passive()
	_test_dead_unit_skips_turn()
	_test_lifesteal()


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("PASS  ", label)
	else:
		_failed += 1
		print("FAIL  ", label)


func _ensure_path_db() -> void:
	if root.get_node_or_null("PathDB") == null:
		var db := PathDatabase.new()
		db.name = "PathDB"
		root.add_child(db)


func _make_unit(with_path := false) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.is_enemy = false
	var data := CharacterData.new()
	data.character_name = "测试者"
	if with_path:
		data.path_name = "侠盗"
	unit.character_data = data
	unit.current_hp = 100
	return unit


func _make_manager(unit: BattleUnit) -> BattleManager:
	var manager := BattleManager.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260812
	manager.setup([unit], rng)
	manager.turn_system.action_order = [0]
	manager.turn_system.current_index = 0
	return manager


func _apply_buff(manager: BattleManager, unit: BattleUnit, buff_name: String, stacks: int, duration: int) -> void:
	var effect := BuffEffect.new()
	effect.target = "self"
	effect.buff_type = buff_name
	effect.duration = duration
	effect.stacks = stacks
	var card := CardData.new()
	card.card_name = buff_name
	card.effects = [effect]
	manager._resolve_effects(unit, card, null)


func _test_buff_duration_scaling() -> void:
	var unit := _make_unit()
	var manager := _make_manager(unit)
	_apply_buff(manager, unit, "中毒", 3, 0)
	var poison := manager._find_buff(unit, "中毒")
	_check(not poison.is_empty() and int(poison.get("duration", 0)) == 3, "中毒3层：首次施加持续3回合")
	var unit2 := _make_unit()
	var manager2 := _make_manager(unit2)
	_apply_buff(manager2, unit2, "易伤", 5, 0)
	var vuln := manager2._find_buff(unit2, "易伤")
	_check(not vuln.is_empty() and int(vuln.get("duration", 0)) == 5, "易伤5层：首次施加持续5回合")
	var unit3 := _make_unit()
	var manager3 := _make_manager(unit3)
	_apply_buff(manager3, unit3, "疗愈", 12, 0)
	var heal := manager3._find_buff(unit3, "疗愈")
	_check(not heal.is_empty() and int(heal.get("stacks", 0)) == 7 and int(heal.get("duration", 0)) == 7, "疗愈12层：按上限保留7层")


func _test_buff_stack_unlimited() -> void:
	var unit := _make_unit()
	var manager := _make_manager(unit)
	_apply_buff(manager, unit, "易伤", 8, 8)
	_apply_buff(manager, unit, "易伤", 5, 5)
	var vuln := manager._find_buff(unit, "易伤")
	_check(int(vuln.get("stacks", 0)) == 13, "易伤叠层：8+5 无上限（13）")


func _test_poison_decay_after_damage() -> void:
	var unit := _make_unit()
	var manager := _make_manager(unit)
	_apply_buff(manager, unit, "中毒", 3, 0)
	var starting_hp := unit.current_hp
	for loss in [3, 5, 6]:
		manager._resolve_turn_buffs(unit)
		manager._resolve_end_turn_buffs(unit)
		_check(unit.current_hp == starting_hp - loss, "中毒先失血后衰减：累计损失 %d" % loss)
	_check(manager._find_buff(unit, "中毒").is_empty(), "中毒三次触发后消失")


func _test_healing_cap_and_end_turn() -> void:
	var unit := _make_unit()
	var manager := _make_manager(unit)
	unit.current_hp = 100
	_apply_buff(manager, unit, "疗愈", 3, 0)
	for expected_hp in [103, 105, 106]:
		manager._resolve_turn_buffs(unit)
		manager._resolve_end_turn_buffs(unit)
		_check(unit.current_hp == expected_hp, "疗愈结束回合回复至 %d" % expected_hp)
	_check(manager._find_buff(unit, "疗愈").is_empty(), "疗愈三次触发后消失")


func _test_first_strike_passive() -> void:
	var unit := _make_unit(true)
	var manager := _make_manager(unit)
	manager.turn_system.round_number = 1
	var passive := unit.character_data.get_passive()
	_check(passive != null and passive.passive_name == "先下手为强", "侠盗被动解析")
	manager._on_turn_started(unit)
	_check(unit.hand.size() == 7, "先下手为强：首回合抽 5+2 张")
	_check(unit.energy == 3, "首回合获得 3 点费用")
	_check(unit.remaining_move_points == 4, "先下手为强：移动力 +1（4）")


func _test_dead_unit_skips_turn() -> void:
	var dead := _make_unit()
	var enemy := BattleUnit.new()
	enemy.is_enemy = true
	enemy.configure_enemy(EnemyData.new())
	var manager := BattleManager.new()
	manager.setup([dead, enemy], RandomNumberGenerator.new())
	manager.turn_system.action_order = [0, 1]
	manager.turn_system.current_index = 0
	dead.current_hp = 0
	manager._on_turn_started(dead)
	_check(manager.turn_system.current_index == 1, "倒地单位回合被跳过（current_index 前移）")

func _test_lifesteal() -> void:
	var unit := _make_unit()
	var enemy := BattleUnit.new()
	enemy.is_enemy = true
	enemy.configure_enemy(EnemyData.new())
	var manager := _make_manager(unit)
	var card := CardData.new()
	card.card_name = "兽性觉醒"
	card.lifesteal = true
	var effect := AttackEffect.new()
	effect.value = 8
	effect.attack_range = 1
	card.effects = [effect]
	# 无格挡：打 8 回 8
	unit.current_hp = 50
	enemy.current_hp = 100
	manager._resolve_attack(unit, card, effect, enemy)
	_check(enemy.current_hp == 92, "吸血：敌人失去 8 点生命")
	_check(unit.current_hp == 58, "吸血：攻击者恢复 8 点生命")
	# 有格挡：按实际扣血回血（8 伤 - 3 格挡 = 回 5）
	unit.current_hp = 40
	enemy.current_hp = 100
	enemy.block_value = 3
	manager._resolve_attack(unit, card, effect, enemy)
	_check(enemy.current_hp == 95, "吸血：格挡抵消 3 点（敌人失去 5 点）")
	_check(unit.current_hp == 45, "吸血：按实际伤害恢复 5 点")
