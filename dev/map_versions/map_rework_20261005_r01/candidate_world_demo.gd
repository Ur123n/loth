extends "res://maps/leyton/viewer.gd"

const WORLD_PATH := "res://dev/map_versions/map_rework_20261005_r01/world.candidate.json"
var world: Dictionary
var route_panel: Control
var visited: Dictionary = {}

func _ready() -> void:
	world = JSON.parse_string(FileAccess.get_file_as_string(WORLD_PATH))
	initial_map_id = world.start_map
	super._ready()
	route_panel = Control.new()
	route_panel.set_script(load("res://dev/leyton_world_demo/route_panel.gd"))
	route_panel.world = world
	route_panel.visible = false
	hud.get_parent().add_child(route_panel)
	_refresh()

func create_map(id: String) -> Node2D:
	assert(world.maps.has(id), "Unknown candidate district: " + id)
	return load(world.maps[id].scene).instantiate()

func configure_map(candidate: Node2D) -> void:
	for patch: Dictionary in world.exit_overrides:
		if candidate.map_id != patch.map:
			continue
		for ex: Dictionary in candidate.layout.exits:
			if ex.edge == patch.edge:
				ex.to = patch.to
				ex.enabled = patch.enabled
	candidate.set_surface_enabled(surface)

func load_map(id: String, edge := "") -> void:
	super.load_map(id, edge)
	visited[current.map_id] = true
	_refresh()

func _physics_process(delta: float) -> void:
	if is_instance_valid(route_panel) and route_panel.visible:
		return
	super._physics_process(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_M:
			route_panel.visible = not route_panel.visible
			_refresh()
			return
		if event.physical_keycode == KEY_ESCAPE and route_panel.visible:
			route_panel.hide()
			return
		if event.physical_keycode == KEY_0:
			load_map(initial_map_id)
			return
	super._unhandled_input(event)

func _refresh() -> void:
	super._refresh()
	var direction := "沿路探索；地图边缘自动切换，M查看路线"
	if current.map_id == "MONASTERY":
		direction = "向下沿山道到莱顿；V切换修道院候选/活动材质"
	elif current.map_id == "M02":
		direction = "M02三种宅邸材质轮换；V切换候选/活动材质"
	elif current.map_id == "M01":
		direction = "北：贵族区　南：贫民窟　西：商业区　东：住宅区"
	hud.text = "地图重制候选 r01 · 修道院 + 莱顿 M02\n%s | 门禁：%s | %s\nWASD 移动 · V 新旧材质 · M 全路线 · Tab 总览 · E 上下墙 · G 门禁 · C 测试车\n%s\n%s  |  已到访 %d/9  |  0修道院 / 1—8跳区 / R复位" % [current.layout.name, ["开放", "宵禁", "封锁"][state], "墙顶" if on_wall else "地面", direction, status, visited.size()]
	if is_instance_valid(route_panel):
		route_panel.current_id = current.map_id
		route_panel.visited = visited
		route_panel.queue_redraw()
