class_name Building
extends Node2D

## 大型建筑 Prefab 的根节点脚本（每座建筑的 `<Name>.tscn` 都挂它）。
##
## 一座建筑 = 一个独立的大型视觉对象 + 一套逻辑数据，**不是一堆 Tile**：
##
## ```
## Building                    ← 本脚本；原点在 footprint 底部中心（Y 轴排序用）
## ├── Visual                  ← 视觉层（与逻辑完全解耦）
## │   ├── Base                ←   主视觉大图（Sprite2D，不居中，左上角对齐 footprint)
## │   └── Roof                ←   屋顶叠加层（可选；角色走进室内时自动收起）
## ├── Collision               ← 物理层（StaticBody2D + 按 collision 掩码贪心分解出的矩形）
## ├── Occupancy               ← 逻辑：占用区（只存数据，供工具与寻路读）
## ├── WalkableArea            ← 逻辑：可通行区
## ├── Doors                   ← 逻辑：门/入口（Marker2D，名字 = door id，meta 带朝向与标签）
## ├── Interaction             ← 玩法：门前的 Area2D 交互点（靠近可触发）
## └── TacticalData            ← 战斗：掩体/高低差/是否遮挡视线
## ```
##
## 地图侧只认三件事：**占用哪些格、哪些格能走、门口在哪**（见 `core/world/map_scene.gd`）。
## 视觉尺寸与逻辑尺寸互不绑定：图可以 2880×3312 像素，逻辑只占 60×69 格。

const CHILD_VISUAL := "Visual"
const CHILD_BASE := "Base"
const CHILD_ROOF := "Roof"
const CHILD_COLLISION := "Collision"
const CHILD_OCCUPANCY := "Occupancy"
const CHILD_WALKABLE := "WalkableArea"
const CHILD_DOORS := "Doors"
const CHILD_INTERACTION := "Interaction"
const CHILD_TACTICAL := "TacticalData"

## 建筑 id（决定从哪个资产包读 metadata）。生成 Prefab 时写死，放置后一般不用改。
@export var building_id: String = ""
## metadata 路径；留空则按 building_id 从资产包约定路径推。
@export var data_path: String = ""
## 是否显示屋顶层（俯视游戏里"进屋收屋顶"就是这个开关）。
@export var show_roof: bool = true
## 角色走进占用区时自动收屋顶（需要场景里有 "player" 组的节点）。
@export var auto_hide_roof_on_enter: bool = true
## 打开后在建筑上方画出占用/可走/门/房间的调试图层（编辑期自查用）。
@export var debug_draw: bool = false:
	set(value):
		debug_draw = value
		queue_redraw()

var _data: BuildingData
## 放置时记录：footprint 左上角所在地图格。**外部请用 `get_top_left_cell()` 读**：
## 这个字段不导出（不写进 .tscn），从 position 反解，节点被挪动/从磁盘读回都自动跟着变；
## 但「只实例化、不进场景树」时 _ready() 不跑，直接读字段会拿到 (0,0)。
var top_left_cell: Vector2i = Vector2i.ZERO
var _placement_valid := false
var _placement_source_position := Vector2.INF
var _debug_font: Font
var _roof_node: Node2D
var _base_node: Sprite2D
var _sort_band_nodes: Array[Node2D] = []


func _ready() -> void:
	_data = load_data()
	if _data == null:
		push_error("Building 「%s」数据加载失败：%s" % [building_id, data_path])
		return
	ensure_placement()
	_apply_anchor()
	_base_node = get_node_or_null(NodePath("%s/%s" % [CHILD_VISUAL, CHILD_BASE])) as Sprite2D
	_roof_node = get_node_or_null(NodePath("%s/%s" % [CHILD_VISUAL, CHILD_ROOF])) as Node2D
	# 子节点 _ready 时父 YSort 仍可能处于批量挂载阶段；下一空闲帧再添加同级切带。
	_create_sort_bands.call_deferred()
	set_roof_visible(show_roof)
	if auto_hide_roof_on_enter:
		set_process(true)
	else:
		set_process(false)


