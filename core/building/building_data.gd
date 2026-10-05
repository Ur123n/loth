class_name BuildingData
extends RefCounted

## 大型建筑的**机器可读描述**（metadata/building.json 的内存形态）。
##
## 为什么要有它：Agent 每次要用一座建筑时，**不应该再去"看"那张大图**。
## 建筑做完一次，几何就固定下来（占用/可走/实体/门/房间/战术/层级），
## 之后所有工具（放置、校验、寻路、战斗）都只读这份描述。
##
## 坐标系统（全项目统一，别在别处另立一套）：
## - **局部格**：建筑左上角为 (0,0)，x 向东、y 向南，整数格。
## - **局部像素**：`局部格 × tile_size`，原点 = 建筑左上角像素。
## - **地图格**：`建筑左上角所在地图格 + 局部格`。
## - **世界像素**：`Building` 节点位置 + 局部像素（节点原点在底部中心，见 anchor）。
##
## 视觉尺寸与逻辑尺寸**故意解耦**：`visual.size_tiles` 可以远大于
## `footprint.size_cells`（一栋 69×73 格的建筑，视觉就是 3312×3504 像素一张图），
## 也可以略大（出血），两者都不影响逻辑。

const SCHEMA := "building/1"

var building_id: String = ""
var display_name: String = ""
var display_name_en: String = ""
var kind: String = "large_building"
var tile_size: Vector2i = Vector2i(48, 48)
var asset_path: String = ""
var prefab_path: String = ""
var source_path: String = ""
## 视觉：size_px / size_tiles / padding_tiles / layers[{name, path, z_index, visible, role}]
var visual: Dictionary = {}
## 逻辑外形：origin_cell（局部格，恒为 (0,0)）+ size_cells + size_px
var footprint: Dictionary = {}
## 锚点：节点原点在局部格坐标系里的位置（默认底部中心 → 保证 Y 轴排序正确）
var anchor: Dictionary = {}
var sorting: Dictionary = {}
var tactical: Dictionary = {}
var collision: Dictionary = {}
var rooms: Array = []
var doors: Array = []
var masks: Dictionary = {}
var source: Dictionary = {}
var raw: Dictionary = {}

var _occupied: Dictionary = {}
var _walkable: Dictionary = {}
var _blocked: Dictionary = {}
var _occlusion: Dictionary = {}
var _door_cells: Dictionary = {}
var _door_by_cell: Dictionary = {}


## 从字典建（metadata JSON 的内容）。几何字段同时接受 `occupied_cells` 与
## `occupied_hexes`（旧命名兼容），取值优先前者。
static func from_dictionary(dict: Dictionary) -> BuildingData:
	var data := BuildingData.new()
	data.raw = dict.duplicate(true)
	data.building_id = String(dict.get("building_id", ""))
	data.display_name = String(dict.get("display_name", data.building_id))
	data.display_name_en = String(dict.get("display_name_en", ""))
	data.kind = String(dict.get("kind", "large_building"))
	data.asset_path = String(dict.get("asset_path", ""))
	data.prefab_path = String(dict.get("prefab_path", ""))
	data.source_path = String(dict.get("source_path", ""))
	data.visual = dict.get("visual", {})
	data.footprint = dict.get("footprint", {})
	data.anchor = dict.get("anchor", {})
	data.sorting = dict.get("sorting", {})
	data.tactical = dict.get("tactical", {})
	data.collision = dict.get("collision", {})
	data.rooms = dict.get("rooms", [])
	data.doors = dict.get("doors", [])
	data.masks = dict.get("masks", {})
	data.source = dict.get("source", {})

	var size: Array = data.footprint.get("size_cells", [0, 0])
	var tile_array: Array = dict.get("tile_size", data.visual.get("tile_size", [48, 48]))
	data.tile_size = Vector2i(maxi(1, int(tile_array[0])), maxi(1, int(tile_array[1])))

	data._occupied = BuildingMask.cells_from_runs(_runs_of(dict, "occupied_cells", "occupied_hexes"))
	data._walkable = BuildingMask.cells_from_runs(_runs_of(dict, "walkable_cells", "walkable_hexes"))
	data._blocked = BuildingMask.cells_from_runs(_runs_of(dict, "blocked_cells", "blocked_hexes"))
	data._occlusion = BuildingMask.cells_from_runs(_runs_of(dict, "occlusion_cells", "occlusion_hexes"))
	if data._occupied.is_empty() and size.size() >= 2 and int(size[0]) > 0:
		push_warning("建筑 %s 的 occupied_cells 为空（footprint %s）" % [data.building_id, str(size)])

	for door in data.doors:
		var d: Dictionary = door
		var cell_array: Array = d.get("cell", [0, 0])
		var cell := Vector2i(int(cell_array[0]), int(cell_array[1]))
		data._door_cells[cell] = true
		data._door_by_cell[cell] = d
		var width := int(d.get("width_tiles", 1))
		# 门可能横跨多格（双开门）：把整段都登记上（n/s 门沿 x 展开，e/w 门沿 y 展开）
		var outward := String(d.get("outward_side", "n"))
		for i in range(1, maxi(1, width)):
			var along := Vector2i(i, 0) if outward in ["n", "s"] else Vector2i(0, i)
			data._door_cells[cell + along] = true
			data._door_by_cell[cell + along] = d
	return data


