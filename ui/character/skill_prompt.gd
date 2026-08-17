class_name SkillPrompt
extends Control

## 技能提示界面：询问是否将技能加入当前角色技能库。
## 是 → confirmed；否 → declined。

signal confirmed
signal declined

var _card_name_label: Label
var _description_label: Label


func _ready() -> void:
	_build_ui()
	visible = false


func show_prompt(skill_name: String) -> void:
	_card_name_label.text = "是否将「%s」加入技能库？" % skill_name
	var card := CardDB.get_card(skill_name)
	_description_label.text = "「%s」：%s" % [skill_name, CardDB.describe_card(card)]
	visible = true


func _build_ui() -> void:
	name = "SkillPrompt"
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
	panel.custom_minimum_size = Vector2(440, 230)
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
	vbox.name = "Content"
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "发现技能"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	vbox.add_child(title)

	_card_name_label = Label.new()
	_card_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_name_label.add_theme_font_size_override("font_size", 18)
	_card_name_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.97))
	vbox.add_child(_card_name_label)

	_description_label = Label.new()
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_label.add_theme_font_size_override("font_size", 14)
	_description_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82))
	vbox.add_child(_description_label)

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
