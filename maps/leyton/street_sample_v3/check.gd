extends SceneTree
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func verify(ok: bool, label_text: String) -> void:
	checks += 1
	if not ok: failures.append(label_text)
func route(map: Node, points: Array, footprint: Vector2) -> bool:
	for i in range(points.size()-1):
		var a := Vector2(points[i][0],points[i][1])*48
		var b := Vector2(points[i+1][0],points[i+1][1])*48
		for step in range(ceili(a.distance_to(b)/6.0)+1):
			var pos := a.move_toward(b,step*6)
			if not map.can_occupy(pos,footprint):
				print("BLOCKED ",pos/48," footprint=",footprint)
				return false
	return true
func walk_reachable(map: Node, target: Vector2) -> bool:
	var start: Vector2i = map.local_to_cell(map.get_spawn_position())
	var goal: Vector2i = map.local_to_cell(target*48)
	var pending: Array[Vector2i] = [start]
	var visited := {start:true}
	var index := 0
	while index < pending.size():
		var cell := pending[index]
		index += 1
		if cell == goal: return true
		for offset: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next := cell+offset
			if not visited.has(next) and map.can_occupy(map.cell_to_local(next),Vector2(24,24)):
				visited[next] = true
				pending.append(next)
	return false
func capture(demo: Node, name_text: String) -> void:
	demo._refresh()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	verify(root.get_texture().get_image().save_png("res://maps/leyton/street_sample_v3/qa/"+name_text+".png")==OK,"save "+name_text)
func run() -> void:
	root.size = Vector2i(1280,900)
	var demo: Node = load("res://maps/leyton/street_sample_v3/review.tscn").instantiate()
	root.add_child(demo)
	demo.set_physics_process(false)
	var map: Node = demo.current
	verify(map.can_occupy(demo.player.position,Vector2(24,24)),"spawn")
	verify(route(map,map.layout.review.vehicle_path,Vector2(96,144)),"continuous vehicle sweep")
	for p: Array in map.layout.review.walk_points:
		verify(walk_reachable(map,Vector2(p[0],p[1])),"reachable "+str(p))
	for building: Node2D in map.block_visuals:
		verify(building.has_method("get_footprint_cells") and building.has_node("Collision"),"pattern contract "+building.name)
	verify(not map.can_occupy(Vector2(2,8)*48,Vector2(24,24)),"solid wing")
	verify(not map.can_occupy(Vector2(18,17)*48,Vector2(24,24)),"solid well")
	demo.player.position = Vector2(8,10)*48
	demo._refresh()
	verify(map.get_building_root().get_node("estate_south/GeneratedVisual/Roof").modulate.a < 0.5,"courtyard occlusion fade")
	demo.player.position = Vector2(10,19)*48
	demo._refresh()
	verify(map.get_building_root().get_node("estate_south").modulate.a == 1.0,"occlusion restores")
	if DisplayServer.get_name() != "headless":
		demo.overview = true
		await capture(demo,"textured_overview")
		demo.overview = false
		await capture(demo,"textured_street")
		demo.player.position = Vector2(8,10)*48
		await capture(demo,"textured_courtyard")
		demo.player.position = Vector2(22,23)*48
		await capture(demo,"textured_east_street")
		demo.current.set_art_enabled(false)
		demo.overview = true
		await capture(demo,"graybox_overview")
	var f := FileAccess.open("res://maps/leyton/street_sample_v3/qa/checks.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_video_adapter_name()},"\t"))
	print("STREET_SAMPLE checks=",checks," failed=",failures.size()," ",failures)
	quit(0 if failures.is_empty() else 1)
