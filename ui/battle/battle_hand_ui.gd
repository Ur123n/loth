class_name BattleHandUI
extends Control

## 战斗手牌界面（表现层）：屏幕底部显示当前角色手牌。
## 鼠标按住卡牌向上拖动（超过阈值）即打出；可拖到目标上方指定目标。

signal card_play_requested(card: CardData, screen_position: Vector2)

const DRAG_THRESHOLD := 90.0
const CARD_SIZE := Vector2(96, 132)
const HAND_PANEL_HEIGHT := 190.0

var _unit: BattleUnit
var _panel: PanelContainer
var _energy_label: Label
var _cards_box: HBoxContainer
var _hint_label: Label

var _drag_card: CardData = null
var _drag_start: Vector2 = Vector2.ZERO
var _ghost: Label


func _ready() -> void:
	_build_ui()
	_apply_bottom_layout()
	visible = false


## 显式把底部面板铺到视口底部（不依赖锚点，保证任何情况下都可见）。
func _apply_bottom_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0:
		viewport_size = Vector2(1280, 720)
	size = viewport_size
	_panel.position = Vector2(0, viewport_size.y - HAND_PANEL_HEIGHT)
	_panel.size = Vector2(viewport_size.x, HAND_PANEL_HEIGHT)


func is_dragging() -> bool:
	return _drag_card != null


func set_unit(unit: BattleUnit) -> void:
	_unit = unit
	visible = unit != null
	refresh()


func refresh() -> void:
	if _unit == null:
		return
	_energy_label.text = "费用：%d/%d" % [_unit.energy, BattleManager.ENERGY_PER_TURN]
	for child in _cards_box.get_children():
		child.free()
	for card in _unit.hand:
		_cards_box.add_child(_make_card_view(card))


func _input(event: InputEvent) -> void:
	if _unit == null or not visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _drag_card == null:
				_drag_card = _card_at(event.position)
				if _drag_card != null:
					_drag_start = event.position
					_show_ghost(event.position)
		else:
			if _drag_card != null:
				_hide_ghost()
				var delta: Vector2 = _drag_start - event.position
				if delta.y >= DRAG_THRESHOLD:
					card_play_requested.emit(_drag_card, event.position)
				_drag_card = null
	elif event is InputEventMouseMotion and _drag_card != null:
		_move_ghost(event.position)


func _card_at(screen_position: Vector2) -> CardData:
	for i in _unit.hand.size():
		var view := _cards_box.get_child(i)
		if view != null and view.get_global_rect().has_point(screen_position):
			return _unit.hand[i]
	return null


func _make_card_view(card: CardData) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CARD_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.19, 0.25)
	style.border_color = Color(0.45, 0.55, 0.70)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var name_label := Label.new()
	var locked := card.doom_dream and _unit.dream_progress < 2
	name_label.text = card.card_name + ("（锁定）" if locked else "")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color",
		Color(0.55, 0.60, 0.66) if locked else Color(0.95, 0.92, 0.80))
	vbox.add_child(name_label)

	var cost_label := Label.new()
	cost_label.text = "费用 %d" % card.cost
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 12)
	if card.cost > _unit.energy:
		cost_label.add_theme_color_override("font_color", Color(0.85, 0.35, 0.35))
	else:
		cost_label.add_theme_color_override("font_color", Color(0.80, 0.85, 0.95))
	vbox.add_child(cost_label)

	var keyword_labels := card.keyword_labels()
	if not keyword_labels.is_empty():
		var keyword_label := Label.new()
		keyword_label.text = "　".join(keyword_labels)
		keyword_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		keyword_label.add_theme_font_size_override("font_size", 11)
		keyword_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.45))
		vbox.add_child(keyword_label)

	var effect_label := Label.new()
	effect_label.text = CardDB.describe_card(card)
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.add_theme_font_size_override("font_size", 10)
	effect_label.add_theme_color_override("font_color", Color(0.65, 0.70, 0.78))
	effect_label.custom_minimum_size = Vector2(CARD_SIZE.x - 12, 0)
	vbox.add_child(effect_label)
	return panel


func _show_ghost(position: Vector2) -> void:
	if _drag_card == null:
		return
	_ghost.text = _drag_card.card_name
	_ghost.position = position + Vector2(12, 12)
	_ghost.visible = true


func _move_ghost(position: Vector2) -> void:
	_ghost.position = position + Vector2(12, 12)


func _hide_ghost() -> void:
	_ghost.visible = false


func _build_ui() -> void:
	name = "BattleHandUI"
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_panel = PanelContainer.new()
	_panel.name = "HandPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.07, 0.10, 0.96)
	panel_style.border_color = Color(0.35, 0.42, 0.55)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 16.0
	panel_style.content_margin_right = 16.0
	panel_style.content_margin_top = 10.0
	panel_style.content_margin_bottom = 10.0
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	var top_row := HBoxContainer.new()
	vbox.add_child(top_row)
	_energy_label = Label.new()
	_energy_label.add_theme_font_size_override("font_size", 15)
	_energy_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	top_row.add_child(_energy_label)
	_hint_label = Label.new()
	_hint_label.text = "　按住卡牌向上拖动打出；点击高亮格移动；点击“结束回合”结束行动"
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.add_theme_color_override("font_color", Color(0.60, 0.64, 0.72))
	top_row.add_child(_hint_label)

	_cards_box = HBoxContainer.new()
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_box.add_theme_constant_override("separation", 10)
	vbox.add_child(_cards_box)

	_ghost = Label.new()
	_ghost.add_theme_font_size_override("font_size", 16)
	_ghost.add_theme_color_override("font_color", Color(1.0, 0.95, 0.70))
	_ghost.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_ghost.add_theme_constant_override("outline_size", 6)
	_ghost.visible = false
	add_child(_ghost)
