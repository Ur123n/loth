extends "res://dev/leyton_world_demo/tools/capture.gd"
func run() -> void:
	root.size = Vector2i(1280,720)
	var demo: Node = load("res://dev/leyton_world_demo/world_demo.tscn").instantiate()
	root.add_child(demo)
	demo.set_physics_process(false)
	await shot(demo,"rework_monastery_spawn")
	demo.load_map("M02")
	demo.overview = true
	await shot(demo,"rework_noble_overview")
	demo.overview = false
	demo.player.position = demo.current.cell_to_local(Vector2i(34,32))
	await shot(demo,"rework_noble_street")
	demo.player.position = demo.current.cell_to_local(Vector2i(58,53))
	await shot(demo,"rework_noble_south")
	demo.load_map("M03")
	demo.player.position = demo.current.cell_to_local(Vector2i(48,19))
	await shot(demo,"rework_slum_street")
	demo.load_map("MONASTERY")
	demo.player.position = demo.current.cell_to_local(Vector2i(12,70))
	await shot(demo,"rework_monastery_services")
	print("REWORK_DETAILS failed=",failed)
	quit(1 if failed else 0)
