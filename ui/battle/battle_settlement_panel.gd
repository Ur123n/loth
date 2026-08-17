class_name BattleSettlementPanel
extends Control

## 战斗结算界面（居中横置长方形，短边在下）。
## 第一页（战利品页）：上方钱币、下方战利品（悬停看信息，点击拾取并检测背包空位）+ 下一步；
## 第二页（经验页）：四名角色头像槽/经验条/升级提示 + 上一页 / 结束战斗。

signal settled

const PANEL_SIZE := Vector2(860, 540)
const LOOT_COLORS: Array[Color] = [
	Color(0.72, 0.62, 0.42), Color(0.55, 0.70, 0.58), Color(0.58, 0.63, 0.78),
	Color(0.75, 0.55, 0.62), Color(0.62, 0.72, 0.72), Color(0.80, 0.72, 0.50),
]

var _coins: int = 0
var _loot: Array = []                # Array[ItemData]
var _before_levels: Array[int] = []
var _picked: Dictionary = {}         # index -> true（已拾取）
var _loot_slots: Array[Button] = []
var _feedback_label: Label
var _tooltip_label: Label
var _page_1: Control
var _page_2: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "CenterPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_left = -PANEL_SIZE.x * 0.5
	panel.offset_top = -PANEL_SIZE.y * 0.5
	panel.offset_right = PANEL_SIZE.x * 0.5
	panel.offset_bottom = PANEL_SIZE.y * 0.5
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.10, 0.13, 0.98)
	style.border_color = Color(0.42, 0.46, 0.52)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "Layout"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	_page_1 = _build_loot_page(vbox)
	_page_2 = _build_exp_page(vbox)
	_page_1.visible = true
	_page_2.visible = false


func setup(coins: int, loot: Array, before_levels: Array[int]) -> void:
	_coins = coins
	_loot = loot
	_before_levels = before_levels
	_picked.clear()
	_rebuild_loot_page()
	_rebuild_exp_page()
	_show_page(1)


func _build_loot_page(parent: Control) -> Control:
	var page := VBoxContainer.new()
	page.name = "LootPage"
	page.add_theme_constant_override("separation", 10)
	parent.add_child(page)

	var title := Label.new()
	title.text = "战 斗 结 算"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.95, 0.86, 0.58))
	page.add_child(title)

	var coins_label := Label.new()
	coins_label.name = "CoinsLabel"
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coins_label.add_theme_font_size_override("font_size", 20)
	coins_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.30))
	page.add_child(coins_label)

	var loot_title := Label.new()
	loot_title.text = "可拾取战利品（悬停查看信息，点击拾取）"
	loot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loot_title.add_theme_font_size_override("font_size", 15)
	loot_title.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
	page.add_child(loot_title)

	var loot_box := PanelContainer.new()
	loot_box.name = "LootBox"
	var loot_style := StyleBoxFlat.new()
	loot_style.bg_color = Color(0.13, 0.15, 0.19, 0.9)
	loot_style.set_corner_radius_all(6)
	loot_box.add_theme_stylebox_override("panel", loot_style)
	page.add_child(loot_box)

	var loot_grid := GridContainer.new()
	loot_grid.name = "LootGrid"
	loot_grid.columns = 4
	loot_grid.add_theme_constant_override("h_separation", 10)
	loot_grid.add_theme_constant_override("v_separation", 10)
	loot_box.add_child(loot_grid)

	_tooltip_label = Label.new()
	_tooltip_label.name = "Tooltip"
	_tooltip_label.visible = false
	_tooltip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tooltip_label.add_theme_font_size_override("font_size", 13)
	_tooltip_label.add_theme_color_override("font_color", Color(0.72, 0.90, 1.0))
	page.add_child(_tooltip_label)

	_feedback_label = Label.new()
	_feedback_label.name = "Feedback"
	_feedback_label.visible = false
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 14)
	_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	page.add_child(_feedback_label)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	page.add_child(bottom)
	var next_button := Button.new()
	next_button.text = "下一步"
	next_button.custom_minimum_size = Vector2(140, 40)
	next_button.add_theme_font_size_override("font_size", 16)
	next_button.pressed.connect(_on_next_pressed)
	bottom.add_child(next_button)
	return page


func _build_exp_page(parent: Control) -> Control:
	var page := VBoxContainer.new()
	page.name = "ExpPage"
	page.add_theme_constant_override("separation", 12)
	parent.add_child(page)

	var title := Label.new()
	title.text = "战斗奖励——经验"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.95, 0.86, 0.58))
	page.add_child(title)

	var hint := Label.new()
	hint.text = "全队共享本次战斗经验，经验条满即升级（获得 1 点自由属性点，可在角色面板分配）"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.62, 0.68, 0.76))
	page.add_child(hint)

	var rows_box := VBoxContainer.new()
	rows_box.name = "ExpRows"
	rows_box.add_theme_constant_override("separation", 12)
	page.add_child(rows_box)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 24)
	page.add_child(bottom)
	var prev_button := Button.new()
	prev_button.text = "上一页"
	prev_button.custom_minimum_size = Vector2(140, 40)
	prev_button.add_theme_font_size_override("font_size", 16)
	prev_button.pressed.connect(_on_prev_pressed)
	bottom.add_child(prev_button)
	var finish_button := Button.new()
	finish_button.text = "结束战斗"
	finish_button.custom_minimum_size = Vector2(140, 40)
	finish_button.add_theme_font_size_override("font_size", 16)
	finish_button.pressed.connect(_on_finish_pressed)
	bottom.add_child(finish_button)
	return page


