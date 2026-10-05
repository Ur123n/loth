class_name BuildingValidator
extends RefCounted

## 建筑校验：**返回结构化错误，不是一段自然语言**。
##
## 每条问题是 `{"code", "severity", "path", "message", "detail"}`：
## - `code`  稳定机器码（Agent 按码分支，不要按中文文案匹配）
## - `severity` `"error"` / `"warning"`
## - `path`  出问题的资源路径或"字段路径"（如 `metadata.doors[2].cell`）
## - `message` 人读的一句话
## - `detail` 机器读的补充数据（格坐标、期望值等）
##
## 校验分三层，可单独跑：
## 1. `validate_package()`  —— 资产包自身：文件是否齐、metadata 是否完整、掩码是否自洽
## 2. `validate_prefab()`   —— Prefab 是否能实例化、节点结构是否齐、视觉/碰撞是否对得上
## 3. `validate_placement()` —— 放进某张地图后：是否越界、是否与别处冲突、门口能不能走到

const SEVERITY_ERROR := "error"
const SEVERITY_WARNING := "warning"

## 资产包必须存在的文件（相对资产目录）。
const REQUIRED_MASKS: Array[String] = [
	"masks/occupancy.png", "masks/walkable.png", "masks/collision.png",
	"masks/occlusion.png", "masks/doors.png", "masks/legend.json",
]
const REQUIRED_METADATA: Array[String] = ["metadata/building.json"]
const REQUIRED_VISUAL: Array[String] = ["visual/base.png"]

var _issues: Array = []


func get_issues() -> Array:
	return _issues


func has_errors() -> bool:
	for issue in _issues:
		if String((issue as Dictionary).get("severity", "")) == SEVERITY_ERROR:
			return true
	return false


func error_count() -> int:
	var count := 0
	for issue in _issues:
		if String((issue as Dictionary).get("severity", "")) == SEVERITY_ERROR:
			count += 1
	return count


func warning_count() -> int:
	var count := 0
	for issue in _issues:
		if String((issue as Dictionary).get("severity", "")) == SEVERITY_WARNING:
			count += 1
	return count


func clear() -> void:
	_issues.clear()


func _error(code: String, path: String, message: String, detail: Dictionary = {}) -> void:
	_issues.append({
		"code": code, "severity": SEVERITY_ERROR, "path": path,
		"message": message, "detail": detail,
	})


func _warn(code: String, path: String, message: String, detail: Dictionary = {}) -> void:
	_issues.append({
		"code": code, "severity": SEVERITY_WARNING, "path": path,
		"message": message, "detail": detail,
	})


## 汇总成 Agent 直接吃的结构。
func report(building_id: String) -> Dictionary:
	return {
		"ok": not has_errors(),
		"building_id": building_id,
		"errors": error_count(),
		"warnings": warning_count(),
		"issues": _issues.duplicate(true),
	}


# ================================================================ 1. 资产包

## 校验一座建筑的资产包（不实例化 Prefab）。
func validate_package(building_id: String) -> Array:
	var library := BuildingLibrary.new()
	var base := library.get_asset_dir(building_id)
	if not FileAccess.file_exists(library.get_metadata_path(building_id)):
		_error("package.missing_metadata", library.get_metadata_path(building_id),
			"建筑资产包缺少 metadata/building.json（先跑 build_building.gd）",
			{"building_id": building_id})
		return _issues
	if DirAccess.open(base) == null:
		_error("package.missing_dir", base, "建筑资产目录不存在", {"building_id": building_id})
		return _issues

	for relative in REQUIRED_METADATA + REQUIRED_VISUAL + REQUIRED_MASKS:
		var full := base.path_join(relative)
		if not FileAccess.file_exists(full):
			_error("package.missing_file", full, "资产包缺少必需文件：%s" % relative,
				{"building_id": building_id, "relative": relative})

	var data := library.load_building(building_id)
	if data == null:
		_error("metadata.parse_failed", library.get_metadata_path(building_id),
			"metadata/building.json 不是合法 JSON 或结构不对")
		return _issues

	_validate_metadata_fields(data, library)
	if has_errors() and data.get_footprint_size() == Vector2i.ZERO:
		return _issues   # 几何都没法定下来，后面的检查没有意义
	_validate_geometry(data)
	_validate_doors(data)
	_validate_collision(data)
	_validate_visual_files(data, library)
	_validate_declared_paths(data)
	return _issues


