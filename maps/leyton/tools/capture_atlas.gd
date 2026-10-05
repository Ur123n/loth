extends SceneTree
var failed := 0
var captures: Array = []
func _initialize() -> void: call_deferred("run")
func capture(viewer: Node, name_text: String) -> Image:
	viewer._refresh()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var shot := root.get_texture().get_image()
	var path := "res://maps/leyton/qa/atlas_%s.png" % name_text
	var err := shot.save_png(path)
	if err != OK: failed += 1
	captures.append({"map_id":viewer.current.map_id,"path":path,"error":err})
	print("ATLAS_CAPTURE ",name_text," error=",err)
	return shot
func run() -> void:
	root.size = Vector2i(1280,720)
	var viewer: Node = load("res://maps/leyton/scenes/slice_test.tscn").instantiate()
	root.add_child(viewer)
	viewer.set_physics_process(false)
	viewer.overview = true
	var contact := Image.create(1280,1440,false,Image.FORMAT_RGB8)
	for index in 8:
		viewer.load_map("M%02d" % (index+1))
		var shot := await capture(viewer,"m%02d_overview" % (index+1))
		shot.resize(640,360,Image.INTERPOLATE_NEAREST)
		shot.convert(Image.FORMAT_RGB8)
		var origin := Vector2i((index%2)*640,(index/2)*360)
		contact.blit_rect(shot,Rect2i(0,0,640,360),origin)
		if contact.get_region(Rect2i(origin,Vector2i(640,360))).get_data() != shot.get_data():
			failed += 1
	# Keep aspect ratio in the contact sheet; full-size originals remain canonical.
	if contact.save_png("res://maps/leyton/qa/atlas_contact_sheet.png") != OK: failed += 1
	viewer.overview = false
	for id in ["M05","M06","M08"]:
		viewer.state = 0
		viewer.load_map(id)
		viewer.player.position = viewer.current.cell_to_local(viewer.current.rect(viewer.current.layout.gate).get_center())
		await capture(viewer,id.to_lower()+"_open_gate")
		viewer.state = 2
		viewer.current.set_gate_state(2)
		viewer.player.position = viewer.current.cell_to_local(Vector2i(viewer.current.layout.stairs_ground[0],viewer.current.layout.stairs_ground[1]))
		if not viewer.use_stairs(): failed += 1
		await capture(viewer,id.to_lower()+"_upper_sealed")
	viewer.state = 0
	viewer.load_map("M01")
	viewer.load_map("M08","west")
	await capture(viewer,"residential_arrival")
	var file := FileAccess.open("res://maps/leyton/qa/atlas_render.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":RenderingServer.get_video_adapter_name(),"captures":captures,"failed":failed},"\t")+"\n")
	viewer.queue_free()
	await process_frame
	print("ATLAS_RENDER failed=",failed)
	quit(1 if failed else 0)
