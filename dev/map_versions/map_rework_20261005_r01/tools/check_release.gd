extends SceneTree

var passed := 0
var failed := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS  ", label)
	else:
		failed += 1
		printerr("FAIL  ", label)

func _check_monastery(map: Node2D, entry: String) -> void:
	var building := map.get_node_or_null("建筑对象/IserraMonasteryHighland") as Node2D
	_check(building != null, entry + " loads Iserra building")
	if building == null:
		return
	var base := building.get_node("Visual/Base") as Sprite2D
	_check(base.material is ShaderMaterial, entry + " Base uses released material")
	_check(building.get_meta("active_surface_revision", "") == "iserra_surface_20261005_r01", entry + " uses released revision")
	var bands: Array = building.get_sort_band_nodes()
	_check(bands.size() == 5, entry + " has five YSort bands")
	var bound := bands.size() == 5
	for band in bands:
		var region := band.get_node("Region") as Sprite2D
		bound = bound and region.material == base.material
	_check(bound, entry + " visible bands use released material")

func _run() -> void:
	var main: Node2D = load("res://world/map/MainHighlandMap.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var default_map := main.get_node_or_null("MonasteryMap") as Node2D
	_check(default_map != null, "Default main loads highland map")
	if default_map != null:
		_check_monastery(default_map, "Default main")
	root.remove_child(main)
	main.queue_free()
	await process_frame

	var demo: Node2D = load("res://dev/leyton_world_demo/world_demo.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	await process_frame
	_check(demo.current.map_id == "MONASTERY", "World demo starts in monastery")
	_check_monastery(demo.current, "World demo")
	demo.load_map("M02")
	await process_frame
	_check(demo.current.map_id == "M02", "World demo loads active M02")
	_check(demo.current.get_meta("active_surface_revision", "") == "leyton_m02_surface_20261005_r01", "M02 uses released revision")
	_check(demo.current.candidate_visuals.size() == 34, "M02 binds all 34 houses")
	_check(demo.current.candidate_variant_counts == [12, 11, 11], "M02 uses three surface variants")
	var all_bound := true
	for visual: Sprite2D in demo.current.candidate_visuals:
		all_bound = all_bound and visual.material is ShaderMaterial
	_check(all_bound, "M02 visuals use released materials")
	root.remove_child(demo)
	demo.queue_free()
	await process_frame
	print("MAP_REWORK_RELEASE passed=%d failed=%d" % [passed, failed])
	quit(1 if failed else 0)
