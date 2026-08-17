extends Node2D

## 主场景（大世界）：四向移动、↑/↓ 切换角色、Tab 角色面板、
## 战斗触发点、技能光点（靠近后询问是否将“冲锋”加入当前角色技能库）。
## B 键打开背包（非战斗地图）；背包打开时暂停移动与事件触发。
## 启动时读取存档并为角色卡组补足基础牌（5 打击 + 5 防御）；
## 面板数据变化（加入/移出牌组等）即时写入存档。

@export var party_characters: Array = []
@export var battle_trigger_position: Vector2 = Vector2(1040, 500)
@export var battle_trigger_radius: float = 56.0
@export var skill_light_radius: float = 56.0
@export var skill_light_decline_cooldown: float = 2.0

var _party: PartyManager
var _character: Character
var _panel: CharacterPanel
var _party_bar: PartyBar
var _prompt: SkillPrompt
var _skill_light: SkillLight
var _inventory_panel: InventoryPanel
var _prompt_open: bool = false
var _skill_light_cooldown_active: bool = false
var _skill_light_cooldown_timer: Timer


func _ready() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.10, 0.12, 0.16)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	GameState.setup_party(party_characters)
	GameState.load_game()                 # 恢复上次操作结果
	GameState.apply_path_system()         # 道途系统：path_name + 专属初始牌进技能库/卡组
	GameState.ensure_basic_deck_cards()   # 卡组补齐：基础牌补齐到 20 张

	_party = PartyManager.new()
	_party.character_selected.connect(_on_party_character_selected)
	_party.setup(party_characters)

	# 地图上只有一个实体：被选中的角色代表整个队伍
	_character = Character.new()
	_character.name = "PartyEntity"
	_character.character_data = _party.get_current_character()
	_character.position = GameState.overworld_position
	add_child(_character)

	_panel = CharacterPanel.new()
	add_child(_panel)
	_panel.setup(_party.get_current_character())
	_panel.visible = false
	_panel.data_changed.connect(_on_panel_data_changed)   # 面板数据变化 → 即时存档

	_party_bar = PartyBar.new()
	add_child(_party_bar)
	_party_bar.setup(_party.characters)

	_prompt = SkillPrompt.new()
	add_child(_prompt)
	_prompt.confirmed.connect(_on_prompt_confirmed)
	_prompt.declined.connect(_on_prompt_declined)
	_prompt.visible = false

	_inventory_panel = InventoryPanel.new()
	add_child(_inventory_panel)
	_inventory_panel.visible = false
	_inventory_panel.closed.connect(_on_inventory_closed)
	_inventory_panel.equip_requested.connect(_on_equip_requested)

	# 选择“否”后的触发冷却：2 秒内不再弹出提示，避免反复卡住
	_skill_light_cooldown_timer = Timer.new()
	_skill_light_cooldown_timer.name = "SkillLightCooldown"
	_skill_light_cooldown_timer.one_shot = true
	_skill_light_cooldown_timer.wait_time = skill_light_decline_cooldown
	_skill_light_cooldown_timer.timeout.connect(_on_skill_light_cooldown_timeout)
	add_child(_skill_light_cooldown_timer)

	_build_battle_trigger()
	_build_skill_light()

	var hint := Label.new()
	hint.name = "ControlHint"
	hint.text = "WASD 移动　|　↑/↓ 切换角色　|　Tab 角色面板　|　B 背包　|　靠近红色标记/光点触发事件"
	hint.position = Vector2(12, 12)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.62, 0.65, 0.72))
	add_child(hint)


func _input(event: InputEvent) -> void:
	if _inventory_panel != null and _inventory_panel.visible:
		if event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel"):
			_close_inventory()
		return
	if _prompt_open:
		return
	if event.is_action_pressed("character_panel"):
		_panel.visible = not _panel.visible
		_character.input_enabled = not _panel.visible
		if _panel.visible:
			_panel.show_main_view()
	elif event.is_action_pressed("party_select_previous"):
		_party.select_previous()
	elif event.is_action_pressed("party_select_next"):
		_party.select_next()
	elif event.is_action_pressed("inventory"):
		_open_inventory()


func _physics_process(_delta: float) -> void:
	if _inventory_panel != null and _inventory_panel.visible:
		return
	if _prompt_open:
		return
	_check_battle_trigger()
	_check_skill_light()


func _check_battle_trigger() -> void:
	var distance := _character.position.distance_to(battle_trigger_position)
	if GameState.battle_trigger_consumed:
		# 离开触发点一段距离后重新武装，避免返回时立即再次触发
		if distance > battle_trigger_radius + 24.0:
			GameState.battle_trigger_consumed = false
		return
	if distance <= battle_trigger_radius:
		GameState.battle_trigger_consumed = true
		GameState.overworld_position = _character.position
		GameState.save_game()   # 进入战斗前持久化当前位置
		get_tree().change_scene_to_file("res://world/encounters/BattleMap.tscn")


func _check_skill_light() -> void:
	if GameState.skill_light_consumed or _skill_light == null:
		return
	if _skill_light_cooldown_active:
		return
	var distance := _character.position.distance_to(GameState.skill_light_position)
	if distance <= skill_light_radius:
		_open_skill_prompt()


