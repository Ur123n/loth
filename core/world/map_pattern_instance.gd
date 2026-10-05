class_name MapPatternInstance
extends Node2D

## Reusable small-building/stamp instance. The root is the pattern anchor (normally
## the bottom-center ground point); visuals may extend freely above that anchor.

@export var pattern_id: String = ""
@export var footprint_cells: Vector2i = Vector2i.ONE
@export var anchor_cell: Vector2i = Vector2i.ZERO
@export_file("*.tscn") var interior_scene: String = ""


func get_pattern_id() -> String:
	return pattern_id


func get_footprint_cells() -> Vector2i:
	return footprint_cells


func get_anchor_cell() -> Vector2i:
	return anchor_cell


func get_entrance_marker(entrance_id: String = "door_main") -> Marker2D:
	return get_node_or_null(NodePath("Entrances/%s" % entrance_id)) as Marker2D


func get_interior_scene() -> String:
	return interior_scene

