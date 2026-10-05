extends Node2D

## 大型建筑查验器（自包含的小工具，不依赖 main.gd）。
##
## 用途：把一张「带大型建筑的地图」打开，**用键盘/鼠标在地图上走一圈**，
## 鼠标指哪儿就在左上角报出那一格的实情：
## 属于哪座建筑、是占用/可走/实体/门、落在哪个房间、地图级是否可通行。
## 这是"建筑放进地图之后到底对不对"最直观的验收方式（比看预览图强，因为能逐格查）。
##
## 用法：
##   godot --path C:\游戏 res://world/map/BuildingViewer.tscn
##   或双击 启动建筑查验.bat
##
## 操作：WASD / 方向键 = 平移镜头；鼠标滚轮 = 缩放；R = 回到起点；F = 显示/隐藏屋顶层；
##       Tab = 显示/隐藏占位调试图层（占用蓝 / 实体红 / 可走绿 / 门黄）。

const DEFAULT_MAP := "res://maps/godot/scenes/monastery_grounds.tscn"
const PROJECTION_ID := "orthogonal_3q_48_v1"
const PAN_SPEED := 900.0
const PROBE_SPEED := 420.0
const ZOOM_STEP := 1.15
const ZOOM_MIN := 0.25
const ZOOM_MAX := 6.0

@export var map_scene_path: String = DEFAULT_MAP
@export var debug_overlay: bool = false
## 实验模式：不改地图/Prefab，只在运行时把大型建筑 Base 切成水平绘制带，
## 并把可移动角色探针放进建筑对象的同一个 YSort 域。
@export var projection_lab: bool = false
@export_range(1, 16, 1) var projection_band_height_cells: int = 6

var _map: Node2D
var _camera: Camera2D
var _label: Label
var _hint: Label
var _start_position := Vector2.ZERO
var _sort_world: Node2D
var _projection_probe: Node2D
var _projection_bands: Array[Node2D] = []


func _ready() -> void:
	_build_ui()
	_load_map()
	_setup_projection_lab()
	_build_camera()


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)

	var panel := ColorRect.new()
	panel.color = Color(0.04, 0.05, 0.07, 0.82)
	panel.position = Vector2(8, 8)
	panel.size = Vector2(780, 172)
	canvas.add_child(panel)

	_label = Label.new()
	_label.position = Vector2(18, 14)
	_label.size = Vector2(760, 156)
	_label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.85))
	canvas.add_child(_label)

	_hint = Label.new()
	_hint.position = Vector2(18, 660)
	_hint.add_theme_color_override("font_color", Color(0.55, 0.58, 0.62))
	_hint.text = "实验场：WASD 移动探针，方向键平移　滚轮缩放　R 复位　F 收/放屋顶　Tab 掩码　Esc 退出"
	canvas.add_child(_hint)


func _load_map() -> void:
	var packed := load(map_scene_path) as PackedScene
	if packed == null:
		_label.text = "地图加载失败：%s" % map_scene_path
		return
	_map = packed.instantiate() as Node2D
	add_child(_map)
	# 起点：地图的 spawn 标记（叫不出标记就退回地图中心）
	var spawn: Vector2 = _map.call("get_spawn_position") if _map.has_method("get_spawn_position") \
		else Vector2.ZERO
	if projection_lab and _map.has_method("get_marker_position"):
		var gate: Vector2 = _map.call("get_marker_position", "gate")
		if gate != Vector2.INF:
			spawn = gate
	_start_position = spawn


func _setup_projection_lab() -> void:
	if not projection_lab or _map == null:
		return
	_sort_world = _map.call("get_building_root") as Node2D if _map.has_method("get_building_root") else null
	if _sort_world == null:
		_sort_world = Node2D.new()
		_sort_world.name = "YSortWorld"
		_sort_world.y_sort_enabled = true
		_map.add_child(_sort_world)
	else:
		_sort_world.y_sort_enabled = true
	_create_projection_probe()
	for building in _buildings():
		# Viewer 的地图已完成挂载，可立即兑现生产 metadata 切带；延迟调用随后会因幂等检查跳过。
		if building.has_method("get_sort_band_nodes") and building.has_method("_create_sort_bands"):
			building.call("_create_sort_bands")
		_create_projection_bands(building)


