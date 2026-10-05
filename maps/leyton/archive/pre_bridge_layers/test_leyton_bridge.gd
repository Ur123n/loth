extends SceneTree
var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: " + message)

func run() -> void:
	var viewer: Node = load("res://maps/leyton/scenes/slice_test.tscn").instantiate()
	root.add_child(viewer)
	viewer.set_physics_process(false)
	for id in ["M04", "M01", "M04", "M07", "M04"]:
		viewer.load_map(id)
		var map: Node = viewer.current
		check(map.get_buildings().size() == (1 if id == "M04" else 0), id + " runtime instance count")
		if id != "M04":
			continue
		var bridge: Node = map.get_buildings()[0]
		check(bridge.get_top_left_cell() == Vector2i(42,59), "anchor placement")
		check(bridge.get_node("Visual/Base").texture.resource_path == "res://assets/buildings/leyton_cargo_bridge/visual/base.png", "loaded intended texture")
		var blocked := 0
		for y in 11:
			for x in 12:
				if not map.is_cell_walkable(Vector2i(42+x,59+y)):
					blocked += 1
		check(blocked == 18, "only 18 parapet cells blocked")
		for skin in [false, true, false, true]:
			map.set_surface_enabled(skin)
			check(map.get_buildings().size() == 1, "skin switch does not duplicate bridge")
			check(not map.can_occupy(map.cell_to_local(Vector2i(42,64)), Vector2(24,24)), "west rail blocks player")
			check(not map.can_occupy(map.cell_to_local(Vector2i(53,64)), Vector2(96,144)), "east rail blocks cart")
			var clear := true
			for y in range(57*48,72*48,6):
				clear = clear and map.can_occupy(Vector2(48*48,y), Vector2(96,144))
			check(clear, "continuous north-south cart crossing")
		check(map.is_cell_walkable(Vector2i(42,59)) and map.is_cell_walkable(Vector2i(53,69)), "open apron corners")
		check(not map.is_cell_walkable(Vector2i(41,64)) and not map.is_cell_walkable(Vector2i(54,64)), "water outside bridge blocked")
	viewer.queue_free()
	await process_frame
	print("LEYTON_BRIDGE passed=%d failed=%d" % [passed,failed])
	quit(1 if failed else 0)
