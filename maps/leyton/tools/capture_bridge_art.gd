extends SceneTree
## Actual GPU captures and pixel comparisons for sorting, with no player input required.
var failures := 0

func _initialize() -> void:
	call_deferred("capture")

func frame(viewer: Node) -> Image:
	viewer._refresh()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func save_capture(viewer: Node, suffix: String) -> void:
	var image := await frame(viewer)
	var path := "res://maps/leyton/qa/bridge_art_%s.png" % suffix
	var error := image.save_png(path)
	print("CAPTURE ", path, " error=", error)
	if error != OK:
		failures += 1

func capture() -> void:
	root.size = Vector2i(1280,720)
	var viewer: Node = load("res://maps/leyton/scenes/slice_test.tscn").instantiate()
	root.add_child(viewer)
	viewer.set_physics_process(false)
	viewer.load_map("M04")
	viewer.player.position = Vector2(48,64)*48
	await save_capture(viewer, "player")
	viewer.cart = true
	await save_capture(viewer, "cart")
	viewer.cart = false
	# Legal position just south of west parapet: actor's head overlaps the cap.
	viewer.player.position = Vector2(42.5*48,69*48+12)
	await save_capture(viewer, "south_front")
	# Legal position beside west parapet; the rail clips the actor's left edge.
	viewer.player.position = Vector2(43*48+12,68.5*48)
	await save_capture(viewer, "side_behind")
	# Strong synthetic sort probe: diagnostic rectangle overlaps the same rail pixel
	# while its foot is north/south of the rail's sorting anchor. Not a movement test.
	viewer.footprint_outline.visible = false
	viewer.player.position = Vector2(42.5*48,69*48+12)
	viewer._refresh()
	viewer.player.get_node("Body").visible = false
	viewer.player.get_node("Shadow").visible = false
	viewer.hud.visible = false
	var sort_parent: Node2D = viewer.player.get_parent()
	var probe := Node2D.new()
	probe.name = "OcclusionQAProbe"
	sort_parent.add_child(probe)
	var quad := Polygon2D.new()
	quad.color = Color(1,0,1,1)
	probe.add_child(quad)
	var rail_pixel := Vector2(42.5*48,69*48-18)
	var results: Dictionary = {}
	for front: bool in [false,true]:
		probe.position = Vector2(rail_pixel.x,69*48+(12 if front else -12))
		var center: Vector2 = rail_pixel-probe.position
		quad.polygon = PackedVector2Array([center+Vector2(-6,-6),center+Vector2(6,-6),center+Vector2(6,6),center+Vector2(-6,6)])
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var shot := root.get_texture().get_image()
		var screen: Vector2 = viewer.get_viewport().get_canvas_transform() * sort_parent.to_global(rail_pixel)
		var pixel := shot.get_pixelv(Vector2i(screen.round()))
		var is_probe := pixel.r > 0.9 and pixel.b > 0.9 and pixel.g < 0.1
		var ok: bool = is_probe == front
		results["front" if front else "behind"] = {"passed":ok,"sample":[pixel.r,pixel.g,pixel.b],"screen":[screen.x,screen.y]}
		if not ok:
			failures += 1
		shot.save_png("res://maps/leyton/qa/bridge_art_probe_%s.png" % ("front" if front else "behind"))
	probe.queue_free()
	var report := FileAccess.open("res://maps/leyton/qa/bridge_art_render.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"renderer":RenderingServer.get_video_adapter_name(),"occlusion":results,"failed":failures},"\t")+"\n")
	viewer.queue_free()
	await process_frame
	print("BRIDGE_ART_RENDER failed=", failures)
	quit(1 if failures else 0)
