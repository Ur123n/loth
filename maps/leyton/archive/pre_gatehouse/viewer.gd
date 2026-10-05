extends Node2D
## Acceptance harness reuses phase-one player art/camera and MapScene semantics.
const PlayerScene := preload("res://dev/map_pipeline_test/phase_one_player.tscn")
var current: Node2D
var player: CharacterBody2D
var hud: Label
var cart := false
var on_wall := false
var state := 0
var overview := false
var surface := true
var status := ""
var cart_visual: Polygon2D
var footprint_outline: Line2D

func _ready() -> void:
	player = PlayerScene.instantiate()
	add_child(player)
	player.set_physics_process(false)
	player.get_node("Camera2D").position = Vector2.ZERO
	player.get_node("Camera2D").position_smoothing_enabled = false
	player.get_node("Shadow").z_index = 0
	cart_visual = Polygon2D.new()
	cart_visual.name = "CartFootprint"
	cart_visual.polygon = PackedVector2Array([Vector2(-48,-72), Vector2(48,-72), Vector2(48,72), Vector2(-48,72)])
	cart_visual.color = Color(0.85, 0.55, 0.23, 0.8)
	player.add_child(cart_visual)
	footprint_outline = Line2D.new()
	footprint_outline.name = "FootprintOutline"
	footprint_outline.width = 2
	footprint_outline.default_color = Color.WHITE
	footprint_outline.closed = true
	player.add_child(footprint_outline)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = Label.new()
	hud.position = Vector2(16, 12)
	hud.add_theme_color_override("font_shadow_color", Color.BLACK)
	hud.add_theme_constant_override("shadow_offset_x", 2)
	hud.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(hud)
	load_map("M01")

func load_map(id: String, edge := "") -> void:
	if current != null:
		# Preserve actor/camera before retiring their current map and sorting parent.
		player.reparent(self)
		remove_child(current)
		current.queue_free()
	current = load("res://maps/leyton/scenes/%s.tscn" % id.to_lower()).instantiate()
	current.use_surface = surface
	current.z_index = -1
	add_child(current)
	move_child(current, 0)
	current.set_gate_state(state)
	player.reparent(current.get_building_root())
	on_wall = false
	player.position = current.get_spawn_position() if edge.is_empty() else current.arrival(edge)
	status = "进入 " + id
	_refresh()

func footprint() -> Vector2:
	return Vector2(96, 144) if cart else Vector2(24, 24)

func _physics_process(delta: float) -> void:
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down") * (180.0 if cart else 260.0) * delta
	var steps := maxi(1, ceili(move.length() / 6.0))
	for i in steps:
		for offset in [Vector2(move.x / steps, 0), Vector2(0, move.y / steps)]:
			if current.can_occupy(player.position + offset, footprint(), on_wall):
				player.position += offset
	if not on_wall:
		var cell: Vector2i = current.local_to_cell(player.position)
		for ex: Dictionary in current.layout.exits:
			if ex.enabled and current.exit_rect(ex).has_point(cell):
				var destination: PackedStringArray = ex.to.split(":")
				load_map(destination[0], destination[1])
				break
	_refresh()

func toggle_cart() -> bool:
	if on_wall:
		return false
	var target := Vector2(24, 24) if cart else Vector2(96, 144)
	if not current.can_occupy(player.position, target):
		status = "空间不足，不能切换马车"
		return false
	cart = not cart
	status = "马车 2×3 格" if cart else "玩家"
	return true

func use_stairs() -> bool:
	if cart or current.layout.stairs_ground.is_empty():
		return false
	var origin: Array = current.layout.stairs_wall if on_wall else current.layout.stairs_ground
	if player.position.distance_to(current.cell_to_local(Vector2i(origin[0], origin[1]))) > 72:
		return false
	var target: Array = current.layout.stairs_ground if on_wall else current.layout.stairs_wall
	on_wall = not on_wall
	player.position = current.cell_to_local(Vector2i(target[0], target[1]))
	status = "墙顶巡逻道" if on_wall else "返回地面"
	return true

func cycle_gate() -> bool:
	if current.map_id != "M07":
		status = "请在 M07 西门测试城门状态"
		return false
	if not on_wall and current.rect(current.layout.gate).grow(2).has_point(current.local_to_cell(player.position)):
		status = "请先离开门洞，再切换状态"
		return false
	state = (state + 1) % 3
	current.set_gate_state(state)
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_C: toggle_cart()
			KEY_E: use_stairs()
			KEY_G: cycle_gate()
			KEY_TAB: overview = not overview
			KEY_T:
				surface = not surface
				current.set_surface_enabled(surface)
			KEY_R: load_map(current.map_id)
			KEY_1: load_map("M01")
			KEY_4: load_map("M04")
			KEY_7: load_map("M07")
		_refresh()

func _refresh() -> void:
	cart_visual.visible = cart
	player.get_node("Body").visible = not cart
	player.get_node("Shadow").visible = not cart
	var half := footprint() * 0.5
	footprint_outline.points = PackedVector2Array([Vector2(-half.x,-half.y), Vector2(half.x,-half.y), Vector2(half.x,half.y), Vector2(-half.x,half.y)])
	var camera: Camera2D = player.get_node("Camera2D")
	if overview:
		camera.zoom = Vector2.ONE * minf(get_viewport_rect().size.x / (current.map_size_cells.x * 48.0), (get_viewport_rect().size.y - 150) / (current.map_size_cells.y * 48.0))
		camera.position = Vector2(current.map_size_cells) * 24 - player.position + Vector2(0, -200)
	else:
		camera.zoom = Vector2.ONE * 0.7
		camera.position = Vector2.ZERO
	hud.text = "%s %s | %s | 西门：%s\nWASD 移动 · C 玩家/马车 · E 墙梯 · G 西门状态 · Tab 总览 · T 地表/灰盒\n1/4/7 跳图 · R 复位；绿色为出口，橙色为墙梯。M04石桥已分层，其余建筑仍为占位。\n%s | 坐标 %s | %s" % [current.map_id, current.layout.name, "马车 2×3" if cart else "玩家", ["开放", "宵禁", "封锁"][state], status, str(current.local_to_cell(player.position)), "墙顶" if on_wall else "地面"]
	queue_redraw()

func _draw() -> void:
	if current == null:
		return
	for ex: Dictionary in current.layout.exits:
		var r: Rect2i = current.exit_rect(ex)
		draw_rect(Rect2(Vector2(r.position) * 48, Vector2(r.size) * 48), Color(0.2, 1, 0.5, 0.5) if ex.enabled else Color(0.9, 0.2, 0.2, 0.6))
	if not current.layout.stairs_ground.is_empty():
		for point: Array in [current.layout.stairs_ground, current.layout.stairs_wall]:
			draw_rect(Rect2(Vector2(point[0], point[1]) * 48, Vector2(48, 48)), Color.ORANGE)
