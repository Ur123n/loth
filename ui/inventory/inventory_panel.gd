class_name InventoryPanel
extends Control

## 背包界面（非战斗地图按 B 打开）：一排排方格组成，滚轮翻页。
## 显示背包物品（含体积/形状）、钱币与占用统计；悬停查看物品信息。

signal closed

const WINDOW_SIZE := Vector2(720, 600)
const CELL_SIZE := 52.0
const PITCH := 56.0
const ITEM_COLORS: Array[Color] = [
	Color(0.62, 0.52, 0.36), Color(0.45, 0.60, 0.48), Color(0.48, 0.53, 0.68),
	Color(0.65, 0.45, 0.52), Color(0.52, 0.62, 0.62), Color(0.70, 0.62, 0.40),
]

var _page: int = 0
var _grid_origin: Vector2 = Vector2.ZERO
var _cells: Array[PanelContainer] = []
var _item_rects: Array[ColorRect] = []
var _page_label: Label
var _money_label: Label
var _usage_label: Label
var _tooltip_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var window := PanelContainer.new()
	window.name = "Window"
	window.set_anchors_preset(Control.PRESET_CENTER)
	window.grow_horizontal = Control.GROW_DIRECTION_BOTH
	window.grow_vertical = Control.GROW_DIRECTION_BOTH
	window.offset_left = -WINDOW_SIZE.x * 0.5
	window.offset_top = -WINDOW_SIZE.y * 0.5
	window.offset_right = WINDOW_SIZE.x * 0.5
	window.offset_bottom = WINDOW_SIZE.y * 0.5
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.10, 0.13, 0.98)
	style.border_color = Color(0.42, 0.46, 0.52)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	window.add_theme_stylebox_override("panel", style)
	add_child(window)

	var vbox := VBoxContainer.new()
	vbox.name = "Layout"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	window.add_child(vbox)

	var title := Label.new()
	title.text = "背 包"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.95, 0.86, 0.58))
	vbox.add_child(title)

	_money_label = Label.new()
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_money_label.add_theme_font_size_override("font_size", 16)
	_money_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.30))
	vbox.add_child(_money_label)

	_usage_label = Label.new()
	_usage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_usage_label.add_theme_font_size_override("font_size", 13)
	_usage_label.add_theme_color_override("font_color", Color(0.66, 0.72, 0.80))
	vbox.add_child(_usage_label)

	# 网格：8 列 x 6 行
	var grid_wrap := CenterContainer.new()
	vbox.add_child(grid_wrap)
	var grid := GridContainer.new()
	grid.columns = GameState.inventory.cols()
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid_wrap.add_child(grid)
	var cell_style := StyleBoxFlat.new()
	cell_style.bg_color = Color(0.16, 0.18, 0.22, 0.9)
	cell_style.border_color = Color(0.28, 0.31, 0.36)
	cell_style.set_border_width_all(1)
	cell_style.set_corner_radius_all(3)
	for i in GameState.inventory.cols() * GameState.inventory.rows():
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
		cell.add_theme_stylebox_override("panel", cell_style)
		grid.add_child(cell)
		_cells.append(cell)

	# 物品层：绝对定位覆盖在网格上方；网格实际位置在 _process 中动态校正
	# 物品层使用独立 Control，直接铺在窗口上
	var item_layer := Control.new()
	item_layer.name = "ItemLayer"
	item_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	item_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(item_layer)

	_page_label = Label.new()
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.add_theme_font_size_override("font_size", 14)
	_page_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
	vbox.add_child(_page_label)

	_tooltip_label = Label.new()
	_tooltip_label.name = "Tooltip"
	_tooltip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_label.custom_minimum_size = Vector2(0, 36)
	_tooltip_label.add_theme_font_size_override("font_size", 13)
	_tooltip_label.add_theme_color_override("font_color", Color(0.72, 0.90, 1.0))
	vbox.add_child(_tooltip_label)

	var hint := Label.new()
	hint.text = "滚轮翻页　|　B / Esc 关闭"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.52, 0.56, 0.62))
	vbox.add_child(hint)

	refresh()


