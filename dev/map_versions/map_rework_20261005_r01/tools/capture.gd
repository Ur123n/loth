extends SceneTree

var failed := 0
var captures: Array = []

func _initialize() -> void:
	call_deferred("run")

func shot(demo: Node, name_text: String) -> void:
	demo._refresh()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "res://dev/map_versions/map_rework_20261005_r01/qa/" + name_text + ".png"
	if image.save_png(path) != OK:
		failed += 1
	captures.append({"name": name_text, "map": demo.current.map_id, "path": path})
	print("MAP_REWORK_CAPTURE ", name_text)

func run() -> void:
	root.size = Vector2i(1280, 720)
	var demo: Node = load("res://dev/map_versions/map_rework_20261005_r01/review.tscn").instantiate()
	root.add_child(demo)
	demo.set_physics_process(false)
	demo.overview = true
	await shot(demo, "iserra_candidate_overview")
	demo.current.set_candidate_art_enabled(false)
	await shot(demo, "iserra_active_overview")
	demo.current.set_candidate_art_enabled(true)
	demo.overview = false
	demo.player.position = Vector2(42, 54) * 48
	await shot(demo, "iserra_candidate_courtyard")
	demo.player.position = Vector2(42, 70) * 48
	await shot(demo, "iserra_candidate_gate")

	demo.load_map("M02")
	demo.overview = true
	await shot(demo, "m02_candidate_overview")
	demo.current.set_candidate_art_enabled(false)
	await shot(demo, "m02_active_overview")
	demo.current.set_candidate_art_enabled(true)
	demo.overview = false
	demo.player.position = Vector2(41, 13) * 48
	await shot(demo, "m02_candidate_north_street")

	var report := {
		"renderer": RenderingServer.get_video_adapter_name(),
		"failed": failed,
		"captures": captures,
		"candidate_revision": "map_rework_20261005_r01",
	}
	var file := FileAccess.open("res://dev/map_versions/map_rework_20261005_r01/qa/render.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	print("MAP_REWORK_RENDER failed=", failed)
	quit(1 if failed else 0)