## 第一页：钱币 + 战利品槽。
func _rebuild_loot_page() -> void:
	var coins_label := _page_1.get_node("CoinsLabel") as Label
	coins_label.text = "获得钱币：+%d" % _coins

	var grid := _page_1.get_node("LootBox/LootGrid") as GridContainer
	for child in grid.get_children():
		child.queue_free()
	_loot_slots.clear()
	for i in _loot.size():
		var item := _loot[i] as ItemData
		var button := Button.new()
		button.custom_minimum_size = Vector2(178, 72)
		button.text = "%s\n%s" % [item.item_name, item.shape_label()]
		button.add_theme_font_size_override("font_size", 13)
		button.mouse_entered.connect(_on_loot_hover.bind(i))
		button.mouse_exited.connect(_on_loot_unhover)
		button.pressed.connect(_on_loot_pressed.bind(i))
		grid.add_child(button)
		_loot_slots.append(button)
	_feedback_label.visible = false
	_tooltip_label.visible = false


func _on_loot_hover(index: int) -> void:
	if index < 0 or index >= _loot.size():
		return
	var item := _loot[index] as ItemData
	_tooltip_label.text = "%s　|　体积：%s　|　价值：%d\n%s" % [
		item.item_name, item.shape_label(), item.value, item.description]
	_tooltip_label.visible = true


func _on_loot_unhover() -> void:
	_tooltip_label.visible = false


func _on_loot_pressed(index: int) -> void:
	if _picked.has(index):
		return
	var item := _loot[index] as ItemData
	var spot := GameState.inventory.find_free_spot(item)
	if not spot.get("found", false):
		_feedback_label.text = "背包已满，无法拾取「%s」（需要 %s）" % [item.item_name, item.shape_label()]
		_feedback_label.visible = true
		return
	GameState.inventory.place(item, int(spot.get("page", 0)), int(spot.get("x", 0)), int(spot.get("y", 0)))
	GameState.save_game()
	_picked[index] = true
	var button := _loot_slots[index]
	button.disabled = true
	button.text = "✓ 已拾取\n%s" % item.item_name
	_feedback_label.text = "已拾取「%s」（第 %d 页）" % [item.item_name, int(spot.get("page", 0)) + 1]
	_feedback_label.visible = true


## 第二页：四名角色头像槽（美术占位）+ 经验条 + 升级提示。
func _rebuild_exp_page() -> void:
	var rows_box := _page_2.get_node("ExpRows") as VBoxContainer
	for child in rows_box.get_children():
		child.queue_free()
	var party: Array = GameState.party_characters
	for i in party.size():
		var character := party[i] as CharacterData
		if character == null:
			continue
		rows_box.add_child(_build_exp_row(character, i))


func _build_exp_row(character: CharacterData, index: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	# 头像槽（美术资源槽位：portrait_path 有图则显示，否则色块占位）
	var avatar := PanelContainer.new()
	avatar.custom_minimum_size = Vector2(64, 64)
	var avatar_style := StyleBoxFlat.new()
	avatar_style.bg_color = character.block_color.darkened(0.25)
	avatar_style.border_color = Color(0.85, 0.87, 0.90)
	avatar_style.set_border_width_all(1)
	avatar_style.set_corner_radius_all(8)
	avatar.add_theme_stylebox_override("panel", avatar_style)
	var avatar_texture := ArtLoader.load_texture(character.portrait_path)
	if avatar_texture != null:
		var tex_rect := TextureRect.new()
		tex_rect.texture = avatar_texture
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		avatar.add_child(tex_rect)
	else:
		var placeholder := Label.new()
		placeholder.text = "立绘槽\n%s" % character.character_name
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.add_theme_font_size_override("font_size", 12)
		placeholder.add_theme_color_override("font_color", Color(0.92, 0.94, 0.97))
		avatar.add_child(placeholder)
	row.add_child(avatar)

	# 名称 + 等级
	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(150, 0)
	var name_label := Label.new()
	name_label.text = "%s　Lv.%d" % [character.character_name, character.level]
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.97))
	info.add_child(name_label)
	var leveled_up := not _before_levels.is_empty() \
		and index < _before_levels.size() and character.level > _before_levels[index]
	var level_hint := Label.new()
	level_hint.text = "升级！获得 1 点属性点" if leveled_up else "经验进度"
	level_hint.add_theme_font_size_override("font_size", 12)
	level_hint.add_theme_color_override("font_color",
		Color(1.0, 0.82, 0.30) if leveled_up else Color(0.62, 0.68, 0.76))
	info.add_child(level_hint)
	row.add_child(info)

	# 经验条
	var need := character.exp_to_next_level()
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(330, 26)
	bar.min_value = 0
	bar.max_value = maxf(need, 1.0)
	bar.value = clampf(character.exp, 0, need)
	bar.show_percentage = false
	var bar_label := Label.new()
	bar_label.text = "%d / %d" % [character.exp, need]
	bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar_label.add_theme_font_size_override("font_size", 12)
	bar.add_child(bar_label)
	bar_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_child(bar)
	return row


func _show_page(page: int) -> void:
	_page_1.visible = page == 1
	_page_2.visible = page == 2


func _on_next_pressed() -> void:
	_show_page(2)


func _on_prev_pressed() -> void:
	_show_page(1)


func _on_finish_pressed() -> void:
	settled.emit()
