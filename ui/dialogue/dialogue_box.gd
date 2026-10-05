class_name DialogueBox
extends Control

## 对话 UI（文本框 / 头像 / 打字 / 选项 / 历史面板）。
## 由 DialogueSystem 驱动；本类只负责显示与输入，不保存对话状态。
## 输入约定：点击 / 空格 / 回车 推进台词（未打印完则直接显示全文）；
## ↑/↓ 选择选项；H 开关历史；Esc / H 关闭历史。

signal line_advanced
signal option_chosen(index: int)
signal history_closed

const AVATAR_SIZE := Vector2(96, 96)
const TEXT_PANEL_HEIGHT := 170.0
const OPTION_PANEL_WIDTH := 560.0
const OPTION_PANEL_HEIGHT := 240.0

var _dim: ColorRect
var _text_panel: PanelContainer
var _speaker_label: Label
var _text_label: Label
var _avatar_holder: Control
var _avatar_texture: TextureRect
var _avatar_fallback: PanelContainer
var _avatar_fallback_label: Label
var _advance_indicator: Label
var _history_panel: PanelContainer
var _history_label: RichTextLabel
var _option_panel: VBoxContainer
var _options: Array[Button] = []
var _option_index := 0

var _line_ready := false
var _line_consumed := false
var _options_visible := false
var _history_visible := false
var _auto_pending := false
var _speed := 0.03
var _type_tween: Tween
var _blink_tween: Tween


func _ready() -> void:
	name = "DialogueBox"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_ui()


func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0.0, 0.0, 0.0, 0.28)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	_history_panel = _build_history_panel()
	add_child(_history_panel)

	_option_panel = VBoxContainer.new()
	_option_panel.name = "OptionPanel"
	_option_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_option_panel.offset_left = -OPTION_PANEL_WIDTH / 2.0
	_option_panel.offset_right = OPTION_PANEL_WIDTH / 2.0
	_option_panel.offset_top = -OPTION_PANEL_HEIGHT - TEXT_PANEL_HEIGHT - 20.0
	_option_panel.offset_bottom = -TEXT_PANEL_HEIGHT - 20.0
	_option_panel.add_theme_constant_override("separation", 8)
	_option_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_option_panel.visible = false
	add_child(_option_panel)

	_text_panel = PanelContainer.new()
	_text_panel.name = "TextPanel"
	_text_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_text_panel.offset_left = 90.0
	_text_panel.offset_right = -90.0
	_text_panel.offset_top = -TEXT_PANEL_HEIGHT - 10.0
	_text_panel.offset_bottom = -10.0
	_text_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.13, 0.96)
	style.border_color = Color(0.75, 0.62, 0.32)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	_text_panel.add_theme_stylebox_override("panel", style)
	_text_panel.gui_input.connect(_on_text_panel_gui_input)
	add_child(_text_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	_text_panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	margin.add_child(hbox)

	_avatar_holder = Control.new()
	_avatar_holder.custom_minimum_size = AVATAR_SIZE
	hbox.add_child(_avatar_holder)

	_avatar_fallback = PanelContainer.new()
	_avatar_fallback.name = "AvatarFallback"
	_avatar_fallback.custom_minimum_size = AVATAR_SIZE
	var avatar_style := StyleBoxFlat.new()
	avatar_style.bg_color = Color(0.36, 0.48, 0.63)
	avatar_style.set_corner_radius_all(14)
	_avatar_fallback.add_theme_stylebox_override("panel", avatar_style)
	_avatar_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_avatar_holder.add_child(_avatar_fallback)

	var avatar_center := CenterContainer.new()
	avatar_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_avatar_fallback.add_child(avatar_center)

	_avatar_fallback_label = Label.new()
	_avatar_fallback_label.add_theme_font_size_override("font_size", 40)
	_avatar_fallback_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	avatar_center.add_child(_avatar_fallback_label)

	_avatar_texture = TextureRect.new()
	_avatar_texture.name = "AvatarTexture"
	_avatar_texture.custom_minimum_size = AVATAR_SIZE
	_avatar_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_avatar_texture.visible = false
	_avatar_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_avatar_holder.add_child(_avatar_texture)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	_speaker_label = Label.new()
	_speaker_label.name = "SpeakerLabel"
	_speaker_label.add_theme_font_size_override("font_size", 18)
	_speaker_label.add_theme_color_override("font_color", Color(0.92, 0.76, 0.38))
	vbox.add_child(_speaker_label)

	_text_label = Label.new()
	_text_label.name = "TextLabel"
	_text_label.add_theme_font_size_override("font_size", 16)
	_text_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.97))
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_text_label)

	_advance_indicator = Label.new()
	_advance_indicator.name = "AdvanceIndicator"
	_advance_indicator.text = "▼"
	_advance_indicator.add_theme_font_size_override("font_size", 18)
	_advance_indicator.add_theme_color_override("font_color", Color(0.92, 0.76, 0.38))
	_advance_indicator.visible = false
	_advance_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_advance_indicator)


