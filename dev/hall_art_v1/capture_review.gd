extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene = load("res://dev/hall_art_v1/hall_art_v1.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.player.set_physics_process(false)
	for state in ["outside", "inside", "north"]:
		scene.player.position = {"outside": Vector2(552, 792), "inside": Vector2(552, 504), "north": Vector2(552, 210)}[state]
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://dev/hall_art_v1/review_%s.png" % state
		print("CAPTURE ", path, " error=", root.get_texture().get_image().save_png(path))
	var reports := {}
	var all_passed := true
	for layer_name in ["Ground", "Base", "Roof"]:
		var original: Sprite2D = scene.hall.get_node("Visual/" + layer_name)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(672, 576)
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
		var colors := {}
		for index in range(3, actual_bytes.size(), 4):
			if actual_bytes[index] != expected_bytes[index]:
				mismatch += 1
			if actual_bytes[index] > 0:
				var rgb := Vector3i(actual_bytes[index - 3], actual_bytes[index - 2], actual_bytes[index - 1])
				colors[rgb] = true
		var palette_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/dark48/色板/map_env.json"))
		var off_palette := 0
		for color: Vector3i in colors:
			var found := false
			for rgb in palette_data["palette"]:
				if absi(color.x - int(rgb[0])) <= 1 and absi(color.y - int(rgb[1])) <= 1 and absi(color.z - int(rgb[2])) <= 1:
					found = true
					break
			if not found:
				off_palette += 1
		var ok := mismatch == 0 and off_palette == 0
		all_passed = all_passed and ok
		reports[layer_name] = {"passed": ok, "alpha_mismatch_pixels": mismatch, "unique_colors": colors.size(), "off_palette_colors_tolerance_1": off_palette}
		print("GPU_QA ", layer_name, " ", JSON.stringify(reports[layer_name]))
		viewport.queue_free()
		await process_frame
	var file := FileAccess.open("res://dev/hall_art_v1/gpu_qa.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": all_passed, "layers": reports}, "  "))
	file.close()
	quit(0 if all_passed else 1)