func _open_skill_prompt() -> void:
	_prompt_open = true
	_character.input_enabled = false
	_prompt.show_prompt("冲锋")


func _on_prompt_confirmed() -> void:
	_add_skill_to_current_character("冲锋")
	GameState.skill_light_consumed = true
	if _skill_light != null:
		_skill_light.queue_free()
		_skill_light = null
	_close_prompt()
	GameState.save_game()   # 记录学习结果与光点状态


func _on_prompt_declined() -> void:
	_close_prompt()
	# 选择“否”：2 秒内不再触发技能光点判定
	_skill_light_cooldown_active = true
	_skill_light_cooldown_timer.start()


func _on_skill_light_cooldown_timeout() -> void:
	_skill_light_cooldown_active = false


func _close_prompt() -> void:
	_prompt_open = false
	_prompt.visible = false
	_character.input_enabled = true


## 面板数据（牌组等）变化时即时存档，关闭游戏后仍保留。
func _on_panel_data_changed() -> void:
	GameState.save_game()


func _add_skill_to_current_character(skill_name: String) -> void:
	var character := _party.get_current_character()
	if character == null:
		return
	for existing in character.skill_library:
		if existing.skill_name == skill_name:
			return
	var skill := SkillData.new()
	skill.skill_name = skill_name
	var card := CardDB.get_card(skill_name)
	var description := CardDB.describe_card(card)
	skill.description = description if not description.is_empty() else skill_name
	character.skill_library.append(skill)
	_panel.setup(character)


func _build_battle_trigger() -> void:
	var marker := ColorRect.new()
	marker.name = "BattleTrigger"
	marker.color = Color(0.85, 0.25, 0.25)
	marker.size = Vector2(46, 46)
	marker.position = battle_trigger_position - Vector2(23, 23)
	add_child(marker)

	var label := Label.new()
	label.name = "BattleTriggerLabel"
	label.text = "战斗"
	label.position = battle_trigger_position + Vector2(-23, 28)
	label.size = Vector2(46, 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.95, 0.80, 0.80))
	add_child(label)


func _build_skill_light() -> void:
	if GameState.skill_light_consumed:
		return
	_skill_light = SkillLight.new()
	_skill_light.name = "SkillLight"
	_skill_light.position = GameState.skill_light_position
	add_child(_skill_light)


func _on_party_character_selected(index: int, character: CharacterData) -> void:
	_character.apply_character_data(character)
	_panel.setup(character)
	_party_bar.set_selected(index)


func _open_inventory() -> void:
	_inventory_panel.open()
	_character.input_enabled = false


func _close_inventory() -> void:
	_inventory_panel.close()


func _on_inventory_closed() -> void:
	_character.input_enabled = true


## 背包点击物品：可装备 → 穿到当前角色（槽位被占先卸下旧装备回背包）。
func _on_equip_requested(item_name: String) -> void:
	var character := _party.get_current_character()
	if character == null:
		return
	var equip_db := get_node_or_null("/root/EquipDB")
	if equip_db == null:
		return
	var equip: EquipmentData = equip_db.get_equipment(item_name)
	if equip == null:
		_inventory_panel.show_tooltip_message("「%s」不是可装备物品" % item_name)
		return
	var occupied := character.get_equipped_in_slot(equip.slot)
	if occupied != null:
		if not _return_equipment_to_inventory(character, occupied):
			_inventory_panel.show_tooltip_message("背包已满，无法更换「%s」" % item_name)
			return
	if not character.equip_equipment(equip):
		if occupied != null:
			character.equip_equipment(occupied)   # 兜底还原旧装备
		_inventory_panel.show_tooltip_message("无法装备「%s」" % item_name)
		return
	_remove_inventory_item(item_name)
	_inventory_panel.refresh()
	_panel.setup(character)
	GameState.save_game()
	_inventory_panel.show_tooltip_message("已装备「%s」：%s" % [equip.equipment_name, equip.description])


## 卸下装备并放回背包；背包无空位则还原并返回 false。
func _return_equipment_to_inventory(character: CharacterData, equip: EquipmentData) -> bool:
	var removed := character.unequip_slot(equip.slot)
	if removed == null:
		return false
	var item := _item_by_name(removed.equipment_name)
	if item == null:
		return true    # 无对应物品（旧数据）直接卸下
	var spot := GameState.inventory.find_free_spot(item)
	if not spot.get("found", false):
		character.equip_equipment(removed)
		return false
	GameState.inventory.place(item, spot.page, spot.x, spot.y)
	return true


func _item_by_name(item_name: String) -> ItemData:
	var db := get_node_or_null("/root/ItemDB")
	return db.get_item(item_name) if db != null else null


## 从背包移除指定名称的第一件物品（已穿上的装备）。
func _remove_inventory_item(item_name: String) -> void:
	for i in GameState.inventory.items.size():
		var entry: Dictionary = GameState.inventory.items[i]
		var item: ItemData = entry.get("item")
		if item != null and item.item_name == item_name:
			GameState.inventory.items.remove_at(i)
			return