## 建筑 id → Prefab 文件名（`iserra_monastery` → `IserraMonastery.tscn`）。
## 全项目只有这一处定义命名规则，生成器与校验器都调它，避免各写一份对不上。
static func prefab_file_name(building_id: String) -> String:
	var out := ""
	for part in building_id.split("_"):
		if part.is_empty():
			continue
		out += part.substr(0, 1).to_upper() + part.substr(1)
	if out.is_empty():
		out = "Building"
	return out + ".tscn"


## 游程编码归一成 int。
## **为什么需要**：metadata 是 JSON，JSON 里的数字没有 int/float 之分，
## 读回来一律变成 float（`0` → `0.0`）。需要拿它跟"现算出来的"游程做相等比较时，
## 先过一遍这里，避免 `[0, 0, 51] != [0.0, 0.0, 51.0]` 这种假失败。
static func normalize_runs(runs: Array) -> Array:
	var out: Array = []
	for entry in runs:
		if typeof(entry) != TYPE_ARRAY:
			continue
		var row: Array = entry
		if row.size() < 3:
			continue
		out.append([int(row[0]), int(row[1]), int(row[2])])
	return out


static func _runs_of(dict: Dictionary, key: String, fallback_key: String) -> Array:
	var holder: Variant = dict.get(key, null)
	if holder == null:
		holder = dict.get(fallback_key, null)
	if holder == null:
		return []
	if typeof(holder) == TYPE_ARRAY:
		return holder
	if typeof(holder) == TYPE_DICTIONARY:
		return (holder as Dictionary).get("runs", [])
	return []


## 从 JSON 文件读；失败返回 null 并 push_warning。
static func load_from_json(path: String) -> BuildingData:
	if not FileAccess.file_exists(path):
		push_warning("建筑 metadata 不存在：%s" % path)
		return null
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("建筑 metadata 不是合法 JSON：%s" % path)
		return null
	var data := from_dictionary(parsed)
	data.source_path = path
	return data


# ---------------------------------------------------------------- 基础几何

func get_footprint_size() -> Vector2i:
	var size: Array = footprint.get("size_cells", [0, 0])
	return Vector2i(int(size[0]), int(size[1]))


func get_visual_size_px() -> Vector2i:
	var size: Array = visual.get("size_px", [0, 0])
	return Vector2i(int(size[0]), int(size[1]))


func get_visual_size_tiles() -> Vector2i:
	var size: Array = visual.get("size_tiles", [0, 0])
	return Vector2i(int(size[0]), int(size[1]))


func get_padding_tiles() -> int:
	return int(visual.get("padding_tiles", 0))


## footprint 在局部格坐标系里的矩形（原点恒为 (0,0)）。
func get_footprint_rect() -> Rect2i:
	return Rect2i(Vector2i.ZERO, get_footprint_size())


func get_tile_size() -> Vector2i:
	return tile_size


## 局部格 → 局部像素（左上角）。
func cell_to_local_px(cell: Vector2i) -> Vector2:
	return Vector2(cell) * Vector2(tile_size)


