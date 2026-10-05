extends Node2D

## 主场景（大世界）：四向移动、↑/↓ 切换角色、Tab 角色面板、
## 战斗触发点、技能光点（靠近后询问是否将“冲锋”加入当前角色技能库）。
## B 键打开背包（非战斗地图）；背包打开时暂停移动与事件触发。
## 启动时读取存档并为角色卡组补足基础牌（5 打击 + 5 防御）；
## 面板数据变化（加入/移出牌组等）即时写入存档。
## 剧情系统：剧情播放期间（GameState.story_active）切断玩家输入与事件触发；
## 示例剧情触发点在 STORY_TRIGGER_POSITION（金色菱形标记），只触发一次。
## 底图由 overworld_map_scene 指定；尺寸与 spawn/battle_trigger/story_trigger/skill_light
## 位置统一读取 Godot 地图场景里的标记（core/world/map_scene.gd，见 docs/world/map_pipeline.md）。

@export var party_characters: Array = []
## 大世界底图场景：默认使用 48px Godot 地图管线的高原修道院。
## 尺寸、出生点与各触发点自动读取地图标记（见 core/world/map_scene.gd）。
@export var overworld_map_scene: String = OVERWORLD_MAP_SCENE
@export var battle_trigger_position: Vector2 = Vector2(976, 600)
@export var battle_trigger_radius: float = 56.0
@export var skill_light_radius: float = 56.0
@export var skill_light_decline_cooldown: float = 2.0

## 48px 高原修道院；地图实际尺寸与显示倍率在 MapScene 中声明。
const OVERWORLD_MAP_SCENE := "res://maps/godot/scenes/iserra_monastery_highlands.tscn"
const MAP_POSITION := Vector2.ZERO
const MAP_SCALE := Vector2.ONE
const _NpcSchedule := preload("res://core/world/npc_schedule.gd")
const MAP_RECT := Rect2(Vector2.ZERO, Vector2(1280, 720))
const DEFAULT_SPAWN_POSITION := Vector2(640, 360)
const STORY_TRIGGER_POSITION := Vector2(640, 360)
const STORY_TRIGGER_RADIUS := 60.0
const WORLD_TIME_RATE := 10.0           # 每秒真实时间 = 10 游戏分钟（世界时钟/NPC 行动轨迹）
const NPC_INTERACT_RADIUS := 42.0       # E 键与 NPC 交互半径（主场景坐标）
const NPC_CHECK_INTERVAL := 0.5         # 任务自动推进检查间隔（秒）

## 地图元数据：Godot 地图场景自带尺寸、显示倍率与标记；常量仅用于资源损坏时的防御性兜底。
var _map_rect: Rect2 = MAP_RECT
var _map_position: Vector2 = MAP_POSITION
var _map_scale: Vector2 = MAP_SCALE
var _spawn_position: Vector2 = DEFAULT_SPAWN_POSITION
var _story_trigger_position: Vector2 = STORY_TRIGGER_POSITION
var _world_map: Node2D
var _world_sort_root: Node2D

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
var _npc_markers: Dictionary = {}      # npc_name -> Node2D（行动轨迹标记）
var _quest_check_timer: float = 0.0


func _build_world_map() -> void:
	var map_scene := load(overworld_map_scene) as PackedScene
	if map_scene == null:
		push_warning("大世界地图加载失败：%s" % overworld_map_scene)
		return
	var map := map_scene.instantiate()
	map.name = "MonasteryMap"
	_apply_map_metadata(map)      # 先算尺寸/缩放/关键点，再按结果摆位
	map.position = _map_position
	map.scale = _map_scale
	add_child(map)
	_world_map = map as Node2D
	if map.has_method("get_building_root"):
		_world_sort_root = map.call("get_building_root") as Node2D
		if _world_sort_root != null:
			_world_sort_root.y_sort_enabled = true


func _world_actor_parent() -> Node:
	return _world_sort_root if is_instance_valid(_world_sort_root) else self


func _attach_world_actor(actor: Node2D, world_position: Vector2) -> void:
	_world_actor_parent().add_child(actor)
	actor.global_position = world_position


