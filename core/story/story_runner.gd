extends Node

## 剧情执行器（Autoload：StoryRunner）
## 时间轴 + 指令模型：
##   - 指令按顺序执行；blocking=false 的指令立即放行（操作在后台继续，Runner 不等待）；
##   - "parallel" 指令并行执行子指令并等待全部完成。
## 指令直接驱动运行中的游戏对象（对话 / 镜头 / 角色 / Flag / 场景…），而非播放动画。
## 指令处理器是同步函数，返回“操作句柄”（Tween / SceneTreeTimer / 对话令牌 / null）；
## Runner 对阻塞指令轮询句柄完成，非阻塞指令直接丢弃句柄（后台继续）。
## 剧情开始：锁定玩家输入、置 GameState.story_active；结束：恢复输入并关闭对话。
## 数据：content/stories/*.json（StoryDB）；指令实现：story_instructions.gd。
## 启动采用队列 + _process 内 await（Godot 4.7 禁止不 await 的协程调用）。

signal story_started(story_id: String)
signal story_finished(story_id: String)
signal instruction_started(story_id: String, index: int, type: String)
signal instruction_finished(story_id: String, index: int, type: String)
signal input_locked_changed(locked: bool)

const DEFAULT_BLOCKING := true

var _ctx: StoryContext = null
var _queued_story: String = ""
var _queued_forced := false
var _registry: Dictionary = {}
var _instructions_lib: StoryInstructions = null
var _message_label: Label = null


class StoryContext:
	var story_id: String = ""
	var story: StoryData = null
	var variables: Dictionary = {}
	var interrupted := false
	var runner = null

	func tree() -> SceneTree:
		return Engine.get_main_loop() as SceneTree


func _ready() -> void:
	_instructions_lib = StoryInstructions.new()
	_registry = _instructions_lib.build_registry()
	if StoryDB != null:
		StoryDB.validate_known_types(get_known_types())


## 队列中的剧情在下一帧由 _process 启动（run_story 本身是同步的）。
func _process(_delta: float) -> void:
	if _queued_story != "" and _ctx == null:
		var story_id := _queued_story
		var forced := _queued_forced
		_queued_story = ""
		_queued_forced = false
		await _start_story(story_id, forced)


func is_running() -> bool:
	return _ctx != null


func has_pending_story() -> bool:
	return _queued_story != ""


func is_busy() -> bool:
	return _ctx != null or _queued_story != ""


func get_known_types() -> Array:
	var types: Array = _registry.keys()
	types.append_array(["if", "story.start", "end", "parallel"])
	return types


## 播放剧情：已播放过则直接忽略（防重复触发）；正在播放时忽略新请求。
func run_story(story_id: String) -> void:
	if is_busy():
		push_warning("[StoryRunner] 已有剧情 %s 播放中，忽略 %s" % [_current_story_label(), story_id])
		return
	if GameState.is_story_played(story_id):
		return
	_queued_story = story_id
	_queued_forced = false


## 供测试 / 编辑器预览强制播放：跳过“已播放”检查，但防重入。
func run_story_forced(story_id: String) -> void:
	if is_busy():
		push_warning("[StoryRunner] 已有剧情 %s 播放中，忽略 %s" % [_current_story_label(), story_id])
		return
	_queued_story = story_id
	_queued_forced = true


func _current_story_label() -> String:
	if _ctx != null:
		return _ctx.story_id
	if _queued_story != "":
		return _queued_story
	return "?"


func _start_story(story_id: String, forced: bool) -> void:
	var story := StoryDB.get_story(story_id)
	if story == null:
		push_warning("[StoryRunner] 剧情不存在：%s" % story_id)
		return
	if not forced:
		GameState.mark_story_played(story_id)
	_ctx = StoryContext.new()
	_ctx.story_id = story_id
	_ctx.story = story
	_ctx.runner = self
	GameState.story_active = true
	_set_player_input_enabled(false)
	input_locked_changed.emit(true)
	story_started.emit(story_id)
	await run_instructions(story.instructions, _ctx)
	if Dialogue.is_active():
		Dialogue.end_session()
	_set_player_input_enabled(true)
	GameState.story_active = false
	input_locked_changed.emit(false)
	_ctx = null
	story_finished.emit(story_id)


