class_name ConfirmPrompt
extends Control

## 通用确认弹窗：显示标题与正文，是 → confirmed，否 → declined。

signal confirmed
signal declined

var _title_label: Label
var _text_label: Label


func _ready() -> void:
	_build_ui()
	visible = false


func show_prompt(title: String, text: String) -> void:
	_title_label.text = title
	_text_label.text = text
	visible = true


func hide_prompt() -> void:
	visible = false


func _build_ui() -> void:
	name = "ConfirmPrompt"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.5)
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
	panel.custom_minimum_size = Vector2(460, 220)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.10, 0.14, 0.98)
	panel_style.border_color = Color(0.90, 0.78, 0.40)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.content_margin_left = 30.0
	panel_style.content_margin_right = 30.0
	panel_style.content_margin_top = 24.0
	panel_style.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	vbox.add_child(_title_label)

	_text_label = Label.new()
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_size_override("font_size", 15)
	_text_label.add_theme_color_override("font_color", Color(0.88, 0.90, 0.94))
	vbox.add_child(_text_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 28)
	vbox.add_child(buttons)

	var yes_button := Button.new()
	yes_button.text = "是"
	yes_button.custom_minimum_size = Vector2(130, 42)
	yes_button.add_theme_font_size_override("font_size", 16)
	yes_button.pressed.connect(func(): confirmed.emit())
	buttons.add_child(yes_button)

	var no_button := Button.new()
	no_button.text = "否"
	no_button.custom_minimum_size = Vector2(130, 42)
	no_button.add_theme_font_size_override("font_size", 16)
	no_button.pressed.connect(func(): declined.emit())
	buttons.add_child(no_button)
