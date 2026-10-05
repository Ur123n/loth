extends Node

## 独立剧情触发器（Autoload：StoryTrigger）
## 读取 res://content/stories/triggers.json：
##   { "id", "story", "type", ... }
##   area    : {"area": {"position": [x, y], "radius": n}} —— 玩家进入圆形区域
##   interact: {"target": "NPC/对象名", "any": bool} —— 世界脚本调用 StoryTrigger.interact(id)
##   flag    : {"key": "flag名", "value": 期望值} —— GameState.set_flag 变化时判定
##   auto    : 场景就绪后自动触发（可选 "scene" 限定场景路径）
##   scene   : 进入指定场景时触发（"scene": "res://..."）
## 触发前总检查 GameState.is_story_played()，防止重复触发；
## once=true 表示本次运行内只触发一次（存档级防重由 GameState 负责）。
## 剧情播放期间的 flag 变化会暂存，剧情结束后补触发（用于剧情链）。

const TRIGGER_FILE := "res://content/stories/triggers.json"
const DEFAULT_COOLDOWN := 0.5

var triggers: Array = []          # 全部触发器（含 enabled=false，供校验）
var _active: Array = []
var _last_fire_time: Dictionary = {}
var _fired_once: Dictionary = {}
var _pending_flag_fires: Array = []
var _auto_scene_checked: String = ""


func _ready() -> void:
	reload()
	GameState.flag_changed.connect(_on_flag_changed)
	get_tree().scene_changed.connect(_on_scene_changed)
	StoryRunner.story_finished.connect(_on_story_finished)


func reload() -> void:
	triggers.clear()
	_active.clear()
	if not FileAccess.file_exists(TRIGGER_FILE):
		push_warning("[StoryTrigger] 触发器文件不存在：%s" % TRIGGER_FILE)
		return
	var file := FileAccess.open(TRIGGER_FILE, FileAccess.READ)
	if file == null:
		push_warning("[StoryTrigger] 无法读取：%s" % TRIGGER_FILE)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Array:
		push_warning("[StoryTrigger] %s 应为 JSON 数组" % TRIGGER_FILE)
		return
	for entry in parsed:
		if not entry is Dictionary:
			continue
		triggers.append(entry)
		if bool(entry.get("enabled", true)):
			_active.append(entry)
	_validate()


func _validate() -> void:
	for t in triggers:
		var id := str(t.get("id", ""))
		var story_id := str(t.get("story", ""))
		var type := str(t.get("type", ""))
		if id.is_empty():
			push_warning("[StoryTrigger] 触发器缺少 id")
		if story_id.is_empty():
			push_warning("[StoryTrigger] %s 缺少 story" % id)
		elif not StoryDB.has_story(story_id):
			push_warning("[StoryTrigger] %s 引用不存在的剧情：%s" % [id, story_id])
		if not ["area", "interact", "flag", "auto", "scene"].has(type):
			push_warning("[StoryTrigger] %s 未知类型：%s" % [id, type])


func get_triggers() -> Array:
	return triggers


func _physics_process(_delta: float) -> void:
	if GameState.story_active or get_tree().current_scene == null:
		return
	_check_auto_for_current_scene()
	for t in _active:
		if str(t.get("type", "")) == "area":
			_check_area(t)


func _check_auto_for_current_scene() -> void:
	var scene_path := get_tree().current_scene.scene_file_path
	if _auto_scene_checked == scene_path:
		return
	_auto_scene_checked = scene_path
	for t in _active:
		if str(t.get("type", "")) != "auto":
			continue
		if _scene_matches(t, scene_path) and _can_fire(t):
			_fire(t)


func _on_scene_changed() -> void:
	_auto_scene_checked = ""
	var scene_path := get_tree().current_scene.scene_file_path if get_tree().current_scene != null else ""
	for t in _active:
		if str(t.get("type", "")) != "scene":
			continue
		if _scene_matches(t, scene_path) and _can_fire(t):
			_fire(t)


func _scene_matches(t: Dictionary, scene_path: String) -> bool:
	var wanted := str(t.get("scene", ""))
	return wanted.is_empty() or wanted == scene_path


func _check_area(t: Dictionary) -> void:
	if not _can_fire(t):
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var area: Dictionary = t.get("area", {})
	var pos := _to_vector2(area.get("position", [0, 0]))
	var radius := float(area.get("radius", 50.0))
	if player.position.distance_to(pos) <= radius:
		_fire(t)


## 世界脚本在玩家与对象 / NPC 交互时调用。
func interact(target_id: String) -> void:
	if GameState.story_active:
		return
	for t in _active:
		if str(t.get("type", "")) != "interact":
			continue
		var want := str(t.get("target", ""))
		if (want.is_empty() or want == target_id or bool(t.get("any", false))) and _can_fire(t):
			_fire(t)


func _on_flag_changed(key: String, value) -> void:
	if GameState.story_active:
		_pending_flag_fires.append({"key": key, "value": value})
		return
	_process_flag_change(key, value)


func _process_flag_change(key: String, value) -> void:
	for t in _active:
		if str(t.get("type", "")) != "flag":
			continue
		if str(t.get("key", "")) != key:
			continue
		if _compare(value, t.get("value", true)) and _can_fire(t):
			_fire(t)


func _on_story_finished(_story_id: String) -> void:
	if _pending_flag_fires.is_empty():
		return
	var pending := _pending_flag_fires
	_pending_flag_fires = []
	for entry in pending:
		_process_flag_change(str(entry.get("key", "")), entry.get("value"))


func _can_fire(t: Dictionary) -> bool:
	var id := str(t.get("id", ""))
	var story_id := str(t.get("story", ""))
	if GameState.story_active:
		return false
	if GameState.is_story_played(story_id):
		return false
	if bool(t.get("once", true)) and _fired_once.get(id, false):
		return false
	var cooldown := float(t.get("cooldown", DEFAULT_COOLDOWN))
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_fire_time.get(id, -999.0)) < cooldown:
		return false
	return true


func _fire(t: Dictionary) -> void:
	var id := str(t.get("id", ""))
	var story_id := str(t.get("story", ""))
	_last_fire_time[id] = Time.get_ticks_msec() / 1000.0
	if bool(t.get("once", true)):
		_fired_once[id] = true
	StoryRunner.run_story(story_id)


func _compare(actual, expected) -> bool:
	if actual is bool or expected is bool:
		return bool(actual) == bool(expected)
	if actual is float or expected is float or actual is int or expected is int:
		return float(actual) == float(expected)
	return actual == expected


func _to_vector2(value) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Dictionary:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	return Vector2.ZERO
