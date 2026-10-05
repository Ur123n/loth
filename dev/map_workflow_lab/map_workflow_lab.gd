extends "res://core/world/map_scene.gd"

const HALL_CELL := Vector2i(6, 5)
const PALETTE = preload("res://maps/godot/tools/map_palette.gd")
var hall: Node2D
var player: CharacterBody2D


func _ready() -> void:
	map_size_cells = Vector2i(24, 20)
	var tiles := load("res://maps/godot/tilesets/dark48.tres") as TileSet
	for layer_name in LAYERS:
		var layer := TileMapLayer.new()
		layer.name = layer_name
		layer.tile_set = tiles
		layer.z_index = -20 if layer_name == LAYER_TERRAIN else -10
		add_child(layer)
	var palette := PALETTE.new()
	palette.setup(tiles)
	for y in map_size_cells.y:
		for x in map_size_cells.x:
			palette.set_material(get_layer(LAYER_TERRAIN), Vector2i(x, y), "grass")
	for y in map_size_cells.y:
		for x in range(11, 13):
			palette.set_material(get_layer(LAYER_TERRAIN), Vector2i(x, y), "road_stone")
	palette.apply_autotile(get_layer(LAYER_TERRAIN))
	var markers := Node2D.new()
	markers.name = MARKER_ROOT
	add_child(markers)
	for marker_name in REQUIRED_MARKERS:
		var marker := Marker2D.new()
		marker.name = marker_name
		marker.position = Vector2(552, 792)
		markers.add_child(marker)
	var objects := Node2D.new()
	objects.name = BUILDING_ROOT
	objects.y_sort_enabled = true
	add_child(objects)
	hall = load("res://assets/buildings/workflow_hall/WorkflowHall.tscn").instantiate()
	hall.name = "WorkflowHall"
	var data = hall.get_building_data()
	hall.position = data.top_left_cell_to_node_position(HALL_CELL)
	objects.add_child(hall)
	hall.set_placement_cell(HALL_CELL)
	player = load("res://dev/map_pipeline_test/phase_one_player.tscn").instantiate()
	player.name = "Player"
	player.position = Vector2(552, 792)
	player.collision_mask = 2
	player.camera_zoom = Vector2.ONE
	objects.add_child(player)
	player.get_node("Camera2D").enabled = false
	var camera := Camera2D.new()
	camera.position = Vector2(576, 480)
	camera.zoom = Vector2(0.7, 0.7)
	add_child(camera)
	var ui := CanvasLayer.new()
	add_child(ui)
	var help := Label.new()
	help.position = Vector2(20, 16)
	help.text = "地图制作样板 · 12×10米灰盒\nWASD 移动 · 从南门穿过大厅到北门 · R 返回入口\nF 手动查看屋顶（暂停自动切换） · T 恢复自动屋顶 · B 碰撞网格\n此场景用于结构验收，尚未进入精细美术阶段。"
	help.add_theme_color_override("font_shadow_color", Color.BLACK)
	help.add_theme_constant_override("shadow_offset_x", 2)
	help.add_theme_constant_override("shadow_offset_y", 2)
	ui.add_child(help)
	super._ready()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R:
				player.position = Vector2(552, 792)
			KEY_F:
				hall.set_process(false)
				hall.set_roof_visible(not hall.is_roof_visible())
			KEY_T:
				hall.set_process(true)
			KEY_B:
				hall.debug_draw = not hall.debug_draw
