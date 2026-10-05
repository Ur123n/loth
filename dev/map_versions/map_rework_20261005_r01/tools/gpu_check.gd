extends SceneTree

var reports: Dictionary = {}
var all_passed := true
var palette: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _load_palette() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/dark48/色板/map_env.json"))
	palette = data.palette

func _on_palette(color: Vector3i) -> bool:
	for rgb in palette:
		if absi(color.x - int(rgb[0])) <= 1 and absi(color.y - int(rgb[1])) <= 1 and absi(color.z - int(rgb[2])) <= 1:
			return true
	return false

func _check_sprite(label: String, original: Sprite2D) -> void:
	var size := original.texture.get_size()
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sprite := Sprite2D.new()
	sprite.texture = original.texture
	sprite.material = original.material
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(sprite)
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var rendered := viewport.get_texture().get_image()
	var expected := original.texture.get_image()
	rendered.convert(Image.FORMAT_RGBA8)
	expected.convert(Image.FORMAT_RGBA8)
	var actual_bytes := rendered.get_data()
	var expected_bytes := expected.get_data()
	var mismatch := 0
	var colors: Dictionary = {}
	var opaque_colors: Dictionary = {}
	var semi_transparent_pixels := 0
	for index in range(3, actual_bytes.size(), 4):
		if actual_bytes[index] != expected_bytes[index]:
			mismatch += 1
		if actual_bytes[index] > 0:
			var color := Vector3i(actual_bytes[index - 3], actual_bytes[index - 2], actual_bytes[index - 1])
			colors[color] = true
			if actual_bytes[index] >= 254:
				opaque_colors[color] = true
			else:
				semi_transparent_pixels += 1
	var off_palette := 0
	for color: Vector3i in opaque_colors:
		if not _on_palette(color):
			off_palette += 1
	var ok := mismatch == 0 and off_palette == 0
	all_passed = all_passed and ok
	reports[label] = {
		"passed": ok,
		"alpha_mismatch_pixels": mismatch,
		"unique_colors": colors.size(),
		"opaque_unique_colors": opaque_colors.size(),
		"semi_transparent_pixels": semi_transparent_pixels,
		"off_palette_colors_tolerance_1": off_palette,
		"logical_canvas": [size.x, size.y],
	}
	print("MAP_REWORK_GPU ", label, " ", JSON.stringify(reports[label]))
	viewport.queue_free()
	await process_frame

func _run() -> void:
	_load_palette()
	var monastery: Node2D = load("res://dev/map_versions/map_rework_20261005_r01/iserra/candidate_monastery.tscn").instantiate()
	root.add_child(monastery)
	await process_frame
	await _check_sprite("iserra_base", monastery.get_node("建筑对象/IserraMonasteryHighland/Visual/Base") as Sprite2D)
	root.remove_child(monastery)
	monastery.queue_free()
	await process_frame

	var m02: Node2D = load("res://dev/map_versions/map_rework_20261005_r01/leyton_m02/candidate_m02.tscn").instantiate()
	root.add_child(m02)
	await process_frame
	for index in 3:
		await _check_sprite("m02_variant_%s" % ["a", "b", "c"][index], m02.candidate_visuals[index])
	root.remove_child(m02)
	m02.queue_free()
	await process_frame

	var output := FileAccess.open("res://dev/map_versions/map_rework_20261005_r01/qa/gpu_qa.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed": all_passed, "renderer": RenderingServer.get_video_adapter_name(), "layers": reports}, "\t") + "\n")
	output.close()
	quit(0 if all_passed else 1)
