class_name CharacterPanel
extends Control

## 角色面板（UI 表现层）。
## 主视图显示 姓名 / 道途 / 等级 / 属性，并可点击打开：
## 装备栏（8 个部位）、技能库（每排 5 槽，滚轮翻阅）、卡组（20 槽，每排 5 槽，滚轮翻阅）。
## 卡组交互：空卡槽点击 → 跳转技能库选牌加入牌组；
## 已加入的卡点击 → 详情 + 移出牌组；技能库点击 → 详情。
## 属性加点：升级获得自由属性点，主视图属性行带 + 按钮，显示剩余可分配点数。
## 牌组/技能数据一旦变化会发出 data_changed，供外部即时存档。

signal data_changed

const PANEL_SIZE := Vector2(540, 640)
const DECK_CAPACITY := 20

var _data: CharacterData

var _main_view: VBoxContainer
var _equipment_view: VBoxContainer
var _skill_view: VBoxContainer
var _deck_view: VBoxContainer

var _equipment_panel: EquipmentPanel
var _skill_grid: CardGridPanel
var _deck_grid: CardGridPanel
var _detail_popup: CardDetailPopup

var _skill_hint_label: Label
var _deck_pick_mode: bool = false
var _detail_action: Callable = Callable()

var _name_value: Label
var _path_value: Label
var _level_value: Label
var _strength_value: Label
var _agility_value: Label
var _endurance_value: Label
var _willpower_value: Label
var _hp_value: Label
var _load_capacity_value: Label
var _attribute_points_label: Label
var _alloc_buttons: Dictionary = {}   # 属性名 -> Button

var _skill_button: Button
var _equipment_button: Button
var _deck_button: Button


func _ready() -> void:
	_build_ui()
	show_main_view()
	visible = false


func setup(data: CharacterData) -> void:
	_data = data
	refresh()


func refresh() -> void:
	if _data == null:
		return
	_name_value.text = _data.character_name
	_path_value.text = _data.get_path_display()
	_level_value.text = str(_data.level)
	# 装备合并后属性（基础 + 得/舍），有修正时显示差值
	_strength_value.text = _stat_text(_data.strength, _data.get_effective_strength())
	_agility_value.text = _stat_text(_data.agility, _data.get_effective_agility())
	_endurance_value.text = _stat_text(_data.endurance, _data.get_effective_endurance())
	_willpower_value.text = _stat_text(_data.willpower, _data.get_effective_willpower())
	var base_max_hp := _data.base_hp + _data.endurance * _data.endurance_hp_bonus
	_hp_value.text = _stat_text(base_max_hp, _data.get_max_hp())
	_load_capacity_value.text = "%d（意志力派生）" % _data.get_effective_load_capacity()
	_attribute_points_label.text = "剩余可分配属性点：%d" % _data.attribute_points
	var has_points := _data.attribute_points > 0
	for stat in _alloc_buttons:
		(_alloc_buttons[stat] as Button).disabled = not has_points
	_skill_button.text = "技能库　（%d）" % _data.skill_library.size()
	_equipment_button.text = "装备　（%d/8）" % _data.equipment.size()
	_deck_button.text = "卡组　（%d/%d）" % [_data.deck.size(), DECK_CAPACITY]
	_equipment_panel.refresh(_data)
	_skill_grid.set_cards(_data.skill_library)
	_deck_grid.set_cards(_data.deck)
	_deck_pick_mode = false
	_skill_hint_label.text = "点击技能查看详情"


func show_main_view() -> void:
	_deck_pick_mode = false
	_main_view.visible = true
	_equipment_view.visible = false
	_skill_view.visible = false
	_deck_view.visible = false


## 在子视图中按 Esc：优先关弹窗 → 退出选牌模式 → 返回主视图。
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if _detail_popup.visible:
			_detail_popup.hide_info()
			_detail_action = Callable()
		elif _deck_pick_mode and _skill_view.visible:
			_deck_pick_mode = false
			_open_view(_deck_view)
		elif not _main_view.visible:
			show_main_view()


func _open_view(view: VBoxContainer) -> void:
	_main_view.visible = false
	_equipment_view.visible = false
	_skill_view.visible = false
	_deck_view.visible = false
	view.visible = true