func _create_projection_probe() -> void:
	_projection_probe = Node2D.new()
	_projection_probe.name = "ProjectionProbe"
	_projection_probe.position = _start_position
	_projection_probe.z_index = 0
	_projection_probe.add_to_group("player")
	_projection_probe.set_meta("projection_id", PROJECTION_ID)
	_projection_probe.set_meta("sort_anchor", "feet")
	_sort_world.add_child(_projection_probe)

	var shadow := Polygon2D.new()
	shadow.name = "ContactShadow"
	shadow.polygon = PackedVector2Array([Vector2(-18, -5), Vector2(15, -5), Vector2(22, 1), Vector2(-12, 4)])
	shadow.color = Color(0.02, 0.015, 0.025, 0.55)
	shadow.z_index = -1
	_projection_probe.add_child(shadow)

	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([
		Vector2(-12, -2), Vector2(12, -2), Vector2(10, -48),
		Vector2(5, -66), Vector2(-5, -66), Vector2(-10, -48)])
	body.color = Color(0.78, 0.60, 0.22)
	_projection_probe.add_child(body)

	var feet := Line2D.new()
	feet.name = "FeetAnchor"
	feet.points = PackedVector2Array([Vector2(-18, 0), Vector2(18, 0)])
	feet.width = 3.0
	feet.default_color = Color(1.0, 0.25, 0.2)
	_projection_probe.add_child(feet)


func _create_projection_bands(building: Node) -> void:
	if not building.has_method("get_building_data"):
		return
	var data: Variant = building.call("get_building_data")
	if data == null:
		return
	var sorting: Dictionary = data.call("get_sorting")
	if not bool(sorting.get("occluder", false)):
		return
	if building.has_method("get_sort_band_nodes"):
		var semantic_bands: Array = building.call("get_sort_band_nodes")
		if not semantic_bands.is_empty():
			for semantic_band in semantic_bands:
				_projection_bands.append(semantic_band as Node2D)
			return
	var visual := building.get_node_or_null("Visual") as Node2D
	if visual == null:
		return
	var base_name := "Base"
	for layer_value in data.call("get_visual_layers"):
		var layer: Dictionary = layer_value
		if String(layer.get("role", "")) == "base":
			base_name = String(layer.get("name", "Base"))
			break
	var base := visual.get_node_or_null(NodePath(base_name)) as Sprite2D
	if base == null or base.texture == null:
		return

	var tile_size: Vector2i = data.call("get_tile_size")
	var band_height := maxi(tile_size.y, tile_size.y * projection_band_height_cells)
	var texture_size := Vector2i(base.texture.get_size())
	var origin := _sort_world.to_local(base.global_position)
	var band_index := 0
	var source_y := 0
	while source_y < texture_size.y:
		var height := mini(band_height, texture_size.y - source_y)
		# YSort 使用 Node2D 自身的位置；锚节点放在带底边，真正图像作为子节点向上偏移。
		var band := Node2D.new()
		band.name = "%s_%sBand_%02d" % [String(building.name), base_name, band_index]
		band.position = origin + Vector2(0, source_y + height)
		band.z_index = base.z_index
		band.set_meta("projection_band", true)
		band.set_meta("source_building", String(building.name))
		band.set_meta("source_rect_px", Rect2(0, source_y, texture_size.x, height))
		_sort_world.add_child(band)

		var region := Sprite2D.new()
		region.name = "Region"
		region.texture = base.texture
		region.centered = false
		region.region_enabled = true
		region.region_rect = Rect2(0, source_y, texture_size.x, height)
		region.position = Vector2(0, -height)
		region.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		band.add_child(region)
		_projection_bands.append(band)
		source_y += height
		band_index += 1
	base.visible = false
	base.set_meta("hidden_by_projection_lab", true)


func _build_camera() -> void:
	if CameraCtrl != null:
		_camera = CameraCtrl.ensure_camera()
	if _camera == null:
		_camera = Camera2D.new()
		_camera.name = "ViewerCamera"
		add_child(_camera)
		_camera.make_current()
	_camera.position = _start_position
	_camera.zoom = Vector2(0.9, 0.9)
	_apply_debug_overlay()


func _process(delta: float) -> void:
	if _camera == null:
		return
	var direction := Vector2.ZERO
	if projection_lab and _projection_probe != null:
		var probe_direction := Vector2.ZERO
		if Input.is_key_pressed(KEY_A):
			probe_direction.x -= 1.0
		if Input.is_key_pressed(KEY_D):
			probe_direction.x += 1.0
		if Input.is_key_pressed(KEY_W):
			probe_direction.y -= 1.0
		if Input.is_key_pressed(KEY_S):
			probe_direction.y += 1.0
		if probe_direction != Vector2.ZERO:
			var motion := probe_direction.normalized() * PROBE_SPEED * delta
			_projection_probe.position += motion
			_camera.position += motion
		if Input.is_key_pressed(KEY_LEFT):
			direction.x -= 1.0
		if Input.is_key_pressed(KEY_RIGHT):
			direction.x += 1.0
		if Input.is_key_pressed(KEY_UP):
			direction.y -= 1.0
		if Input.is_key_pressed(KEY_DOWN):
			direction.y += 1.0
	else:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			direction.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			direction.x += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			direction.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			direction.y += 1.0
	if direction != Vector2.ZERO:
		_camera.position += direction.normalized() * PAN_SPEED * delta / maxf(_camera.zoom.x, 0.01)
	_update_readout()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(ZOOM_STEP)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.0 / ZOOM_STEP)
	elif event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		match key.keycode:
			KEY_R:
				_camera.position = _start_position
				if _projection_probe != null:
					_projection_probe.position = _start_position
			KEY_F:
				_toggle_roofs()
			KEY_TAB:
				debug_overlay = not debug_overlay
				_apply_debug_overlay()
			KEY_ESCAPE:
				get_tree().quit()