func _actor_move_bounds() -> Rect2:
	if not is_instance_valid(_world_sort_root):
		return _map_rect
	var local_start := _world_sort_root.to_local(_map_rect.position)
	var local_end := _world_sort_root.to_local(_map_rect.end)
	return Rect2(local_start, local_end - local_start)


## 读地图自带的地图尺寸、显示倍率与关键点标记（core/world/map_scene.gd 提供），
## 并按视口居中摆位；接口缺失时使用防御性常量兜底。
func _apply_map_metadata(map: Node) -> void:
	var local_rect := Rect2(Vector2.ZERO, MAP_RECT.size / MAP_SCALE)
	var scale_value := MAP_SCALE.x
	if map != null and map.has_method("get_map_rect"):
		local_rect = map.call("get_map_rect")
		var declared: Variant = map.get("display_scale")
		if declared != null and float(declared) > 0.0:
			scale_value = float(declared)
	_map_scale = Vector2(scale_value, scale_value)
	var viewport_size := Vector2(1280, 720)
	if is_inside_tree():
		viewport_size = get_viewport_rect().size
	_map_position = ((viewport_size - local_rect.size * _map_scale) / 2.0).round()
	_map_rect = Rect2(_map_position, local_rect.size * _map_scale)
	_spawn_position = _marker_to_world(map, "spawn", DEFAULT_SPAWN_POSITION)
	battle_trigger_position = _marker_to_world(map, "battle_trigger", battle_trigger_position)
	_story_trigger_position = _marker_to_world(map, "story_trigger", STORY_TRIGGER_POSITION)


## 地图标记（地图局部像素）→ 主场景坐标；标记缺失时沿用传入的兜底值。
func _marker_to_world(map: Node, marker_id: String, fallback: Vector2) -> Vector2:
	if map == null or not map.has_method("get_marker_position"):
		return fallback
	var local: Vector2 = map.call("get_marker_position", marker_id)
	if local == Vector2.INF:
		return fallback
	return _map_position + local * _map_scale


func _clamp_to_map(pos: Vector2) -> Vector2:
	return pos.clamp(_map_rect.position, _map_rect.end)


func _ready() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.10, 0.12, 0.16)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_build_world_map()

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
	if not _map_rect.has_point(GameState.overworld_position):
		GameState.overworld_position = _spawn_position   # 旧档/越界位置重置到出生点
	if not GameState.skill_light_consumed:
		# 地图（Godot 管线）自带 skill_light 标记时以地图为准，否则沿用存档里的位置
		var light := _marker_to_world(get_node_or_null("MonasteryMap"), "skill_light", Vector2.INF)
		if light != Vector2.INF:
			GameState.skill_light_position = light
		GameState.skill_light_position = _clamp_to_map(GameState.skill_light_position)
	_character.move_bounds = _actor_move_bounds()
	_character.add_to_group("player")
	_attach_world_actor(_character, GameState.overworld_position)

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
	CameraCtrl.ensure_camera()          # 独立摄像机：默认视口中心，画面不变
	_build_story_trigger()
	_spawn_npcs()                       # 按行动轨迹放置并移动 NPC

	var hint := Label.new()
	hint.name = "ControlHint"
	hint.text = "WASD 移动　|　↑/↓ 切换角色　|　Tab 角色面板　|　B 背包　|　E 与 NPC 交谈　|　靠近红色标记/光点触发事件"
	hint.position = Vector2(12, 12)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.62, 0.65, 0.72))
	add_child(hint)


func _input(event: InputEvent) -> void:
	if GameState.story_active:
		return
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
	elif event.is_action_pressed("interact"):
		_try_interact_npc()


func _physics_process(_delta: float) -> void:
	if GameState.story_active:
		return
	if _inventory_panel != null and _inventory_panel.visible:
		return
	if _prompt_open:
		return
	# 世界时钟推进（NPC 行动轨迹/时间类任务依赖）
	GameState.advance_world_time(_delta, WORLD_TIME_RATE)
	_update_npc_markers()
	# 任务自动推进检查（覆盖物品/时间等无信号条件）
	_quest_check_timer -= _delta
	if _quest_check_timer <= 0.0:
		_quest_check_timer = NPC_CHECK_INTERVAL
		var quest_system := get_node_or_null("/root/QuestSystem")
		if quest_system != null:
			quest_system.check_advance()
	_check_battle_trigger()
	_check_skill_light()


