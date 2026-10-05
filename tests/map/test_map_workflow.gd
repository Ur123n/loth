extends SceneTree

var passed := 0
var failed := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		print("FAIL ", label)


func _run() -> void:
	var map = load("res://dev/map_workflow_lab/map_workflow_lab.tscn").instantiate()
	root.add_child(map)
	await process_frame
	await physics_frame
	var data = map.hall.get_building_data()
	check(data.get_footprint_size() == Vector2i(12, 10), "12x10 footprint")
	check(data.get_doors().size() == 2, "two declared doors")
	for child_name in ["Collision", "Doors", "Interaction"]:
		check(map.hall.get_node(child_name).position == -data.get_anchor_local_px(), "logical anchor " + child_name)
	map.hall._apply_anchor()
	check(map.hall.get_node("Collision").position == -data.get_anchor_local_px(), "anchor application is idempotent")
	check(data.is_cell_walkable(Vector2i(5, 9)), "south entrance open")
	check(data.is_cell_walkable(Vector2i(5, 0)), "north entrance open")
	check(data.is_cell_blocked(Vector2i(2, 9)), "south wall blocks")
	check(data.is_cell_occluded(Vector2i(5, 5)), "interior roof mask")
	var route_ok := true
	for y in range(4, 17):
		route_ok = route_ok and map.is_cell_walkable(Vector2i(11, y))
	check(route_ok, "north-south route connects through both doors")
	var outside_ok := true
	for y in range(4, 16):
		outside_ok = outside_ok and map.is_cell_walkable(Vector2i(5, y)) and map.is_cell_walkable(Vector2i(18, y))
	check(outside_ok, "both exterior side paths open")
	map.player.set_physics_process(false)
	map.player.position = Vector2(552, 504)
	await process_frame
	await process_frame
	check(not map.hall.is_roof_visible(), "roof hides inside")
	map.player.position = Vector2(552, 792)
	await process_frame
	await process_frame
	check(map.hall.is_roof_visible(), "roof restores outside")
	var bands := 0
	for child in map.get_node("建筑对象").get_children():
		if child.has_meta("semantic_band_id"):
			bands += 1
			check(child.z_index == map.player.z_index, "band shares player z index")
	check(bands == 4, "semantic bands instantiated")
	map.player.position = Vector2(408, 790)
	await physics_frame
	var hit = map.player.move_and_collide(Vector2(0, -150))
	check(hit != null, "physical south wall stops player")
	map.player.position = Vector2(552, 790)
	await physics_frame
	hit = map.player.move_and_collide(Vector2(0, -240))
	check(hit == null, "physical doorway admits player")
	var validator = load("res://core/building/building_placer.gd").new()
	var report: Dictionary = validator.validate_building("workflow_hall")
	check(bool(report.get("ok", false)), "package and prefab validator")
	if not report.get("ok", false):
		print(JSON.stringify(report))
	map.queue_free()
	await process_frame
	print("RESULT: passed=%d failed=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)
