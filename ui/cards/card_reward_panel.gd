class_name CardRewardPanel
extends Control

## 卡牌奖励面板（Demo 专用）。
## 战斗结算后按“每名角色独立掉落”顺序展示：每名角色给出 3 张随机卡牌
## （通用库 + 该角色道途专属卡），玩家三选一加入技能库，或跳过。

signal finished

const PANEL_SIZE := Vector2(940, 560)

var _queue: Array = []               # [{character: CharacterData, offers: Array[CardData]}]
var _current_character: CharacterData
var _current_offers: Array = []
var _offer_buttons: Array[Button] = []
var _offer_cards: Array[Control] = []
var _title_label: Label
var _hint_label: Label
var _status_label: Label
var _skip_button: Button
var _continue_button: Button


func _ready() -> void:
	_build_ui()
	visible = false


func setup(rewards: Array) -> void:
	_queue = rewards.duplicate()
	visible = true
	_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		finished.emit()
		return
	var entry: Dictionary = _queue.pop_front()
	_current_character = entry.get("character") as CharacterData
	_current_offers = entry.get("offers", [])
	if _current_character == null or _current_offers.is_empty():
		_show_next()
		return
	_title_label.text = "卡牌奖励 —— 为「%s」选择一张卡牌" % _current_character.character_name
	_hint_label.text = "从通用库与该角色道途卡中随机三选一，加入技能库；跳过则不获得"
	_status_label.visible = false
	_skip_button.disabled = false
	_continue_button.visible = false
	for i in _offer_buttons.size():
		var button: Button = _offer_buttons[i]
		var card_control: Control = _offer_cards[i]
		if i < _current_offers.size():
			card_control.visible = true
			button.disabled = false
			_refresh_card(i, _current_offers[i] as CardData)
		else:
			card_control.visible = false


func _refresh_card(index: int, card: CardData) -> void:
	var container: PanelContainer = _offer_cards[index]
	var vbox := container.get_node("VBox") as VBoxContainer
	var name_label := vbox.get_node("Name") as Label
	var desc_label := vbox.get_node("Desc") as Label
	var learned := _skill_has(_current_character, card.card_name)
	name_label.text = "%s　费用 %d%s" % [
		card.card_name, card.cost, "　（已掌握）" if learned else ""]
	name_label.add_theme_color_override("font_color",
		Color(0.85, 0.92, 1.0) if not learned else Color(0.60, 0.66, 0.58))
	desc_label.text = CardDB.describe_card(card)


func _on_offer_pressed(index: int) -> void:
	if _current_character == null or index >= _current_offers.size():
		return
	var card := _current_offers[index] as CardData
	if not _skill_has(_current_character, card.card_name):
		var skill := SkillData.new()
		skill.skill_name = card.card_name
		skill.description = CardDB.describe_card(card)
		_current_character.skill_library.append(skill)
	GameState.save_game()
	_status_label.text = "已将「%s」加入技能库" % card.card_name
	_status_label.visible = true
	_lock_choice()


func _on_skip_pressed() -> void:
	_status_label.text = "已跳过（不获得卡牌）"
	_status_label.visible = true
	_lock_choice()


func _lock_choice() -> void:
	_skip_button.disabled = true
	for button in _offer_buttons:
		button.disabled = true
	_continue_button.visible = true


func _on_continue_pressed() -> void:
	_show_next()


func _skill_has(character: CharacterData, skill_name: String) -> bool:
	for skill in character.skill_library:
		if skill.skill_name == skill_name:
			return true
	return false


func _build_ui() -> void:
	name = "CardRewardPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_left = -PANEL_SIZE.x * 0.5
	panel.offset_top = -PANEL_SIZE.y * 0.5
	panel.offset_right = PANEL_SIZE.x * 0.5
	panel.offset_bottom = PANEL_SIZE.y * 0.5
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.10, 0.13, 0.98)
	style.border_color = Color(0.48, 0.52, 0.60)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.86, 0.58))
	vbox.add_child(_title_label)

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.add_theme_color_override("font_color", Color(0.62, 0.68, 0.76))
	vbox.add_child(_hint_label)

	var offers := HBoxContainer.new()
	offers.alignment = BoxContainer.ALIGNMENT_CENTER
	offers.add_theme_constant_override("separation", 16)
	vbox.add_child(offers)

	for i in 3:
		var card_control := _make_offer_card(i)
		offers.add_child(card_control)
		_offer_cards.append(card_control)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.add_theme_color_override("font_color", Color(0.72, 0.90, 1.0))
	vbox.add_child(_status_label)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 24)
	vbox.add_child(bottom)

	_skip_button = Button.new()
	_skip_button.text = "跳过"
	_skip_button.custom_minimum_size = Vector2(140, 40)
	_skip_button.add_theme_font_size_override("font_size", 15)
	_skip_button.pressed.connect(_on_skip_pressed)
	bottom.add_child(_skip_button)

	_continue_button = Button.new()
	_continue_button.text = "继续"
	_continue_button.custom_minimum_size = Vector2(140, 40)
	_continue_button.add_theme_font_size_override("font_size", 15)
	_continue_button.pressed.connect(_on_continue_pressed)
	bottom.add_child(_continue_button)


func _make_offer_card(index: int) -> PanelContainer:
	var container := PanelContainer.new()
	container.custom_minimum_size = Vector2(270, 190)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.16, 0.21, 0.95)
	style.border_color = Color(0.42, 0.50, 0.62)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	container.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 8)
	container.add_child(vbox)

	var name_label := Label.new()
	name_label.name = "Name"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.name = "Desc"
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.86))
	desc_label.custom_minimum_size = Vector2(240, 120)
	vbox.add_child(desc_label)

	var overlay := Button.new()
	overlay.flat = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.pressed.connect(_on_offer_pressed.bind(index))
	container.add_child(overlay)
	_offer_buttons.append(overlay)
	return container
