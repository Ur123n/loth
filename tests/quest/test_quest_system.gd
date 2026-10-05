extends SceneTree

## 任务系统无头测试：
## - QuestDB 加载 content/quests/*.json
## - 自动接取（start 条件：npc_talked）→ 完成（item_count）→ 奖励发放 → 分支/下一任务
## - 分支：按 flag 选择不同后续任务；默认分支（always）
## - battle_won / world_time 条件；save 往返（quest_state / world_time）
## 运行：godot --headless --path C:\游戏 --script tests\quest\test_quest_system.gd

const RT_SAVE_PATH := "res://.tests_tmp/test_quest_system.json"

const _Condition := preload("res://core/quest/quest_condition.gd")

var _passed := 0
var _failed := 0
var _done := false

var gs: Node
var item_db: Node
var quest_db: Node
var qsys: Node


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_run_all()
	print("RESULT: passed=%d failed=%d" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
	return true


func _ensure_autoload(node_name: String, script_path: String) -> Node:
	var node: Node = root.get_node_or_null(node_name)
	if node == null:
		node = load(script_path).new()
		node.name = node_name
		root.add_child(node)
	return node


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("PASS  ", label)
	else:
		_failed += 1
		print("FAIL  ", label)


func _run_all() -> void:
	DirAccess.make_dir_recursive_absolute("res://.tests_tmp")
	gs = _ensure_autoload("GameState", "res://core/save/game_state.gd")
	gs.save_path = RT_SAVE_PATH
	item_db = _ensure_autoload("ItemDB", "res://core/items/item_database.gd")
	_ensure_autoload("CardDB", "res://core/card/card_database.gd")
	_ensure_autoload("EquipDB", "res://core/equipment/equipment_database.gd")
	quest_db = _ensure_autoload("QuestDB", "res://core/quest/quest_database.gd")
	qsys = _ensure_autoload("QuestSystem", "res://core/quest/quest_system.gd")

	var char_data := CharacterData.new()
	char_data.character_name = "测试员"
	gs.setup_party([char_data])
	gs.load_game()
	_reset_world()

	_test_db_loads()
	_test_conditions()
	_test_auto_start_complete_chain()
	_test_branch_choice()
	_test_time_quest()
	_test_save_roundtrip()
	_cleanup()


func _reset_world() -> void:
	gs.quest_state = {}
	gs.flags = {}
	gs.money = 0
	gs.world_time = 8.0
	gs.inventory.items.clear()
	for character in gs.party_characters:
		if character is CharacterData:
			character.skill_library.clear()
			character.exp = 0
	gs.save_game()


func _test_db_loads() -> void:
	_check(quest_db.has_quest("monastery_errand"), "QuestDB 加载 monastery_errand")
	_check(quest_db.has_quest("garden_task"), "QuestDB 加载 garden_task")
	_check(quest_db.has_quest("kitchen_task"), "QuestDB 加载 kitchen_task")
	_check(quest_db.problems.is_empty(), "QuestDB 无校验问题（%d 个）" % quest_db.problems.size())


func _test_conditions() -> void:
	_check(_Condition.evaluate({"type": "always"}, gs), "条件 always 恒真")
	_check(_Condition.evaluate({"type": "coin", "min": 5}, gs) == false, "条件 coin 未满足")
	gs.add_money(10)
	_check(_Condition.evaluate({"type": "coin", "min": 5}, gs), "条件 coin 满足")
	gs.money = 0
	gs.set_flag("test_flag", true)
	_check(_Condition.evaluate({"type": "flag", "key": "test_flag", "value": true}, gs), "条件 flag 满足")
	_check(_Condition.evaluate({"type": "and", "and": [
		{"type": "flag", "key": "test_flag", "value": true},
		{"type": "not", "not": {"type": "coin", "min": 5}},
	]}, gs), "条件 and/not 组合")


func _test_auto_start_complete_chain() -> void:
	_reset_world()
	# 与主教交谈 → 自动接取 monastery_errand
	qsys.notify_npc_talked("赫伯特主教")
	_check(qsys.get_active_quest_id() == "monastery_errand", "npc_talked 自动接取 monastery_errand")
	# 收集 1 株草药 → 自动完成 → 奖励 + 分支（无 garden_first → kitchen_task）
	var herb = item_db.get_item("草药")
	_check(herb != null, "物品 草药 存在")
	gs.inventory.place(herb, 0, 0, 0)
	qsys.check_advance()
	_check(qsys.is_quest_done("monastery_errand"), "monastery_errand 完成")
	_check(gs.money == 30, "奖励：钱币 +30（当前 %d）" % gs.money)
	_check(qsys.get_active_quest_id() == "kitchen_task", "分支默认进入 kitchen_task")
	# kitchen_task：战斗胜利 1 次 → 完成
	qsys.notify_battle_won()
	_check(qsys.is_quest_done("kitchen_task"), "kitchen_task 完成（battle_won）")
	var dry := 0
	for entry in gs.inventory.items:
		if entry.get("item") != null and entry.get("item").item_name == "干粮":
			dry += 1
	_check(dry == 2, "奖励：干粮 ×2（当前 %d）" % dry)
	var first: CharacterData = gs.party_characters[0]
	_check(first.exp >= 20, "奖励：经验 +20（当前 %d）" % first.exp)
	_check(qsys.get_active_quest_id().is_empty(), "任务链结束：无 active")


func _test_branch_choice() -> void:
	_reset_world()
	gs.set_flag("garden_first", true)
	qsys.notify_npc_talked("赫伯特主教")
	_check(qsys.get_active_quest_id() == "monastery_errand", "分支测试：接取 monastery_errand")
	var herb = item_db.get_item("草药")
	gs.inventory.place(herb, 0, 0, 0)
	qsys.check_advance()
	_check(qsys.is_quest_done("monastery_errand"), "分支测试：monastery_errand 完成")
	_check(qsys.get_active_quest_id() == "garden_task", "分支：garden_first=true → garden_task（当前 %s）" % qsys.get_active_quest_id())
	_check(not qsys.is_quest_done("kitchen_task"), "分支：kitchen_task 未进入")


func _test_time_quest() -> void:
	# garden_task 完成条件 world_time >= 18
	_check(not qsys.is_quest_done("garden_task"), "garden_task 未完成（时间未到）")
	gs.world_time = 18.5
	qsys.check_advance()
	_check(qsys.is_quest_done("garden_task"), "garden_task 完成（world_time>=18）")


func _test_save_roundtrip() -> void:
	gs.quest_state = {"active": "kitchen_task", "done": ["monastery_errand"], "talked": ["赫伯特主教"], "battles_won": 2}
	gs.world_time = 13.5
	gs.save_game()
	var loaded := _ensure_autoload("GameStateRT2", "res://core/save/game_state.gd")
	loaded.save_path = RT_SAVE_PATH
	loaded.setup_party([CharacterData.new()])
	loaded.load_game()
	_check(loaded.quest_state.get("active", "") == "kitchen_task", "存档往返：quest_state.active")
	_check(int(loaded.quest_state.get("battles_won", 0)) == 2, "存档往返：quest_state.battles_won")
	_check(absf(float(loaded.world_time) - 13.5) < 0.001, "存档往返：world_time")


func _cleanup() -> void:
	var dir := DirAccess.open("res://.tests_tmp")
	if dir != null and dir.file_exists(RT_SAVE_PATH.get_file()):
		dir.remove(RT_SAVE_PATH.get_file())
