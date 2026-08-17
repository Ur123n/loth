class_name CardDetailPopup
extends Control

## 卡牌/技能详细信息弹窗。
## 可显示标题、多行信息，以及一个可选操作按钮（如“移出牌组”）。

signal action_pressed

var _title_label: Label
var _content_label: Label
var _action_button: Button


func _ready() -> void:
	_build_ui()
	visible = false


func show_info(title: String, lines: Array, action_text: String = "") -> void:
	_title_label.text = title
	_content_label.text = "\n".join(lines)
	if action_text.is_empty():
		_action_button.visible = false
	else:
		_action_button.text = action_text
		_action_button.visible = true
	visible = true


func hide_info() -> void:
	visible = false


func _build_ui() -> void:
	name = "CardDetailPopup"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(520, 460)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.10, 0.14, 0.98)
	panel_style.border_color = Color(0.42, 0.62, 0.92)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.content_margin_left = 30.0
	panel_style.content_margin_right = 30.0
	panel_style.content_margin_top = 24.0
	panel_style.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "Content"
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	vbox.add_child(_title_label)
	vbox.add_child(HSeparator.new())

	_content_label = Label.new()
	_content_label.add_theme_font_size_override("font_size", 15)
	_content_label.add_theme_color_override("font_color", Color(0.88, 0.91, 0.95))
	_content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_label.custom_minimum_size = Vector2(430, 260)
	vbox.add_child(_content_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	vbox.add_child(buttons)

	_action_button = Button.new()
	_action_button.custom_minimum_size = Vector2(130, 40)
	_action_button.add_theme_font_size_override("font_size", 15)
	_action_button.pressed.connect(func(): action_pressed.emit())
	buttons.add_child(_action_button)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(130, 40)
	close_button.add_theme_font_size_override("font_size", 15)
	close_button.pressed.connect(hide_info)
	buttons.add_child(close_button)
