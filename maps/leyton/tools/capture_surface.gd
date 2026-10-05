extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1280, 720)
	var viewer: Node = load("res://maps/leyton/scenes/slice_test.tscn").instantiate()
	root.add_child(viewer)
	viewer.set_physics_process(false)
	for id in ["M01", "M04", "M07"]:
		viewer.load_map(id)
		for overview in [true, false]:
			viewer.overview = overview
			viewer.player.position = Vector2(48, 64) * 48 if id != "M07" else Vector2(88, 51) * 48
			viewer._refresh()
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var path := "res://maps/leyton/qa/surface_v1_%s_%s.png" % [id.to_lower(), "overview" if overview else "detail"]
			print("CAPTURE ", path, " error=", root.get_texture().get_image().save_png(path))
	viewer.queue_free()
	await process_frame
	quit()
