extends SceneTree

var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS  ", label)
	else:
		failed += 1
		printerr("FAIL  ", label)

func run() -> void:
	var active_text := FileAccess.get_file_as_string("res://maps/leyton/slice.json")
	var candidate_text := FileAccess.get_file_as_string("res://dev/map_versions/map_rework_20261005_r01/leyton_m02/slice.candidate.json")
	check(active_text == candidate_text, "M02候选布局文档与活动slice逐字一致")

	var active_m02: Node2D = load("res://maps/leyton/scenes/m02.tscn").instantiate()
	root.add_child(active_m02)
	var candidate_m02: Node2D = load("res://dev/map_versions/map_rework_20261005_r01/leyton_m02/candidate_m02.tscn").instantiate()
	root.add_child(candidate_m02)
	check(active_m02.map_size_cells == candidate_m02.map_size_cells and candidate_m02.map_size_cells == Vector2i(88, 80), "M02尺寸保持88×80")
	check(active_m02.get_spawn_position() == candidate_m02.get_spawn_position(), "M02出生点不变")
	check(JSON.stringify(active_m02.layout.exits) == JSON.stringify(candidate_m02.layout.exits), "M02出口不变")
	check(active_m02.layout.structures.size() == candidate_m02.layout.structures.size() and candidate_m02.layout.structures.size() == 34, "M02保持34个结构占地")
	var walkability_equal := true
	for y in candidate_m02.map_size_cells.y:
		for x in candidate_m02.map_size_cells.x:
			var cell := Vector2i(x, y)
			if active_m02.is_cell_walkable(cell) != candidate_m02.is_cell_walkable(cell):
				walkability_equal = false
	check(walkability_equal, "M02全部7040格通行结果不变")
	check(candidate_m02.candidate_visuals.size() == 34, "M02的34个宅邸均绑定候选材质")
	check(candidate_m02.candidate_variant_counts == [12, 11, 11], "M02三套材质按12/11/11轮换")
	candidate_m02.set_candidate_art_enabled(false)
	var all_disabled := true
	for visual: Sprite2D in candidate_m02.candidate_visuals:
		all_disabled = all_disabled and visual.material == null
	check(all_disabled, "M02可切回活动材质")
	candidate_m02.set_candidate_art_enabled(true)
	var all_enabled := true
	for visual: Sprite2D in candidate_m02.candidate_visuals:
		all_enabled = all_enabled and visual.material is ShaderMaterial
	check(all_enabled, "M02可恢复候选材质")
	root.remove_child(active_m02)
	active_m02.queue_free()
	root.remove_child(candidate_m02)
	candidate_m02.queue_free()
	await process_frame

	var monastery: Node2D = load("res://dev/map_versions/map_rework_20261005_r01/iserra/candidate_monastery.tscn").instantiate()
	root.add_child(monastery)
	await process_frame
	check(monastery.map_size_cells == Vector2i(84, 88), "修道院地图尺寸保持84×88")
	check(monastery.get_node("标记").get_child_count() == 12, "修道院12个标记保持")
	check(monastery.get_spawn_position() == monastery.cell_to_local(Vector2i(45, 74)), "修道院Demo出生格保持(45,74)")
	var base := monastery.get_node("建筑对象/IserraMonasteryHighland/Visual/Base") as Sprite2D
	check(base.material is ShaderMaterial, "修道院Base绑定候选材质")
	check((base.material as ShaderMaterial).get_shader_parameter("logical_canvas") == Vector2(2400, 2880), "修道院显式使用2400×2880逻辑画布")
	var band_regions: Array[Sprite2D] = []
	for band in monastery.get_node("建筑对象").get_children():
		if band.has_meta("semantic_band_id"):
			band_regions.append(band.get_node("Region") as Sprite2D)
	check(band_regions.size() == 5, "修道院五个语义遮挡带存在")
	var bands_enabled := true
	for region in band_regions:
		bands_enabled = bands_enabled and region.material == base.material
	check(bands_enabled, "修道院五个可见遮挡带绑定候选材质")
	monastery.set_candidate_art_enabled(false)
	check(base.material == null, "修道院可切回活动材质")
	var bands_disabled := true
	for region in band_regions:
		bands_disabled = bands_disabled and region.material == null
	check(bands_disabled, "修道院五个遮挡带可切回活动材质")
	monastery.set_candidate_art_enabled(true)
	check(base.material is ShaderMaterial, "修道院可恢复候选材质")
	root.remove_child(monastery)
	monastery.queue_free()
	await process_frame

	var demo: Node2D = load("res://dev/map_versions/map_rework_20261005_r01/review.tscn").instantiate()
	root.add_child(demo)
	check(demo.current.map_id == "MONASTERY", "候选九图入口加载修道院")
	demo.load_map("M02")
	check(demo.current.map_id == "M02" and demo.current.has_meta("candidate_revision"), "候选九图入口加载M02候选")
	root.remove_child(demo)
	demo.queue_free()
	await process_frame

	print("MAP_REWORK_R01 passed=%d failed=%d" % [passed, failed])
	quit(1 if failed else 0)
