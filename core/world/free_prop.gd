class_name FreeProp
extends Node2D

## Freely placed world prop. It is deliberately not a TileMap cell: the root is
## a bottom-center ground anchor and collision is maintained independently.

@export var prop_id: String = ""
@export var footprint_cells: Vector2i = Vector2i.ONE
@export var solid: bool = true


func get_prop_id() -> String:
	return prop_id


func get_footprint_cells() -> Vector2i:
	return footprint_cells


func has_independent_collision() -> bool:
	return get_node_or_null(NodePath("Collision")) is StaticBody2D

