extends SceneTree

var captures: Array = []
var failed := 0

func _initialize() -> void:
	_run.call_deferred()

func _shot(demo: Node2D, name_text: String) -> void:
	demo._refresh()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://dev/map_versions/map_rework_20261005_r01/qa/" + name_text + ".png"
	if root.get_texture().get_image().save_png(path) != OK:
		failed += 1
	captures.append({"map": demo.current.map_id, "path": path})
	print("RELEASE_CAPTURE ", name_text)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var demo: Node2D = load("res://dev/leyton_world_demo/world_demo.tscn").instantiate()
	root.add_child(demo)
	demo.set_physics_process(false)
	demo.overview = true
	await _shot(demo, "released_iserra_overview")
	demo.load_map("M02")
	demo.overview = true
	await _shot(demo, "released_m02_overview")
	demo.overview = false
	demo.player.position = Vector2(41, 13) * 48
	await _shot(demo, "released_m02_north_street")
	var file := FileAccess.open("res://dev/map_versions/map_rework_20261005_r01/qa/release_render.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer": RenderingServer.get_video_adapter_name(), "failed": failed, "captures": captures}, "\t") + "\n")
	file.close()
	quit(1 if failed else 0)