## 由节点位置反解 footprint 左上角所在格（节点不在场景树里、还没 _ready() 时也能用，
## 工具链靠这条在"只实例化不入树"的情况下读放置位置）。
func ensure_placement() -> void:
	if _placement_valid and position == _placement_source_position:
		return
	var data := get_building_data()
	if data == null:
		return
	top_left_cell = data.node_position_to_top_left_cell(position)
	_placement_valid = true
	_placement_source_position = position


## 显式设定放置格（放好之后立刻生效，不用等 _ready()）。
func set_placement_cell(cell: Vector2i) -> void:
	top_left_cell = cell
	_placement_valid = true
	_placement_source_position = position


## 读放置格（**外部一律用这个**，不要直接读 `top_left_cell` 字段）。
## 节点还没进场景树时 `_ready()` 不会跑，这里会就地按 position 反解，结果一样。
func get_top_left_cell() -> Vector2i:
	ensure_placement()
	return top_left_cell


## 角色走到**屋顶压住的格**上时自动收屋顶，走出去再盖上（需要场景里有 "player" 组的节点）。
## 判定依据是 occlusion 掩码：mask 里标了"这格会被建筑遮挡"，就把屋顶拿掉让角色露出来。
func _process(_delta: float) -> void:
	if _roof_node == null or _data == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var cell := world_position_to_local_cell(player.global_position)
	var occluded := _data.is_cell_occluded(cell)
	# 目标状态：被遮挡 → 收屋顶；没被遮挡 → 盖回去
	if _roof_node.visible == occluded:
		set_roof_visible(not occluded)


## 读 metadata（找不到时返回 null）。
func load_data() -> BuildingData:
	var path := data_path
	if path.is_empty():
		path = "res://assets/buildings/%s/metadata/building.json" % building_id
	if not FileAccess.file_exists(path):
		return null
	_data = BuildingData.load_from_json(path)
	return _data


func get_building_data() -> BuildingData:
	if _data == null:
		_data = load_data()
	return _data


func get_building_id() -> String:
	if not building_id.is_empty():
		return building_id
	var data := get_building_data()
	return data.building_id if data != null else ""


## 把视觉层对齐到 footprint：节点原点在底部中心，贴图按 metadata 里的
## `visual.anchor_offset_px` 摆放（视觉图可能因为出血比 footprint 大几格）。
func _apply_anchor() -> void:
	var data := get_building_data()
	if data == null:
		return
	# Logical children are authored from footprint top-left; root is bottom-center.
	# Absolute assignment also repairs old prefabs without accumulating offsets.
	for child_name in [CHILD_COLLISION, CHILD_DOORS, CHILD_INTERACTION]:
		var logical := get_node_or_null(NodePath(child_name)) as Node2D
		if logical != null:
			logical.position = -data.get_anchor_local_px()
	var visual := get_node_or_null(NodePath(CHILD_VISUAL)) as Node2D
	if visual == null:
		return
	var offset := data.get_visual_offset_px()
	for layer in data.get_visual_layers():
		var l: Dictionary = layer
		var node := visual.get_node_or_null(NodePath(String(l.get("name", "")))) as Sprite2D
		if node == null:
			continue
		node.position = offset
		node.z_index = int(l.get("z_index", 0))
		node.visible = bool(l.get("visible", true))


