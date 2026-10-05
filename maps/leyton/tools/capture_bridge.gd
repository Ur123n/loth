extends SceneTree
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1280,720)
	var viewer: Node = load("res://maps/leyton/scenes/slice_test.tscn").instantiate()
	root.add_child(viewer)
	viewer.set_physics_process(false)
	viewer.load_map("M04")
	viewer.player.position = Vector2(48,64)*48
	for cart in [false,true]:
		viewer.cart = cart
		viewer._refresh()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://maps/leyton/qa/bridge_graybox_%s.png" % ("cart" if cart else "player")
		print("CAPTURE ",path," error=",root.get_texture().get_image().save_png(path))
	viewer.queue_free()
	await process_frame
	quit()