func _zoom(factor: float) -> void:
	var value := clampf(_camera.zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
	_camera.zoom = Vector2(value, value)


func _toggle_roofs() -> void:
	for building in _buildings():
		var current: bool = building.call("is_roof_visible")
		building.call("set_roof_visible", not current)


func _apply_debug_overlay() -> void:
	for building in _buildings():
		building.set("auto_hide_roof_on_enter", projection_lab)
		building.set_process(projection_lab)
		building.set("debug_draw", debug_overlay)


func _buildings() -> Array:
	if _map == null or not _map.has_method("get_buildings"):
		return []
	return _map.call("get_buildings")


## 逐格读盘：这一格是什么，就是地图与建筑两个系统对同一格的最终裁定。
func _update_readout() -> void:
	if _map == null:
		return
	var mouse := get_global_mouse_position()
	var cell: Vector2i = _map.call("local_to_cell", mouse - _map.position)
	var lines := PackedStringArray()
	lines.append("地图 %s　格 %s　镜头 %s（zoom %.2f）" % [
		map_scene_path.get_file(), str(cell), str(_camera.position.round()), _camera.zoom.x])
	lines.append("地图尺寸 %s 格　建筑 %d 座" % [
		str(_map.call("get_map_size_cells")), _buildings().size()])
	if projection_lab:
		lines.append("投影 %s（地图声明：%s）　YSort 切带 %d　探针与切带同域：%s" % [
			PROJECTION_ID, String(_map.get_meta("projection_id", "未声明")), _projection_bands.size(),
			str(_projection_probe != null and _projection_probe.get_parent() == _sort_world)])

	var walkable: bool = _map.call("is_cell_walkable", cell)
	lines.append("地图判定：%s" % ("可通行" if walkable else "不可通行"))
	var building: Node = _map.call("get_building_at", cell) if _map.has_method("get_building_at") else null
	if building == null:
		lines.append("建筑：无（这一格走原来的图块规则）")
	else:
		var data: Variant = building.call("get_building_data")
		var local: Vector2i = building.call("map_cell_to_local_cell", cell)
		var verdict: Variant = building.call("judge_map_cell", cell)
		var flags := PackedStringArray()
		if bool(data.call("is_cell_occupied", local)):
			flags.append("占用")
		if bool(data.call("is_cell_walkable", local)):
			flags.append("可走")
		if bool(data.call("is_cell_blocked", local)):
			flags.append("实体")
		if bool(data.call("is_cell_occluded", local)):
			flags.append("被屋顶遮住")
		if bool(data.call("is_cell_door", local)):
			flags.append("门")
		var room_id := "-"
		var rooms: Array = data.call("get_rooms")
		for room in rooms:
			var r: Dictionary = room
			var rect_array: Array = r.get("rect", [0, 0, 0, 0])
			if Rect2i(int(rect_array[0]), int(rect_array[1]),
					int(rect_array[2]), int(rect_array[3])).has_point(local):
				room_id = String(r.get("label", r.get("id", "-")))
				break
		var door: Dictionary = _map.call("get_door_at", cell) if _map.has_method("get_door_at") else {}
		lines.append("建筑：%s　局部格 %s　裁定 %s" % [
			String(building.name), str(local), "可通行" if verdict == true else "不可通行"])
		lines.append("掩码：%s　房间：%s%s" % [
			("、".join(flags) if not flags.is_empty() else "（无）"), room_id,
			"" if (door as Dictionary).is_empty() else "　门：%s（朝%s）" % [
				String((door as Dictionary).get("id", "")), String((door as Dictionary).get("outward_side", ""))]])
	_label.text = "\n".join(lines)


## 供 headless 自检读取实验场结构，不进入生产地图 API。
func get_projection_probe() -> Node2D:
	return _projection_probe


func get_projection_bands() -> Array[Node2D]:
	return _projection_bands


func get_projection_sort_world() -> Node2D:
	return _sort_world
