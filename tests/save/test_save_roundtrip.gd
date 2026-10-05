extends SceneTree

## 存档往返测试：
## - v5 保存 → 加载 → 数据一致（玩家位置/触发状态/钱币/背包/队伍/装备/剧情已播放/预留状态字段）
## - 旧格式（v3/v4）缺省字段可用：新字段取默认值，旧字段照常还原
## 运行：godot --headless --path C:\游戏 --script tests\save\test_save_roundtrip.gd

const RT_SAVE_PATH := "res://.tests_tmp/test_save_roundtrip.json"
const OLD_SAVE_PATH := "res://.tests_tmp/test_save_old_v3.json"

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
	DirAccess.make_dir_recursive_absolute("res://.tests_tmp")
	_ensure_autoload("CardDB", "res://core/card/card_database.gd")
	_ensure_autoload("EquipDB", "res://core/equipment/equipment_database.gd")
	_ensure_autoload("ItemDB", "res://core/items/item_database.gd")
	_ensure_autoload("PathDB", "res://core/progression/path_database.gd")
	_test_roundtrip_v5()
	_test_old_v3_defaults()
	_test_old_v4_defaults()
	_cleanup()


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("PASS  ", label)
	else:
		_failed += 1
		print("FAIL  ", label)


func _ensure_autoload(node_name: String, script_path: String) -> Node:
	var node: Node = root.get_node_or_null(node_name)
	if node == null:
		node = load(script_path).new()
		node.name = node_name
		root.add_child(node)
	return node


func _make_game_state(node_name: String, save_path: String) -> Node:
	var gs: Node = load("res://core/save/game_state.gd").new()
	gs.name = node_name
	root.add_child(gs)
	gs.save_path = save_path
	return gs


func _make_character(name: String, level: int, exp: int, points: int) -> CharacterData:
	var char_data := CharacterData.new()
	char_data.character_name = name
	char_data.level = level
	char_data.exp = exp
	char_data.attribute_points = points
	var skill := SkillData.new()
	skill.skill_name = "打击"
	skill.description = "造成 6 点伤害"
	char_data.skill_library.append(skill)
	return char_data


func _test_roundtrip_v5() -> void:
	var gs := _make_game_state("GameStateRT", RT_SAVE_PATH)
	gs.overworld_position = Vector2(123, 456)
	gs.battle_trigger_consumed = true
	gs.skill_light_position = Vector2(30, 40)
	gs.skill_light_consumed = true
	gs.money = 88
	gs.story_played = ["example_intro", "example_flag_story"]
	gs.flags = {"tutorial_done": true, "met_npcs": ["村长"]}
	gs.quest_state = {"main_quest_step": 2}
	gs.world_state = {"light_revived": false}
	gs.world_time = 13.5
	# 背包放一件物品
	var item_db: Node = root.get_node("ItemDB")
	var item = item_db.get_item("干粮")
	gs.inventory.place(item, 0, 0, 0)
	# 队伍：两名角色，一名穿两件装备
	var chars: Array[CharacterData] = [
		_make_character("鲍德温", 5, 40, 2),
		_make_character("艾莉丝", 3, 10, 1),
	]
	var equip_db: Node = root.get_node("EquipDB")
	chars[0].equip_equipment(equip_db.get_equipment("铁剑"))
	chars[0].equip_equipment(equip_db.get_equipment("长枪"))
	gs.setup_party(chars)
	gs.ensure_basic_deck_cards()
	gs.save_game()

	var loaded := _make_game_state("GameStateRT2", RT_SAVE_PATH)
	loaded.setup_party([_make_character("鲍德温", 1, 0, 0), _make_character("艾莉丝", 1, 0, 0)])
	loaded.load_game()
	_check(loaded.overworld_position == Vector2(123, 456), "往返：大世界位置")
	_check(loaded.battle_trigger_consumed == true, "往返：战斗触发状态")
	_check(loaded.skill_light_position == Vector2(30, 40), "往返：技能光点位置")
	_check(loaded.skill_light_consumed == true, "往返：技能光点消耗状态")
	_check(loaded.money == 88, "往返：钱币")
	_check(loaded.inventory.items.size() == 1 and loaded.inventory.items[0].get("item").item_name == "干粮", "往返：背包物品")
	_check(loaded.party_characters.size() == 2, "往返：队伍人数")
	var first: CharacterData = loaded.party_characters[0]
	_check(first.character_name == "鲍德温" and first.level == 5 and first.exp == 40 \
			and first.attribute_points == 2, "往返：角色成长")
	_check(first.skill_library.size() == 2 and first.skill_library[0].skill_name == "打击"
		and first.skill_library[1].skill_name == "防御", "往返：初始基础牌也属于已获牌库")
	var strike_count := 0
	var defend_count := 0
	for card in first.deck:
		if card.card_name == "打击":
			strike_count += 1
		elif card.card_name == "防御":
			defend_count += 1
	_check(first.deck.size() == 20 and strike_count == 10 and defend_count == 10, "往返：卡组补齐")
	var equip_names: Array = []
	for equip in first.equipment:
		equip_names.append(equip.equipment_name)
	_check(equip_names == ["铁剑", "长枪"], "往返：装备")
	_check(loaded.story_played == ["example_intro", "example_flag_story"], "往返：剧情已播放记录")
	_check(loaded.flags == {"tutorial_done": true, "met_npcs": ["村长"]}, "往返：剧情 flags")
	# 注意：Godot JSON 解析把整数读为 float，读取方需按字段类型转换（既有约定）
	_check(int(loaded.quest_state.get("main_quest_step", 0)) == 2, "往返：任务状态")
	_check(loaded.world_state == {"light_revived": false}, "往返：世界状态")
	_check(absf(loaded.world_time - 13.5) < 0.001, "往返：世界时钟")


