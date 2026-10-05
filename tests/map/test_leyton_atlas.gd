extends SceneTree
var passed := 0
var failed := 0
var evidence: Array = []
const PLAYER := Vector2(24,24)
const CART := Vector2(96,144)
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label_text: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		printerr("FAIL: ",label_text)

func flood(map: Node, start: Vector2i, size: Vector2, upper := false) -> Dictionary:
	var todo: Array[Vector2i] = [start]
	var seen := {start:true}
	var blocked := {}
	var cursor := 0
	while cursor < todo.size():
		var cell := todo[cursor]
		cursor += 1
		for step in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var next: Vector2i = cell+step
			if seen.has(next) or blocked.has(next): continue
			if map.can_occupy(map.cell_to_local(next),size,upper):
				seen[next] = true
				todo.append(next)
			else: blocked[next] = true
	return seen

func exit_position(map: Node, ex: Dictionary, size: Vector2) -> Vector2:
	var middle := float(ex.offset)+float(ex.width)/2.0
	match ex.edge:
		"west": return Vector2(maxf(size.x/96.0,0.5),middle)*48
		"east": return Vector2(map.map_size_cells.x-maxf(size.x/96.0,0.5),middle)*48
		"north": return Vector2(middle,maxf(size.y/96.0,0.5))*48
	return Vector2(middle,map.map_size_cells.y-maxf(size.y/96.0,0.5))*48

