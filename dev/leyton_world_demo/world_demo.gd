extends "res://maps/leyton/viewer.gd"
var world: Dictionary
var route_panel: Control
var visited: Dictionary = {}

func _ready() -> void:
	world = JSON.parse_string(FileAccess.get_file_as_string("res://dev/leyton_world_demo/world.json"))
	initial_map_id = world.start_map
	super._ready()
	route_panel = Control.new()
	route_panel.set_script(load("res://dev/leyton_world_demo/route_panel.gd"))
	route_panel.world = world
	route_panel.visible = false
	hud.get_parent().add_child(route_panel)
	_refresh()

func create_map(id: String) -> Node2D:
	assert(world.maps.has(id),"Unknown world demo district: "+id)
	return load(world.maps[id].scene).instantiate()

func configure_map(candidate: Node2D) -> void:
	for patch: Dictionary in world.exit_overrides:
		if candidate.map_id != patch.map: continue
		for ex: Dictionary in candidate.layout.exits:
			if ex.edge==patch.edge:
				ex.to = patch.to
				ex.enabled = patch.enabled
		candidate.set_surface_enabled(surface)

func load_map(id: String, edge := "") -> void:
	super.load_map(id,edge)
	visited[current.map_id] = true
	_refresh()

func _physics_process(delta: float) -> void:
	if is_instance_valid(route_panel) and route_panel.visible: return
	super._physics_process(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_M:
			route_panel.visible = not route_panel.visible
			_refresh()
			return
		if event.physical_keycode==KEY_ESCAPE and route_panel.visible:
			route_panel.hide()
			return
		if event.physical_keycode==KEY_0:
			load_map(initial_map_id)
			return
		if event.physical_keycode==KEY_T and current.map_id=="MONASTERY":
			status = "修道院使用既有完整地表；T可切换莱顿地表/灰盒"
			_refresh()
			return
	super._unhandled_input(event)

func _refresh() -> void:
	super._refresh()
	var direction := "沿路探索；地图边缘自动切换，M查看路线"
	if current.map_id=="MONASTERY": direction = "向下沿山道 → 莱顿城北门城外；向上可审验修道院"
	elif current.map_id=="M05": direction = "向上返回修道院；向下穿过北门 → 贵族区 → 中心广场"
	elif current.map_id=="M01": direction = "北：贵族区　南：贫民窟　西：商业区　东：经住宅区抵达东门"
	hud.text = "修道院 — 莱顿城 · 移动审验\n%s | 门禁：%s | %s\nWASD 移动 · M 全路线 · Tab 当前图总览 · E 上下墙 · G 门禁 · C 测试车\n%s\n%s  |  已到访 %d/9  |  0修道院 / 1—8跳区 / R复位" % [current.layout.name,["开放","宵禁","封锁"][state],"墙顶" if on_wall else "地面",direction,status,visited.size()]
	if is_instance_valid(route_panel):
		route_panel.current_id = current.map_id
		route_panel.visited = visited
		route_panel.queue_redraw()
