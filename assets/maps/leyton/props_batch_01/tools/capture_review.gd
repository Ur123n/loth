extends SceneTree
const ROOT := "res://assets/maps/leyton/props_batch_01/"
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label_text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",label_text)
func frame() -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run() -> void:
	root.size = Vector2i(1280,960)
	var review: Node = load(ROOT+"review.tscn").instantiate()
	root.add_child(review)
	var original := await frame()
	check(original.save_png(ROOT+"qa/review_sheet.png")==OK,"review screenshot")
	var result: Array = []
	for item: Dictionary in review.items:
		var e: Dictionary = item.entry
		var sprite: Sprite2D = item.prop.get_node("Visual")
		var img := sprite.texture.get_image()
		var width: int = img.get_width()
		var at := Vector2i(-1,-1)
		for y in range(int(e.anchor[1])-5,0,-1):
			if img.get_pixel(width/2,y).a>0.95:
				at = Vector2i(width/2,y)
				break
		check(at.x>=0,e.id+" opaque sort probe")
		var point: Vector2 = item.prop.to_global(sprite.position+Vector2(at))
		item.probe.visible = true
		var states := {}
		for front in [false,true]:
			item.probe.position = item.prop.position+Vector2(0,1 if front else -1)
			item.marker.position = point-item.probe.position
			var shot := await frame()
			var pixel := shot.get_pixelv(Vector2i(point.round()))
			var visible: bool = pixel.r>0.9 and pixel.g<0.1 and pixel.b>0.9
			check(visible==front,e.id+" YSort front="+str(front))
			states["front" if front else "behind"] = {"visible":visible,"passed":visible==front}
		item.probe.visible = false
		check(item.prop.has_independent_collision(),e.id+" collision body")
		await physics_frame
		var params := PhysicsPointQueryParameters2D.new()
		params.position = item.prop.to_global(Vector2(0,-float(e.collision_size_px[1])/2))
		params.collision_mask = 2
		check(not item.prop.get_world_2d().direct_space_state.intersect_point(params).is_empty(),e.id+" physics query")
		result.append({"id":e.id,"sorting":states})
	var final_shot := await frame()
	check(final_shot.save_png(ROOT+"qa/review_sheet.png")==OK,"final clean screenshot")
	var file := FileAccess.open(ROOT+"qa/runtime.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":RenderingServer.get_video_adapter_name(),"checks":checks,"failed":failures,"assets":result},"\t")+"\n")
	print("PROPS_RUNTIME checks=",checks," failed=",failures)
	quit(1 if failures else 0)
