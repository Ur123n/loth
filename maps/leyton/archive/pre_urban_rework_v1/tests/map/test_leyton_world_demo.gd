extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label_text: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		printerr("FAIL ",label_text)
func walk(demo: Node, action: String, frames: int, until := "") -> void:
	Input.action_press(action)
	for i in frames:
		demo._physics_process(1.0/60.0)
		if not until.is_empty() and demo.current.map_id==until: break
	Input.action_release(action)
func edge_point(map: Node, ex: Dictionary, size: Vector2) -> Vector2:
	var middle := float(ex.offset)+float(ex.width)/2.0
	match ex.edge:
		"west": return Vector2(maxf(size.x/96.0,0.5),middle)*48
		"east": return Vector2(map.map_size_cells.x-maxf(size.x/96.0,0.5),middle)*48
		"north": return Vector2(middle,maxf(size.y/96.0,0.5))*48
	return Vector2(middle,map.map_size_cells.y-maxf(size.y/96.0,0.5))*48
func run() -> void:
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dev/leyton_world_demo/qa/canonical_before.json"))
	for path: String in baseline:
		check(FileAccess.get_sha256("res://"+path.replace("\\","/")).to_upper()==String(baseline[path]).to_upper(),"canonical unchanged "+path)
	var demo: Node = load("res://dev/leyton_world_demo/world_demo.tscn").instantiate()
	demo.surface = false
	root.add_child(demo)
	demo.set_physics_process(false)
	var player_id: int = demo.player.get_instance_id()
	check(demo.current.map_id=="MONASTERY","initial monastery")
	check(demo.current.get_buildings().size()==1,"canonical complete monastery building")
	check(demo.current.can_occupy(demo.player.position,demo.footprint()),"spawn clear")
	check(not demo.current.can_occupy(Vector2(-1,-1),demo.footprint()),"boundary collision")
	walk(demo,"move_down",400,"M05")
	check(demo.current.map_id=="M05","real southbound monastery travel")
	check(demo.current.local_to_cell(demo.player.position).y==4,"north exterior arrival")
	demo._physics_process(0)
	check(demo.current.map_id=="M05","no return loop")
	walk(demo,"move_up",100,"MONASTERY")
	check(demo.current.map_id=="MONASTERY","real northbound return")
	check(demo.current.can_occupy(demo.player.position,demo.footprint()),"monastery return clear")
	demo._physics_process(0)
	check(demo.current.map_id=="MONASTERY","monastery return guard")
	# Holding down continues through the north exterior and its open gate into M02.
	walk(demo,"move_down",150,"M05")
	walk(demo,"move_down",1100,"M02")
	check(demo.current.map_id=="M02","walk full north approach and gate")
	var panel_key := InputEventKey.new()
	panel_key.pressed = true
	panel_key.physical_keycode = KEY_M
	demo._unhandled_input(panel_key)
	var old: Vector2 = demo.player.position
	walk(demo,"move_down",20)
	check(demo.route_panel.visible and demo.player.position==old,"route overlay pauses movement")
	demo._unhandled_input(panel_key)
	check(not demo.route_panel.visible,"route overlay closes")
	var links := 0
	var opposite := {"north":"south","south":"north","east":"west","west":"east"}
	for cart_mode in [false,true]:
		demo.cart = cart_mode
		for id: String in demo.world.maps:
			demo.state = 0
			demo.load_map(id)
			check(demo.current.can_occupy(demo.player.position,demo.footprint()),id+" spawn footprint "+str(cart_mode))
			var exits: Array = demo.current.layout.exits.duplicate(true)
			for ex: Dictionary in exits:
				if not ex.enabled: continue
				demo.load_map(id)
				var pieces: PackedStringArray = String(ex.to).split(":")
				check(pieces[1]==opposite[ex.edge],id+" destination edge")
				var start: Vector2 = demo.current.arrival(ex.edge)
				var target := edge_point(demo.current,ex,demo.footprint())
				var clear := true
				for step in 49: clear = clear and demo.current.can_occupy(start.lerp(target,step/48.0),demo.footprint())
				check(clear,id+" full-footprint exit approach "+ex.edge)
				demo.player.position = target
				demo._physics_process(0)
				check(demo.current.map_id==pieces[0],id+" real transition "+ex.to)
				check(demo.current.can_occupy(demo.player.position,demo.footprint()),id+" safe arrival")
				if ex.get("mode","")=="abstract_residential": check(demo.status.contains("普通住宅区"),"residential travel visible")
				demo._physics_process(0)
				check(demo.current.map_id==pieces[0],id+" stable arrival")
				if not cart_mode: links += 1
	check(links==16,"16 directed demo connections")
	check(demo.player.get_instance_id()==player_id,"same actor and camera across maps")
	for mode in [1,2]:
		demo.state = mode
		demo.cart = false
		demo.load_map("M02")
		demo.player.position = Vector2(44,0.5)*48
		demo._physics_process(0)
		check(demo.current.map_id=="M02","closed north gate refuses city arrival")
		check(demo.current.can_occupy(demo.player.position,demo.footprint()),"rejection safe")
		demo.load_map("MONASTERY")
		walk(demo,"move_down",400,"M05")
		check(demo.current.map_id=="M05","closed gate still permits exterior approach")
		walk(demo,"move_down",1100)
		check(demo.current.map_id=="M05" and demo.current.local_to_cell(demo.player.position).y<61,"closed gate stops south movement")
		demo.player.position = demo.current.cell_to_local(Vector2i(54,59))
		check(demo.use_stairs() and demo.on_wall,"north wall stairs remain available")
		check(demo.use_stairs() and not demo.on_wall,"north wall descend")
	demo.queue_free()
	await process_frame
	var standalone: Node = load("res://maps/leyton/scenes/m05.tscn").instantiate()
	standalone.use_surface = false
	root.add_child(standalone)
	check(not standalone.layout.exits[0].enabled and standalone.layout.exits[0].to=="world:north","standalone M05 unchanged")
	standalone.free()
	var result := {"passed":passed,"failed":failed,"directed_links":links}
	var file := FileAccess.open("res://dev/leyton_world_demo/qa/test_result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t")+"\n")
	print("LEYTON_WORLD_DEMO passed=",passed," failed=",failed)
	quit(1 if failed else 0)
