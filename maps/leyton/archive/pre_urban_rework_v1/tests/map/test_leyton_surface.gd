extends SceneTree
var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label_text: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		printerr("FAIL ", label_text)

func run() -> void:
	for id in ["m01", "m04", "m07"]:
		var map: Node = load("res://maps/leyton/scenes/%s.tscn" % id).instantiate()
		map.use_surface = false
		root.add_child(map)
		var states: Array = []
		for state in 3:
			map.set_gate_state(state)
			var mask := PackedByteArray()
			for y in 80:
				for x in 96:
					mask.append(1 if map.is_cell_walkable(Vector2i(x, y)) else 0)
			states.append(mask)
		map.set_surface_enabled(true)
		check(map.use_surface, id + " surface enabled")
		check(map.surface_qa.conflicts.is_empty(), id + " autotile conflicts")
		check(map.surface_qa.changed > 0, id + " transitions generated")
		check(map.surface_qa.shore_cells > 0, id + " shore drawn")
		check(map.surface_qa.variant_cells > 0, id + " variants drawn")
		for state in 3:
			map.set_gate_state(state)
			var same := true
			for y in 80:
				for x in 96:
					same = same and int(map.is_cell_walkable(Vector2i(x, y))) == states[state][y * 96 + x]
			check(same, id + " all-cell collision unchanged state " + str(state))
		var terrain: TileMapLayer = map.get_layer("地形")
		var tags: Dictionary = map.palette.count_materials(terrain)
		check(tags.get("water_deep", 0) > 0, id + " water texture")
		check(tags.get("road_stone", 0) > 0, id + " road texture")
		check(tags.get("dirt", 0) > 0, id + " road verge")
		check(terrain.tile_set.tile_size == Vector2i(48, 48), id + " pixel scale")
		var shore_safe := true
		var snapshot := {}
		for cell: Vector2i in terrain.get_used_cells():
			var tag: String = map.palette.tag_of_cell(terrain, cell)
			if tag.begins_with("shore_"):
				shore_safe = shore_safe and map.cells[cell] == 2 and not map.is_cell_walkable(cell)
			snapshot[cell] = [terrain.get_cell_source_id(cell), terrain.get_cell_atlas_coords(cell)]
		check(shore_safe, id + " shore stays in blocked water")
		if id == "m04":
			check(map.palette.tag_of_cell(terrain, Vector2i(20, 62)) == "shore_1", "north grass bank")
			check(map.palette.tag_of_cell(terrain, Vector2i(20, 65)) == "shore_9", "south grass bank")
		map.set_surface_enabled(true)
		var stable := true
		for cell: Vector2i in snapshot:
			stable = stable and snapshot[cell] == [terrain.get_cell_source_id(cell), terrain.get_cell_atlas_coords(cell)]
		check(stable, id + " stable coordinate variants")
		map.set_surface_enabled(false)
		check(not map.use_surface and terrain.tile_set.get_source_count() == 1, id + " graybox restored")
		map.free()
	for name in ["water_deep", "wall_top"]:
		var texture := load("res://assets/maps/leyton/surface_v1/tiles/%s.png" % name) as Texture2D
		var image := texture.get_image()
		check(image.get_size() == Vector2i(48, 48), name + " size")
		var x_match := true
		var y_match := true
		for i in 48:
			x_match = x_match and image.get_pixel(0, i) == image.get_pixel(47, i)
			y_match = y_match and image.get_pixel(i, 0) == image.get_pixel(i, 47)
		check(x_match and y_match, name + " seamless edges")
	for name in ["grass", "road_stone"]:
		var base: Image = load("res://assets/maps/leyton/surface_v2/tiles/%s.png" % name).get_image()
		for v in range(1, 4):
			var variant: Image = load("res://assets/maps/leyton/surface_v2/tiles/%s_variant_%d.png" % [name, v]).get_image()
			var edges_match := true
			for i in 48:
				edges_match = edges_match and variant.get_pixel(i, 0) == base.get_pixel(i, 0) and variant.get_pixel(i, 47) == base.get_pixel(i, 47)
				edges_match = edges_match and variant.get_pixel(0, i) == base.get_pixel(0, i) and variant.get_pixel(47, i) == base.get_pixel(47, i)
			check(edges_match, name + " variant shared edges " + str(v))
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/leyton/surface_v2/manifest.json"))
	for item: Dictionary in report.materials:
		check(item.std_luma < item.previous_std_luma * 0.8, item.name + " reduced contrast variation")
	print("LEYTON_SURFACE passed=%d failed=%d" % [passed, failed])
	quit(1 if failed else 0)