func _validate_metadata_fields(data: BuildingData, library: BuildingLibrary) -> void:
	var meta_path := library.get_metadata_path(data.building_id)
	if data.building_id.is_empty():
		_error("metadata.missing_field", meta_path, "metadata 缺少 building_id", {"field": "building_id"})
	if data.display_name.is_empty():
		_warn("metadata.missing_field", meta_path, "metadata 缺少 display_name（界面会退回用 id）",
			{"field": "display_name"})
	if data.get_footprint_size().x <= 0 or data.get_footprint_size().y <= 0:
		_error("metadata.bad_footprint", meta_path, "footprint.size_cells 必须是正整数",
			{"size_cells": data.footprint.get("size_cells", [])})
	if data.get_visual_size_px().x <= 0 or data.get_visual_size_px().y <= 0:
		_error("metadata.bad_visual_size", meta_path, "visual.size_px 必须是正整数",
			{"size_px": data.visual.get("size_px", [])})
	if data.tile_size.x <= 0 or data.tile_size.y <= 0:
		_error("metadata.bad_tile_size", meta_path, "tile_size 必须是正整数",
			{"tile_size": [data.tile_size.x, data.tile_size.y]})
	if data.get_visual_layers().is_empty():
		_error("metadata.no_visual_layer", meta_path, "visual.layers 为空，视觉层无法构建")
	if data.tactical.is_empty():
		_warn("metadata.no_tactical", meta_path, "缺少 tactical（战斗系统会当成无掩体无高低差）",
			{"field": "tactical"})
	if data.sorting.is_empty():
		_warn("metadata.no_sorting", meta_path, "缺少 sorting（Y 轴排序会退回默认）",
			{"field": "sorting"})
	else:
		_validate_sort_bands(data, meta_path)
	if not data.anchor.has("mode"):
		_warn("metadata.no_anchor_mode", meta_path, "anchor 缺少 mode，按默认 bottom_center 处理",
			{"field": "anchor.mode"})
	if data.raw.has("schema") and String(data.raw["schema"]) != BuildingData.SCHEMA:
		_warn("metadata.schema_mismatch", meta_path,
			"metadata schema 是 %s，本版工具按 %s 解析" % [data.raw["schema"], BuildingData.SCHEMA],
			{"found": String(data.raw["schema"]), "expected": BuildingData.SCHEMA})


