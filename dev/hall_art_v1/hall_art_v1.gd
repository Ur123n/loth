extends "res://dev/map_workflow_lab/map_workflow_lab.gd"

var art_materials: Dictionary = {}
var art_enabled := true


func _ready() -> void:
	super._ready()
	var palette_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/dark48/色板/map_env.json"))
	var colors := PackedColorArray()
	for rgb in palette_data["palette"]:
		colors.append(Color(float(rgb[0]) / 255.0, float(rgb[1]) / 255.0, float(rgb[2]) / 255.0))
	for layer_name in ["Ground", "Base", "Roof"]:
		var material := ShaderMaterial.new()
		material.shader = load("res://dev/hall_art_v1/surface.gdshader")
		material.set_shader_parameter("art_surface", load("res://dev/hall_art_v1/%s.png" % layer_name.to_lower()))
		material.set_shader_parameter("map_colors", colors)
		var color: Color = {"Ground": Color("3a342c"), "Base": Color("777269"), "Roof": Color("373c40")}[layer_name]
		material.set_shader_parameter("fallback_color", color)
		art_materials[layer_name] = material
		(hall.get_node("Visual/" + layer_name) as Sprite2D).material = material
	_update_art_help()


func set_art_enabled(enabled: bool) -> void:
	art_enabled = enabled
	for layer_name in art_materials:
		(hall.get_node("Visual/" + layer_name) as Sprite2D).material = art_materials[layer_name] if enabled else null
	for band in get_node("建筑对象").get_children():
		if band.has_meta("semantic_band_id"):
			(band.get_node("Region") as Sprite2D).material = art_materials["Base"] if enabled else null
	_update_art_help()


func _update_art_help() -> void:
	for child in get_children():
		if child is CanvasLayer:
			for label in child.get_children():
				if label is Label:
					label.text = "边境石砌会堂 · 美术样板 v1 · 12×10米\nWASD 移动 · R 回入口 · F 手动屋顶 · T 自动屋顶 · B 碰撞\nC 切换美术/灰盒 · 当前：%s\n此版本用于材质、比例与遮挡审验，未作正式美术发布。" % ("美术" if art_enabled else "灰盒")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_C:
		set_art_enabled(not art_enabled)
	else:
		super._unhandled_input(event)
