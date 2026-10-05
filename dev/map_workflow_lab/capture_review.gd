extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene = load("res://dev/map_workflow_lab/map_workflow_lab.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.player.set_physics_process(false)
	for state in ["outside", "inside", "north"]:
		scene.player.position = {"outside": Vector2(552, 792), "inside": Vector2(552, 504), "north": Vector2(552, 210)}[state]
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://dev/map_workflow_lab/review_%s.png" % state
		var error := root.get_texture().get_image().save_png(path)
		print("CAPTURE ", path, " error=", error)
	quit()