func run() -> void:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://maps/leyton/slice.json"))
	check(doc.maps.size()==8,"eight districts")
	var links := 0
	for m: Dictionary in doc.maps:
		var map: Node = load("res://maps/leyton/scenes/%s.tscn" % String(m.map_id).to_lower()).instantiate()
		map.use_surface = false
		root.add_child(map)
		check(map.map_size_cells==Vector2i(m.size[0],m.size[1]),m.map_id+" dimensions")
		check(map.can_occupy(map.get_spawn_position(),CART),m.map_id+" cart spawn")
		var pedestrians := flood(map,map.local_to_cell(map.get_spawn_position()),PLAYER)
		var carts := flood(map,map.local_to_cell(map.get_spawn_position()),CART)
		var approaches: Array = []
		for structure: Dictionary in m.structures:
			var r: Rect2i = map.rect(structure.rect)
			var approach := Vector2i(-1,-1)
			for cell: Vector2i in pedestrians:
				if r.grow(1).has_point(cell) and not r.has_point(cell):
					approach = cell
					break
			check(approach.x>=0,m.map_id+" approach "+structure.label)
			approaches.append({"label":structure.label,"cell":[approach.x,approach.y],"interior_implemented":false})
		for ex: Dictionary in m.exits:
			if not ex.enabled:
				check(not map.is_cell_walkable(map.exit_rect(ex).get_center()),m.map_id+" world blocked")
				continue
			links += 1
			var destination: Vector2 = map.arrival(ex.edge)
			check(map.can_occupy(destination,CART),m.map_id+" arrival "+ex.edge)
			check(not map.exit_rect(ex).has_point(map.local_to_cell(destination)),m.map_id+" return guard "+ex.edge)
			check(pedestrians.has(map.local_to_cell(destination)),m.map_id+" player route "+ex.edge)
			check(carts.has(map.local_to_cell(destination)),m.map_id+" cart route "+ex.edge)
		if not m.gate.is_empty():
			var gate: Rect2i = map.rect(m.gate)
			var stairs := Vector2i(m.stairs_ground[0],m.stairs_ground[1])
			check(pedestrians.has(stairs),m.map_id+" stairs ground access")
			for state in 3:
				map.set_gate_state(state)
				check(map.can_occupy(map.cell_to_local(gate.get_center()),CART)==(state==0),m.map_id+" gate state "+str(state))
				check(map.gate_body.collision_layer==(0 if state==0 else 2),m.map_id+" physics state "+str(state))
				var path: Dictionary = flood(map,Vector2i(m.stairs_wall[0],m.stairs_wall[1]),PLAYER,true)
				var lane: Rect2i = map.rect(m.wall_walk)
				check(path.size()==lane.get_area(),m.map_id+" complete upper lane state "+str(state))
				check(map.can_occupy(map.cell_to_local(stairs),PLAYER),m.map_id+" usable stairs state "+str(state))
		# New districts must preserve logical passability when toggling the surface.
		if m.map_id in ["M02","M03","M05","M06","M08"]:
			map.set_gate_state(0)
			var before := PackedByteArray()
			for y in map.map_size_cells.y:
				for x in map.map_size_cells.x: before.append(int(map.is_cell_walkable(Vector2i(x,y))))
			map.set_surface_enabled(true)
			var same := true
			for y in map.map_size_cells.y:
				for x in map.map_size_cells.x: same = same and before[y*map.map_size_cells.x+x]==int(map.is_cell_walkable(Vector2i(x,y)))
			check(same,m.map_id+" surface logical equivalence")
		evidence.append({"map_id":m.map_id,"walkable_connected_player_cells":pedestrians.size(),"walkable_connected_cart_centers":carts.size(),"facility_approaches":approaches})
		map.free()
	check(links==14,"fourteen directed city connections")
	var viewer: Node = load("res://maps/leyton/scenes/slice_test.tscn").instantiate()
	viewer.surface = false
	root.add_child(viewer)
	viewer.set_physics_process(false)
	for is_cart in [false,true]:
		viewer.cart = is_cart
		for m: Dictionary in doc.maps:
			for ex: Dictionary in m.exits:
				if not ex.enabled: continue
				viewer.state = 0
				viewer.load_map(m.map_id)
				var trigger := exit_position(viewer.current,ex,viewer.footprint())
				var approach: Vector2 = viewer.current.arrival(ex.edge)
				var sweep_clear := true
				for step in 49:
					sweep_clear = sweep_clear and viewer.current.can_occupy(approach.lerp(trigger,step/48.0),viewer.footprint())
				check(sweep_clear,"continuous footprint reaches exit "+m.map_id+" "+ex.edge)
				viewer.player.position = trigger
				viewer._physics_process(0)
				var target: String = String(ex.to).split(":")[0]
				check(viewer.current.map_id==target,"runtime "+m.map_id+" to "+target+" cart="+str(is_cart))
				check(viewer.current.can_occupy(viewer.player.position,viewer.footprint()),"runtime destination safe")
				if ex.get("mode","")=="abstract_residential": check(viewer.status.contains("普通住宅区"),"residential journey explicit")
				viewer._physics_process(0)
				check(viewer.current.map_id==target,"no immediate return")
	# All city-side approaches reject arrival into closed gates for both footprints.
	for route in [["M02","north","M05"],["M03","south","M06"],["M04","west","M07"],["M01","east","M08"]]:
		for gate_state in [1,2]:
			for is_cart in [false,true]:
				viewer.cart = is_cart
				viewer.state = gate_state
				viewer.load_map(route[0])
				for ex: Dictionary in viewer.current.layout.exits:
					if ex.edge==route[1]: viewer.player.position = exit_position(viewer.current,ex,viewer.footprint())
				viewer._physics_process(0)
				check(viewer.current.map_id==route[0],"closed arrival rejected "+route[2])
				check(viewer.current.can_occupy(viewer.player.position,viewer.footprint()),"rejected actor safe")
		viewer.cart = false
		viewer.load_map(route[2])
		viewer.player.position = viewer.current.cell_to_local(Vector2i(viewer.current.layout.stairs_ground[0],viewer.current.layout.stairs_ground[1]))
		check(viewer.use_stairs() and viewer.on_wall,"runtime ascend "+route[2])
		check(not viewer.toggle_cart(),"cart stairs rejected")
		check(viewer.cycle_gate(),"four-gate control "+route[2])
		check(viewer.use_stairs() and not viewer.on_wall,"runtime descend "+route[2])
	viewer.queue_free()
	await process_frame
	var report := FileAccess.open("res://maps/leyton/qa/atlas_playable_report.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"maps":evidence,"directed_links":links,"passed":passed,"failed":failed},"\t")+"\n")
	print("LEYTON_ATLAS passed=%d failed=%d" % [passed,failed])
	quit(1 if failed else 0)
