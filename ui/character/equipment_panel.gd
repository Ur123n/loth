class_name EquipmentPanel
extends VBoxContainer

## 装备栏（表现层）：头部 / 身体 / 腿部 / 足部 / 两个首饰 / 左右手武器。
## 点击已穿装备由外部处理卸下；悬停显示装备描述与「得/舍」修正。

signal slot_pressed(slot_name: String)

const SLOT_ORDER := ["头部", "身体", "腿部", "足部", "首饰1", "首饰2", "左手武器", "右手武器"]
const SLOT_SIZE := Vector2(215, 44)

var _slot_labels: Dictionary = {}
var _slot_boxes: Dictionary = {}


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
		box.gui_input.connect(_on_slot_gui_input.bind(slot_name))
		box.tooltip_text = "%s：空槽位\n打开背包（B）点击对应装备，穿到当前角色" % slot_name
		grid.add_child(box)
		_slot_labels[slot_name] = label
		_slot_boxes[slot_name] = box


func refresh(data: CharacterData) -> void:
	if data == null:
		return
	for slot_name in _slot_labels:
		var label: Label = _slot_labels[slot_name]
		label.text = "%s　空" % slot_name
		label.add_theme_color_override("font_color", Color(0.42, 0.46, 0.54))
		var box := _slot_boxes.get(slot_name) as PanelContainer
		if box != null:
			box.tooltip_text = "%s：空槽位\n打开背包（B）点击对应装备，穿到当前角色" % slot_name
	for entry in data.equipment:
		var equip := entry as EquipmentData
		if equip == null:
			continue
		if _slot_labels.has(equip.slot):
			var label: Label = _slot_labels[equip.slot]
			label.text = "%s　%s" % [equip.slot, equip.equipment_name]
			label.add_theme_color_override("font_color", Color(0.90, 0.93, 0.97))
			_set_slot_tooltip(equip)


## 装备槽位点击：交外部处理（CharacterPanel 卸下 / 提示）。
func _on_slot_gui_input(event: InputEvent, slot_name: String) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		slot_pressed.emit(slot_name)
		accept_event()


## 悬停提示：描述 + 得（绿）/ 舍（红）修正列表。
func _set_slot_tooltip(equip: EquipmentData) -> void:
	var lines: Array[String] = [equip.description, ""]
	if not equip.benefit_lines().is_empty():
		lines.append("【得】%s" % "，".join(equip.benefit_lines()))
	if not equip.cost_lines().is_empty():
		lines.append("【舍】%s" % "，".join(equip.cost_lines()))
	var box := _slot_boxes.get(equip.slot) as PanelContainer
	if box != null:
		box.tooltip_text = "\n".join(lines)


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
