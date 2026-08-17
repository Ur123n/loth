class_name PartyBar
extends Control

## 队伍状态条（表现层）：显示 4 名角色名字，高亮当前选中者。

const SLOT_SIZE := Vector2(150, 36)

var _slots: Array[PanelContainer] = []
var _slot_colors: Array[Color] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	offset_bottom = 48


func setup(characters: Array[CharacterData]) -> void:
	var hbox := HBoxContainer.new()
	hbox.name = "Slots"
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(hbox)

	for character in characters:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = SLOT_SIZE

		var label := Label.new()
		label.text = character.character_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 15)
		panel.add_child(label)

		hbox.add_child(panel)
		_slots.append(panel)
		_slot_colors.append(character.block_color)

	set_selected(0)


func set_selected(index: int) -> void:
	for i in _slots.size():
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(6)
		if i == index:
			style.bg_color = _slot_colors[i].darkened(0.35)
			style.border_color = Color(1.0, 1.0, 1.0, 0.9)
			style.set_border_width_all(2)
		else:
			style.bg_color = Color(0.12, 0.14, 0.18, 0.85)
			style.border_color = Color(0.32, 0.36, 0.42)
			style.set_border_width_all(1)
		_slots[i].add_theme_stylebox_override("panel", style)
