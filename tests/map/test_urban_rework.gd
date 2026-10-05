extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		printerr("FAIL ",text)
func run() -> void:
	for id in ["m01","m02","m03","m04"]:
		var map: Node = load("res://maps/leyton/scenes/%s.tscn" % id).instantiate()
		root.add_child(map)
		var tags: Dictionary = map.palette.count_materials(map.get_layer("地形"))
		check(tags.get("grass",0)==0,id+" no urban grass")
		check(tags.get("urban_pavers",0)>1000,id+" paved city")
		var patterns := 0
		var props := 0
		for child in map.get_building_root().get_children():
			if child.has_method("get_pattern_id"):
				patterns += 1
				check(child.get_node_or_null("Visual") is Sprite2D,id+" complete house sprite")
			if child.has_method("get_prop_id"):
				props += 1
				check(child.has_independent_collision(),id+" prop collision")
		check(patterns>=15,id+" repeated complete patterns")
		check(props>=8,id+" decorations placed")
		check(map.get_building_root().y_sort_enabled,id+" common sort domain")
		var density := 0.0
		for entry: Dictionary in map.layout.structures: density += entry.rect[2]*entry.rect[3]
		density /= map.map_size_cells.x*map.map_size_cells.y
		check(density>=(0.32 if id=="m01" else 0.40),id+" footprint density "+str(density))
		if id=="m02":
			var points: Array = map.layout.roads[0].points
			var length := 0.0
			for i in range(1,points.size()): length += Vector2(points[i][0],points[i][1]).distance_to(Vector2(points[i-1][0],points[i-1][1]))
			check(points.size()>=7 and length>95,"noble winding primary route")
			check(map.layout.roads.size()>=5,"noble branching loops")
		var masks: Array = []
		for entry: Dictionary in map.layout.props:
			var r: Rect2i = map.rect(entry.block_rect)
			check(not map.is_cell_walkable(r.get_center()),id+" prop blocks semantic movement")
		map.free()
	var monastery: Node = load("res://maps/godot/scenes/iserra_monastery_highlands.tscn").instantiate()
	root.add_child(monastery)
	check(monastery.get_meta("environment_revision","")=="urban_rework_v1","latest monastery revision")
	check(monastery.get_buildings().size()==1,"complete monastery preserved")
	check(monastery.validate().is_empty() and monastery.validate_buildings().is_empty(),"monastery contracts")
	check(monastery.validate_spawn_walkable().is_empty(),"monastery spawn")
	check(monastery.get_layer("植被").get_used_cells().is_empty(),"vegetation migrated out of terrain tiles")
	var props := 0
	var patterns := 0
	for child in monastery.get_building_root().get_children():
		if child.has_method("get_prop_id"): props += 1
		if child.has_method("get_pattern_id"): patterns += 1
	check(props>=30 and patterns==2,"monastery independent landscape and service houses")
	check(monastery.has_node("Gameplay") and monastery.has_node("Navigation"),"separated responsibility nodes")
	monastery.free()
	print("URBAN_REWORK passed=",passed," failed=",failed)
	quit(1 if failed else 0)
