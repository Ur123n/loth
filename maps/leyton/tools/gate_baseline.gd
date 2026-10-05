extends SceneTree

static func signature(map: Node, upper: bool) -> String:
	var bits := PackedByteArray()
	for y in map.map_size_cells.y:
		for x in map.map_size_cells.x:
			var cell := Vector2i(x,y)
			bits.append(int(map.can_occupy(map.cell_to_local(cell),Vector2(24,24),true) if upper else map.is_cell_walkable(cell)))
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(bits)
	return hash_context.finish().hex_encode()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var path := "res://maps/leyton/qa/gatehouse_before.json"
	if FileAccess.file_exists(path):
		printerr("Refusing to replace immutable pre-gatehouse baseline")
		quit(1)
		return
	var map: Node = load("res://maps/leyton/scenes/m07.tscn").instantiate()
	root.add_child(map)
	var states: Array = []
	for state in 3:
		map.set_gate_state(state)
		states.append({"state":state,"ground":signature(map,false),"wall":signature(map,true)})
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"map":"M07","states":states},"\t")+"\n")
	map.queue_free()
	await process_frame
	print("GATE_BASELINE states=3 saved")
	quit()
