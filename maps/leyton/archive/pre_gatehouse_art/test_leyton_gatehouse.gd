extends SceneTree
const Baseline := preload("res://maps/leyton/tools/gate_baseline.gd")
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
	viewer.load_map("M07")
	await process_frame
	var map: Node = viewer.current
	var gate: Node = map.get_buildings()[0]
	check(map.get_buildings().size() == 1, "one independent gatehouse")
	check(gate.get_building_id() == "leyton_west_gatehouse", "correct gatehouse instance")
	check(gate.get_top_left_cell() == Vector2i(85,32), "placement retained")
	var data = gate.get_building_data()
	check(data.get_footprint_size() == Vector2i(11,16), "11x16 footprint")
	check(data.get_occupied_cells().size() == 176 and data.get_walkable_cells().size() == 66 and data.get_blocked_cells().size() == 110, "ground masks")
	check(data.raw.doors.size() == 2 and data.raw.doors[0].width_tiles == 6 and data.raw.doors[1].width_tiles == 6, "two six-cell entrances")
	check(gate.get_node("Visual/WallWalk").z_index == 4 and gate.get_node("Visual/Floor").z_index == -1, "independent upper and ground visual levels")
	var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://maps/leyton/qa/gatehouse_before.json"))
	for state in 3:
		map.set_gate_state(state)
		await physics_frame
		await physics_frame
		check(Baseline.signature(map,false) == before.states[state].ground, "whole-map ground baseline state %d" % state)
		check(Baseline.signature(map,true) == before.states[state].wall, "whole-map upper baseline state %d" % state)
		check(map.gate_barrier.visible == (state != 0), "barrier visual follows state")
		var query := PhysicsPointQueryParameters2D.new()
		query.position = map.cell_to_local(Vector2i(89,40))
		query.collision_mask = 2
		var hits: Array = map.get_world_2d().direct_space_state.intersect_point(query)
		var gate_hit := false
		for hit: Dictionary in hits:
			gate_hit = gate_hit or hit.collider == map.gate_body
		check(gate_hit == (state != 0), "physical lower-level blocker follows gate state")
		for size: Vector2 in [Vector2(24,24),Vector2(96,144)]:
			var all_clear := true
			for x in range(83*48,95*48,6):
				all_clear = all_clear and map.can_occupy(Vector2(x,40*48),size)
			check(all_clear == (state == 0), "continuous ground crossing for actor size " + str(size))
		var upper_clear := true
		for y in range(10*48,76*48,6):
			upper_clear = upper_clear and map.can_occupy(Vector2(93.5*48,y),Vector2(24,24),true)
		check(upper_clear, "wall route crosses gatehouse and water gate in every state")
		check(not map.can_occupy(Vector2(91.5*48,40*48),Vector2(24,24),true), "upper walk rejects outside lane")
		check(not map.can_occupy(Vector2(93.5*48,64*48),Vector2(24,24)), "water gate does not open ground river route")
		check(map.can_occupy(Vector2(93.5*48,64*48),Vector2(24,24),true), "same XY is walkable only on wall")
		for skin in [false,true]:
			map.set_surface_enabled(skin)
			check(map.get_buildings().size() == 1 and map.gate_state == state, "skin retains gate instance and state")
			check(map.is_cell_walkable(Vector2i(89,40)) == (state == 0), "skin preserves ground gate blocking")
	viewer.state = 0
	map.set_gate_state(0)
	viewer.player.position = map.cell_to_local(Vector2i(87,49))
	check(viewer.use_stairs() and viewer.on_wall and viewer.player.z_index == 5, "stairs raise actor above upper surface")
	check(not viewer.toggle_cart(), "cart forbidden on upper walk")
	check(viewer.use_stairs() and not viewer.on_wall and viewer.player.z_index == 0, "stairs restore ground depth")
	viewer.cart = true
	check(not viewer.use_stairs(), "cart cannot ascend stairs")
	viewer.cart = false
	viewer.player.position = map.cell_to_local(Vector2i(89,40))
	check(not viewer.cycle_gate(), "gate cannot close around ground actor")
	viewer.player.position = map.cell_to_local(Vector2i(87,49))
	check(viewer.use_stairs(), "ascend for transition test")
	var old_map: WeakRef = weakref(map)
	var old_gate: WeakRef = weakref(gate)
	viewer.load_map("M04")
	await process_frame
	check(old_map.get_ref() == null and old_gate.get_ref() == null, "old gatehouse freed with map")
	check(not viewer.on_wall and viewer.player.z_index == 0, "map transition resets elevation")
	viewer.load_map("M07")
	await process_frame
	check(viewer.current.get_buildings().size() == 1, "return creates one gatehouse")
	viewer.player.position = viewer.current.get_spawn_position()
	for expected in [1,2,0]:
		check(viewer.cycle_gate() and viewer.current.gate_state == expected, "viewer cycles all three states")
	# Closed M07's east arrival lies within its lower gate volume. Reject it
	# before retiring M04, for both player and cart; opening restores the route.
	for cart_mode: bool in [false,true]:
		viewer.cart = cart_mode
		viewer.state = 1
		viewer.load_map("M04")
		var source_map: Node = viewer.current
		var actor_id: int = viewer.player.get_instance_id()
		viewer.player.position = Vector2(1.25,40)*48
		viewer._physics_process(0)
		await process_frame
		check(viewer.current == source_map and viewer.current.map_id == "M04", "closed destination keeps source map")
		check(viewer.player.get_instance_id() == actor_id and viewer.current.can_occupy(viewer.player.position,viewer.footprint()), "rejected arrival retains actor at safe departure")
		check(viewer.get_child_count() == 2, "rejected candidate map freed")
		viewer.state = 0
		viewer.player.position = Vector2(1.25,40)*48
		viewer._physics_process(0)
		await process_frame
		check(viewer.current.map_id == "M07" and viewer.current.can_occupy(viewer.player.position,viewer.footprint()), "open destination restores safe transition")
	viewer.queue_free()
	await process_frame
	print("LEYTON_GATEHOUSE passed=%d failed=%d" % [passed,failed])
	quit(1 if failed else 0)
