class_name BuildingPlacer
extends RefCounted

## **Agent 的高层建筑接口**。地图侧想放/查/删一座大型建筑，只调这里的方法，
## 不要自己去 add_child 几十个节点、不要自己去写占用数据。
##
## 典型一句话流程（"在当前地图中央放一座伊瑟拉修道院"）：
## ```
## var placer := BuildingPlacer.new()
## placer.list_buildings()                       # 1. 有哪些建筑
## placer.inspect_building("iserra_monastery")   # 2. 它长什么样、多大、门在哪
## placer.place_building(map_path, "iserra_monastery", cell)   # 3. 放下去（自动占格/碰撞/门/层级）
## placer.validate_map_buildings(map_path)       # 4. 放完验一遍
## ```
##
## 所有方法都返回**结构化结果**（Dictionary），失败时 `ok = false` 且带 `errors`，
## 而不是靠打印一段话。
##
## 与地图系统的分工（不破坏现有地图）：
## - 建筑自己管视觉、碰撞、门、战术数据；
## - 地图只管把建筑节点挂到 `建筑对象` 容器下，并在 `is_cell_walkable()` 里
##   让建筑对**它占用到的格**表态（见 core/world/map_scene.gd）。

const BUILDING_ROOT := "建筑对象"
const BUILDING_SCRIPT := "res://core/building/building.gd"

var library: BuildingLibrary
var validator: BuildingValidator


func _init() -> void:
	library = BuildingLibrary.new()
	validator = BuildingValidator.new()


# ================================================================ 查询

## 列出全部建筑（Agent 选建筑用）。
func list_buildings() -> Array:
	return library.list_buildings()


## 看一座建筑的细节：摘要 + 门清单 + 房间清单 + 文件清单 + 校验结果。
func inspect_building(building_id: String) -> Dictionary:
	if not library.has_building(building_id):
		return {
			"ok": false,
			"building_id": building_id,
			"errors": [{"code": "building.not_found", "severity": "error",
				"path": library.get_metadata_path(building_id),
				"message": "建筑「%s」不存在" % building_id,
				"detail": {"available": Array(library.list_building_ids())}}],
		}
	var data := library.load_building(building_id)
	if data == null:
		return {
			"ok": false,
			"building_id": building_id,
			"errors": [{"code": "building.metadata_unreadable", "severity": "error",
				"path": library.get_metadata_path(building_id),
				"message": "metadata 解析失败", "detail": {}}],
		}
	var doors: Array = []
	for door in data.get_doors():
		var d: Dictionary = door
		var cell: Array = d.get("cell", [0, 0])
		doors.append({
			"id": String(d.get("id", "")),
			"label": String(d.get("label", "")),
			"cell": [int(cell[0]), int(cell[1])],
			"outward_side": String(d.get("outward_side", "")),
			"width_tiles": int(d.get("width_tiles", 1)),
			"target": String(d.get("target", "")),
			"interact": String(d.get("interact", "")),
		})
	var rooms: Array = []
	for room in data.get_rooms():
		var r: Dictionary = room
		rooms.append({
			"id": String(r.get("id", "")),
			"label": String(r.get("label", "")),
			"rect": r.get("rect", []),
			"roofed": bool(r.get("roofed", false)),
		})
	return {
		"ok": true,
		"building_id": building_id,
		"summary": data.summarize(),
		"doors": doors,
		"rooms": rooms,
		"files": library.list_files(building_id),
		"footprint_rect": [0, 0, data.get_footprint_size().x, data.get_footprint_size().y],
		"tactical": data.get_tactical(),
		"sorting": data.get_sorting(),
	}


## 查一座建筑（package + prefab 两层）。
func validate_building(building_id: String, check_prefab: bool = true) -> Dictionary:
	validator.clear()
	validator.validate_package(building_id)
	if check_prefab:
		validator.validate_prefab(building_id, true)
	return validator.report(building_id)


## 查一张地图里的全部建筑（含每座建筑的放置合法性）。
func validate_map_buildings(map_path: String) -> Dictionary:
	validator.clear()
	var packed := load(map_path) as PackedScene
	if packed == null:
		return {
			"ok": false,
			"map": map_path,
			"errors": [{"code": "map.load_failed", "severity": "error", "path": map_path,
				"message": "地图场景加载失败", "detail": {}}],
			"warnings": 0, "issues": [],
		}
	var map := packed.instantiate()
	var buildings: Array = []
	if map.has_method("get_buildings"):
		buildings = map.call("get_buildings")
	for candidate in buildings:
		var building := candidate as Building
		if building == null:
			continue
		var data := building.get_building_data()
		if data == null:
			validator._error("map.building_without_data", map_path,
				"地图里的节点「%s」挂了 Building 脚本但读不到数据" % building.name, {})
			continue
		validator.validate_package(data.building_id)
		# 传自己的节点名：不然"与已有建筑重叠"会把这座建筑自己算成冲突
		validator.validate_placement(data.building_id, map, building.get_top_left_cell(),
			String(building.name))
	var report := validator.report(map_path)
	report["map"] = map_path
	report["buildings"] = _building_summaries(map)
	map.free()
	return report


