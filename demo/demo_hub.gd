extends Node2D

## 战斗测试 Demo 的修整营地：空白大地图，中央光点触发“是否进入下一场战斗”。
## WASD 移动、↑/↓ 切换角色、Tab 角色面板、B 背包。

const LIGHT_POSITION := Vector2(640, 360)
const LIGHT_RADIUS := 58.0
const DECLINE_COOLDOWN := 1.5

var _party: PartyManager
var _character: Character
var _party_bar: PartyBar
var _inventory_panel: InventoryPanel
var _character_panel: CharacterPanel
var _prompt: ConfirmPrompt
var _cooldown_timer: Timer
var _prompt_open: bool = false


func _ready() -> void:
	_build_ground()
	_build_light()

	_party = PartyManager.new()
	_party.character_selected.connect(_on_party_character_selected)
	_party.setup(GameState.party_characters)

	_character = Character.new()
	_character.name = "PartyEntity"
	_character.character_data = _party.get_current_character()
	_character.position = Vector2(640, 580)
	add_child(_character)

	_party_bar = PartyBar.new()
	add_child(_party_bar)
	_party_bar.setup(_party.characters)

	_character_panel = CharacterPanel.new()
	add_child(_character_panel)
	_character_panel.setup(_party.get_current_character())
	_character_panel.visible = false
	_character_panel.data_changed.connect(_on_panel_data_changed)

	_inventory_panel = InventoryPanel.new()
	add_child(_inventory_panel)
	_inventory_panel.visible = false
	_inventory_panel.closed.connect(_on_inventory_closed)

	_prompt = ConfirmPrompt.new()
	add_child(_prompt)
	_prompt.confirmed.connect(_on_prompt_confirmed)
	_prompt.declined.connect(_on_prompt_declined)

	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = true
	_cooldown_timer.wait_time = DECLINE_COOLDOWN
	_cooldown_timer.timeout.connect(func(): _cooldown_timer.stop())
	add_child(_cooldown_timer)

	_build_hud()


func _input(event: InputEvent) -> void:
	if _prompt_open:
		return
	if _inventory_panel.visible:
		if event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel"):
			_inventory_panel.close()
		return
	if event.is_action_pressed("character_panel"):
		_character_panel.visible = not _character_panel.visible
		_character.input_enabled = not _character_panel.visible
		if _character_panel.visible:
			_character_panel.show_main_view()
	elif event.is_action_pressed("party_select_previous"):
		_party.select_previous()
	elif event.is_action_pressed("party_select_next"):
		_party.select_next()
	elif event.is_action_pressed("inventory"):
		_inventory_panel.open()
		_character.input_enabled = false


func _physics_process(_delta: float) -> void:
	if _prompt_open or _cooldown_timer.time_left > 0.0 or _inventory_panel.visible \
			or _character_panel.visible:
		return
	if _character.position.distance_to(LIGHT_POSITION) <= LIGHT_RADIUS:
		_open_next_battle_prompt()


func _open_next_battle_prompt() -> void:
	_prompt_open = true
	_character.input_enabled = false
	var next := GameState.demo_battle_number + 1
	var total := DemoComposer.total_battles()
	if next > total:
		_prompt.show_prompt("战役通关", "已完成全部 %d 场战斗！\n重新开始将重置角色与战斗进度，是否继续？" % total)
	else:
		var tier := DemoComposer.battle_tier(next)
		_prompt.show_prompt("前方光点", "是否进入第 %d / %d 场战斗（%s战）？\n（在营地修整后出发，敌怪与地图每次随机生成）" % [next, total, tier])


func _on_prompt_confirmed() -> void:
	_prompt_open = false
	_prompt.hide_prompt()
	_character.input_enabled = true
	if GameState.demo_battle_number >= DemoComposer.total_battles():
		GameState.demo_battle_number = 0
		GameState.save_game()
		get_tree().change_scene_to_file("res://demo/BattleTestDemo.tscn")
	else:
		GameState.demo_battle_number += 1
		GameState.save_game()
		get_tree().change_scene_to_file("res://world/encounters/BattleMap.tscn")


func _on_prompt_declined() -> void:
	_prompt_open = false
	_prompt.hide_prompt()
	_character.input_enabled = true
	_cooldown_timer.start()


func _on_party_character_selected(index: int, character: CharacterData) -> void:
	_character.apply_character_data(character)
	_character_panel.setup(character)
	_party_bar.set_selected(index)


func _on_panel_data_changed() -> void:
	GameState.save_game()


func _on_inventory_closed() -> void:
	_character.input_enabled = true


func _build_ground() -> void:
	var ground := ColorRect.new()
	ground.name = "Ground"
	ground.color = Color(0.13, 0.16, 0.12)
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)

	var border := ColorRect.new()
	border.name = "Border"
	border.color = Color(0.20, 0.25, 0.18)
	border.size = Vector2(1280, 720)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(border)


func _build_light() -> void:
	var light := Node2D.new()
	light.name = "BattleLight"
	light.position = LIGHT_POSITION
	add_child(light)
	var glow := Polygon2D.new()
	glow.polygon = _circle_points(16.0)
	glow.color = Color(1.0, 0.85, 0.30, 0.22)
	light.add_child(glow)
	var dot := Polygon2D.new()
	dot.polygon = _circle_points(10.0)
	dot.color = Color(1.0, 0.90, 0.45)
	light.add_child(dot)
	var label := Label.new()
	label.text = "战斗"
	label.position = Vector2(-20, 16)
	label.size = Vector2(40, 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.70))
	light.add_child(label)
	var anim := light.create_tween().set_loops()
	anim.tween_property(dot, "scale", Vector2(1.2, 1.2), 0.6).set_trans(Tween.TRANS_SINE)
	anim.tween_property(dot, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)


func _build_hud() -> void:
	var label := Label.new()
	var total := DemoComposer.total_battles()
	var done := GameState.demo_battle_number >= total
	var next_tier := "" if done else DemoComposer.battle_tier(GameState.demo_battle_number + 1)
	label.text = "修整营地　——　战役进度 %d / %d（下一场：%s）　|　钱币 %d\n%s" % [
		mini(GameState.demo_battle_number, total), total, next_tier, GameState.money,
		"战役已通关！靠近中央光点重新开始" if done else "WASD 移动　|　靠近中央光点进入下一场战斗"]
	label.position = Vector2(12, 12)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.90))
	add_child(label)


func _circle_points(radius: float, segments: int = 24) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * i / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
