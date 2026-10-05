extends "res://core/world/map_scene.gd"

const MapPaletteScript := preload("res://maps/godot/tools/map_palette.gd")

const ACTUAL_BUILDING_CELL := Vector2i(75, 5)
const GHOST_START_CELL := Vector2i(5, 5)
const PLAYER_START := Vector2(3120, 3480)

@onready var _ghost: Node2D = get_node("BuildingGhost")
@onready var _player: CharacterBody2D = get_node("建筑对象/Player")
@onready var _actual_building: Node2D = get_node("建筑对象/IserraMonastery")
@onready var _help: Label = get_node("UI/Help")


func _ready() -> void:
	super._ready()
	_paint_phase_one_map()
	_ghost.call("configure", self, "iserra_monastery", GHOST_START_CELL)
	_update_help("第一阶段地图管线已加载")


func _paint_phase_one_map() -> void:
	var terrain := get_layer(LAYER_TERRAIN)
	if terrain == null or terrain.tile_set == null:
		push_error("第一阶段测试图缺少地形 TileSet")
		return
	var palette := MapPaletteScript.new()
	if not palette.setup(terrain.tile_set):
		push_error("第一阶段测试图无法读取 TileSet pipeline 元数据")
		return
	for y in map_size_cells.y:
		for x in map_size_cells.x:
			palette.set_material(terrain, Vector2i(x, y), "grass")
	for y in range(69, 76):
		for x in map_size_cells.x:
			palette.set_material(terrain, Vector2i(x, y), "dirt")
	for x in map_size_cells.x:
		palette.set_material(terrain, Vector2i(x, 72), "road_stone")
	for y in range(64, 73):
		for x in range(64, 72):
			palette.set_material(terrain, Vector2i(x, y), "dirt")
	palette.apply_autotile(terrain)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _ghost.visible:
		_ghost.call("set_anchor_world_position", get_global_mouse_position())
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _ghost.visible:
		var placed: Node2D = _ghost.call("place_runtime")
		_update_help("建筑已放置（仅本次运行）" if placed != null else "当前位置不可放置")
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_G:
				_ghost.visible = not _ghost.visible
				_update_help("Ghost %s" % ("开启" if _ghost.visible else "关闭"))
			KEY_F:
				_actual_building.call("set_roof_visible", not bool(_actual_building.call("is_roof_visible")))
				_update_help("Roof %s" % ("显示" if bool(_actual_building.call("is_roof_visible")) else "隐藏"))
			KEY_R:
				_player.global_position = PLAYER_START
				_player.velocity = Vector2.ZERO
				_ghost.call("set_top_left_cell", GHOST_START_CELL)
				_update_help("玩家与 Ghost 已复位")


func _update_help(status: String) -> void:
	var validity := "可放置" if bool(_ghost.call("is_placement_valid")) else "不可放置"
	_help.text = "%s\nWASD 移动 · E 进入小屋 · F 屋顶 · G Ghost · 左键放置 · R 复位\nGhost: %s  cell=%s" % [
		status, validity, str(_ghost.get("top_left_cell"))]