## 局部格中心 → 局部像素。
func cell_center_local_px(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * Vector2(tile_size)


## 局部像素 → 局部格（floor）。
func local_px_to_cell(px: Vector2) -> Vector2i:
	return Vector2i(floori(px.x / float(tile_size.x)), floori(px.y / float(tile_size.y)))


## 节点原点（默认底部中心）在局部像素坐标系里的位置。
## Y 轴排序要求节点原点落在建筑"脚下"，否则整栋楼会永远压在角色下面。
func get_anchor_local_px() -> Vector2:
	return BuildingData.anchor_local_px(String(anchor.get("mode", "bottom_center")),
		get_footprint_size(), tile_size)


## 锚点换算（生成器与本类共用同一套规则，避免两处实现漂移）。
static func anchor_local_px(mode: String, size: Vector2i, tile: Vector2i) -> Vector2:
	match mode:
		"top_left":
			return Vector2.ZERO
		"center":
			return Vector2(size) * 0.5 * Vector2(tile)
		"bottom_left":
			return Vector2(0, size.y) * Vector2(tile)
		_:
			return Vector2(size.x * 0.5, float(size.y)) * Vector2(tile)


## 视觉层贴图相对节点原点的偏移：`视觉图左上角在局部像素里的位置 − 锚点`。
## 视觉图左上角不一定等于 footprint 左上角（有出血 padding 时会差几格），
## 所以这个偏移不能想当然地写成 `-anchor`。
func get_visual_offset_px() -> Vector2:
	var declared: Variant = visual.get("anchor_offset_px", null)
	if typeof(declared) == TYPE_ARRAY and (declared as Array).size() >= 2:
		return Vector2(float(declared[0]), float(declared[1]))
	var origin: Array = visual.get("origin_tile", [0, 0])
	return Vector2(int(origin[0]), int(origin[1])) * Vector2(tile_size) - get_anchor_local_px()


## 从「footprint 左上角所在地图格」到节点位置的像素换算（放置器用）。
func top_left_cell_to_node_position(top_left_cell: Vector2i) -> Vector2:
	return Vector2(top_left_cell) * Vector2(tile_size) + get_anchor_local_px()


## 节点位置 → footprint 左上角所在地图格。
func node_position_to_top_left_cell(node_position: Vector2) -> Vector2i:
	return local_px_to_cell(node_position - get_anchor_local_px())


# ---------------------------------------------------------------- 逻辑查询

func get_occupied_cells() -> Dictionary:
	return _occupied


func get_walkable_cells() -> Dictionary:
	return _walkable


func get_blocked_cells() -> Dictionary:
	return _blocked


func get_occlusion_cells() -> Dictionary:
	return _occlusion


func get_door_cells() -> Dictionary:
	return _door_cells


func get_occupied_count() -> int:
	return _occupied.size()


func get_walkable_count() -> int:
	return _walkable.size()


func get_blocked_count() -> int:
	return _blocked.size()


func is_cell_occupied(cell: Vector2i) -> bool:
	return _occupied.has(cell)


func is_cell_walkable(cell: Vector2i) -> bool:
	return _walkable.has(cell)


func is_cell_blocked(cell: Vector2i) -> bool:
	return _blocked.has(cell)


func is_cell_door(cell: Vector2i) -> bool:
	return _door_cells.has(cell)


func is_cell_occluded(cell: Vector2i) -> bool:
	return _occlusion.has(cell)


## 占用区里"既不通行也不阻挡"的格（屋顶投影、纯装饰占位）——不算冲突。
func is_cell_decorative(cell: Vector2i) -> bool:
	return _occupied.has(cell) and not _walkable.has(cell) and not _blocked.has(cell)


## 一格的通行裁定：**建筑占用区内由建筑说了算**。
## 返回 `{"occupied", "walkable", "blocked", "door", "authoritative"}`。
func resolve_cell(cell: Vector2i) -> Dictionary:
	var occupied := _occupied.has(cell)
	return {
		"occupied": occupied,
		"walkable": _walkable.has(cell),
		"blocked": _blocked.has(cell),
		"door": _door_cells.has(cell),
		"occluded": _occlusion.has(cell),
		"authoritative": occupied,
	}


func get_doors() -> Array:
	return doors


func get_door_at(cell: Vector2i) -> Dictionary:
	return _door_by_cell.get(cell, {})


func get_rooms() -> Array:
	return rooms


func get_room(room_id: String) -> Dictionary:
	for room in rooms:
		if String((room as Dictionary).get("id", "")) == room_id:
			return room
	return {}


func get_tactical() -> Dictionary:
	return tactical


func get_sorting() -> Dictionary:
	return sorting


func get_collision() -> Dictionary:
	return collision


func get_collision_rects() -> Array:
	return collision.get("rects", [])


func get_visual_layers() -> Array:
	return visual.get("layers", [])


## 供 Agent 一眼看懂的摘要（不返回几何，几何在 metadata 里）。
func summarize() -> Dictionary:
	return {
		"building_id": building_id,
		"display_name": display_name,
		"kind": kind,
		"footprint_cells": [get_footprint_size().x, get_footprint_size().y],
		"footprint_px": [get_footprint_size().x * tile_size.x, get_footprint_size().y * tile_size.y],
		"visual_size_px": [get_visual_size_px().x, get_visual_size_px().y],
		"tile_size": [tile_size.x, tile_size.y],
		"occupied": get_occupied_count(),
		"walkable": get_walkable_count(),
		"blocked": get_blocked_count(),
		"doors": doors.size(),
		"rooms": rooms.size(),
		"collision_rects": get_collision_rects().size(),
		"prefab_path": prefab_path,
		"asset_path": asset_path,
		"tactical": tactical,
	}