func _build_history_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "HistoryPanel"
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -440.0
	panel.offset_right = -14.0
	panel.offset_top = 14.0
	panel.offset_bottom = -14.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.14, 0.97)
	style.border_color = Color(0.55, 0.62, 0.72)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", style)
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "对话历史"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.92, 0.76, 0.38))
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_history_label = RichTextLabel.new()
	_history_label.bbcode_enabled = true
	_history_label.scroll_active = false
	_history_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_label.custom_minimum_size = Vector2(400, 0)
	_history_label.add_theme_font_size_override("normal_font_size", 15)
	scroll.add_child(_history_label)

	var hint := Label.new()
	hint.text = "H / Esc 关闭"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.55, 0.58, 0.64))
	vbox.add_child(hint)
	return panel


func present_line(speaker: String, text: String, avatar_path: String, color: Color,
		speed: float, auto_advance: bool, auto_delay: float) -> void:
	_line_ready = false
	_line_consumed = false
	_auto_pending = false
	_speed = speed
	_kill_tweens()
	show_box()
	hide_options()
	close_history()
	_speaker_label.text = speaker
	_speaker_label.visible = not speaker.is_empty()
	_text_label.text = text
	_text_label.add_theme_color_override("font_color", color)
	_text_label.visible_characters = 0
	_advance_indicator.visible = false
	_set_avatar(avatar_path, speaker, color)
	if text.is_empty() or speed <= 0.0:
		_finish_printing()
	else:
		_type_tween = create_tween()
		_type_tween.tween_method(_set_visible_chars, 0.0, float(text.length()),
			maxf(speed * float(text.length()), 0.05))
		_type_tween.tween_callback(_finish_printing)
	if auto_advance:
		var timer := get_tree().create_timer(maxf(auto_delay, 0.1))
		timer.timeout.connect(func() -> void:
			if _line_ready and not _line_consumed:
				_advance()
			elif not _line_ready:
				_auto_pending = true
		)


func _set_visible_chars(count: float) -> void:
	if _text_label != null:
		_text_label.visible_characters = int(count)


func _finish_printing() -> void:
	if _text_label != null:
		_text_label.visible_characters = -1
	_line_ready = true
	_advance_indicator.visible = true
	_start_blink()
	if _auto_pending:
		_auto_pending = false
		_advance()


func _complete_printing() -> void:
	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
		_type_tween = null
	if _text_label != null:
		_text_label.visible_characters = -1
	_line_ready = true
	if _advance_indicator != null:
		_advance_indicator.visible = true


func _advance() -> void:
	if _history_visible or _options_visible or _line_consumed:
		return
	if not _line_ready:
		_complete_printing()
		return
	_line_consumed = true
	_advance_indicator.visible = false
	line_advanced.emit()


func _start_blink() -> void:
	_kill_blink()
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_property(_advance_indicator, "modulate:a", 0.15, 0.45)
	_blink_tween.tween_property(_advance_indicator, "modulate:a", 1.0, 0.45)


func _kill_tweens() -> void:
	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
		_type_tween = null
	_kill_blink()


