extends SceneTree

## 道途系统无头测试：角色道途归属、专属初始牌进技能库与卡组、幂等性。
## 运行：godot --headless --path C:\游戏 --script tests\character\test_path_system.gd

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
	var path_db := _ensure_autoload("PathDB", "res://core/progression/path_database.gd")
	var card_db := _ensure_autoload("CardDB", "res://core/card/card_database.gd")
	_check(path_db != null and card_db != null, "PathDB / CardDB 可用")

	# PathDB：按角色查道途
	var dismas_path: PathData = path_db.get_path_for_character("迪马斯")
	_check(dismas_path != null and dismas_path.path_name == "侠盗", "get_path_for_character：迪马斯→侠盗")
	var alice_path: PathData = path_db.get_path_for_character("艾莉丝")
	_check(alice_path != null and alice_path.path_name == "梦魇行者", "get_path_for_character：艾莉丝→梦魇行者")

	# 构造四名角色（道途留空，模拟新档）
	var names: Array[String] = ["艾莉丝", "鲍德温", "迪马斯", "卡莎"]
	var expected: Dictionary = {
		"艾莉丝": "梦魇行者",
		"鲍德温": "孢子卫士",
		"迪马斯": "侠盗",
		"卡莎": "解剖学者",
	}
	var party: Array[CharacterData] = []
	for n in names:
		var character := CharacterData.new()
		character.character_name = n
		character.path_name = ""
		party.append(character)

	var game_state := _ensure_game_state()
	game_state.party_characters.clear()
	for c in party:
		game_state.party_characters.append(c)
	game_state.apply_path_system()

	# 道途归属
	var path_ok := true
	for character in party:
		if character.path_name != expected[character.character_name]:
			path_ok = false
	_check(path_ok, "apply_path_system：四名角色道途归属正确")

	# 初始牌进技能库（SkillData + 描述）与卡组
	var starters_ok := true
	for character in party:
		var path_data: PathData = path_db.get_path_for_character(character.character_name)
		for card_name in path_data.starter_cards:
			if not _skill_has(character, card_name):
				starters_ok = false
				print("  技能库缺少：", character.character_name, " / ", card_name)
			if not _deck_has(character, card_name):
				starters_ok = false
				print("  卡组缺少：", character.character_name, " / ", card_name)
			var skill := _find_skill(character, card_name)
			if skill != null and skill.description.is_empty():
				starters_ok = false
				print("  技能描述为空：", card_name)
	_check(starters_ok, "道途初始牌进入对应角色技能库与卡组（含描述）")

	# 侠盗初始牌数量
	var dismas: CharacterData = party[2]
	_check(dismas.skill_library.size() == 4, "侠盗初始技能库 4 张（双枪连射/掠夺本能/弹雨/顺手牵羊）")
	_check(dismas.deck.size() >= 4, "侠盗卡组包含 4 张初始牌")

	# 幂等：再次调用不重复
	var skill_count := dismas.skill_library.size()
	var deck_count := dismas.deck.size()
	game_state.apply_path_system()
	_check(dismas.skill_library.size() == skill_count, "apply_path_system 幂等：技能库不重复")
	_check(dismas.deck.size() == deck_count, "apply_path_system 幂等：卡组不重复")


func _ensure_autoload(node_name: String, script_path: String) -> Node:
	var node: Node = root.get_node_or_null(node_name)
	if node == null:
		var script := load(script_path)
		node = script.new()
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


func _skill_has(character: CharacterData, skill_name: String) -> bool:
	return _find_skill(character, skill_name) != null


func _find_skill(character: CharacterData, skill_name: String) -> SkillData:
	for skill in character.skill_library:
		if skill.skill_name == skill_name:
			return skill
	return null


func _deck_has(character: CharacterData, card_name: String) -> bool:
	for card in character.deck:
		if card.card_name == card_name:
			return true
	return false


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("PASS  ", label)
	else:
		_failed += 1
		print("FAIL  ", label)
