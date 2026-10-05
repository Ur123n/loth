extends SceneTree

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var file := FileAccess.open("res://dev/card_import/generated/A001.json", FileAccess.READ)
	_check(file != null, "A001 staged source exists")
	if file == null:
		_finish()
		return
	var data = JSON.parse_string(file.get_as_text())
	_check(data is Dictionary, "A001 JSON parses")
	if not data is Dictionary:
		_finish()
		return
	var database := CardDatabase.new()
	var card := database._parse_card(data)
	var live_db := root.get_node_or_null("CardDB") as CardDatabase
	_check(live_db != null and live_db.get_card("佣兵打击") != null, "A001 loads from live card directory")
	var staged_ids := ["A001", "A002", "A003", "A005", "A009", "A026", "D001", "K001", "B001"]
	var loaded := 0
	for staged_id in staged_ids:
		var staged_file := FileAccess.open("res://dev/card_import/generated/%s.json" % staged_id, FileAccess.READ)
		if staged_file == null:
			continue
		var staged_data = JSON.parse_string(staged_file.get_as_text())
		if staged_data is Dictionary and not staged_data.get("effects", []).is_empty() \
				and ArtLoader.load_texture("res://content/cards/" + str(staged_data.get("art", ""))) != null:
			loaded += 1
	_check(loaded == staged_ids.size(), "nine legacy staged cards retain effects and preview art")
	_check(card.card_id == "A001" and card.card_name == "佣兵打击", "A001 identity")
	_check(card.character_name == "艾莉丝" and card.rarity == "Basic", "owner and rarity")
	_check(card.cost == 1 and card.load == 1 and card.range == 1, "cost, load and range")
	_check(card.effects.size() == 1 and card.effects[0] is AttackEffect and (card.effects[0] as AttackEffect).value == 6, "six damage effect")
	_check(CardDatabase.describe_card(card) == "造成6伤害。", "source description")
	var texture := ArtLoader.load_texture("res://content/cards/" + card.art_path)
	_check(texture != null and texture.get_width() == 144 and texture.get_height() == 216, "published card art loads")
	var hand := BattleHandUI.new()
	root.add_child(hand)
	var unit := BattleUnit.new()
	unit.character_data = CharacterData.new()
	unit.character_data.character_name = "艾莉丝"
	unit.current_hp = 20
	unit.energy = 3
	unit.hand.append(card)
	hand.set_unit(unit)
	var panel := hand._cards_box.get_child(0)
	var art := panel.find_child("Art", true, false)
	_check(art is TextureRect and (art as TextureRect).texture != null, "battle hand displays published art")
	hand.free()
	var enemy := BattleUnit.new()
	enemy.is_enemy = true
	enemy.current_hp = 20
	var fighters: Array[BattleUnit] = [unit, enemy]
	var battle := BattleManager.new()
	battle.setup(fighters)
	battle.turn_system.action_order = [0, 1]
	battle.turn_system.current_index = 0
	unit.energy = 3
	unit.hand.append(card)
	_check(battle.play_card(card, enemy) and enemy.current_hp == 14, "A001 plays in battle for six damage")
	var combo_file := FileAccess.open("res://dev/card_import/generated/D015.json", FileAccess.READ)
	_check(combo_file != null, "D015 staged source exists")
	if combo_file != null:
		var combo := database._parse_card(JSON.parse_string(combo_file.get_as_text()))
		unit.energy = 3
		unit.hand.append(combo)
		_check(battle.play_card(combo, enemy) and enemy.current_hp == 6, "D015 resolves two separate four damage hits")
	var poison_file := FileAccess.open("res://dev/card_import/generated/K004.json", FileAccess.READ)
	_check(poison_file != null, "K004 staged source exists")
	if poison_file != null:
		var poison_card := database._parse_card(JSON.parse_string(poison_file.get_as_text()))
		unit.energy = 3
		unit.hand.append(poison_card)
		var applied := battle.play_card(poison_card, enemy)
		var poison := battle._find_buff(enemy, "中毒")
		_check(applied and int(poison.get("stacks", 0)) == 5, "K004 applies five poison")
		battle._resolve_end_turn_buffs(enemy)
		_check(enemy.current_hp == 1 and int(poison.get("stacks", 0)) == 4, "K004 poison ticks for five then decays")
	_finish()


func _check(result: bool, label: String) -> void:
	if result:
		_passed += 1
		print("PASS  ", label)
	else:
		_failed += 1
		print("FAIL  ", label)


func _finish() -> void:
	print("RESULT: passed=%d failed=%d" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
