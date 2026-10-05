class_name BuildingGhost
extends Node2D

## Non-destructive large-building placement preview.
## Shows the complete prefab at partial opacity plus footprint grid, anchor and
## entrances. Validation reuses BuildingValidator, so preview and placement
## cannot silently disagree about overlap/bounds/door reachability.

const BuildingLibraryScript := preload("res://core/building/building_library.gd")
const BuildingValidatorScript := preload("res://core/building/building_validator.gd")

@export var building_id: String = ""
@export var top_left_cell: Vector2i = Vector2i.ZERO
@export var valid_color := Color(0.35, 1.0, 0.55, 0.48)
@export var invalid_color := Color(1.0, 0.25, 0.2, 0.48)
@export var grid_color := Color(0.85, 0.92, 1.0, 0.28)
@export var anchor_color := Color(1.0, 0.82, 0.15, 1.0)
@export var entrance_color := Color(0.2, 0.85, 1.0, 1.0)

var _map: Node
var _library := BuildingLibraryScript.new()
var _validator := BuildingValidatorScript.new()
var _data: RefCounted
var _preview: Node2D
var _placement_valid := false
var _issues: Array = []


func _ready() -> void:
	z_index = 100
	if get_parent() != null and get_parent().has_method("get_map_size_cells"):
		configure(get_parent(), building_id, top_left_cell)


func configure(target_map: Node, next_building_id: String,
		initial_top_left: Vector2i = Vector2i.ZERO) -> bool:
	_map = target_map
	building_id = next_building_id
	top_left_cell = initial_top_left
	_data = _library.load_building(building_id)
	_rebuild_preview()
	if _data == null:
		_placement_valid = false
		queue_redraw()
		return false
	set_top_left_cell(initial_top_left)
	return _preview != null


func set_top_left_cell(cell: Vector2i) -> void:
	top_left_cell = cell
	if _data != null:
		position = _data.call("top_left_cell_to_node_position", cell)
	refresh_validation()
	queue_redraw()


## Cursor position is the building Anchor world position, then snapped to grid.
func set_anchor_world_position(world_position: Vector2) -> void:
	if _map == null or _data == null:
		return
	var map_node := _map as Node2D
	if map_node == null:
		return
	var local_anchor: Vector2 = map_node.to_local(world_position)
	set_top_left_cell(_data.call("node_position_to_top_left_cell", local_anchor))


func refresh_validation() -> bool:
	_issues.clear()
	_placement_valid = false
	if _map == null or _data == null:
		_apply_preview_color()
		return false
	_validator.clear()
	_validator.validate_placement(building_id, _map, top_left_cell)
	var report: Dictionary = _validator.report(building_id)
	_issues = (report.get("issues", []) as Array).duplicate(true)
	_placement_valid = bool(report.get("ok", false))
	_apply_preview_color()
	return _placement_valid


func is_placement_valid() -> bool:
	return _placement_valid


func get_placement_issues() -> Array:
	return _issues.duplicate(true)


func get_preview_node() -> Node2D:
	return _preview


func get_footprint_rect_cells() -> Rect2i:
	if _data == null:
		return Rect2i()
	return Rect2i(top_left_cell, _data.call("get_footprint_size"))


func get_anchor_world_position() -> Vector2:
	return global_position


func get_entrance_map_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if _data == null:
		return out
	for door in _data.call("get_doors"):
		var raw: Array = (door as Dictionary).get("cell", [0, 0])
		out.append(top_left_cell + Vector2i(int(raw[0]), int(raw[1])))
	return out


## Runtime placement for the phase-one lab. Persistent map editing remains the
## responsibility of BuildingPlacer/building_tool.gd.
func place_runtime() -> Node2D:
	if not refresh_validation() or _data == null or _map == null:
		return null
	var packed := load(String(_data.get("prefab_path"))) as PackedScene
	if packed == null:
		return null
	var instance := packed.instantiate() as Node2D
	if instance == null:
		return null
	var root_node: Node2D = _map.call("get_building_root")
	if root_node == null:
		root_node = Node2D.new()
		root_node.name = "建筑对象"
		root_node.y_sort_enabled = true
		_map.add_child(root_node)
	root_node.add_child(instance)
	instance.position = _data.call("top_left_cell_to_node_position", top_left_cell)
	if instance.has_method("set_placement_cell"):
		instance.call("set_placement_cell", top_left_cell)
	instance.set_meta("building_id", building_id)
	instance.set_meta("top_left_cell", top_left_cell)
	refresh_validation()
	return instance


func _rebuild_preview() -> void:
	if _preview != null:
		remove_child(_preview)
		_preview.free()
		_preview = null
	if _data == null:
		return
	var packed := load(String(_data.get("prefab_path"))) as PackedScene
	if packed == null:
		return
	_preview = packed.instantiate() as Node2D
	if _preview == null:
		return
	_preview.name = "Preview"
	add_child(_preview)
	_disable_runtime_behavior(_preview)
	_apply_preview_color()


func _disable_runtime_behavior(node: Node) -> void:
	if node is CollisionObject2D:
		(node as CollisionObject2D).collision_layer = 0
		(node as CollisionObject2D).collision_mask = 0
	if node is Area2D:
		(node as Area2D).monitoring = false
		(node as Area2D).monitorable = false
	for child in node.get_children():
		_disable_runtime_behavior(child)
	if node == _preview:
		node.process_mode = Node.PROCESS_MODE_DISABLED


func _apply_preview_color() -> void:
	if _preview != null:
		_preview.modulate = valid_color if _placement_valid else invalid_color


func _draw() -> void:
	if _data == null:
		return
	var tile: Vector2i = _data.call("get_tile_size")
	var size: Vector2i = _data.call("get_footprint_size")
	var anchor: Vector2 = _data.call("get_anchor_local_px")
	var origin := -anchor
	var rect := Rect2(origin, Vector2(size) * Vector2(tile))
	draw_rect(rect, valid_color if _placement_valid else invalid_color, true)
	draw_rect(rect, grid_color, false, 3.0)
	for x in range(1, size.x):
		var px := origin.x + float(x * tile.x)
		draw_line(Vector2(px, origin.y), Vector2(px, rect.end.y), grid_color, 1.0)
	for y in range(1, size.y):
		var py := origin.y + float(y * tile.y)
		draw_line(Vector2(origin.x, py), Vector2(rect.end.x, py), grid_color, 1.0)
	draw_line(Vector2(-16, 0), Vector2(16, 0), anchor_color, 4.0)
	draw_line(Vector2(0, -16), Vector2(0, 16), anchor_color, 4.0)
	for door in _data.call("get_doors"):
		var raw: Array = (door as Dictionary).get("cell", [0, 0])
		var local_cell := Vector2i(int(raw[0]), int(raw[1]))
		var center: Vector2 = _data.call("cell_center_local_px", local_cell) - anchor
		draw_circle(center, 10.0, entrance_color)
