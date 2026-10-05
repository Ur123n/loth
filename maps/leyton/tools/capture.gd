extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1280, 720)
	var viewer: Node = load("res://maps/leyton/scenes/slice_test.tscn").instantiate()
	root.add_child(viewer)
	viewer.set_physics_process(false)
	viewer.overview = true
	for id in ["M01", "M04", "M07"]:
		viewer.load_map(id)
		viewer._refresh()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://maps/leyton/qa/%s_overview.png" % id.to_lower()
		var error := root.get_texture().get_image().save_png(path)
		print("CAPTURE ", id, " error=", error)
	viewer.queue_free()
	await process_frame
	quit()
