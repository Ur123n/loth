extends SceneTree

## 剧情系统测试：
## - StoryDB 加载 content/stories/*.json，指令类型全部在注册表内
## - StoryTrigger 加载 triggers.json，引用的剧情存在
## - 执行器：阻塞顺序、parallel 并行、flag/var、if 分支、emit_signal、已播放防重
## 运行：C:\1\Godot_v4.7.1-stable_win64_console.exe --headless --path C:\游戏 --script tests\story\test_story_data.gd

var _passed := 0
var _failed := 0
var _done := false
var _emitted: Array = []
var gs: Node
var story_db: Node
var story_runner: Node
var story_trigger: Node


func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true
	_run_all()
	return false


func _run_all() -> void:
	_ensure_autoloads()
	gs.set("save_path", "user://test_story_save.json")
	await process_frame
	_test_story_database()
	_test_triggers_database()
	await _test_runner_blocking()
	await _test_runner_parallel()
	await _test_runner_branch_and_signal()
	await _test_played_guard()
	_cleanup()
	print("RESULT: passed=%d failed=%d" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _ensure_autoloads() -> void:
	gs = _ensure_autoload("GameState", "res://core/save/game_state.gd")
	_ensure_autoload("CameraCtrl", "res://core/camera/camera_controller.gd")
	_ensure_autoload("Dialogue", "res://core/dialogue/dialogue_system.gd")
	story_db = _ensure_autoload("StoryDB", "res://core/story/story_database.gd")
	story_runner = _ensure_autoload("StoryRunner", "res://core/story/story_runner.gd")
	story_trigger = _ensure_autoload("StoryTrigger", "res://core/story/trigger_manager.gd")


func _ensure_autoload(node_name: String, script_path: String) -> Node:
	var node: Node = root.get_node_or_null(node_name)
	if node == null:
		node = load(script_path).new()
		node.name = node_name
		root.add_child(node)
	return node


func _test_story_database() -> void:
	var stories: Dictionary = story_db.get("stories")
	_check(stories.size() >= 3, "StoryDB 至少 3 个剧情（示例 + 触发示例）")
	var known: Array = story_runner.get_known_types()
	_check(known.size() >= 20, "指令注册表至少 20 种（实际 %d）" % known.size())
	for id in stories:
		var story: StoryData = stories[id]
		_check(not story.story_id.is_empty(), "剧情 %s 有 id" % id)
		_check(story.instructions.size() > 0, "剧情 %s 有指令" % id)
		var problems: Array[String] = []
		story.validate(problems, known)
		for p in problems:
			_check(false, "剧情 %s：%s" % [id, p])
	_check(story_db.has_story("example_intro"), "示例剧情 example_intro 存在")
	_check(story_db.has_story("example_flag_story"), "flag 触发示例剧情存在")


func _test_triggers_database() -> void:
	var trigs: Array = story_trigger.get_triggers()
	_check(trigs.size() >= 3, "触发器至少 3 个（实际 %d）" % trigs.size())
	for t in trigs:
		var id := str(t.get("id", ""))
		_check(not id.is_empty(), "触发器有 id")
		_check(not str(t.get("story", "")).is_empty(), "触发器 %s 有 story" % id)
		_check(story_db.has_story(str(t.get("story", ""))), "触发器 %s 引用的剧情存在" % id)
		_check(["area", "interact", "flag", "auto", "scene"].has(str(t.get("type", ""))),
			"触发器 %s 类型合法" % id)


func _test_runner_blocking() -> void:
	_register_test_story("test_block", [
		{"type": "flag.set", "key": "test:step1", "value": true},
		{"type": "wait", "seconds": 0.1, "blocking": true},
		{"type": "flag.set", "key": "test:step2", "value": true},
	])
	await _run_story("test_block")
	_check(gs.get_flag("test:step1") == true, "blocking: 顺序指令 1 已执行")
	_check(gs.get_flag("test:step2") == true, "blocking: 顺序指令 3 已执行")
	_check(gs.is_story_played("test_block"), "blocking: 已记录播放")
	_check(not gs.get("story_active"), "blocking: 结束后解除 story_active")
	_check(not story_runner.is_running(), "blocking: 结束后无运行中剧情")


func _test_runner_parallel() -> void:
	_register_test_story("test_parallel", [
		{"type": "parallel", "instructions": [
			{"type": "wait", "seconds": 0.3},
			{"type": "wait", "seconds": 0.3},
		]},
		{"type": "flag.set", "key": "test:parallel_done", "value": true},
	])
	var start := Time.get_ticks_msec()
	await _run_story("test_parallel")
	var elapsed := (Time.get_ticks_msec() - start) / 1000.0
	_check(gs.get_flag("test:parallel_done") == true, "parallel: 完成后继续执行")
	_check(elapsed < 0.55, "parallel: 两个 0.3s 指令并行（实际 %.2fs）" % elapsed)


func _test_runner_branch_and_signal() -> void:
	gs.flag_changed.connect(_on_flag_probe)
	_register_test_story("test_branch", [
		{"type": "var.set", "name": "n", "value": 2},
		{"type": "emit_signal", "on": "/root/GameState", "signal": "flag_changed", "args": ["test:emitted", 7]},
		{"type": "if", "condition": {"var": "n", "equals": 2}, "then": [
			{"type": "flag.set", "key": "test:if_then", "value": true}
		], "else": [
			{"type": "flag.set", "key": "test:if_else", "value": true}
		]},
		{"type": "if", "condition": {"var": "n", "equals": 3}, "then": [
			{"type": "flag.set", "key": "test:if_wrong", "value": true}
		]},
	])
	await _run_story("test_branch")
	_check(gs.get_flag("test:if_then") == true, "if: then 分支执行")
	_check(gs.get_flag("test:if_else") != true, "if: else 分支未执行")
	_check(gs.get_flag("test:if_wrong") != true, "if: 条件不满足时不执行")
	_check(_emitted.has(["test:emitted", 7]), "emit_signal: 信号被发出并携带参数")


func _test_played_guard() -> void:
	var before: int = gs.get("story_played").size()
	await _run_story("test_block")
	_check(gs.get("story_played").size() == before, "已播放剧情不重复播放")
	await _run_story("test_block", true)
	_check(gs.get_flag("test:step1") == true, "forced 重放成功（编辑器预览用）")


func _register_test_story(id: String, instructions: Array) -> void:
	var story := StoryData.from_dict({"id": id, "title": id, "instructions": instructions})
	var stories: Dictionary = story_db.get("stories")
	stories[id] = story


func _run_story(story_id: String, forced := false) -> void:
	story_runner.call("run_story_forced" if forced else "run_story", story_id)
	while story_runner.is_busy():
		await process_frame


func _on_flag_probe(key: String, value) -> void:
	if key == "test:emitted":
		_emitted.append([key, value])


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("PASS  ", label)
	else:
		_failed += 1
		print("FAIL  ", label)


func _cleanup() -> void:
	gs.set("flags", {})
	gs.set("story_played", [])
	gs.set("save_path", gs.SAVE_PATH)
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("test_story_save.json"):
		dir.remove("test_story_save.json")
