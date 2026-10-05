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

func reachable(map: Node, start: Vector2i, goal: Vector2i, size: Vector2, wall := false) -> bool:
	var open: Array[Vector2i] = [start]
	var seen := {start: true}
	var cursor := 0
	while cursor < open.size():
		var cell := open[cursor]
		cursor += 1
		if cell == goal:
			return true
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + step
			if not seen.has(next) and map.can_occupy(map.cell_to_local(next), size, wall):
				seen[next] = true
				open.append(next)
	return false

func run() -> void:
	for id in ["m01", "m04", "m07"]:
		var map: Node = load("res://maps/leyton/scenes/%s.tscn" % id).instantiate()
		root.add_child(map)
		check(map.get_tile_size() == Vector2i(48, 48), id + " 48px")
		check(map.map_size_cells == Vector2i(96, 80), id + " dimensions")
		check(map.can_occupy(map.get_spawn_position(), Vector2(96, 144)), id + " cart spawn")
		check(not map.can_occupy(Vector2(-1, -1), Vector2(24, 24)), id + " boundary")
		var start: Vector2i = map.local_to_cell(map.get_spawn_position())
		for ex: Dictionary in map.layout.exits:
			if not ex.enabled:
				check(not map.is_cell_walkable(map.exit_rect(ex).get_center()), id + " unfinished exit blocked")
				continue
			var arrival: Vector2 = map.arrival(ex.edge)
			check(not map.exit_rect(ex).has_point(map.local_to_cell(arrival)), id + " return guard")
			check(map.can_occupy(arrival, Vector2(96, 144)), id + " cart arrival")
			check(reachable(map, start, map.local_to_cell(arrival), Vector2(96, 144)), id + " cart reaches " + ex.edge)
		for bridge: Array in map.layout.bridges:
			var r: Rect2i = map.rect(bridge)
			var a := Vector2i(r.get_center().x, r.position.y - 2)
			var b := Vector2i(r.get_center().x, r.end.y + 2)
			# Explicit deck traversal; M07 bridge is east-west.
			if id == "m07":
				a = Vector2i(r.position.x - 2, 40)
				b = Vector2i(r.end.x + 2, 40)
			check(reachable(map, a, b, Vector2(96, 144)), id + " cart bridge")
			var deck_clear := true
			var from: Vector2 = map.cell_to_local(a)
			var to: Vector2 = map.cell_to_local(b)
			for step in 101:
				deck_clear = deck_clear and map.can_occupy(from.lerp(to, step / 100.0), Vector2(96, 144))
			check(deck_clear, id + " continuous cart deck")
		check(not map.is_cell_walkable(Vector2i(2, 64)) if id != "m07" else not map.is_cell_walkable(Vector2i(93, 64)), id + " water not navigable")
		if id == "m07":
			check(not map.is_cell_walkable(Vector2i(63, 52)), "parking leaves river clear")
			check(reachable(map, Vector2i(80, 40), Vector2i(93, 40), Vector2(96, 144)), "open gate cart")
			for state in [1, 2]:
				map.set_gate_state(state)
				check(not reachable(map, Vector2i(80, 40), Vector2i(93, 40), Vector2(24, 24)), "closed gate player")
				check(not reachable(map, Vector2i(80, 40), Vector2i(93, 40), Vector2(96, 144)), "closed gate cart")
				check(reachable(map, Vector2i(93, 49), Vector2i(93, 10), Vector2(24, 24), true), "wall over gate")
				check(reachable(map, Vector2i(93, 49), Vector2i(93, 75), Vector2(24, 24), true), "wall over water gate")
			check(not map.can_occupy(Vector2(91 * 48, 49 * 48), Vector2(24, 24), true), "wall edge")
			check(reachable(map, Vector2i(80, 40), Vector2i(87, 49), Vector2(24, 24)), "stairs accessible")
		root.remove_child(map)
		map.free()
	var viewer: Node = load("res://maps/leyton/scenes/slice_test.tscn").instantiate()
	root.add_child(viewer)
	viewer.set_physics_process(false)
	for route in [["M01", "west", "M04"], ["M04", "west", "M07"], ["M07", "east", "M04"], ["M04", "east", "M01"]]:
		viewer.load_map(route[0])
		for ex: Dictionary in viewer.current.layout.exits:
			if ex.edge == route[1]:
				viewer.player.position = viewer.current.cell_to_local(viewer.current.exit_rect(ex).get_center())
				break
		viewer._physics_process(0)
		check(viewer.current.map_id == route[2], "runtime transition " + str(route))
		viewer._physics_process(0)
		check(viewer.current.map_id == route[2], "no return loop")
	viewer.load_map("M07")
	viewer.player.position = viewer.current.cell_to_local(Vector2i(87, 49))
	check(viewer.use_stairs() and viewer.on_wall, "runtime ascend")
	check(not viewer.toggle_cart(), "cart cannot climb")
	check(viewer.use_stairs() and not viewer.on_wall, "runtime descend")
	viewer.player.position = Vector2(90 * 48, 40 * 48)
	check(not viewer.cycle_gate(), "gate cannot close on actor")
	viewer.queue_free()
	await process_frame
	print("LEYTON passed=%d failed=%d" % [passed, failed])
	quit(1 if failed else 0)