func _build_ui() -> void:
	name = "CharacterPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
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
	panel.custom_minimum_size = PANEL_SIZE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.10, 0.14, 0.98)
	panel_style.border_color = Color(0.42, 0.62, 0.92)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.content_margin_left = 30.0
	panel_style.content_margin_right = 30.0
	panel_style.content_margin_top = 22.0
	panel_style.content_margin_bottom = 22.0
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.name = "Root"
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	_main_view = _build_main_view()
	root.add_child(_main_view)
	_equipment_view = _build_equipment_view()
	root.add_child(_equipment_view)
	_skill_view = _build_skill_view()
	root.add_child(_skill_view)
	_deck_view = _build_deck_view()
	root.add_child(_deck_view)

	_detail_popup = CardDetailPopup.new()
	_detail_popup.name = "CardDetailPopup"
	add_child(_detail_popup)
	_detail_popup.action_pressed.connect(_on_detail_action_pressed)


func _build_main_view() -> VBoxContainer:
	var view := VBoxContainer.new()
	view.name = "MainView"
	view.add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = "角色信息"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	view.add_child(title)
	view.add_child(HSeparator.new())

	var info_grid := GridContainer.new()
	info_grid.columns = 2
	info_grid.add_theme_constant_override("h_separation", 24)
	info_grid.add_theme_constant_override("v_separation", 6)
	_name_value = _add_row(info_grid, "姓名")
	_path_value = _add_row(info_grid, "道途")
	_level_value = _add_row(info_grid, "等级")
	view.add_child(info_grid)

	view.add_child(_make_section_title("属性"))
	var stat_rows := VBoxContainer.new()
	stat_rows.name = "StatRows"
	stat_rows.add_theme_constant_override("separation", 4)
	_strength_value = _add_stat_row(stat_rows, "力量")
	_agility_value = _add_stat_row(stat_rows, "敏捷")
	_endurance_value = _add_stat_row(stat_rows, "耐力")
	_willpower_value = _add_stat_row(stat_rows, "意志力")
	view.add_child(stat_rows)

	_attribute_points_label = Label.new()
	_attribute_points_label.name = "AttributePoints"
	_attribute_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_attribute_points_label.add_theme_font_size_override("font_size", 15)
	_attribute_points_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.30))
	view.add_child(_attribute_points_label)

	var hp_grid := GridContainer.new()
	hp_grid.columns = 2
	hp_grid.add_theme_constant_override("h_separation", 24)
	hp_grid.add_theme_constant_override("v_separation", 6)
	_hp_value = _add_row(hp_grid, "生命值")
	_load_capacity_value = _add_row(hp_grid, "荷载容量")
	view.add_child(hp_grid)

	_skill_button = _make_section_button("技能库", _on_skill_button_pressed)
	view.add_child(_skill_button)
	_equipment_button = _make_section_button("装备", _on_equipment_button_pressed)
	view.add_child(_equipment_button)
	_deck_button = _make_section_button("卡组", _on_deck_button_pressed)
	view.add_child(_deck_button)

	var hint := Label.new()
	hint.text = "属性行 + 分配自由属性点　|　点击 技能库 / 装备 / 卡组 打开详细界面　|　Tab 关闭"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.62, 0.66, 0.72))
	hint.add_theme_font_size_override("font_size", 13)
	view.add_child(hint)
	return view


func _build_equipment_view() -> VBoxContainer:
	var view := VBoxContainer.new()
	view.name = "EquipmentView"
	view.add_theme_constant_override("separation", 10)
	view.add_child(_make_view_title("装备栏"))
	var hint := Label.new()
	hint.text = "点击已穿装备卸下（放回背包）　|　打开背包（B）点击装备穿上"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.62, 0.66, 0.72))
	view.add_child(hint)
	_equipment_panel = EquipmentPanel.new()
	_equipment_panel.name = "EquipmentGrid"
	_equipment_panel.slot_pressed.connect(_on_equipment_slot_pressed)
	view.add_child(_equipment_panel)
	view.add_child(_make_back_button())
	return view


func _build_skill_view() -> VBoxContainer:
	var view := VBoxContainer.new()
	view.name = "SkillView"
	view.add_theme_constant_override("separation", 10)
	view.add_child(_make_view_title("技能库"))
	_skill_hint_label = Label.new()
	_skill_hint_label.add_theme_font_size_override("font_size", 13)
	_skill_hint_label.add_theme_color_override("font_color", Color(0.62, 0.66, 0.72))
	view.add_child(_skill_hint_label)
	_skill_grid = CardGridPanel.new()
	_skill_grid.name = "SkillGrid"
	_skill_grid.setup(5, 5, 0)
	_skill_grid.slot_pressed.connect(_on_skill_slot_pressed)
	view.add_child(_skill_grid)
	view.add_child(_make_back_button())
	return view


