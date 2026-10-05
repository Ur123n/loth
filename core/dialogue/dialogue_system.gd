extends Node

## 独立对话系统（Autoload：Dialogue）
## 职责：会话管理、台词展示（打字 / 推进）、选项、对话历史。
## UI 委托给 ui/dialogue/dialogue_box.gd；本类不解释剧情指令。
## 本类不提供协程：begin_line() / show_options() 同步返回递增令牌（token），
## StoryRunner 通过 is_line_done(token) / is_choice_done(token) 轮询完成状态。
## 历史：会话内已完成的台词存于 history；H 键打开面板回看。

signal session_started
signal session_ended
signal line_finished(speaker: String, text: String)
signal history_closed

var box: DialogueBox
var history: DialogueHistory
var active := false

var _line_token := 0
var _last_line_done := 0
var _current_line_token := -1
var _current_line_speaker := ""
var _current_line_text := ""
var _current_line_avatar := ""
var _current_line_color := Color(0.92, 0.94, 0.97)
var _choice_token := 0
var _last_choice_done := 0
var _current_choice_token := -1
var _last_choice_index := -1


func _ready() -> void:
	history = DialogueHistory.new()
	_ensure_box()


func _ensure_box() -> void:
	if box != null and is_instance_valid(box):
		return
	var script := load("res://ui/dialogue/dialogue_box.gd")
	if script == null:
		push_warning("对话 UI 脚本缺失：res://ui/dialogue/dialogue_box.gd")
		return
	box = script.new()
	box.name = "DialogueBox"
	# Autoload _ready 期间 root 正在初始化，延迟到下一帧挂载
	get_tree().root.add_child.call_deferred(box)
	box.line_advanced.connect(_on_line_advanced)
	box.option_chosen.connect(_on_option_chosen)
	box.history_closed.connect(func() -> void: history_closed.emit())


func start_session() -> void:
	_ensure_box()
	active = true
	history.clear()
	box.hide_options()
	box.show_box()
	session_started.emit()


func end_session() -> void:
	_ensure_box()
	active = false
	box.hide_box()
	session_ended.emit()


func is_active() -> bool:
	return active


## 开始显示一句台词；返回完成令牌（用 is_line_done(token) 轮询）。
func begin_line(speaker: String, text: String, avatar_path := "", color := Color(0.92, 0.94, 0.97),
		speed := 0.03, auto_advance := false, auto_delay := 1.2) -> int:
	_ensure_box()
	if not active:
		start_session()
	_line_token += 1
	_current_line_token = _line_token
	_current_line_speaker = speaker
	_current_line_text = text
	_current_line_avatar = avatar_path
	_current_line_color = color
	box.present_line(speaker, text, avatar_path, color, speed, auto_advance, auto_delay)
	return _line_token


func _on_line_advanced() -> void:
	if _current_line_token > _last_line_done:
		_last_line_done = _current_line_token
	if _current_line_text.is_empty() or not active:
		return
	history.append_line(_current_line_speaker, _current_line_text, _current_line_avatar, _current_line_color)
	line_finished.emit(_current_line_speaker, _current_line_text)


func is_line_done(token: int) -> bool:
	return token <= _last_line_done


## 显示一组选项；返回完成令牌（用 is_choice_done 轮询，get_last_choice_index 读结果）。
func show_options(options: Array[String]) -> int:
	_ensure_box()
	if not active:
		start_session()
	_choice_token += 1
	_current_choice_token = _choice_token
	box.show_options(options)
	return _choice_token


func _on_option_chosen(index: int) -> void:
	_last_choice_done = _current_choice_token
	_last_choice_index = index


func is_choice_done(token: int) -> bool:
	return token <= _last_choice_done


func get_last_choice_index() -> int:
	return _last_choice_index


func open_history() -> void:
	_ensure_box()
	box.set_history_lines(history.lines)
	box.open_history()


func close_history() -> void:
	if box != null:
		box.close_history()


func toggle_history() -> void:
	if box != null and box.is_history_visible():
		close_history()
	else:
		open_history()


func get_history() -> Array[Dictionary]:
	return history.lines