func _validate_sort_bands(data: BuildingData, meta_path: String) -> void:
	var bands: Array = data.sorting.get("bands", [])
	if bands.is_empty():
		return
	var size_array: Array = data.visual.get("size_tiles", [])
	if size_array.size() != 2:
		_error("sorting.missing_visual_size", meta_path, "sorting.bands 需要 visual.size_tiles")
		return
	var visual_size := Vector2i(int(size_array[0]), int(size_array[1]))
	var covered: Dictionary = {}
	var ids: Dictionary = {}
	var overlap_count := 0
	for index in bands.size():
		if typeof(bands[index]) != TYPE_DICTIONARY:
			_error("sorting.band_bad_entry", meta_path, "sorting.bands[%d] 必须是对象" % index)
			continue
		var band: Dictionary = bands[index]
		var band_id := String(band.get("id", ""))
		if band_id.is_empty() or ids.has(band_id):
			_error("sorting.band_duplicate_id", meta_path, "切带 id 为空或重复：%s" % band_id,
				{"index": index, "id": band_id})
		else:
			ids[band_id] = true
		var values: Array = band.get("source_rect_tiles", [])
		if values.size() != 4:
			_error("sorting.band_bad_rect", meta_path, "切带 %s 的 source_rect_tiles 必须有 4 个整数" % band_id)
			continue
		var rect := Rect2i(int(values[0]), int(values[1]), int(values[2]), int(values[3]))
		if rect.position.x < 0 or rect.position.y < 0 or rect.size.x <= 0 or rect.size.y <= 0:
			_error("sorting.band_bad_rect", meta_path, "切带 %s 的矩形必须为非负起点和正尺寸" % band_id,
				{"rect": values})
			continue
		if rect.end.x > visual_size.x or rect.end.y > visual_size.y:
			_error("sorting.band_out_of_bounds", meta_path, "切带 %s 超出视觉画布" % band_id,
				{"rect": values, "visual_size_tiles": [visual_size.x, visual_size.y]})
			continue
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var cell := Vector2i(x, y)
				if covered.has(cell):
					overlap_count += 1
				covered[cell] = band_id
	if overlap_count > 0:
		_error("sorting.band_overlap", meta_path, "语义切带有 %d 个视觉格重叠" % overlap_count,
			{"overlap_cells": overlap_count})
	var expected_area := visual_size.x * visual_size.y
	if covered.size() != expected_area:
		_error("sorting.band_coverage_gap", meta_path, "语义切带没有完整覆盖视觉画布",
			{"covered_cells": covered.size(), "expected_cells": expected_area})


func _validate_geometry(data: BuildingData) -> void:
	var footprint := data.get_footprint_rect()
	var occupied := data.get_occupied_cells()
	var walkable := data.get_walkable_cells()
	var blocked := data.get_blocked_cells()

	if occupied.is_empty():
		_error("geometry.empty_occupancy", data.source_path, "occupied_cells 为空：建筑没有占用任何格")
		return

	# 1) 占用区必须在 footprint 内（越界 = 视觉与逻辑对不上）
	var out_of_bounds: Array = []
	for cell in occupied:
		if not footprint.has_point(cell):
			out_of_bounds.append([cell.x, cell.y])
	if not out_of_bounds.is_empty():
		_error("geometry.occupancy_out_of_bounds", data.source_path,
			"有 %d 个占用格超出 footprint %s" % [out_of_bounds.size(), str(footprint.size)],
			{"count": out_of_bounds.size(), "sample": out_of_bounds.slice(0, 8),
			 "footprint": [footprint.size.x, footprint.size.y]})

	# 2) 可通行区必须 ⊆ 占用区
	var walk_outside := BuildingMask.subtract(walkable, occupied)
	if not walk_outside.is_empty():
		var sample := _sample_cells(walk_outside)
		_error("geometry.walkable_outside_occupancy", data.source_path,
			"有 %d 个可通行格不在占用区内" % walk_outside.size(),
			{"count": walk_outside.size(), "sample": sample})

	# 3) 可通行区与实体区不得重叠
	var both := BuildingMask.intersect(walkable, blocked)
	if not both.is_empty():
		_error("geometry.walkable_collision_overlap", data.source_path,
			"有 %d 个格同时被标为可通行与实体" % both.size(),
			{"count": both.size(), "sample": _sample_cells(both)})

	# 4) 实体区必须 ⊆ 占用区
	var blocked_outside := BuildingMask.subtract(blocked, occupied)
	if not blocked_outside.is_empty():
		_error("geometry.collision_outside_occupancy", data.source_path,
			"有 %d 个实体格不在占用区内" % blocked_outside.size(),
			{"count": blocked_outside.size(), "sample": _sample_cells(blocked_outside)})

	# 5) 遮挡区 ⊆ 占用区
	var occl_outside := BuildingMask.subtract(data.get_occlusion_cells(), occupied)
	if not occl_outside.is_empty():
		_warn("geometry.occlusion_outside_occupancy", data.source_path,
			"有 %d 个遮挡格不在占用区内（不会致命，但收屋顶会算错）" % occl_outside.size(),
			{"count": occl_outside.size(), "sample": _sample_cells(occl_outside)})

	# 6) 必须真的有能走的地方，否则建筑是个实心疙瘩
	if walkable.is_empty():
		_error("geometry.no_walkable", data.source_path,
			"occupied 有格但 walkable 为空：建筑完全进不去")
	elif float(walkable.size()) / float(maxi(1, occupied.size())) < 0.05:
		_warn("geometry.tiny_walkable", data.source_path,
			"可通行格只占占用区的 %.1f%%，像是掩码填错了" % (100.0 * walkable.size() / maxi(1, occupied.size())),
			{"walkable": walkable.size(), "occupied": occupied.size()})

	# 7) 占用区必须连通（分散的碎块通常是掩码写错，而不是设计意图）
	var components := _component_count(occupied)
	if components > 1:
		_warn("geometry.disconnected_occupancy", data.source_path,
			"占用区被分成 %d 块（同一座建筑通常应当连通）" % components,
			{"components": components})
	# 8) 可通行区必须连通：封死的房间进不去（少开门 / 墙没打通）
	var walk_components := _component_count(walkable)
	if walk_components > 1:
		_error("geometry.disconnected_walkable", data.source_path,
			"可通行区被分成 %d 块：有房间被封死了（门没开穿墙 / 少了柱廊开口）" % walk_components,
			{"components": walk_components, "walkable": walkable.size(),
			 "hint": "在 building.spec.json 的 plan.doors 或 plan.openings 里补上连通"})