func _build_deck_view() -> VBoxContainer:
	var view := VBoxContainer.new()
	view.name = "DeckView"
	view.add_theme_constant_override("separation", 10)
	view.add_child(_make_view_title("卡组（%d 槽）" % DECK_CAPACITY))
	var hint := Label.new()
	hint.text = "点击空卡槽从技能库选牌加入牌组；点击已加入的卡查看详情/移出"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.62, 0.66, 0.72))
	view.add_child(hint)
	_deck_grid = CardGridPanel.new()
	_deck_grid.name = "DeckGrid"
	_deck_grid.setup(5, 3, DECK_CAPACITY)
	_deck_grid.slot_pressed.connect(_on_deck_slot_pressed)
	view.add_child(_deck_grid)
	view.add_child(_make_back_button())
	return view


func _on_skill_button_pressed() -> void:
	_deck_pick_mode = false
	_skill_hint_label.text = "点击技能查看详情"
	_open_view(_skill_view)


func _on_equipment_button_pressed() -> void:
	_equipment_panel.refresh(_data)
	_open_view(_equipment_view)


## 点击装备槽位：有装备则卸下并放回背包；空槽提示从背包穿戴。
func _on_equipment_slot_pressed(slot_name: String) -> void:
	if _data == null:
		return
	var equipped := _data.get_equipped_in_slot(slot_name)
	if equipped == null:
		_detail_popup.show_info("装备", ["该槽位为空。", "打开背包（B），点击对应装备穿到当前角色。"])
		return
	var removed := _data.unequip_slot(slot_name)
	if removed == null:
		return
	var item := _item_by_name(removed.equipment_name)
	if item != null:
		var spot := GameState.inventory.find_free_spot(item)
		if not spot.get("found", false):
			# 背包已满：取消卸下，装备还原
			_data.equip_equipment(removed)
			_detail_popup.show_info("提示", ["背包已满，无法卸下「%s」" % removed.equipment_name])
			return
		GameState.inventory.place(item, spot.page, spot.x, spot.y)
	refresh()
	data_changed.emit()
	_detail_popup.show_info("已卸下", ["「%s」已放回背包。" % removed.equipment_name])


## 按名称查物品（卸下装备时放回背包用）。
func _item_by_name(item_name: String) -> ItemData:
	var db := get_node_or_null("/root/ItemDB")
	return db.get_item(item_name) if db != null else null


## 属性显示：合并后数值，有修正时附（+N/-N）。
func _stat_text(base: int, effective: int) -> String:
	if effective != base:
		return "%d（%+d）" % [effective, effective - base]
	return str(effective)


func _on_deck_button_pressed() -> void:
	_deck_pick_mode = false
	_open_view(_deck_view)


## 卡组卡槽点击：空槽进入选牌模式；有卡显示详情 + 移出。
func _on_deck_slot_pressed(slot_index: int) -> void:
	if _data == null:
		return
	if slot_index < _data.deck.size():
		_show_card_detail(_data.deck[slot_index])
	else:
		_start_deck_pick()


## 技能库卡槽点击：选牌模式下加入牌组；普通模式显示详情。
func _on_skill_slot_pressed(slot_index: int) -> void:
	if _data == null or slot_index >= _data.skill_library.size():
		return
	var skill := _data.skill_library[slot_index]
	if _deck_pick_mode:
		if _add_skill_to_deck(skill):
			_deck_pick_mode = false
			_open_view(_deck_view)
	else:
		_show_skill_detail(skill)


func _start_deck_pick() -> void:
	if _data.skill_library.is_empty():
		_detail_popup.show_info("提示", ["技能库为空，暂无技能可加入牌组"])
		return
	_deck_pick_mode = true
	_skill_hint_label.text = "点击技能加入牌组（Esc 返回卡组）"
	_open_view(_skill_view)


func _add_skill_to_deck(skill: SkillData) -> bool:
	if _data.deck.size() >= DECK_CAPACITY:
		_detail_popup.show_info("提示", ["牌组已满（%d 张）" % DECK_CAPACITY])
		return false
	var card := _skill_to_card(skill)
	for existing in _data.deck:
		if existing.card_name == card.card_name:
			_detail_popup.show_info("提示", ["「%s」已在牌组中" % card.card_name])
			return false
	_data.deck.append(card)
	refresh()
	data_changed.emit()   # 牌组变化 → 通知外部即时存档
	return true