func _building_summaries(map: Node) -> Array:
	var out: Array = []
	if not map.has_method("get_buildings"):
		return out
	for candidate in map.call("get_buildings"):
		var building := candidate as Building
		if building == null:
			continue
		var data := building.get_building_data()
		out.append({
			"node": String(building.name),
			"building_id": building.get_building_id(),
			"top_left_cell": [building.get_top_left_cell().x, building.get_top_left_cell().y],
			"footprint": [] if data == null else [data.get_footprint_size().x, data.get_footprint_size().y],
		})
	return out


# ================================================================ 放置 / 移除

## 把建筑放进地图（改的是场景文件本身，幂等重跑安全）。
##
## `top_left_cell` = 建筑地基左上角要落在哪个地图格。
## 返回 `{"ok", "map", "building_id", "node", "top_left_cell", "occupied_cells", "walkable_cells", "doors", "errors", "warnings"}`
func place_building(map_path: String, building_id: String, top_left_cell: Vector2i,
		options: Dictionary = {}) -> Dictionary:
	var building_data := library.load_building(building_id)
	if building_data == null:
		return _fail("building.not_found", "建筑「%s」不存在（先跑 list_buildings）" % building_id,
			library.get_metadata_path(building_id))

	var map := _open_map(map_path)
	if map == null:
		return _fail("map.load_failed", "地图场景加载失败：%s" % map_path, map_path)

	# 自动扩张地图：建筑比地图大就先把地图撑到装得下（不裁剪已有内容）
	var map_size: Vector2i = map.call("get_map_size_cells")
	var needed: Vector2i = top_left_cell + building_data.get_footprint_size()
	var grown := map_size
	if needed.x > map_size.x:
		grown.x = needed.x
	if needed.y > map_size.y:
		grown.y = needed.y
	if grown != map_size:
		map.set("map_size_cells", grown)

	# 放置前先校验（拿到干净的错误再决定放不放）
	validator.clear()
	validator.validate_placement(building_id, map, top_left_cell)
	if validator.has_errors() and not bool(options.get("force", false)):
		var blocking_report := validator.report(building_id)
		blocking_report["map"] = map_path
		map.free()
		return blocking_report

	var instance := _make_building_node(building_id)
	if instance == null:
		map.free()
		return _fail("prefab.instantiate_failed", "建筑 Prefab 实例化失败：%s" % _prefab_path(building_id),
			_prefab_path(building_id))

	var root := _ensure_building_root(map)
	var node_name := String(options.get("name", instance.name))
	instance.name = node_name
	root.add_child(instance)
	# owner 指向地图根：再保存地图时，这个节点作为"Prefab 的实例"被引用进去，
	# 而不是把几十上百个碰撞节点摊平写进地图（省体积，也让 Prefab 改动能传导）。
	instance.owner = map
	var building := instance as Building
	var data := building.get_building_data()
	building.position = data.top_left_cell_to_node_position(top_left_cell)
	building.set_placement_cell(top_left_cell)
	instance.set_meta("building_id", building_id)
	instance.set_meta("top_left_cell", top_left_cell)

	var save_error := _save_map(map, map_path)
	var final_size: Vector2i = map.call("get_map_size_cells")
	var report := validator.report(building_id)
	var result := {
		"ok": save_error == OK,
		"map": map_path,
		"building_id": building_id,
		"node": "%s/%s" % [BUILDING_ROOT, node_name],
		"top_left_cell": [top_left_cell.x, top_left_cell.y],
		"footprint": [data.get_footprint_size().x, data.get_footprint_size().y],
		"occupied_cells": data.get_occupied_count(),
		"walkable_cells": data.get_walkable_count(),
		"blocked_cells": data.get_blocked_count(),
		"doors": data.get_doors().size(),
		"collision_rects": data.get_collision_rects().size(),
		"map_size_cells": [final_size.x, final_size.y],
		"errors": [],
		"warnings": report["issues"],
	}
	if save_error != OK:
		result["errors"].append({
			"code": "map.save_failed", "severity": "error", "path": map_path,
			"message": "地图保存失败 err=%d" % save_error, "detail": {},
		})
		result["ok"] = false
	else:
		print("WROTE ", map_path)
	map.free()
	return result


