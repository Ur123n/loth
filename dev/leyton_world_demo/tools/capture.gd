extends SceneTree
var failed := 0
var captures: Array = []
func _initialize() -> void: call_deferred("run")
func shot(demo: Node, name_text: String) -> void:
	demo._refresh()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "res://dev/leyton_world_demo/qa/"+name_text+".png"
	if image.save_png(path)!=OK: failed += 1
	captures.append({"name":name_text,"map":demo.current.map_id,"path":path})
	print("WORLD_CAPTURE ",name_text)
func run() -> void:
	root.size = Vector2i(1280,720)
	var demo: Node = load("res://dev/leyton_world_demo/world_demo.tscn").instantiate()
	root.add_child(demo)
	demo.set_physics_process(false)
	await shot(demo,"monastery_spawn")
	demo.overview = true
	await shot(demo,"monastery_overview")
	demo.overview = false
	Input.action_press("move_down")
	for i in 400:
		demo._physics_process(1.0/60)
		if demo.current.map_id=="M05": break
	Input.action_release("move_down")
	if demo.current.map_id!="M05": failed += 1
	await shot(demo,"north_exterior_arrival")
	demo.route_panel.visible = true
	await shot(demo,"world_route")
	demo.route_panel.visible = false
	demo.player.position = Vector2(44,57)*48
	demo.cycle_gate()
	await shot(demo,"north_gate_closed")
	demo.state = 0
	demo.load_map("M01")
	demo.overview = true
	await shot(demo,"leyton_center")
	demo.overview = false
	demo.load_map("M08","west")
	await shot(demo,"east_residential_arrival")
	var file := FileAccess.open("res://dev/leyton_world_demo/qa/render.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":RenderingServer.get_video_adapter_name(),"failed":failed,"captures":captures},"\t")+"\n")
	print("WORLD_RENDER failed=",failed)
	quit(1 if failed else 0)
