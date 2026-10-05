extends SceneTree
var failed := 0

func _initialize() -> void:
	call_deferred("run")

func capture(viewer: Node, suffix: String) -> Image:
	viewer._refresh()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var shot := root.get_texture().get_image()
	var error := shot.save_png("res://maps/leyton/qa/gatehouse_art_%s.png" % suffix)
	if error != OK:
		failed += 1
	print("CAPTURE gatehouse_",suffix," error=",error)
	return shot

func run() -> void:
	root.size = Vector2i(1280,720)
	var viewer: Node = load("res://maps/leyton/scenes/slice_test.tscn").instantiate()
	root.add_child(viewer)
	viewer.set_physics_process(false)
	viewer.load_map("M07")
	viewer.player.position = Vector2(89.5,40)*48
	await capture(viewer,"open_ground")
	viewer.cart = true
	await capture(viewer,"open_cart")
	viewer.cart = false
	viewer.player.position = Vector2(83.5,40)*48
	for state in [1,2]:
		viewer.state = state
		viewer.current.set_gate_state(state)
		await capture(viewer,"curfew" if state == 1 else "sealed")
	viewer.on_wall = true
	viewer.player.position = Vector2(93.5,40)*48
	await capture(viewer,"wall_over_closed_gate")
	viewer.player.position = Vector2(93.5,64)*48
	await capture(viewer,"wall_over_water_gate")
	viewer.state = 0
	viewer.current.set_gate_state(0)
	viewer.cart = false
	viewer.player.position = Vector2(93.5,40)*48
	# Same actor and XY. Only the gameplay elevation changes between captures.
	var result := {}
	for upper: bool in [false,true]:
		viewer.on_wall = upper
		var shot := await capture(viewer,"probe_upper" if upper else "probe_ground")
		var world_point: Vector2 = viewer.player.global_position + Vector2(0,-18)
		var screen: Vector2 = viewer.get_viewport().get_canvas_transform() * world_point
		var pixel := shot.get_pixelv(Vector2i(screen.round()))
		var actor_color := Color(0.75,0.84,0.95)
		var actor_visible := absf(pixel.r-actor_color.r)+absf(pixel.g-actor_color.g)+absf(pixel.b-actor_color.b) < 0.06
		var ok: bool = actor_visible == upper
		result["upper" if upper else "ground"] = {"passed":ok,"actor_visible":actor_visible,"sample":[pixel.r,pixel.g,pixel.b]}
		if not ok:
			failed += 1
	var report := FileAccess.open("res://maps/leyton/qa/gatehouse_art_render.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"renderer":RenderingServer.get_video_adapter_name(),"elevation":result,"failed":failed},"\t")+"\n")
	viewer.queue_free()
	await process_frame
	print("GATEHOUSE_RENDER failed=",failed)
	quit(1 if failed else 0)
