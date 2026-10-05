extends "res://maps/leyton/viewer.gd"
func create_map(_id: String) -> Node2D:
	return load("res://maps/leyton/street_sample_v3/map.gd").new()
func _ready() -> void:
	initial_map_id = "M02"
	super._ready()
func _refresh() -> void:
	super._refresh()
	current.update_occlusion(player.position)
	if overview:
		var camera: Camera2D = player.get_node("Camera2D")
		camera.zoom = Vector2.ONE*0.35
		camera.position = Vector2(16,10)*48-player.position
	hud.text = "城北连续街坊样段 | WASD 移动 · C 人物/车体 · Tab 总览 · V 素材/灰盒 · R 复位\n围合私院 / 连续街屋 / 步行巷 / 曲折车路 · 当前为街坊样段\n" + status
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_V: current.set_art_enabled(not current.art_enabled)
			KEY_C: toggle_cart()
			KEY_TAB: overview = not overview
			KEY_R: load_map("M02")
		_refresh()