func _kill_blink() -> void:
	if _blink_tween != null and _blink_tween.is_valid():
		_blink_tween.kill()
		_blink_tween = null
	if _advance_indicator != null:
		_advance_indicator.modulate.a = 1.0


func _set_avatar(avatar_path: String, speaker: String, color: Color) -> void:
	var texture := ArtLoader.load_texture(avatar_path)
	if texture != null:
		_avatar_texture.texture = texture
		_avatar_texture.visible = true
		_avatar_fallback.visible = false
		return
	_avatar_texture.visible = false
	_avatar_fallback.visible = true
	var style := _avatar_fallback.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		style.bg_color = _avatar_color_for(speaker, color)
	_avatar_fallback_label.text = speaker.left(1) if not speaker.is_empty() else "?"


func _avatar_color_for(speaker: String, fallback: Color) -> Color:
	if speaker.is_empty():
		return fallback
	if GameState != null and GameState.party_characters != null:
		for char in GameState.party_characters:
			if char is CharacterData and char.character_name == speaker:
				return char.block_color
	if NpcDB != null and NpcDB.has_method("get_npc"):
		var npc = NpcDB.get_npc(speaker)
		if npc != null:
			return npc.block_color
	return fallback


func _on_text_panel_gui_input(event: InputEvent) -> void:
	if _options_visible or _history_visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _history_visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("dialogue_history"):
			close_history()
			get_viewport().set_input_as_handled()
		return
	if _options_visible:
		if event.is_action_pressed("ui_down"):
			_move_option(1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_up"):
			_move_option(-1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_accept"):
			_choose(_option_index)
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("dialogue_history"):
		open_history()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept"):
		_advance()
		get_viewport().set_input_as_handled()


func _move_option(step: int) -> void:
	if _options.is_empty():
		return
	_option_index = wrapi(_option_index + step, 0, _options.size())
	_options[_option_index].grab_focus()


func show_options(options: Array[String]) -> void:
	hide_options()
	_options_visible = true
	for i in options.size():
		var btn := Button.new()
		btn.text = options[i]
		btn.custom_minimum_size = Vector2(OPTION_PANEL_WIDTH, 40)
		btn.add_theme_font_size_override("font_size", 15)
		var index := i
		btn.pressed.connect(func() -> void: _choose(index))
		btn.focus_entered.connect(func() -> void: _option_index = index)
		_option_panel.add_child(btn)
		_options.append(btn)
	_option_panel.visible = true
	if _options.size() > 0:
		_option_index = 0
		_options[0].grab_focus()


func hide_options() -> void:
	_options_visible = false
	if _option_panel != null:
		_option_panel.visible = false
	for btn in _options:
		if is_instance_valid(btn):
			btn.queue_free()
	_options.clear()
	_option_index = 0


func _choose(index: int) -> void:
	hide_options()
	option_chosen.emit(index)


func set_history_lines(lines: Array) -> void:
	_history_label.clear()
	for entry in lines:
		if not entry is Dictionary:
			continue
		var speaker := str(entry.get("speaker", ""))
		var text := str(entry.get("text", ""))
		var display_speaker := speaker if not speaker.is_empty() else "旁白"
		_history_label.append_text("[color=#c8a94a]%s[/color]：%s\n" % [display_speaker, _bbcode_escape(text)])


func _bbcode_escape(text: String) -> String:
	return text.replace("[", "[lb]")


func open_history() -> void:
	_history_visible = true
	_history_panel.visible = true
	if _history_label != null and _history_label.get_total_line_count() > 0:
		_history_label.scroll_to_line(_history_label.get_total_line_count() - 1)


func close_history() -> void:
	if not _history_visible:
		return
	_history_visible = false
	_history_panel.visible = false
	history_closed.emit()


func is_history_visible() -> bool:
	return _history_visible


func toggle_history() -> void:
	if _history_visible:
		close_history()
	else:
		open_history()


func show_box() -> void:
	visible = true


func hide_box() -> void:
	_complete_printing()
	hide_options()
	close_history()
	_line_ready = false
	_line_consumed = false
	_auto_pending = false
	visible = false
	line_advanced.emit()
	option_chosen.emit(-1)