func _remove_card_from_deck(card_name: String) -> void:
	for i in _data.deck.size():
		if _data.deck[i].card_name == card_name:
			_data.deck.remove_at(i)
			break
	refresh()
	data_changed.emit()   # 牌组变化 → 通知外部即时存档


func _skill_to_card(skill: SkillData) -> CardData:
	var card := CardDB.get_card(skill.skill_name)
	if card != null:
		return card
	var fallback := CardData.new()
	fallback.card_name = skill.skill_name
	fallback.description = skill.description
	return fallback


func _show_card_detail(card: CardData) -> void:
	_detail_action = func():
		_remove_card_from_deck(card.card_name)
	_detail_popup.show_info(card.card_name, _card_info_lines(card), "移出牌组")


func _show_skill_detail(skill: SkillData) -> void:
	_detail_action = Callable()
	_detail_popup.show_info(skill.skill_name, _skill_info_lines(skill))


func _on_detail_action_pressed() -> void:
	if _detail_action.is_valid():
		_detail_action.call()
	_detail_action = Callable()
	_detail_popup.hide_info()


func _card_info_lines(card: CardData) -> Array[String]:
	var lines: Array[String] = [
		"类型：%s" % _card_type_label(card.card_type),
		"分类：%s" % ("道途专属（%s）" % card.path_name if card.category == CardData.CardCategory.PATH else "通用卡牌"),
		"费用：%d　　荷载：%d" % [card.cost, card.load],
		"目标类型：%s　　范围：%d　　区域：%d" % [_target_label(card.target_type), card.range, card.area],
	]
	if card.is_consumed_on_play():
		lines.append("特性：能力牌打出后自动消失")
	var desc := CardDB.describe_card(card)
	lines.append("效果：%s" % (desc if not desc.is_empty() else "无"))
	if not card.description.is_empty():
		lines.append("说明：%s" % card.description)
	return lines


func _skill_info_lines(skill: SkillData) -> Array[String]:
	var lines: Array[String] = ["技能：%s" % skill.skill_name]
	if not skill.description.is_empty():
		lines.append("描述：%s" % skill.description)
	var card := CardDB.get_card(skill.skill_name)
	if card != null:
		lines.append("")
		lines.append("—— 对应卡牌信息 ——")
		lines.append_array(_card_info_lines(card))
	return lines


func _card_type_label(card_type: CardData.CardType) -> String:
	match card_type:
		CardData.CardType.ACTION:
			return "行动"
		CardData.CardType.ABILITY:
			return "能力"
	return "攻击"


func _target_label(target_type: CardData.TargetType) -> String:
	match target_type:
		CardData.TargetType.SELF:
			return "Self"
		CardData.TargetType.ALLY:
			return "Ally"
		CardData.TargetType.ENEMY:
			return "Enemy"
		CardData.TargetType.HEX:
			return "Hex"
		CardData.TargetType.AREA:
			return "Area"
	return "None"


func _make_view_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.90, 0.92, 0.96))
	return label


func _make_section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
	return label


func _make_section_button(text: String, callable: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 38)
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(callable)
	return button


func _make_back_button() -> Button:
	var button := Button.new()
	button.text = "返回"
	button.custom_minimum_size = Vector2(0, 36)
	button.pressed.connect(show_main_view)
	return button


## 属性行：名称 + 数值 + 加点按钮（无剩余点数时禁用）。
func _add_stat_row(rows: VBoxContainer, stat_key: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var key := Label.new()
	key.text = stat_key
	key.custom_minimum_size = Vector2(70, 0)
	key.add_theme_font_size_override("font_size", 15)
	key.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82))
	row.add_child(key)
	var value := _make_value_label()
	value.custom_minimum_size = Vector2(150, 0)
	row.add_child(value)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(36, 30)
	plus.tooltip_text = "消耗 1 点属性点提升%s" % stat_key
	plus.pressed.connect(_on_allocate_pressed.bind(stat_key))
	row.add_child(plus)
	rows.add_child(row)
	_alloc_buttons[stat_key] = plus
	return value


## 加点：消耗 1 点自由属性点，属性 +1，并通知外部存档。
func _on_allocate_pressed(stat: String) -> void:
	if _data == null:
		return
	if _data.allocate_attribute(stat):
		refresh()
		data_changed.emit()


func _make_value_label() -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 15)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(380, 0)
	return label


func _add_row(grid: GridContainer, key: String) -> Label:
	var key_label := Label.new()
	key_label.text = key
	key_label.add_theme_font_size_override("font_size", 15)
	key_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82))
	var value := _make_value_label()
	grid.add_child(key_label)
	grid.add_child(value)
	return value