## 按顺序执行指令；if / story.start / end / parallel 为结构指令，在此处理。
func run_instructions(instructions: Array, ctx: StoryContext) -> void:
	for i in instructions.size():
		if ctx.interrupted:
			return
		var ins = instructions[i]
		if not ins is Dictionary or ins.is_empty():
			continue
		var type := str(ins.get("type", ""))
		if type == "parallel":
			await _run_parallel(ins.get("instructions", []), ctx)
			continue
		if type == "if":
			var branch_ok := _instructions_lib.evaluate_condition(ctx, ins.get("condition", {}))
			var branch: Array = ins.get("then" if branch_ok else "else", [])
			if branch is Array and not branch.is_empty():
				await run_instructions(branch, ctx)
			continue
		if type == "story.start":
			var nested := StoryDB.get_story(str(ins.get("story", "")))
			if nested == null:
				push_warning("[StoryRunner] story.start 剧情不存在：%s" % str(ins.get("story")))
			else:
				await run_instructions(nested.instructions, ctx)
			continue
		if type == "end":
			ctx.interrupted = true
			continue
		var handler = _registry.get(type)
		if handler == null:
			push_warning("[StoryRunner] 未知指令类型：%s（剧情 %s，第 %d 条）" % [type, ctx.story_id, i])
			continue
		var blocking := bool(ins.get("blocking", DEFAULT_BLOCKING))
		instruction_started.emit(ctx.story_id, i, type)
		var op = handler.call(ctx, ins, blocking)
		if blocking or (op is Dictionary and op.get("kind") == "dialogue_choice"):
			await _await_op(op, ctx)
			if op is Dictionary and op.has("on_done"):
				(op["on_done"] as Callable).call()
		instruction_finished.emit(ctx.story_id, i, type)


## 并行：同时启动所有子指令，轮询等待全部完成。
func _run_parallel(children: Array, ctx: StoryContext) -> void:
	var ops: Array = []
	for ins in children:
		if not ins is Dictionary:
			continue
		var type := str(ins.get("type", ""))
		if ["parallel", "if", "story.start", "end"].has(type):
			push_warning("[StoryRunner] parallel 内不支持 %s（已跳过）" % type)
			continue
		var handler = _registry.get(type)
		if handler == null:
			push_warning("[StoryRunner] 未知指令类型：%s" % type)
			continue
		var blocking := bool(ins.get("blocking", DEFAULT_BLOCKING))
		ops.append(handler.call(ctx, ins, blocking))
	while not _all_ops_done(ops, ctx):
		await get_tree().process_frame
	for op in ops:
		if op is Dictionary and op.has("on_done"):
			(op["on_done"] as Callable).call()


func _all_ops_done(ops: Array, ctx: StoryContext) -> bool:
	for op in ops:
		if op != null and not _op_done(op, ctx):
			return false
	return true


func _op_done(op, ctx: StoryContext) -> bool:
	if op is Tween:
		return not op.is_running()
	if op is SceneTreeTimer:
		return op.time_left <= 0.0
	if op is Dictionary:
		match str(op.get("kind", "")):
			"dialogue_line":
				return Dialogue.is_line_done(int(op.get("token", -1)))
			"dialogue_choice":
				return Dialogue.is_choice_done(int(op.get("token", -1)))
			"history":
				return Dialogue.box == null or not Dialogue.box.is_history_visible()
			"scene":
				var scene: Node = ctx.tree().current_scene
				return scene != null and scene.scene_file_path == str(op.get("scene"))
	return true


## 等待一个操作句柄完成（按帧轮询）。
func _await_op(op, ctx: StoryContext) -> void:
	if op == null:
		return
	while not _op_done(op, ctx):
		await get_tree().process_frame


## 中断当前剧情（运行循环在下一个指令边界停止）。
func interrupt() -> void:
	if _ctx != null:
		_ctx.interrupted = true


func lock_player_input() -> void:
	_set_player_input_enabled(false)
	input_locked_changed.emit(true)


func unlock_player_input() -> void:
	_set_player_input_enabled(true)
	input_locked_changed.emit(false)


func _set_player_input_enabled(enabled: bool) -> void:
	for node in get_tree().get_nodes_in_group("player"):
		if node.get("input_enabled") != null:
			node.set("input_enabled", enabled)


## message 指令的顶部字幕。
func show_message(text: String, duration: float) -> Tween:
	_ensure_message_label()
	_message_label.text = text
	_message_label.visible = true
	_message_label.modulate.a = 1.0
	var tween := create_tween()
	if duration > 0.0:
		tween.tween_interval(maxf(duration - 0.3, 0.0))
		tween.tween_property(_message_label, "modulate:a", 0.0, 0.3)
	return tween


func _ensure_message_label() -> void:
	if _message_label != null and is_instance_valid(_message_label):
		return
	_message_label = Label.new()
	_message_label.name = "StoryMessageLabel"
	_message_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_message_label.offset_top = 72.0
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 22)
	_message_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	_message_label.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.10, 0.9))
	_message_label.add_theme_constant_override("outline_size", 6)
	_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_label.visible = false
	get_tree().root.add_child(_message_label)
