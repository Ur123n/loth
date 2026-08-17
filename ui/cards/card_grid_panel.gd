class_name CardGridPanel
extends VBoxContainer

## 卡槽网格（表现层）：每排 5 个卡槽，滚轮上下翻阅，卡槽可点击。
## 技能库与卡组共用；卡组最多 20 槽，技能库暂无上限。

signal slot_pressed(slot_index: int)

const SLOT_SIZE := Vector2(88, 56)

var _slots_per_row := 5
var _rows_per_page := 5
var _max_slots := 0
var _cards: Array = []
var _page := 0

var _grid: GridContainer
var _slot_buttons: Array[Button] = []
var _page_label: Label


func setup(slots_per_row: int, rows_per_page: int, max_slots: int) -> void:
	_slots_per_row = slots_per_row
	_rows_per_page = rows_per_page
	_max_slots = max_slots
	mouse_filter = Control.MOUSE_FILTER_STOP
	for child in get_children():
		child.queue_free()
	_slot_buttons.clear()

	_grid = GridContainer.new()
	_grid.name = "Grid"
	_grid.columns = _slots_per_row
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_grid)

	for i in _slots_per_row * _rows_per_page:
		var button := _make_slot_button(i)
		_grid.add_child(button)
		_slot_buttons.append(button)

	_page_label = Label.new()
	_page_label.name = "PageLabel"
	_page_label.add_theme_font_size_override("font_size", 13)
	_page_label.add_theme_color_override("font_color", Color(0.70, 0.74, 0.80))
	_page_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_page_label)

	_refresh()


func set_cards(cards: Array) -> void:
	_cards = cards
	_page = 0
	_refresh()


func scroll_page(offset: int) -> void:
	_page += offset
	_refresh()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_page(-1)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_page(1)
			accept_event()


func _refresh() -> void:
	var page_size := _slots_per_row * _rows_per_page
	var total_slots := _cards.size()
	if _max_slots > 0:
		total_slots = maxi(total_slots, _max_slots)
	var total_pages := maxi(1, ceili(total_slots / float(page_size)))
	_page = clampi(_page, 0, total_pages - 1)

	for i in _slot_buttons.size():
		var slot_index := _page * page_size + i
		var button: Button = _slot_buttons[i]
		if _max_slots > 0 and slot_index >= _max_slots:
			button.visible = false
			continue
		button.visible = true
		if slot_index < _cards.size():
			var card = _cards[slot_index]
			button.text = _card_display_name(card)
			button.add_theme_color_override("font_color", Color(0.90, 0.93, 0.97))
		else:
			button.text = "空"
			button.add_theme_color_override("font_color", Color(0.45, 0.49, 0.57))

	_page_label.text = "第 %d / %d 页（滚轮翻阅）" % [_page + 1, total_pages]


func _on_slot_pressed(index: int) -> void:
	slot_pressed.emit(_page * (_slots_per_row * _rows_per_page) + index)


func _card_display_name(card) -> String:
	if card is CardData:
		return card.card_name
	if card is SkillData:
		return card.skill_name
	return "?"


func _make_slot_button(index: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = SLOT_SIZE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color(0.45, 0.49, 0.57))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.13, 0.16, 0.21, 0.95)
	normal.border_color = Color(0.34, 0.40, 0.50)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	button.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = Color(0.18, 0.22, 0.29, 0.98)
	hover.border_color = Color(0.55, 0.62, 0.75)
	button.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.10, 0.13, 0.17, 1.0)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", normal)

	button.pressed.connect(_on_slot_pressed.bind(index))
	return button
