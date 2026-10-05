extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280,720)
	var main: Node = load("res://world/map/MainHighlandMap.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var result := image.save_png("res://maps/leyton/rework_v2/qa/production.png")
	print("PRODUCTION_CAPTURE result=",result," renderer=",RenderingServer.get_video_adapter_name())
	quit(0 if result==OK else 1)
