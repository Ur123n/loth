extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var demo: Node = load("res://dev/leyton_world_demo/world_demo.tscn").instantiate()
	root.add_child(demo)
	demo.set_physics_process(false)
	print("WORLD_SPAWN map=",demo.current.map_id," cell=",demo.current.local_to_cell(demo.player.position)," clear=",demo.current.can_occupy(demo.player.position,demo.footprint()))
	Input.action_press("move_down")
	for i in 400:
		demo._physics_process(1.0/60)
		if demo.current.map_id=="M05": break
	Input.action_release("move_down")
	var ok: bool = demo.current.map_id=="M05"
	print("WORLD_DOWN arrived=",demo.current.map_id," position=",demo.player.position)
	demo.queue_free()
	await process_frame
	quit(0 if ok else 1)