func _validate_doors(data: BuildingData) -> void:
	var doors := data.get_doors()
	if doors.is_empty():
		_error("doors.none", data.source_path, "doors 为空：大型建筑必须有入口")
		return
	var seen_ids := {}
	var footprint := data.get_footprint_rect()
	for index in doors.size():
		var door: Dictionary = doors[index]
		var field := "metadata.doors[%d]" % index
		var door_id := String(door.get("id", ""))
		if door_id.is_empty():
			_error("doors.missing_id", field, "第 %d 个门缺少 id" % index, {"index": index})
		elif seen_ids.has(door_id):
			_error("doors.duplicate_id", field, "门 id 重复：%s" % door_id, {"id": door_id})
		else:
			seen_ids[door_id] = true

		var cell_array: Variant = door.get("cell", null)
		if typeof(cell_array) != TYPE_ARRAY or (cell_array as Array).size() < 2:
			_error("doors.bad_cell", field, "门 %s 的 cell 必须是 [x, y]" % door_id, {"id": door_id})
			continue
		var cell := Vector2i(int(cell_array[0]), int(cell_array[1]))
		if not footprint.has_point(cell):
			_error("doors.cell_out_of_footprint", field,
				"门 %s 落在地基外 %s" % [door_id, str(cell)],
				{"id": door_id, "cell": [cell.x, cell.y],
				 "footprint": [footprint.size.x, footprint.size.y]})
			continue
		# 门必须落在占用区内
		if not data.is_cell_occupied(cell):
			_error("doors.not_in_occupancy", field, "门 %s 所在格没被建筑占用" % door_id,
				{"id": door_id, "cell": [cell.x, cell.y]})
		# 门必须能走（门口不能是实心墙）
		if not data.is_cell_walkable(cell):
			_error("doors.not_walkable", field, "门 %s 所在格不可通行（门被墙堵死了）" % door_id,
				{"id": door_id, "cell": [cell.x, cell.y]})
		# 门应当贴着占用区边界（外门）或两区之间（内门）：四邻里至少要有一个"非占用"或
		# 一个与门不同的房间，否则多半是位置写错了
		var side := String(door.get("outward_side", ""))
		if side.is_empty():
			_warn("doors.no_side", field, "门 %s 没写 outward_side（朝向）" % door_id, {"id": door_id})
		elif not BuildingMask.DOOR_SIDE_COLORS.has(side):
			_error("doors.bad_side", field,
				"门 %s 的 outward_side「%s」不是 n/s/e/w 之一" % [door_id, side],
				{"id": door_id, "side": side, "allowed": BuildingMask.DOOR_SIDES})
		var outward_offset := {"n": Vector2i(0, -1), "s": Vector2i(0, 1), "e": Vector2i(1, 0), "w": Vector2i(-1, 0)}
		if outward_offset.has(side):
			var outside_cell: Vector2i = cell + outward_offset[side]
			if data.is_cell_blocked(outside_cell):
				_error("doors.blocked_outward", field,
					"门 %s 朝外的格 %s 是实体，门推不开" % [door_id, str(outside_cell)],
					{"id": door_id, "outward_cell": [outside_cell.x, outside_cell.y]})
		var target := String(door.get("target", ""))
		if target.is_empty():
			_warn("doors.no_target", field, "门 %s 没写 target（进去之后去哪）" % door_id, {"id": door_id})
		elif target != "outside" and data.get_room(target).is_empty():
			_error("doors.unknown_target", field,
				"门 %s 的 target「%s」在 rooms 里不存在" % [door_id, target],
				{"id": door_id, "target": target})