## 从地图里移除建筑（按节点名或按所在地图格）。
func remove_building(map_path: String, selector: Variant) -> Dictionary:
	var map := _open_map(map_path)
	if map == null:
		return _fail("map.load_failed", "地图场景加载失败：%s" % map_path, map_path)
	var root := map.get_node_or_null(NodePath(BUILDING_ROOT))
	if root == null:
		map.free()
		return _fail("map.no_building_root", "地图里没有「%s」容器，按定义没有任何建筑" % BUILDING_ROOT, map_path)

	var removed: Array = []
	for child in root.get_children():
		var building := child as Building
		if building == null:
			continue
		var matched := false
		if typeof(selector) == TYPE_STRING:
			matched = String(child.name) == String(selector)
		elif selector is Vector2i:
			matched = building.covers_map_cell(selector)
		if not matched:
			continue
		removed.append(String(child.name))
		root.remove_child(child)
		child.queue_free()
	if removed.is_empty():
		map.free()
		return _fail("map.building_not_found", "地图里找不到要移除的建筑：%s" % str(selector), map_path)

	var save_error := _save_map(map, map_path)
	map.free()
	return {
		"ok": save_error == OK,
		"map": map_path,
		"removed": removed,
		"errors": [] if save_error == OK else [{
			"code": "map.save_failed", "severity": "error", "path": map_path,
			"message": "地图保存失败 err=%d" % save_error, "detail": {},
		}],
	}


## 把某座建筑搬到别处（移除 + 重新放置，保持节点名）。
func move_building(map_path: String, node_name: String, top_left_cell: Vector2i) -> Dictionary:
	var map := _open_map(map_path)
	if map == null:
		return _fail("map.load_failed", "地图场景加载失败：%s" % map_path, map_path)
	var root := map.get_node_or_null(NodePath(BUILDING_ROOT))
	var building: Building = null
	if root != null:
		building = root.get_node_or_null(NodePath(node_name)) as Building
	if building == null:
		map.free()
		return _fail("map.building_not_found", "地图里没有建筑节点「%s」" % node_name, map_path)
	var building_id := building.get_building_id()
	map.free()
	remove_building(map_path, node_name)
	return place_building(map_path, building_id, top_left_cell, {"name": node_name})


# ================================================================ 内部

func _open_map(map_path: String) -> Node:
	if not FileAccess.file_exists(map_path):
		return null
	var packed := load(map_path) as PackedScene
	if packed == null:
		return null
	return packed.instantiate()


func _ensure_building_root(map: Node) -> Node2D:
	var existing := map.get_node_or_null(NodePath(BUILDING_ROOT))
	if existing is Node2D:
		return existing
	var root := Node2D.new()
	root.name = BUILDING_ROOT
	# Y 轴排序：建筑之间、建筑与角色之间按"脚下"前后遮挡
	root.y_sort_enabled = true
	map.add_child(root)
	root.owner = map
	return root


func _make_building_node(building_id: String) -> Node:
	var data := library.load_building(building_id)
	if data == null:
		return null
	var prefab := _prefab_path(building_id)
	if FileAccess.file_exists(prefab):
		var packed := load(prefab) as PackedScene
		if packed != null:
			return packed.instantiate()
	# 没有 Prefab 就退回"通用建筑节点"：仍然能显示与占地，只是碰撞形状要运行时按掩码建。
	push_warning("建筑 %s 没有 Prefab（%s），改用通用节点按掩码构建" % [building_id, prefab])
	var node := Node2D.new()
	node.set_script(load(BUILDING_SCRIPT))
	node.set("building_id", building_id)
	node.set("data_path", library.get_metadata_path(building_id))
	node.name = BuildingData.prefab_file_name(building_id).get_basename()
	return node


func _prefab_path(building_id: String) -> String:
	var data := library.load_building(building_id)
	if data != null and not data.prefab_path.is_empty():
		return data.prefab_path
	return library.get_asset_dir(building_id).path_join(BuildingData.prefab_file_name(building_id))


func _save_map(map: Node, map_path: String) -> int:
	var packed := PackedScene.new()
	var pack_error := packed.pack(map)
	if pack_error != OK:
		return pack_error
	return ResourceSaver.save(packed, map_path)


func _fail(code: String, message: String, path: String) -> Dictionary:
	return {
		"ok": false,
		"errors": [{"code": code, "severity": "error", "path": path,
			"message": message, "detail": {}}],
	}
