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
	var player_id: int = viewer.player.get_instance_id()
	var previous_map: WeakRef
	for id in ["M04", "M01", "M04", "M07", "M04"]:
		previous_map = weakref(viewer.current)
		viewer.load_map(id)
		await process_frame
		await process_frame
		var map: Node = viewer.current
		check(previous_map.get_ref() == null, "old map freed after transition")
		check(is_instance_valid(viewer.player) and viewer.player.get_instance_id() == player_id, "same player survives transition")
		check(viewer.player.get_parent() == map.get_building_root(), "player shares building sort parent")
		check(viewer.player.get_node("Camera2D").is_current(), "camera remains current")
		check(map.get_buildings().size() == (1 if id == "M04" else 0), id + " runtime instance count")
		if id != "M04":
			continue
		var bridge: Node = map.get_buildings()[0]
		check(bridge.get_top_left_cell() == Vector2i(42,59), "anchor placement")
		check(bridge.get_node("Visual/Base").texture.resource_path == "res://assets/buildings/leyton_cargo_bridge/visual/base.png", "loaded intended texture")
		check(bridge.get_node("Visual/Deck").z_index == -1, "deck stays below actor and rails")
		check(not bridge.get_node("Visual/Base").visible, "combined rail sprite hidden after bands are built")
		check(bridge.get_sort_band_nodes().size() == 5, "five nonoverlapping canvas bands, two nonempty rails")
		for band: Node2D in bridge.get_sort_band_nodes():
			check(band.get_parent() == viewer.player.get_parent() and band.z_index == viewer.player.z_index, "band and player share effective sorting")
			if String(band.get_meta("semantic_band_id")) in ["west_parapet", "east_parapet"]:
				check(is_equal_approx(band.position.y, 69*48), "rail sorting anchor at south parapet foot")
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
		viewer.player.position = Vector2(48,64)*48
		check(viewer.toggle_cart(), "cart can be enabled on deck")
		viewer._refresh()
		check(viewer.cart_visual.visible and viewer.cart_visual.get_parent() == viewer.player, "cart uses actor sort domain")
		check(not viewer.player.get_node("Body").visible, "cart mode hides player placeholder")
		check(viewer.toggle_cart(), "player can be restored on deck")
		viewer._refresh()
	check_art_layers()
	viewer.queue_free()
	await process_frame
	print("LEYTON_BRIDGE passed=%d failed=%d" % [passed,failed])
	quit(1 if failed else 0)

func check_art_layers() -> void:
	var path := "res://assets/buildings/leyton_cargo_bridge/"
	var deck := read_png(path + "visual/deck.png")
	var rails := read_png(path + "visual/base.png")
	var original := read_png(path + "source/registered_v2/registered.png")
	check(deck.get_size() == Vector2i(672,624) and rails.get_size() == deck.get_size(), "shared 672x624 canvas")
	var rail_rects := [Rect2i(48,96,48,432), Rect2i(576,96,48,432)]
	var reconstruction := true
	var valid_rails := true
	var valid_padding := true
	var apron_clear := true
	for y in 624:
		for x in 672:
			var p := Vector2i(x,y)
			var is_rail: bool = rail_rects[0].has_point(p) or rail_rects[1].has_point(p)
			var rc := rails.get_pixelv(p)
			var dc := deck.get_pixelv(p)
			reconstruction = reconstruction and (rc if is_rail else dc).is_equal_approx(original.get_pixelv(p))
			valid_rails = valid_rails and (is_zero_approx(dc.a) if is_rail else is_zero_approx(rc.a))
			if not Rect2i(48,48,576,528).has_point(p):
				valid_padding = valid_padding and is_zero_approx(rc.a) and is_zero_approx(dc.a)
			if Rect2i(48,48,576,48).has_point(p) or Rect2i(48,528,576,48).has_point(p):
				apron_clear = apron_clear and is_zero_approx(rc.a)
	check(reconstruction, "deck and rails reconstruct registered source exactly")
	check(valid_rails, "rail alpha stays within the 18 blocked cells and layers do not overlap")
	check(valid_padding, "one-cell outer padding is transparent")
	check(apron_clear, "both full apron rows contain no rail alpha")

func read_png(path: String) -> Image:
	var image := Image.new()
	check(image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK, "PNG decodes: " + path)
	return image
