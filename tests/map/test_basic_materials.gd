extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label_text: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		printerr("FAIL ",label_text)
func run() -> void:
	var shared: TileSet = load("res://maps/godot/tilesets/leyton_surface_v2.tres")
	var original_metadata: Dictionary = shared.get_meta("pipeline").duplicate(true)
	var original_sources := shared.get_source_count()
	var replaced := 0
	for index in 8:
		var map: Node = load("res://maps/leyton/scenes/m%02d.tscn" % (index+1)).instantiate()
		map.use_surface = false
		root.add_child(map)
		var states: Array = []
		for state in 3:
			map.set_gate_state(state)
			var mask := PackedByteArray()
			for y in map.map_size_cells.y:
				for x in map.map_size_cells.x:
					mask.append(1 if map.is_cell_walkable(Vector2i(x,y)) else 0)
			states.append(mask)
		map.set_surface_enabled(true)
		for state in 3:
			map.set_gate_state(state)
			var same := true
			for y in map.map_size_cells.y:
				for x in map.map_size_cells.x:
					same = same and int(map.is_cell_walkable(Vector2i(x,y)))==states[state][y*map.map_size_cells.x+x]
			check(same,map.map_id+" full collision mask state "+str(state))
		var terrain: TileMapLayer = map.get_layer("地形")
		var remaining := 0
		for cell: Vector2i in terrain.get_used_cells():
			if terrain.get_cell_source_id(cell)==1000: remaining += 1
			if terrain.get_cell_source_id(cell)==1001: replaced += 1
		check(remaining==0,map.map_id+" no flat gray terrain cells")
		check(map.surface_qa.conflicts.is_empty(),map.map_id+" no transition conflicts")
		map.set_surface_enabled(false)
		check(terrain.tile_set.get_source_count()==1,map.map_id+" diagnostic graybox preserved")
		map.free()
	check(replaced>0,"generated materials actually used")
	check(shared.get_source_count()==original_sources,"shared sources unchanged")
	check(shared.get_meta("pipeline")==original_metadata,"shared metadata unchanged")
	print("BASIC_MATERIALS passed=",passed," failed=",failed," textured_cells=",replaced)
	quit(1 if failed else 0)