func _test_old_v3_defaults() -> void:
	var old_data := {
		"version": 3,
		"overworld_position": [10.0, 20.0],
		"skill_light_consumed": true,
		"money": 55,
		"inventory": [],
		"party": [{
			"name": "鲍德温",
			"level": 3,
			"exp": 100,
			"attribute_points": 1,
			"skills": [{"name": "打击", "description": "造成 6 点伤害"}],
			"deck": ["打击", "防御"],
			"equipment": [],
		}],
	}
	var file := FileAccess.open(OLD_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(old_data))
	file.close()

	var gs := _make_game_state("GameStateOld", OLD_SAVE_PATH)
	gs.setup_party([_make_character("鲍德温", 1, 0, 0)])
	gs.load_game()
	_check(gs.money == 55, "旧档：钱币可读")
	_check(gs.overworld_position == Vector2(10, 20), "旧档：位置可读")
	_check(gs.skill_light_consumed == true, "旧档：光点状态可读")
	_check(gs.battle_trigger_consumed == false, "旧档缺省：battle_trigger_consumed=false")
	_check(gs.skill_light_position == Vector2(496, 408), "旧档缺省：技能光点位置为默认")   # 修道院初始地图花园
	_check(gs.flags == {}, "旧档缺省：flags 为空")
	_check(gs.quest_state == {}, "旧档缺省：quest_state 为空")
	_check(gs.world_state == {}, "旧档缺省：world_state 为空")
	_check(gs.story_played == [], "旧档缺省：story_played 为空")
	_check(absf(gs.world_time - 8.0) < 0.001, "旧档缺省：world_time 为默认 8.0")
	var first: CharacterData = gs.party_characters[0]
	_check(first.level == 3 and first.exp == 100 and first.attribute_points == 1, "旧档：角色成长可读")
	_check(first.skill_library.size() == 1 and first.skill_library[0].skill_name == "打击", "旧档：技能库可读")
	_check(first.deck.size() == 2 and first.deck[0].card_name == "打击" and first.deck[1].card_name == "防御", "旧档：卡组可读")
	_check(first.equipment.is_empty(), "旧档缺省：装备为空")


func _test_old_v4_defaults() -> void:
	# v4 已有 flags 但尚无 story_played：加载后 story_played 缺省为空，flags 照常还原
	var old_data := {
		"version": 4,
		"overworld_position": [200.0, 300.0],
		"battle_trigger_consumed": false,
		"skill_light_position": [496.0, 408.0],
		"skill_light_consumed": false,
		"money": 12,
		"inventory": [],
		"party": [],
		"flags": {"tutorial_done": true},
		"quest_state": {},
		"world_state": {},
	}
	var file := FileAccess.open(OLD_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(old_data))
	file.close()

	var gs := _make_game_state("GameStateV4", OLD_SAVE_PATH)
	gs.load_game()
	_check(gs.story_played == [], "v4 旧档缺省：story_played 为空")
	_check(gs.flags == {"tutorial_done": true}, "v4 旧档：flags 可读")
	_check(gs.overworld_position == Vector2(200, 300), "v4 旧档：位置可读")


func _cleanup() -> void:
	var dir := DirAccess.open("res://.tests_tmp")
	if dir != null:
		if dir.file_exists(RT_SAVE_PATH.get_file()):
			dir.remove(RT_SAVE_PATH.get_file())
		if dir.file_exists(OLD_SAVE_PATH.get_file()):
			dir.remove(OLD_SAVE_PATH.get_file())