func refresh() -> void:
	_money_label.text = "钱币：%d" % GameState.money
	_usage_label.text = "占用：%d / %d 格" % [
		GameState.inventory.used_cell_count(), GameState.inventory.total_cell_count()]
	_page_label.text = "第 %d / %d 页（滚轮翻页）" % [_page + 1, GameState.inventory.page_count()]
	_grid_origin = _current_grid_origin()
	_rebuild_items()


## 网格左上角（面板本地坐标）：取第一个格子的实际位置，随布局动态校正。
func _current_grid_origin() -> Vector2:
	if _cells.is_empty() or not is_inside_tree():
		return Vector2.ZERO
	return _cells[0].global_position - global_position + Vector2(2, 2)


func _rebuild_items() -> void:
	for rect in _item_rects:
		rect.queue_free()
	_item_rects.clear()
	var item_layer := get_node("ItemLayer")
	var inventory := GameState.inventory
	for entry in inventory.items:
		if int(entry.get("page", -1)) != _page:
			continue
		var item := entry.get("item") as ItemData
		var cells := item.shape_cells()
		if cells.is_empty():
			continue
		var min_x := 99
		var min_y := 99
		var max_x := -99
		var max_y := -99
		for cell in cells:
			min_x = mini(min_x, cell.x)
			min_y = mini(min_y, cell.y)
			max_x = maxi(max_x, cell.x)
			max_y = maxi(max_y, cell.y)
		var origin_x := _grid_origin.x + int(entry.get("x", 0)) * PITCH
		var origin_y := _grid_origin.y + int(entry.get("y", 0)) * PITCH
		var rect := ColorRect.new()
		rect.position = Vector2(origin_x, origin_y)
		rect.size = Vector2((max_x - min_x + 1) * PITCH - 4.0, (max_y - min_y + 1) * PITCH - 4.0)
		rect.color = _item_color(item)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_layer.add_child(rect)
		var label := Label.new()
		label.text = item.item_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.92))
		rect.add_child(label)
		_item_rects.append(rect)


func _item_color(item: ItemData) -> Color:
	var palette := ITEM_COLORS
	return palette[absi(item.item_name.hash()) % palette.size()]


func _process(_delta: float) -> void:
	if not visible:
		return
	var origin := _current_grid_origin()
	if origin != _grid_origin:
		_grid_origin = origin
		_rebuild_items()
	_update_tooltip()


func _update_tooltip() -> void:
	if not visible:
		return
	var cell := _cell_at(get_global_mouse_position())
	if cell == Vector2i(-1, -1):
		_tooltip_label.text = ""
		return
	var item := GameState.inventory.item_at(_page, cell.x, cell.y)
	if item == null:
		_tooltip_label.text = ""
		return
	_tooltip_label.text = "%s　|　体积：%s　|　价值：%d\n%s" % [
		item.item_name, item.shape_label(), item.value, item.description]


func _cell_at(mouse_pos: Vector2) -> Vector2i:
	var inv := GameState.inventory
	var local := mouse_pos - global_position
	var col := int((local.x - _grid_origin.x) / PITCH)
	var row := int((local.y - _grid_origin.y) / PITCH)
	if col < 0 or row < 0 or col >= inv.cols() or row >= inv.rows():
		return Vector2i(-1, -1)
	return Vector2i(col, row)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_set_page(_page - 1)
				accept_event()
			MOUSE_BUTTON_WHEEL_DOWN:
				_set_page(_page + 1)
				accept_event()
			MOUSE_BUTTON_LEFT:
				_update_tooltip()


func _set_page(page: int) -> void:
	_page = clampi(page, 0, GameState.inventory.page_count() - 1)
	refresh()


func open() -> void:
	_page = 0
	visible = true
	refresh()


func close() -> void:
	visible = false
	closed.emit()