func _validate_collision(data: BuildingData) -> void:
	var rects: Array = data.get_collision_rects()
	var blocked := data.get_blocked_cells()
	if blocked.is_empty() and rects.is_empty():
		_warn("collision.none", data.source_path, "collision 没有矩形：这栋建筑完全不挡路")
		return
	var area := 0
	var footprint := data.get_footprint_rect()
	for index in rects.size():
		var rect_array: Variant = rects[index]
		if typeof(rect_array) != TYPE_ARRAY or (rect_array as Array).size() < 4:
			_error("collision.bad_rect", "metadata.collision.rects[%d]" % index,
				"碰撞矩形必须是 [x, y, w, h]", {"index": index})
			continue
		var r: Array = rect_array
		var rect := Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))
		if rect.size.x <= 0 or rect.size.y <= 0:
			_error("collision.empty_rect", "metadata.collision.rects[%d]" % index,
				"碰撞矩形尺寸必须为正", {"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]})
			continue
		if not footprint.encloses(rect):
			_error("collision.rect_out_of_bounds", "metadata.collision.rects[%d]" % index,
				"碰撞矩形 %s 超出 footprint %s" % [str(rect), str(footprint.size)],
				{"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]})
		area += rect.size.x * rect.size.y
	# 矩形面积必须等于实体格数（分解得不重不漏）
	if not rects.is_empty() and area != blocked.size():
		_error("collision.area_mismatch", data.source_path,
			"碰撞矩形总面积 %d ≠ 实体格数 %d（分解不重不漏才算有效）" % [area, blocked.size()],
			{"rect_area": area, "blocked_cells": blocked.size(), "rects": rects.size()})


func _validate_visual_files(data: BuildingData, library: BuildingLibrary) -> void:
	var base := library.get_asset_dir(data.building_id)
	for layer in data.get_visual_layers():
		var l: Dictionary = layer
		var path := String(l.get("path", ""))
		if path.is_empty():
			_error("visual.layer_without_path", data.source_path, "视觉层 %s 没有 path" % String(l.get("name", "?")))
			continue
		if not FileAccess.file_exists(path):
			_error("visual.layer_missing_file", path, "视觉层文件不存在（先跑 --import）",
				{"layer": String(l.get("name", ""))})
	var base_png := base.path_join("visual/base.png")
	if FileAccess.file_exists(base_png):
		var image := _read_image(base_png)
		if image == null:
			_error("visual.unreadable", base_png, "visual/base.png 读不出来（不是合法 PNG 或未导入）")
		else:
			var declared := data.get_visual_size_px()
			if image.get_width() != declared.x or image.get_height() != declared.y:
				_error("visual.size_mismatch", base_png,
					"visual/base.png 实际 %d×%d，metadata 声明 %d×%d" % [
						image.get_width(), image.get_height(), declared.x, declared.y],
					{"actual": [image.get_width(), image.get_height()],
					 "declared": [declared.x, declared.y]})
	# 掩码尺寸必须等于 footprint
	for mask_name in BuildingMask.MASK_NAMES:
		var mask_path := base.path_join("masks/%s.png" % mask_name)
		if not FileAccess.file_exists(mask_path):
			continue
		var image := _read_image(mask_path)
		if image == null:
			_error("mask.unreadable", mask_path, "掩码 %s.png 读不出来" % mask_name)
			continue
		var footprint := data.get_footprint_size()
		if image.get_width() != footprint.x or image.get_height() != footprint.y:
			_error("mask.size_mismatch", mask_path,
				"掩码 %s.png 是 %d×%d，footprint 是 %s（1 像素 = 1 格）" % [
					mask_name, image.get_width(), image.get_height(), str(footprint)],
				{"mask": mask_name, "actual": [image.get_width(), image.get_height()],
				 "expected": [footprint.x, footprint.y]})


func _validate_declared_paths(data: BuildingData) -> void:
	if not data.prefab_path.is_empty() and not FileAccess.file_exists(data.prefab_path):
		_error("metadata.prefab_missing", data.prefab_path, "metadata 声明的 prefab_path 不存在")
	for key in ["occupancy", "walkable", "collision", "occlusion", "doors", "legend"]:
		var path := String(data.masks.get(key, ""))
		if path.is_empty():
			_warn("metadata.mask_path_missing", data.source_path, "metadata.masks 缺少 %s" % key,
				{"mask": key})
		elif not FileAccess.file_exists(path):
			_error("metadata.mask_path_not_found", path, "metadata.masks.%s 指向的文件不存在" % key,
				{"mask": key})


# ================================================================ 2. Prefab

## 校验 Prefab：能不能实例化、节点结构齐不齐、视觉与碰撞是否和 metadata 对得上。
func validate_prefab(building_id: String, instantiate: bool = true) -> Array:
	var library := BuildingLibrary.new()
	var data := library.load_building(building_id)
	if data == null:
		_error("prefab.no_metadata", library.get_metadata_path(building_id),
			"没有 metadata，无法定位 Prefab")
		return _issues
	var prefab_path := data.prefab_path
	if prefab_path.is_empty():
		prefab_path = library.get_asset_dir(building_id).path_join(BuildingData.prefab_file_name(building_id))
	if not FileAccess.file_exists(prefab_path):
		_error("prefab.missing", prefab_path, "Prefab 不存在（先跑 build_building.gd）",
			{"expected": prefab_path})
		return _issues
	if not instantiate:
		return _issues

	var packed := load(prefab_path) as PackedScene
	if packed == null:
		_error("prefab.load_failed", prefab_path, "Prefab 加载失败（脚本或依赖资源有错）")
		return _issues
	var instance := packed.instantiate()
	if instance == null:
		_error("prefab.instantiate_failed", prefab_path, "Prefab 实例化返回 null")
		return _issues
	var building := instance as Building
	if building == null:
		_error("prefab.wrong_root_script", prefab_path,
			"Prefab 根节点没挂 core/building/building.gd（拿到 %s）" %
			("null" if instance.get_script() == null else str(instance.get_script().resource_path)))
		instance.free()
		return _issues

	var node_data := building.load_data()
	if node_data == null:
		_error("prefab.data_load_failed", prefab_path,
			"Prefab 实例化后读不到 building.json（检查 building_id / data_path 导出属性）")
		instance.free()
		return _issues
	if node_data.building_id != data.building_id:
		_error("prefab.id_mismatch", prefab_path,
			"Prefab 的 building_id「%s」与资产包「%s」不一致" % [node_data.building_id, data.building_id],
			{"prefab_id": node_data.building_id, "package_id": data.building_id})

	# 必备子节点
	for required in [Building.CHILD_VISUAL, Building.CHILD_COLLISION, Building.CHILD_OCCUPANCY,
			Building.CHILD_WALKABLE, Building.CHILD_DOORS, Building.CHILD_INTERACTION,
			Building.CHILD_TACTICAL]:
		if instance.get_node_or_null(NodePath(required)) == null:
			_error("prefab.missing_child", prefab_path, "Prefab 缺少子节点「%s」" % required,
				{"child": required})
	var base_sprite := instance.get_node_or_null(NodePath("%s/%s" % [Building.CHILD_VISUAL, Building.CHILD_BASE])) as Sprite2D
	if base_sprite == null:
		_error("prefab.missing_base_sprite", prefab_path, "Prefab 缺少 Visual/Base（主视觉 Sprite2D）")
	elif base_sprite.texture == null:
		_error("prefab.base_without_texture", prefab_path, "Visual/Base 没有贴图（视觉层文件缺失或未导入）")

	# 碰撞形状数量与 metadata 对齐
	var collision_node := instance.get_node_or_null(NodePath(Building.CHILD_COLLISION))
	if collision_node != null:
		var shape_count := 0
		for child in collision_node.get_children():
			if child is CollisionShape2D:
				shape_count += 1
		var declared: int = data.get_collision_rects().size()
		if shape_count != declared:
			_error("prefab.collision_shape_mismatch", prefab_path,
				"Prefab 有 %d 个碰撞形状，metadata 声明 %d 个矩形" % [shape_count, declared],
				{"shapes": shape_count, "declared": declared})

	# 门节点数量
	var doors_node := instance.get_node_or_null(NodePath(Building.CHILD_DOORS))
	if doors_node != null:
		var door_nodes := doors_node.get_child_count()
		if door_nodes != data.get_doors().size():
			_error("prefab.door_node_mismatch", prefab_path,
				"Prefab 有 %d 个门节点，metadata 声明 %d 个门" % [door_nodes, data.get_doors().size()],
				{"nodes": door_nodes, "declared": data.get_doors().size()})

	instance.free()
	return _issues


# ================================================================ 3. 放置

## 校验「把某座建筑放在某张地图的某个格」是否合法。
## `map` 可以是 `MapScene` 实例，也可以是场景路径字符串（内部会实例化）。
## `ignore_node` = 校验一个**已经在地图上**的建筑时，传它自己的节点名，
## 否则"与已有建筑重叠"会把它自己算成冲突。
func validate_placement(building_id: String, map: Variant, top_left_cell: Vector2i,
		ignore_node: String = "") -> Array:
	var library := BuildingLibrary.new()
	var data := library.load_building(building_id)
	if data == null:
		_error("placement.no_building", library.get_metadata_path(building_id),
			"建筑 %s 不存在" % building_id)
		return _issues

	var map_node: Node = null
	var owned := false
	# map 这个参数既能收场景路径（工具链常用），也能收已经实例化的地图节点（运行时常用）；
	# 出错信息里统一显示成一个字符串标签。
	var map_label := ""
	if typeof(map) == TYPE_STRING:
		map_label = String(map)
		var packed := load(map_label) as PackedScene
		if packed == null:
			_error("placement.map_load_failed", map_label, "地图场景加载失败")
			return _issues
		map_node = packed.instantiate()
		owned = true
	elif map is Node:
		map_node = map
		map_label = "<节点 %s>" % map_node.name
	else:
		_error("placement.bad_map", "", "validate_placement 需要地图场景路径或节点")
		return _issues

	if not map_node.has_method("get_map_size_cells"):
		_error("placement.not_a_map", map_label, "目标场景不是地图（根节点没挂 core/world/map_scene.gd）")
		if owned:
			map_node.free()
		return _issues

	var map_size: Vector2i = map_node.call("get_map_size_cells")
	var footprint := data.get_footprint_rect()
	var placed_rect := Rect2i(top_left_cell, footprint.size)
	var map_rect := Rect2i(Vector2i.ZERO, map_size)
	if not map_rect.encloses(placed_rect):
		_error("placement.out_of_bounds", map_label,
			"建筑放在 %s 会超出地图 %s（建筑 %s）" % [
				str(placed_rect), str(map_size), str(footprint.size)],
			{"placed_rect": [placed_rect.position.x, placed_rect.position.y,
				placed_rect.size.x, placed_rect.size.y],
			 "map_size": [map_size.x, map_size.y]})

	# 与地图里已有建筑重叠？
	var candidates: Array = []
	if map_node.has_method("get_buildings"):
		candidates = map_node.call("get_buildings")
	for candidate in candidates:
		var other := candidate as Building
		if other == null:
			continue
		if not ignore_node.is_empty() and String(other.name) == ignore_node:
			continue   # 就是它自己，不算"重叠"
		var other_rect := other.get_map_footprint_rect()
		if other_rect.intersects(placed_rect):
			_error("placement.overlaps_existing", map_label,
				"与已有建筑「%s」的地基重叠：%s ∩ %s" % [other.name, str(placed_rect), str(other_rect)],
				{"other": String(other.name), "other_rect": [other_rect.position.x, other_rect.position.y,
					other_rect.size.x, other_rect.size.y]})

	# 门口至少要有一个格通向地图内部
	var reachable_doors := 0
	var outside_cells: Array = []
	for door in data.get_doors():
		var cell_array: Array = (door as Dictionary).get("cell", [0, 0])
		var local := Vector2i(int(cell_array[0]), int(cell_array[1]))
		var side := String((door as Dictionary).get("outward_side", "n"))
		var offset: Vector2i = {"n": Vector2i(0, -1), "s": Vector2i(0, 1), "e": Vector2i(1, 0), "w": Vector2i(-1, 0)}.get(side, Vector2i.ZERO)
		var outward: Vector2i = top_left_cell + local + offset
		outside_cells.append(outward)
		if map_rect.has_point(outward) or map_rect.has_point(top_left_cell + local):
			reachable_doors += 1
	if reachable_doors == 0:
		_error("placement.no_reachable_door", map_label,
			"所有门都落在地图外：这栋建筑放进来之后进不去",
			{"doors": data.get_doors().size()})

	# 地形层有没有铺到门口外面（没铺 = 玩家走不到门口）
	if map_node.has_method("is_cell_walkable"):
		for outward in outside_cells:
			if not map_rect.has_point(outward):
				continue
			if not bool(map_node.call("is_cell_walkable", outward)):
				_warn("placement.door_outside_not_walkable", map_label,
					"门口外侧的格 %s 目前不可通行（地形没铺 / 被 solid 图块压住）" % str(outward),
					{"cell": [outward.x, outward.y]})
				break

	if owned:
		map_node.free()
	return _issues


# ================================================================ 工具函数

func _read_image(path: String) -> Image:
	var global := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(global):
		global = path
	if not FileAccess.file_exists(global):
		return null
	var image := Image.new()
	if image.load(global) != OK:
		return null
	return image


func _sample_cells(cells: Dictionary) -> Array:
	var out: Array = []
	for cell in cells:
		out.append([cell.x, cell.y])
		if out.size() >= 8:
			break
	return out


## 连通块数量（四邻）。
func _component_count(cells: Dictionary) -> int:
	var remaining := cells.duplicate()
	var count := 0
	var offsets := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not remaining.is_empty():
		count += 1
		var keys: Array = remaining.keys()
		var stack: Array = [keys[0]]
		remaining.erase(keys[0])
		while not stack.is_empty():
			var cell: Vector2i = stack.pop_back()
			for offset in offsets:
				var neighbor: Vector2i = cell + offset
				if remaining.has(neighbor):
					remaining.erase(neighbor)
					stack.append(neighbor)
	return count
