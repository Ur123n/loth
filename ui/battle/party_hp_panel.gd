class_name PartyHpPanel
extends PanelContainer

## 队伍血量面板（表现层）：右上角显示四名角色名字、血条与数值，
## 受伤/回复时通过 refresh() 实时更新。

const PANEL_WIDTH := 250.0
const ROW_HEIGHT := 30.0

var _rows_holder: VBoxContainer
var _rows: Array = []   # {panel, name, bar, text}


func _ready() -> void:
	_build_ui()
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0:
		viewport_size = Vector2(1280, 720)
	position = Vector2(viewport_size.x - PANEL_WIDTH - 12, 12)
	size = Vector2(PANEL_WIDTH, 12 + 4.0 * ROW_HEIGHT + 12)


func refresh(units: Array) -> void:
	for i in units.size():
		var unit := units[i] as BattleUnit
		if unit == null:
			continue
		var row = _rows[i] if i < _rows.size() else _add_row()
		row["panel"].visible = true
		row["name"].text = unit.get_display_name()
		if unit.character_data != null:
			row["name"].add_theme_color_override("font_color", unit.character_data.block_color)
		else:
			row["name"].add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		row["bar"].max_value = unit.get_max_hp_value()
		row["bar"].value = unit.current_hp
		row["text"].text = "%d/%d" % [unit.current_hp, unit.get_max_hp_value()]
	for i in range(units.size(), _rows.size()):
		_rows[i]["panel"].visible = false


func _build_ui() -> void:
	name = "PartyHpPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.10, 0.92)
	style.border_color = Color(0.35, 0.42, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", style)

	_rows_holder = VBoxContainer.new()
	_rows_holder.add_theme_constant_override("separation", 4)
	add_child(_rows_holder)


func _add_row() -> Dictionary:
	var panel := HBoxContainer.new()
	panel.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	panel.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(66, 0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	panel.add_child(name_label)

	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(90, 0)
	bar.show_percentage = false
	panel.add_child(bar)

	var text_label := Label.new()
	text_label.custom_minimum_size = Vector2(84, 0)
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.add_theme_font_size_override("font_size", 12)
	text_label.add_theme_color_override("font_color", Color(0.85, 0.90, 0.95))
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(text_label)

	_rows_holder.add_child(panel)
	var row := {"panel": panel, "name": name_label, "bar": bar, "text": text_label}
	_rows.append(row)
	return row