func _check_battle_trigger() -> void:
	var distance := _character.global_position.distance_to(battle_trigger_position)
	if GameState.battle_trigger_consumed:
		# 离开触发点一段距离后重新武装，避免返回时立即再次触发
		if distance > battle_trigger_radius + 24.0:
			GameState.battle_trigger_consumed = false
		return
	if distance <= battle_trigger_radius:
		GameState.battle_trigger_consumed = true
		GameState.overworld_position = _character.global_position
		GameState.save_game()   # 进入战斗前持久化当前位置
		get_tree().change_scene_to_file("res://world/encounters/BattleMap.tscn")


func _check_skill_light() -> void:
	if GameState.skill_light_consumed or _skill_light == null:
		return
	if _skill_light_cooldown_active:
		return
	var distance := _character.global_position.distance_to(GameState.skill_light_position)
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


## 示例剧情触发点标记（金色菱形）；剧情播放过则不再显示。位置默认取常量，地图带 story_trigger 标记时以地图为准。
func _build_story_trigger() -> void:
	if GameState.is_story_played("example_intro"):
		return
	var marker := ColorRect.new()
	marker.name = "StoryTrigger"
	marker.color = Color(0.95, 0.78, 0.30)
	marker.size = Vector2(36, 36)
	marker.position = _story_trigger_position - Vector2(18, 18)
	marker.rotation = PI / 4.0
	add_child(marker)

	var label := Label.new()
	label.name = "StoryTriggerLabel"
	label.text = "剧情"
	label.position = _story_trigger_position + Vector2(-23, 26)
	label.size = Vector2(46, 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.55))
	add_child(label)


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


## 按 NPC 行动轨迹（时间轴）放置标记：色块 + 姓名，位置随世界时钟移动。
func _spawn_npcs() -> void:
	var npc_db := get_node_or_null("/root/NpcDB")
	if npc_db == null:
		return
	for npc in npc_db.npcs:
		if npc.schedule.is_empty():
			continue
		var marker := Node2D.new()
		marker.name = "Npc_" + npc.npc_name
		var box := ColorRect.new()
		box.name = "Body"
		box.color = npc.block_color
		box.size = Vector2(26, 26)
		box.position = Vector2(-13, -26)
		marker.add_child(box)
		var label := Label.new()
		label.name = "Name"
		label.text = npc.npc_name
		label.position = Vector2(-24, 4)
		label.size = Vector2(48, 18)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color(0.96, 0.96, 1.0))
		marker.add_child(label)
		marker.z_index = 0 if is_instance_valid(_world_sort_root) else 5
		_npc_markers[npc.npc_name] = marker
		_attach_world_actor(marker, _map_position)
	_update_npc_markers()


## 按当前世界时钟更新全部 NPC 标记位置（相邻时间点线性插值，跨零点衔接）。
func _update_npc_markers() -> void:
	if _npc_markers.is_empty():
		return
	var npc_db := get_node_or_null("/root/NpcDB")
	if npc_db == null:
		return
	for npc in npc_db.npcs:
		var node: Node2D = _npc_markers.get(npc.npc_name)
		if node == null or npc.schedule.is_empty():
			continue
		var pos := _NpcSchedule.compute_position(npc.schedule, GameState.world_time)
		if pos != Vector2.INF:
			node.global_position = _map_position + pos * _map_scale


## E 键交互：与最近（半径内）的 NPC 交谈 → 触发剧情触发器 + 记录交谈（供任务条件 npc_talked）。
func _try_interact_npc() -> void:
	if _npc_markers.is_empty():
		return
	var nearest := ""
	var best := NPC_INTERACT_RADIUS
	for npc_name in _npc_markers:
		var node: Node2D = _npc_markers[npc_name]
		var d: float = _character.global_position.distance_to(node.global_position)
		if d <= best:
			best = d
			nearest = npc_name
	if nearest.is_empty():
		return
	var trigger := get_node_or_null("/root/StoryTrigger")
	if trigger != null:
		trigger.interact(nearest)
	var quest_system := get_node_or_null("/root/QuestSystem")
	if quest_system != null:
		quest_system.notify_npc_talked(nearest)
