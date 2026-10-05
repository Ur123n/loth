extends SceneTree

var _passed := 0
var _failed := 0
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_test_target_block_snapshot()
	print("RESULT: passed=%d failed=%d" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
	return true


func _check(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  ", label)
	else:
		_failed += 1
		print("FAIL  ", label)


func _make_attack(value: int, condition: Dictionary) -> AttackEffect:
	var effect := AttackEffect.new()
	effect.value = value
	effect.attack_range = 1
	effect.set_meta("condition", condition)
	return effect


func _test_target_block_snapshot() -> void:
	var caster := BattleUnit.new()
	caster.character_data = CharacterData.new()
	caster.character_data.character_name = "机制测试者"
	caster.current_hp = 100
	var enemy := BattleUnit.new()
	enemy.is_enemy = true
	enemy.current_hp = 100
	var manager := BattleManager.new()
	manager.setup([caster, enemy], RandomNumberGenerator.new())
	manager.turn_system.action_order = [0, 1]
	manager.turn_system.current_index = 0
	var system := manager._effect_system
	var at_least := {"type": "target_block_at_play_at_least", "threshold": 2}
	var at_most := {"type": "target_block_at_play_at_most", "threshold": 0}
	_check(system.evaluate_condition(caster, at_least, enemy, {"target_block_at_play": 2}),
		"目标格挡达到阈值时满足不少于条件")
	_check(not system.evaluate_condition(caster, at_least, enemy, {"target_block_at_play": 1}),
		"目标格挡低于阈值时不满足")
	_check(system.evaluate_condition(caster, at_most, enemy, {"target_block_at_play": 0}),
		"目标格挡为零时满足不高于条件")
	_check(not system.evaluate_condition(caster, at_most, enemy, {"target_block_at_play": 1}),
		"目标格挡高于零时不满足")
	_check(not system.evaluate_condition(caster, at_most, null, {"target_block_at_play": 0}),
		"无有效目标时条件不满足")
	var card := CardData.new()
	card.card_name = "格挡快照测试"
	card.target_type = CardData.TargetType.ENEMY
	card.card_type = CardData.CardType.ATTACK
	card.cost = 0
	card.effects = [
		_make_attack(10, {"type": "target_block_at_play_at_least", "threshold": 2}),
		_make_attack(14, {"type": "target_block_at_play_at_most", "threshold": 0}),
	]
	caster.hand.append(card)
	enemy.block_value = 2
	var first_damage := BattleManager.compute_damage(10, caster.character_data.get_strength_damage_basis(), false)
	_check(manager.play_card(card, enemy) and enemy.block_value == 0
		and enemy.current_hp == 100 - maxi(first_damage - 2, 0),
		"首段攻击消耗格挡后，后段仍读取出牌前快照")
	enemy.current_hp = 100
	enemy.block_value = 0
	caster.hand.append(card)
	var second_damage := BattleManager.compute_damage(14, caster.character_data.get_strength_damage_basis(), false)
	_check(manager.play_card(card, enemy) and enemy.current_hp == 100 - second_damage,
		"出牌前格挡为零时仅执行零格挡分支")
