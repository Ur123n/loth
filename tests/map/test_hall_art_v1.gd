extends SceneTree

var passed := 0
var failed := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		print("FAIL ", label)

func _run() -> void:
	var scene = load("res://dev/hall_art_v1/hall_art_v1.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	check(scene.hall.get_building_id() == "workflow_hall", "same verified building geometry")
	for key in ["Ground", "Base", "Roof"]:
		var material: ShaderMaterial = scene.hall.get_node("Visual/" + key).material
		check(material != null and material.get_shader_parameter("art_surface") != null, "surface loaded " + key)
		check(material.get_shader_parameter("map_colors").size() == 32, "map palette " + key)
	var bands := 0
	for band in scene.get_node("建筑对象").get_children():
		if band.has_meta("semantic_band_id"):
			bands += 1
			check(band.get_node("Region").material == scene.art_materials["Base"], "semantic band receives wall material")
	check(bands == 4, "four original bands")
	scene.set_art_enabled(false)
	check(scene.hall.get_node("Visual/Base").material == null, "graybox comparison toggle")
	scene.set_art_enabled(true)
	scene.player.set_physics_process(false)
	scene.player.position = Vector2(408, 790)
	await physics_frame
	check(scene.player.move_and_collide(Vector2(0, -150)) != null, "wall collision preserved")
	scene.player.position = Vector2(552, 790)
	await physics_frame
	check(scene.player.move_and_collide(Vector2(0, -240)) == null, "door passage preserved")
	await process_frame
	await process_frame
	check(not scene.hall.is_roof_visible(), "art roof hides inside")
	scene.player.position = Vector2(552, 792)
	await process_frame
	await process_frame
	check(scene.hall.is_roof_visible(), "art roof restores outside")
	scene.queue_free()
	await process_frame
	print("RESULT: passed=%d failed=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)