## 把完整 Base 纹理按 metadata 的语义矩形生成为 YSort 直接成员。
## 这只是绘制分段；Building 的逻辑、碰撞和源资产仍然是一整座建筑。
func _create_sort_bands() -> void:
	if not _sort_band_nodes.is_empty():
		return
	if _base_node == null or _base_node.texture == null:
		return
	var data := get_building_data()
	if data == null:
		return
	var sorting := data.get_sorting()
	var bands: Array = sorting.get("bands", [])
	if bands.is_empty():
		return
	var sort_parent := get_parent() as Node2D
	if sort_parent == null or not sort_parent.y_sort_enabled:
		push_warning("建筑 %s 声明了 sorting.bands，但父节点不是 YSort 容器" % get_building_id())
		return
	var tile := data.get_tile_size()
	for band_value in bands:
		var band_data: Dictionary = band_value
		var rect_tiles: Array = band_data.get("source_rect_tiles", [])
		if rect_tiles.size() != 4:
			continue
		var rect_px := Rect2(
			Vector2(int(rect_tiles[0]) * tile.x, int(rect_tiles[1]) * tile.y),
			Vector2(int(rect_tiles[2]) * tile.x, int(rect_tiles[3]) * tile.y))
		if rect_px.size.x <= 0.0 or rect_px.size.y <= 0.0:
			continue
		var band := Node2D.new()
		var band_id := String(band_data.get("id", "band_%02d" % _sort_band_nodes.size()))
		band.name = "%s_%sBand_%s" % [name, CHILD_BASE, band_id]
		band.position = sort_parent.to_local(_base_node.to_global(Vector2(rect_px.position.x, rect_px.end.y)))
		band.z_index = _base_node.z_index
		band.set_meta("projection_band", true)
		band.set_meta("semantic_band_id", band_id)
		band.set_meta("source_building", String(name))
		band.set_meta("source_rect_px", rect_px)
		sort_parent.add_child(band)

		var region := Sprite2D.new()
		region.name = "Region"
		region.texture = _base_node.texture
		region.centered = false
		region.region_enabled = true
		region.region_rect = rect_px
		region.position = Vector2(0, -rect_px.size.y)
		region.texture_filter = _base_node.texture_filter
		region.modulate = _base_node.modulate
		region.self_modulate = _base_node.self_modulate
		region.material = _base_node.material
		band.add_child(region)
		_sort_band_nodes.append(band)
	if not _sort_band_nodes.is_empty():
		_base_node.visible = false
		_base_node.set_meta("hidden_by_sort_bands", true)


func get_sort_band_nodes() -> Array[Node2D]:
	return _sort_band_nodes


func _exit_tree() -> void:
	for band in _sort_band_nodes:
		if is_instance_valid(band) and not band.is_queued_for_deletion():
			band.queue_free()
	_sort_band_nodes.clear()


# ---------------------------------------------------------------- 地图侧查询

## 地图格 → 建筑局部格。
func map_cell_to_local_cell(map_cell: Vector2i) -> Vector2i:
	ensure_placement()
	return map_cell - top_left_cell


## 建筑局部格 → 地图格。
func local_cell_to_map_cell(local_cell: Vector2i) -> Vector2i:
	ensure_placement()
	return top_left_cell + local_cell


## 世界像素 → 建筑局部格。
func world_position_to_local_cell(world_position: Vector2) -> Vector2i:
	var data := get_building_data()
	if data == null:
		return Vector2i(-1, -1)
	var local_px := world_position - (global_position - data.get_anchor_local_px())
	return data.local_px_to_cell(local_px)


## 建筑局部格中心 → 世界像素。
func local_cell_to_world_position(local_cell: Vector2i) -> Vector2:
	var data := get_building_data()
	if data == null:
		return global_position
	return global_position + data.cell_center_local_px(local_cell) - data.get_anchor_local_px()


## **地图格是否属于本建筑**（占用区）。
func covers_map_cell(map_cell: Vector2i) -> bool:
	var data := get_building_data()
	if data == null:
		return false
	return data.is_cell_occupied(map_cell_to_local_cell(map_cell))


## 地图格能否通行 —— 只有在占用区内才有发言权（占用区外返回 null 表示"不表态"）。
## `MapScene.is_cell_walkable()` 就是靠这个把建筑逻辑接进地图的。
func judge_map_cell(map_cell: Vector2i) -> Variant:
	var data := get_building_data()
	if data == null:
		return null
	var local := map_cell_to_local_cell(map_cell)
	if not data.is_cell_occupied(local):
		return null
	return data.is_cell_walkable(local)


## 本建筑在地图上占用的全部格（做过坐标平移）。
func get_occupied_map_cells() -> Dictionary:
	var data := get_building_data()
	if data == null:
		return {}
	return BuildingMask.offset_cells(data.get_occupied_cells(), get_top_left_cell())


