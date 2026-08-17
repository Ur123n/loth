extends SceneTree

## Demo 系统无头测试：卡组补齐 20 张、固定战役流程、卡牌掉落表。
## 运行：godot --headless --path C:\游戏 --script tests\battle\test_demo_system.gd

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
	_test_deck_fill()
	_test_campaign_sequence()
	_test_compose_battle()
	_test_card_drop_db()


func _test_deck_fill() -> void:
	var game_state := _ensure_game_state()
	var character := CharacterData.new()
	character.character_name = "测试者"
	character.path_name = ""
	game_state.party_characters.clear()
	game_state.party_characters.append(character)
	game_state.apply_path_system()
	game_state.ensure_basic_deck_cards()
	_check(character.deck.size() == game_state.DECK_CAPACITY, "卡组补齐到 20 张")
	var strikes := 0
	var defends := 0
	for card in character.deck:
		if card.card_name == "打击":
			strikes += 1
		elif card.card_name == "防御":
			defends += 1
	_check(strikes >= 5 and defends >= 5, "卡组含至少 5 打击 + 5 防御")
	_check(strikes + defends == character.deck.size(), "补齐用牌全部为打击/防御")


func _test_campaign_sequence() -> void:
	_check(DemoComposer.total_battles() == 6, "战役共 6 场")
	var tiers: Array[String] = []
	for i in range(1, DemoComposer.total_battles() + 1):
		tiers.append(DemoComposer.battle_tier(i))
	_check(tiers == ["普通", "普通", "精英", "普通", "普通", "Boss"],
		"战役顺序：小→小→精英→小→小→Boss")


func _test_compose_battle() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var normal := DemoComposer.compose_battle(1, rng)
	_check(not normal.is_empty() and normal.all(func(e): return e.tier == "普通"),
		"第 1 场：全部为普通怪")
	var elite_battle := DemoComposer.compose_battle(3, rng)
	_check(elite_battle.any(func(e): return e.tier == "精英"), "第 3 场：含精英怪")
	var boss_battle := DemoComposer.compose_battle(6, rng)
	_check(boss_battle.any(func(e): return e.tier == "Boss"), "第 6 场：含 Boss")


func _test_card_drop_db() -> void:
	var drop_db := _ensure_autoload("CardDropDB", "res://core/card/card_drop_database.gd")
	_check(drop_db != null, "CardDropDB 可用")
	var normal: Dictionary = drop_db.get_drop("普通")
	_check(int(normal.get("chance", 0)) == 50, "普通掉落概率 50%")
	var elite: Dictionary = drop_db.get_drop("精英")
	_check(int(elite.get("chance", 0)) == 80, "精英掉落概率 80%")
	var boss: Dictionary = drop_db.get_drop("Boss")
	_check(int(boss.get("chance", 0)) == 100 and int(boss.get("count", 0)) == 2, "Boss 必掉且可三选一两次")


func _ensure_autoload(node_name: String, script_path: String) -> Node:
	var node: Node = root.get_node_or_null(node_name)
	if node == null:
		node = load(script_path).new()
		node.name = node_name
		root.add_child(node)
	return node


func _ensure_game_state() -> Node:
	var node: Node = root.get_node_or_null("GameState")
	if node == null:
		node = load("res://core/save/game_state.gd").new()
		node.name = "GameState"
		root.add_child(node)
	return node


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("PASS  ", label)
	else:
		_failed += 1
		print("FAIL  ", label)
