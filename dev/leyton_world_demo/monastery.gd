extends "res://maps/leyton/graybox_map.gd"
## Use authored MapScene nodes and existing collision/Building semantics.
## Do not invoke the procedural graybox terrain builder on this inherited map.
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dev/leyton_world_demo/world.json"))
	layout = config.monastery_layout.duplicate(true)
	get_marker("spawn").position = cell_to_local(Vector2i(layout.spawn[0],layout.spawn[1]))
	get_building_root().y_sort_enabled = true
	get_building_root().z_index = 1
	get_layer(LAYER_COLLISION).visible = false

func set_surface_enabled(_enabled: bool) -> void:
	# The canonical monastery art stays intact; T only changes Leyton surfaces.
	use_surface = true
