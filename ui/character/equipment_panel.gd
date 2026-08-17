class_name EquipmentPanel
extends VBoxContainer

## 装备栏（表现层）：头部 / 身体 / 腿部 / 足部 / 两个首饰 / 左右手武器。
## 当前无装备数据，全部显示空槽；数据填充后按部位自动显示装备名。

const SLOT_ORDER := ["头部", "身体", "腿部", "足部", "首饰1", "首饰2", "左手武器", "右手武器"]
const SLOT_SIZE := Vector2(215, 44)

var _slot_labels: Dictionary = {}


func _ready() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(grid)

	for slot_name in SLOT_ORDER:
		var box := _make_slot_box()
		var label: Label = box.get_node("SlotLabel")
		label.text = "%s　空" % slot_name
		grid.add_child(box)
		_slot_labels[slot_name] = label


func refresh(data: CharacterData) -> void:
	if data == null:
		return
	for slot_name in _slot_labels:
		var label: Label = _slot_labels[slot_name]
		label.text = "%s　空" % slot_name
		label.add_theme_color_override("font_color", Color(0.42, 0.46, 0.54))
	for entry in data.equipment:
		var equip := entry as EquipmentData
		if equip == null:
			continue
		if _slot_labels.has(equip.slot):
			var label: Label = _slot_labels[equip.slot]
			label.text = "%s　%s" % [equip.slot, equip.equipment_name]
			label.add_theme_color_override("font_color", Color(0.90, 0.93, 0.97))


func _make_slot_box() -> PanelContainer:
	var box := PanelContainer.new()
	box.custom_minimum_size = SLOT_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.16, 0.21, 0.95)
	style.border_color = Color(0.34, 0.40, 0.50)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	box.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.name = "SlotLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.42, 0.46, 0.54))
	box.add_child(label)
	return box