func get_walkable_map_cells() -> Dictionary:
	var data := get_building_data()
	if data == null:
		return {}
	return BuildingMask.offset_cells(data.get_walkable_cells(), get_top_left_cell())


func get_blocked_map_cells() -> Dictionary:
	var data := get_building_data()
	if data == null:
		return {}
	return BuildingMask.offset_cells(data.get_blocked_cells(), get_top_left_cell())


## 地图格坐标系下 footprint 的矩形。
func get_map_footprint_rect() -> Rect2i:
	var data := get_building_data()
	if data == null:
		return Rect2i()
	return Rect2i(get_top_left_cell(), data.get_footprint_size())


func get_doors() -> Array:
	var data := get_building_data()
	return data.get_doors() if data != null else []


## 门在地图格坐标系里的位置（含 outward 格）。
func get_door_map_cells() -> Array:
	var out: Array = []
	var data := get_building_data()
	if data == null:
		return out
	var top_left := get_top_left_cell()
	for door in data.get_doors():
		var d: Dictionary = door
		var cell: Array = d.get("cell", [0, 0])
		out.append({
			"id": String(d.get("id", "")),
			"label": String(d.get("label", "")),
			"local_cell": Vector2i(int(cell[0]), int(cell[1])),
			"map_cell": top_left + Vector2i(int(cell[0]), int(cell[1])),
			"outward_side": String(d.get("outward_side", "n")),
			"width_tiles": int(d.get("width_tiles", 1)),
			"target": String(d.get("target", "")),
		})
	return out


func get_tactical() -> Dictionary:
	var data := get_building_data()
	return data.get_tactical() if data != null else {}


func get_room_map_rect(room_id: String) -> Rect2i:
	var data := get_building_data()
	if data == null:
		return Rect2i()
	var room := data.get_room(room_id)
	if room.is_empty():
		return Rect2i()
	var rect: Array = room.get("rect", [0, 0, 0, 0])
	return Rect2i(get_top_left_cell() + Vector2i(int(rect[0]), int(rect[1])),
		Vector2i(int(rect[2]), int(rect[3])))


# ---------------------------------------------------------------- 视觉控制

func set_roof_visible(visible_now: bool) -> void:
	show_roof = visible_now
	if _roof_node == null:
		_roof_node = get_node_or_null(NodePath("%s/%s" % [CHILD_VISUAL, CHILD_ROOF])) as Node2D
	if _roof_node != null:
		_roof_node.visible = visible_now


func is_roof_visible() -> bool:
	return _roof_node != null and _roof_node.visible


func set_visual_visible(visible_now: bool) -> void:
	var visual := get_node_or_null(NodePath(CHILD_VISUAL)) as Node2D
	if visual != null:
		visual.visible = visible_now


# ---------------------------------------------------------------- 调试绘制

func _draw() -> void:
	if not debug_draw:
		return
	var data := get_building_data()
	if data == null:
		return
	var tile := Vector2(data.get_tile_size())
	var origin := -data.get_anchor_local_px()
	for cell in data.get_occupied_cells():
		var rect := Rect2(origin + Vector2(cell) * tile, tile)
		if data.is_cell_walkable(cell):
			draw_rect(rect, Color(0.2, 1.0, 0.3, 0.18), true)
		elif data.is_cell_blocked(cell):
			draw_rect(rect, Color(1.0, 0.2, 0.2, 0.22), true)
		else:
			draw_rect(rect, Color(1.0, 0.9, 0.2, 0.12), true)
	for door in data.get_doors():
		var cell_array: Array = (door as Dictionary).get("cell", [0, 0])
		var cell := Vector2i(int(cell_array[0]), int(cell_array[1]))
		var rect := Rect2(origin + Vector2(cell) * tile, tile)
		draw_rect(rect, Color(0.3, 0.6, 1.0, 0.9), false, 3.0)
	draw_rect(Rect2(origin, Vector2(data.get_footprint_size()) * tile), Color(1, 0, 1, 0.7), false, 2.0)
