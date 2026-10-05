extends SceneTree

## 大型建筑管线自检（正方形网格 · 48px/格 · 建筑 = 独立视觉对象 + 独立逻辑）。
##
## 覆盖五层：
##  1. **资产包**：目录/文件齐不齐、metadata 字段完不完整、视觉尺寸与声明是否一致
##  2. **掩码**：5 张掩码的尺寸与子集关系（walkable ⊆ occupancy、collision ⊆ occupancy、
##     walkable ∩ collision = ∅、doors ⊆ walkable、occlusion ⊆ occupancy），
##     以及"掩码 PNG 解出来的格集合 == metadata 里的游程编码"
##  3. **Prefab**：能加载、能实例化、节点结构齐、贴图有、碰撞形状数/门节点数与 metadata 一致
##  4. **运行时**：BuildingData 查询、地图通行判定（MapScene.is_cell_walkable 让建筑说话）
##  5. **高层 API**：list / inspect / validate / place / move / remove / validate-map 全流程
##     外加 **反向用例**：故意造一份坏 metadata，确认校验器给的是**结构化错误码**
##
## 运行：godot --headless --path C:\游戏 --script tests\map\test_building_pipeline.gd

const BuildingLibraryScript := preload("res://core/building/building_library.gd")
const BuildingDataScript := preload("res://core/building/building_data.gd")
const BuildingMaskScript := preload("res://core/building/building_mask.gd")
const BuildingValidatorScript := preload("res://core/building/building_validator.gd")
const BuildingPlacerScript := preload("res://core/building/building_placer.gd")
const BuildingScript := preload("res://core/building/building.gd")
const MapSceneScript := preload("res://core/world/map_scene.gd")

const BUILDING_ID := "iserra_monastery"
const PACKAGE_DIR := "res://assets/buildings/" + BUILDING_ID
const METADATA_PATH := PACKAGE_DIR + "/metadata/building.json"
const PREFAB_PATH := PACKAGE_DIR + "/IserraMonastery.tscn"
const SPEC_PATH := PACKAGE_DIR + "/building.spec.json"
const DEMO_MAP_PATH := "res://maps/godot/scenes/monastery_grounds.tscn"
const PROJECTION_ID := "orthogonal_3q_48_v1"
const HIGHLAND_METADATA_PATH := "res://assets/buildings/iserra_monastery_highland/metadata/building.json"
const HIGHLAND_MAP_PATH := "res://maps/godot/scenes/iserra_monastery_highlands.tscn"
const PROJECTION_LAB_PATH := "res://world/map/BuildingProjectionLab.tscn"
const HIGHLAND_MAIN_PATH := "res://world/map/MainHighlandMap.tscn"
const TMP_MAP_PATH := "res://.tests_tmp/building_place_test.tscn"

## 由 spec（美术线平面图 + 柱廊开口）算出来的关键格，用来验证"逻辑确实贴着画走"。
## 坐标为 footprint 局部格；footprint(0,0) 对应美术画布的 (3,5)。
const NAVE_CELL := Vector2i(27, 10)          # 中殿内部 → 可走
const ARCADE_CELL := Vector2i(27, 3)         # 中殿↔北侧廊的柱廊开口 → 可走（画上是柱列）
const AISLE_OUTER_WALL_CELL := Vector2i(27, 0)  # 北侧廊的外墙 → 实体
const CLOISTER_CELL := Vector2i(18, 32)      # 回廊院内 → 可走（且无屋顶 → 不遮挡）
const WEST_DOOR_CELL := Vector2i(0, 9)       # 教堂西门 → 门 + 可走
const OUTSIDE_CELL := Vector2i(0, 65)        # 建筑西南角外的空地 → 不属于建筑
const OUTSIDE_FOOTPRINT_CELL := Vector2i(57, 5)  # footprint 之外（宽 57 → x 最大 56）

var _passed := 0
var _failed := 0
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_test_package_files()
	_test_metadata_fields()
	_test_masks()
	_test_visual_logic_decoupling()
	_test_doors()
	_test_collision()
	var data := _test_prefab()
	_test_runtime_queries(data)
	_test_validator_negative_cases()
	_test_high_level_api()
	_test_placement_on_map()
	_test_demo_map()
	_test_projection_lab()
	_test_remove_and_move()
	print("RESULT: passed=%d failed=%d" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
	return true


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("PASS  ", label)
	else:
		_failed += 1
		print("FAIL  ", label)


func _check_eq(actual: Variant, expected: Variant, label: String) -> void:
	_check(actual == expected, "%s（实际 %s，期望 %s）" % [label, str(actual), str(expected)])


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _image_of(path: String) -> Image:
	var global := ProjectSettings.globalize_path(path)
	var image := Image.new()
	if image.load(global) != OK:
		return null
	return image


# ---------------------------------------------------------------- 1. 资产包

func _test_package_files() -> void:
	_check(FileAccess.file_exists(SPEC_PATH), "建筑 spec（building.spec.json）存在")
	_check(FileAccess.file_exists(METADATA_PATH), "机器可读 metadata 存在")
	_check(FileAccess.file_exists(PACKAGE_DIR + "/visual/base.png"), "主视觉 base.png 存在")
	_check(FileAccess.file_exists(PACKAGE_DIR + "/visual/roof.png"), "屋顶层 roof.png 存在")
	for mask_name in BuildingMaskScript.MASK_NAMES:
		_check(FileAccess.file_exists("%s/masks/%s.png" % [PACKAGE_DIR, mask_name]),
			"掩码 %s.png 存在" % mask_name)
	_check(FileAccess.file_exists(PACKAGE_DIR + "/masks/legend.json"), "掩码规范 legend.json 存在")
	_check(FileAccess.file_exists(PACKAGE_DIR + "/collision/collision_rects.json"), "碰撞矩形清单存在")
	_check(FileAccess.file_exists(PACKAGE_DIR + "/preview/preview.png"), "预览图存在")
	_check(FileAccess.file_exists(PACKAGE_DIR + "/preview/debug_overlay.png"), "掩码叠查图存在")
	_check(FileAccess.file_exists(PACKAGE_DIR + "/source/monastery_plan.json"), "美术线平面图留档存在")
	_check(FileAccess.file_exists(PREFAB_PATH), "Building Prefab 存在")

	var legend := _load_json(PACKAGE_DIR + "/masks/legend.json")
	_check(not legend.is_empty(), "legend.json 可解析")
	_check(legend.has("masks") and (legend["masks"] as Dictionary).size() == 5,
		"legend 里 5 张掩码都有含义说明")
	_check(legend.has("door_colors") and (legend["door_colors"] as Dictionary).size() == 4,
		"legend 里门的 4 个朝向颜色都有定义")


# ---------------------------------------------------------------- 2. metadata

func _test_metadata_fields() -> void:
	var metadata := _load_json(METADATA_PATH)
	_check(not metadata.is_empty(), "metadata 可解析")
	for field in ["schema", "projection_id", "building_id", "display_name", "asset_path", "visual_size", "anchor",
			"footprint", "occupied_cells", "walkable_cells", "doors", "collision", "tactical", "sorting"]:
		# visual_size 由 visual.size_px 承载（见下），其余字段必须直接存在
		if field == "visual_size":
			_check((metadata.get("visual", {}) as Dictionary).has("size_px"), "metadata 含 visual.size_px")
			continue
		_check(metadata.has(field), "metadata 含字段「%s」" % field)
	_check_eq(String(metadata.get("building_id", "")), BUILDING_ID, "building_id 一致")
	_check_eq(String(metadata.get("projection_id", "")), PROJECTION_ID, "建筑声明统一 3/4 投影契约")
	_check_eq(String(metadata.get("schema", "")), BuildingDataScript.SCHEMA, "schema 版本一致")
	_check_eq(String(metadata.get("prefab_path", "")), PREFAB_PATH, "prefab_path 指向真实 Prefab")

	var data := BuildingDataScript.load_from_json(METADATA_PATH)
	_check(data != null, "BuildingData 能从 metadata 建出来")
	if data == null:
		return
	_check_eq(data.get_tile_size(), Vector2i(48, 48), "tile_size = 48×48")
	_check(data.get_footprint_size().x > 0 and data.get_footprint_size().y > 0, "footprint 为正整数")
	_check_eq(data.get_anchor_local_px(),
		Vector2(data.get_footprint_size().x * 0.5, float(data.get_footprint_size().y)) * Vector2(data.get_tile_size()),
		"锚点是 footprint 底部中心（Y 轴排序用）")
	_check(data.get_occupied_count() > 0, "占用格数 > 0")
	_check(data.get_walkable_count() > 0, "可通行格数 > 0")
	_check(data.get_blocked_count() > 0, "实体格数 > 0")

	# 资源路径都要真的存在
	for key in ["occupancy", "walkable", "collision", "occlusion", "doors", "legend"]:
		var path := String(data.masks.get(key, ""))
		_check(not path.is_empty() and FileAccess.file_exists(path),
			"metadata.masks.%s 指向存在的文件" % key)


# ---------------------------------------------------------------- 3. 掩码

func _test_masks() -> void:
	var data := BuildingDataScript.load_from_json(METADATA_PATH)
	if data == null:
		return
	var footprint := data.get_footprint_size()

	for mask_name in BuildingMaskScript.MASK_NAMES:
		var image := _image_of("%s/masks/%s.png" % [PACKAGE_DIR, mask_name])
		_check(image != null, "掩码 %s.png 可读" % mask_name)
		if image == null:
			continue
		_check_eq(Vector2i(image.get_width(), image.get_height()), footprint,
			"掩码 %s.png 尺寸 = footprint（1 像素 = 1 格）" % mask_name)

	# 掩码解出来的格集合必须与 metadata 的游程编码完全一致
	var occupancy_image := _image_of(PACKAGE_DIR + "/masks/occupancy.png")
	var walkable_image := _image_of(PACKAGE_DIR + "/masks/walkable.png")
	var collision_image := _image_of(PACKAGE_DIR + "/masks/collision.png")
	var occlusion_image := _image_of(PACKAGE_DIR + "/masks/occlusion.png")
	var doors_image := _image_of(PACKAGE_DIR + "/masks/doors.png")
	if occupancy_image == null or walkable_image == null or collision_image == null \
			or occlusion_image == null or doors_image == null:
		return
	var occ := BuildingMaskScript.read_cells(occupancy_image)
	var walk := BuildingMaskScript.read_cells(walkable_image)
	var coll := BuildingMaskScript.read_cells(collision_image)
	var occl := BuildingMaskScript.read_cells(occlusion_image)
	var door := BuildingMaskScript.read_cells(doors_image)

	_check_eq(occ.size(), data.get_occupied_count(), "occupancy.png 格数 = metadata.occupied_cells.count")
	_check_eq(walk.size(), data.get_walkable_count(), "walkable.png 格数 = metadata.walkable_cells.count")
	_check_eq(coll.size(), data.get_blocked_count(), "collision.png 格数 = metadata.blocked_cells.count")
	# 注意：JSON 里数字读回来一律是 float，比较前要归一成 int（runs_of 会做这件事）
	_check_eq(BuildingMaskScript.runs_from_cells(occ),
		BuildingDataScript.normalize_runs(data.raw["occupied_cells"]["runs"]),
		"occupancy 的游程编码可复现（掩码 PNG 与 metadata 是同一份事实）")

	# 掩码之间的子集关系
	_check(BuildingMaskScript.subtract(walk, occ).is_empty(), "walkable ⊆ occupancy")
	_check(BuildingMaskScript.subtract(coll, occ).is_empty(), "collision ⊆ occupancy")
	_check(BuildingMaskScript.subtract(occl, occ).is_empty(), "occlusion ⊆ occupancy")
	_check(BuildingMaskScript.subtract(door, walk).is_empty(), "doors ⊆ walkable")
	_check(BuildingMaskScript.intersect(walk, coll).is_empty(), "walkable 与 collision 不相交")
	_check(BuildingMaskScript.union(walk, coll).size() <= occ.size(), "walkable ∪ collision ⊆ occupancy")

	# 连通性：可通行区必须连成一片（否则有房间是封死的）
	_check(_component_count(walk) == 1, "可通行区连通（没有封死的房间）")
	_check(_component_count(occ) == 1, "占用区连通")

	# 门掩码的颜色语义能被解析回朝向
	var sides := {}
	for cell in door:
		var side := BuildingMaskScript.side_from_color(doors_image.get_pixel(cell.x, cell.y))
		sides[side] = int(sides.get(side, 0)) + 1
	_check(not sides.has(""), "doors.png 的每个像素颜色都是合法朝向色")
	_check(sides.size() >= 2, "门至少覆盖 2 个不同朝向（本例有西门与内门）")


# ---------------------------------------------------------------- 4. 视觉 ≠ 逻辑

func _test_visual_logic_decoupling() -> void:
	var data := BuildingDataScript.load_from_json(METADATA_PATH)
	if data == null:
		return
	var base_image := _image_of(PACKAGE_DIR + "/visual/base.png")
	_check(base_image != null, "主视觉可读")
	if base_image == null:
		return
	var declared := data.get_visual_size_px()
	_check_eq(Vector2i(base_image.get_width(), base_image.get_height()), declared,
		"visual/base.png 实际尺寸 = metadata.visual.size_px")

	# 这是本管线的核心主张：视觉尺寸与逻辑尺寸**故意不绑定**
	_check(Vector2i(base_image.get_width(), base_image.get_height())
			!= data.get_footprint_size() * data.get_tile_size(),
		"视觉尺寸 ≠ 逻辑 footprint 像素尺寸（视觉 %d×%d px / 逻辑 %s 格）" % [
			base_image.get_width(), base_image.get_height(), str(data.get_footprint_size())])
	var visual_tiles := data.get_visual_size_tiles()
	var padding := data.get_padding_tiles()
	_check_eq(visual_tiles, data.get_footprint_size() + Vector2i(padding, padding) * 2,
		"视觉 = footprint + 出血（padding=%d 格）" % padding)

	# 区外必须透明：视觉只负责"占用区 + 出血"那一块，其余要透出地图自己的地形。
	# 取一个"离占用区比出血更远"的地基内格，它的视觉像素必须是透明的。
	var occupied := BuildingMaskScript.cells_from_runs(data.raw["occupied_cells"]["runs"])
	var alpha_region := BuildingMaskScript.grow(occupied, padding)
	var probe_cell := Vector2i(-1, -1)
	for y in data.get_footprint_size().y:
		for x in data.get_footprint_size().x:
			var cell := Vector2i(x, y)
			if not alpha_region.has(cell):
				probe_cell = cell
				break
		if probe_cell.x >= 0:
			break
	_check(probe_cell.x >= 0, "地基内存在「离占用区超过出血」的格（可用来验透明）")
	if probe_cell.x >= 0:
		# 局部格 → 视觉图像素：视觉图左上角对应局部格 (-padding,-padding)
		var probe_px := (probe_cell + Vector2i(padding, padding)) * data.get_tile_size() + Vector2i(24, 24)
		if probe_px.x >= 0 and probe_px.y >= 0 and probe_px.x < base_image.get_width() \
				and probe_px.y < base_image.get_height():
			_check(base_image.get_pixelv(probe_px).a < 0.01,
				"占用区之外的格（局部 %s）在视觉图上是透明的，地图地形能透出来" % str(probe_cell))
		else:
			_check(false, "透明探针像素落到了图外：%s" % str(probe_px))

	# 建筑本体（占用区中心那一格）必须是不透明的
	var center_cell := Vector2i(data.get_footprint_size().x / 2, data.get_footprint_size().y / 2)
	var center_px := (center_cell + Vector2i(padding, padding)) * data.get_tile_size() + Vector2i(24, 24)
	if center_px.x >= 0 and center_px.y >= 0 and center_px.x < base_image.get_width() \
			and center_px.y < base_image.get_height():
		_check(base_image.get_pixelv(center_px).a > 0.5, "建筑本体格在视觉图上是不透明的")


# ---------------------------------------------------------------- 5. 门

func _test_doors() -> void:
	var data := BuildingDataScript.load_from_json(METADATA_PATH)
	if data == null:
		return
	var doors := data.get_doors()
	_check(doors.size() >= 8, "门至少 8 道（实际 %d）" % doors.size())
	var footprint := data.get_footprint_rect()
	var exterior := 0
	for door in doors:
		var d: Dictionary = door
		var id := String(d.get("id", ""))
		var cell_array: Array = d.get("cell", [0, 0])
		var cell := Vector2i(int(cell_array[0]), int(cell_array[1]))
		_check(not id.is_empty(), "门有 id：%s" % id)
		_check(footprint.has_point(cell), "门 %s 在地基内" % id)
		_check(data.is_cell_occupied(cell), "门 %s 落在占用区内" % id)
		_check(data.is_cell_walkable(cell), "门 %s 可通行（没被墙堵死）" % id)
		_check(data.is_cell_door(cell), "门 %s 在 doors 掩码里" % id)
		var side := String(d.get("outward_side", ""))
		_check(BuildingMaskScript.DOOR_SIDE_COLORS.has(side), "门 %s 朝向合法：%s" % [id, side])
		var offset: Vector2i = {"n": Vector2i(0, -1), "s": Vector2i(0, 1), "e": Vector2i(1, 0), "w": Vector2i(-1, 0)}.get(side, Vector2i.ZERO)
		var outward: Vector2i = cell + offset
		if not footprint.has_point(outward):
			exterior += 1
		_check(not data.is_cell_blocked(outward), "门 %s 朝外的格不是实体" % id)
		var target := String(d.get("target", ""))
		_check(target == "outside" or not data.get_room(target).is_empty(),
			"门 %s 的 target「%s」能对上房间" % [id, target])
	_check(exterior >= 1, "至少有一道门通向建筑之外（真正的入口）")
	# 门必须真的把墙打穿（内外两侧都得连得上）
	for door in doors:
		var d: Dictionary = door
		var cell_array: Array = d.get("cell", [0, 0])
		var cell := Vector2i(int(cell_array[0]), int(cell_array[1]))
		var width := int(d.get("width_tiles", 1))
		var thickness := int(d.get("thickness_tiles", 1))
		_check(width >= 1 and thickness >= 1, "门 %s 有宽度与穿墙厚度" % String(d.get("id", "")))
		_check(data.is_cell_walkable(cell), "门 %s 打通了" % String(d.get("id", "")))


# ---------------------------------------------------------------- 6. 碰撞

func _test_collision() -> void:
	var manifest := _load_json(PACKAGE_DIR + "/collision/collision_rects.json")
	_check(not manifest.is_empty(), "碰撞矩形清单可解析")
	var data := BuildingDataScript.load_from_json(METADATA_PATH)
	if data == null:
		return
	var rects := data.get_collision_rects()
	_check(rects.size() > 0, "碰撞矩形不为空（%d 个）" % rects.size())
	_check_eq(int(manifest.get("rect_count", -1)), rects.size(), "清单与 metadata 的矩形数一致")
	var area := 0
	var footprint := data.get_footprint_rect()
	var valid := true
	for entry in rects:
		var r: Array = entry
		var rect := Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))
		if rect.size.x <= 0 or rect.size.y <= 0 or not footprint.encloses(rect):
			valid = false
			break
		area += rect.size.x * rect.size.y
	_check(valid, "每个碰撞矩形都为正且落在地基内")
	_check_eq(area, data.get_blocked_count(), "碰撞矩形总面积 = 实体格数（不重不漏）")
	# 贪心分解必须可复现（同一集合两次分解结果一致）
	var cells := BuildingMaskScript.cells_from_runs(data.raw["blocked_cells"]["runs"])
	_check_eq(BuildingMaskScript.greedy_rects(cells).size(), rects.size(), "矩形分解可复现")


# ---------------------------------------------------------------- 7. Prefab

func _test_prefab() -> BuildingDataScript:
	var packed := load(PREFAB_PATH) as PackedScene
	_check(packed != null, "Prefab 能加载")
	if packed == null:
		return null
	var instance := packed.instantiate()
	_check(instance != null, "Prefab 能实例化")
	if instance == null:
		return null
	var building := instance as BuildingScript
	_check(building != null, "Prefab 根节点挂了 core/building/building.gd")
	if building == null:
		instance.free()
		return null
	var data := building.load_data()
	_check(data != null, "Prefab 实例化后读得到 metadata")
	if data == null:
		instance.free()
		return null
	_check_eq(data.building_id, BUILDING_ID, "Prefab 的 building_id 与资产包一致")

	for required in [BuildingScript.CHILD_VISUAL, BuildingScript.CHILD_COLLISION,
			BuildingScript.CHILD_OCCUPANCY, BuildingScript.CHILD_WALKABLE, BuildingScript.CHILD_DOORS,
			BuildingScript.CHILD_INTERACTION, BuildingScript.CHILD_TACTICAL]:
		_check(instance.get_node_or_null(NodePath(required)) != null, "Prefab 有子节点「%s」" % required)

	var base_sprite := instance.get_node_or_null(
		NodePath("%s/%s" % [BuildingScript.CHILD_VISUAL, BuildingScript.CHILD_BASE])) as Sprite2D
	_check(base_sprite != null, "Visual/Base 是 Sprite2D")
	if base_sprite != null:
		_check(base_sprite.texture != null, "Visual/Base 有贴图")
		_check(not base_sprite.centered, "Visual/Base 不居中（左上角对齐地基）")
	var roof_sprite := instance.get_node_or_null(
		NodePath("%s/%s" % [BuildingScript.CHILD_VISUAL, BuildingScript.CHILD_ROOF])) as Sprite2D
	_check(roof_sprite != null and roof_sprite.texture != null, "Visual/Roof 有贴图（屋顶层）")
	if roof_sprite != null:
		_check(roof_sprite.z_index > base_sprite.z_index, "屋顶层的 z_index 高于底层")

	var collision := instance.get_node_or_null(NodePath(BuildingScript.CHILD_COLLISION))
	var shapes := 0
	if collision != null:
		for child in collision.get_children():
			if child is CollisionShape2D:
				shapes += 1
	_check_eq(shapes, data.get_collision_rects().size(), "碰撞形状数 = metadata 的碰撞矩形数")

	var doors_node := instance.get_node_or_null(NodePath(BuildingScript.CHILD_DOORS))
	var door_nodes := 0
	if doors_node != null:
		door_nodes = doors_node.get_child_count()
	_check_eq(door_nodes, data.get_doors().size(), "门节点数 = metadata 的 doors 数")
	var interaction := instance.get_node_or_null(NodePath(BuildingScript.CHILD_INTERACTION))
	_check(interaction != null and interaction.get_child_count() == data.get_doors().size(),
		"Interaction 下每个门都有一个 Area2D")

	var tactical := instance.get_node_or_null(NodePath(BuildingScript.CHILD_TACTICAL))
	_check(tactical != null and tactical.has_meta("cover") and tactical.has_meta("blocks_los"),
		"TacticalData 带掩体与遮挡视线数据")

	# 视觉偏移：贴图左上角应当落在「地基左上角 + 出血偏移」处
	var expected_offset := data.get_visual_offset_px()
	if base_sprite != null:
		var visual := instance.get_node_or_null(NodePath(BuildingScript.CHILD_VISUAL)) as Node2D
		_check_eq(visual.position + base_sprite.position, expected_offset,
			"视觉层偏移 = metadata.visual.anchor_offset_px")

	instance.free()
	return data


# ---------------------------------------------------------------- 8. 运行时查询

func _test_runtime_queries(data: BuildingDataScript) -> void:
	if data == null:
		return
	_check(data.is_cell_walkable(NAVE_CELL), "中殿内部可通行")
	_check(data.is_cell_walkable(ARCADE_CELL), "中殿↔北侧廊的柱廊开口可通行（openings 生效）")
	_check(data.is_cell_blocked(AISLE_OUTER_WALL_CELL), "北侧廊外墙是实体")
	_check(data.is_cell_occupied(AISLE_OUTER_WALL_CELL), "北侧廊外墙仍在占用区内")
	_check(data.is_cell_walkable(CLOISTER_CELL), "回廊院内可通行")
	_check(data.is_cell_walkable(WEST_DOOR_CELL), "教堂西门可通行")
	_check(data.is_cell_door(WEST_DOOR_CELL), "教堂西门被登记为门")
	_check(not data.is_cell_occupied(OUTSIDE_CELL), "建筑本体之外的格不属于建筑")
	_check(not data.get_footprint_rect().has_point(OUTSIDE_FOOTPRINT_CELL), "能判断出格子落在地基之外")
	# 遮挡语义：屋顶压住的可通行格 = 会挡住角色、需要收屋顶的格
	_check(data.is_cell_occluded(NAVE_CELL), "中殿有屋顶 → 属于遮挡区（进屋要收屋顶）")
	_check(not data.is_cell_occluded(CLOISTER_CELL), "回廊院露天 → 不属于遮挡区")
	_check(data.get_tactical().has("cover_level"), "tactical 带 cover_level")
	_check(data.get_sorting().has("mode"), "sorting 带 mode")
	var room := data.get_room("cloister")
	_check(not room.is_empty(), "能按 id 取到房间 cloister")
	_check(not data.get_door_at(WEST_DOOR_CELL).is_empty(), "能按格取到门")

	# summarize 是给 Agent 看的摘要
	var summary := data.summarize()
	for field in ["building_id", "footprint_cells", "visual_size_px", "occupied", "walkable",
			"blocked", "doors", "prefab_path"]:
		_check(summary.has(field), "summarize 含字段「%s」" % field)


# ---------------------------------------------------------------- 9. 反向用例

## 故意造坏数据，确认校验器返回的是**结构化错误码**而不是一段话。
func _test_validator_negative_cases() -> void:
	# a) 可通行区伸到占用区之外 + 门的位置/朝向/重名/目标都坏 + 碰撞矩形有个空的
	var bad := {
		"schema": BuildingDataScript.SCHEMA,
		"building_id": "unit_bad",
		"display_name": "坏建筑",
		"tile_size": [48, 48],
		"footprint": {"size_cells": [4, 4]},
		"visual": {"size_px": [192, 192], "size_tiles": [4, 4], "anchor_offset_px": [0, 0]},
		"anchor": {"mode": "bottom_center"},
		"occupied_cells": {"count": 8, "runs": [[0, 0, 4], [1, 0, 4]]},
		"walkable_cells": {"count": 2, "runs": [[0, 5, 2]]},     # 跑到地基之外去了
		"blocked_cells": {"count": 4, "runs": [[1, 0, 4]]},
		"occlusion_cells": {"count": 0, "runs": []},
		"doors": [
			{"id": "d1", "cell": [1, 1], "outward_side": "x", "target": "nope"},
			{"id": "d1", "cell": [2, 2], "outward_side": "n", "target": "nope"},
			{"id": "d3", "cell": [9, 9], "outward_side": "n", "target": "outside"},
		],
		"collision": {"rects": [[0, 0, 4, 4], [0, 0, 0, 3]]},
		"tactical": {},
		"sorting": {},
		"masks": {},
	}
	var bad_data := BuildingDataScript.from_dictionary(bad)
	var validator = BuildingValidatorScript.new()
	validator._validate_metadata_fields(bad_data, BuildingLibraryScript.new())
	validator._validate_geometry(bad_data)
	validator._validate_doors(bad_data)
	validator._validate_collision(bad_data)
	var codes := {}
	for issue in validator.get_issues():
		codes[String((issue as Dictionary)["code"])] = true
	for expected in ["metadata.no_visual_layer", "geometry.walkable_outside_occupancy",
			"doors.cell_out_of_footprint", "doors.duplicate_id", "doors.bad_side",
			"collision.empty_rect", "collision.area_mismatch"]:
		_check(codes.has(expected), "坏数据能报出错误码「%s」" % expected)
	var report := validator.report("unit_bad")
	_check(report.has("ok") and report.has("errors") and report.has("issues"),
		"校验结果结构含 ok/errors/issues")
	_check(not report["ok"], "坏数据的 ok = false")
	var structured := true
	for issue in report["issues"]:
		var item: Dictionary = issue
		if not (item.has("code") and item.has("severity") and item.has("path")
				and item.has("message") and item.has("detail")):
			structured = false
	_check(structured, "每条问题都含 code/severity/path/message/detail（Agent 可直接分支）")

	# b) 真实建筑的校验必须是干净的
	validator.clear()
	validator.validate_package(BUILDING_ID)
	var codes_real := []
	for issue in validator.get_issues():
		codes_real.append("%s:%s" % [String((issue as Dictionary)["severity"]),
			String((issue as Dictionary)["code"])])
	_check(validator.error_count() == 0, "真实建筑资产包 0 错误（问题：%s）" % str(codes_real))
	validator.clear()
	validator.validate_prefab(BUILDING_ID, true)
	_check(validator.error_count() == 0, "真实建筑 Prefab 0 错误")


# ---------------------------------------------------------------- 10. 高层 API

func _test_high_level_api() -> void:
	var placer = BuildingPlacerScript.new()
	var listed: Array = placer.list_buildings()
	_check(listed.size() >= 1, "list_buildings() 至少列出一座建筑")
	var ids := []
	for entry in listed:
		ids.append(String((entry as Dictionary).get("building_id", "")))
	_check(ids.has(BUILDING_ID), "list_buildings() 能找到 %s" % BUILDING_ID)

	var inspected: Dictionary = placer.inspect_building(BUILDING_ID)
	_check(bool(inspected.get("ok", false)), "inspect_building() 成功")
	_check((inspected.get("doors", []) as Array).size() >= 8, "inspect 返回门清单")
	_check((inspected.get("rooms", []) as Array).size() >= 11, "inspect 返回房间清单")
	_check((inspected.get("files", {}) as Dictionary).has("visual"), "inspect 返回文件清单")

	var validated: Dictionary = placer.validate_building(BUILDING_ID)
	_check(bool(validated.get("ok", false)), "validate_building() 通过")
	_check_eq(int(validated.get("errors", -1)), 0, "validate_building() 错误数为 0")

	var missing: Dictionary = placer.inspect_building("no_such_building")
	_check(not bool(missing.get("ok", true)), "inspect 不存在的建筑 → ok=false")
	_check_eq(String(((missing.get("errors") as Array)[0] as Dictionary)["code"]),
		"building.not_found", "缺建筑时报 building.not_found 错误码")


# ---------------------------------------------------------------- 11. 放置到地图

func _test_placement_on_map() -> void:
	# 先造一张临时地图（复制 demo 地形，但尺寸更小，专门验越界与自动扩张）
	var demo := load(DEMO_MAP_PATH) as PackedScene
	if demo == null:
		_check(false, "示例地图存在（先跑 building_tool.gd -- demo）")
		return
	_check(true, "示例地图存在")
	var map := demo.instantiate() as MapSceneScript
	_check(map != null, "示例地图根节点挂了 map_scene.gd")
	if map == null:
		return
	root.add_child(map)   # 入树才会跑 _ready()（隐藏碰撞层、建筑解析放置格）

	var data := BuildingDataScript.load_from_json(METADATA_PATH)
	var buildings: Array = map.get_buildings()
	_check_eq(buildings.size(), 1, "示例地图里有 1 座建筑")
	if buildings.is_empty():
		map.free()
		return
	var building: BuildingScript = buildings[0] as BuildingScript
	_check_eq(building.get_building_id(), BUILDING_ID, "地图里的建筑就是 %s" % BUILDING_ID)
	_check_eq(building.get_map_footprint_rect().size, data.get_footprint_size(),
		"建筑在地图上的地基尺寸 = metadata footprint")

	# 地图侧通行判定：占用区内由建筑说话
	var top_left := building.get_top_left_cell()
	_check(map.is_cell_walkable(top_left + NAVE_CELL), "地图认定中殿内部可通行")
	_check(map.is_cell_walkable(top_left + ARCADE_CELL), "地图认定柱廊开口可通行")
	_check(not map.is_cell_walkable(top_left + AISLE_OUTER_WALL_CELL), "地图认定外墙格不可通行")
	_check(map.is_cell_walkable(top_left + WEST_DOOR_CELL), "地图认定教堂西门格可通行")
	_check(map.get_building_at(top_left + NAVE_CELL) == building, "get_building_at 能定位到建筑")
	_check(not map.get_door_at(top_left + WEST_DOOR_CELL).is_empty(), "get_door_at 能取到门")
	# 建筑只在**自己占用的格**上表态；占用区之外仍然走原来的图块规则
	_check(map.get_building_at(top_left + OUTSIDE_CELL) == null,
		"建筑之外的格不属于任何建筑（不表态，交回图块规则）")
	_check(map.get_building_at(top_left + AISLE_OUTER_WALL_CELL) == building,
		"建筑占用的格（含实体墙）归属该建筑")
	_check(map.is_cell_walkable(top_left + OUTSIDE_CELL),
		"建筑之外的地形（示例地图铺了草地）照旧可通行")

	# 地图尺寸把建筑算进来了
	var map_size: Vector2i = map.get_map_size_cells()
	_check(map_size.x >= top_left.x + data.get_footprint_size().x
			and map_size.y >= top_left.y + data.get_footprint_size().y,
		"get_map_size_cells() 覆盖到整座建筑")

	# 建筑自检 + 地图结构自检
	_check_eq(map.validate_buildings().size(), 0, "地图建筑自检 0 问题")
	_check(map.validate().is_empty(), "示例地图结构自检通过")
	_check(map.validate_spawn_walkable().is_empty(), "示例地图出生点可通行")

	# 预览图里必须**真的有建筑**，而且要落在 metadata 声明的格上。
	# 这条专门防「预览把建筑画到地图左上角 / 画成一条缝」这类低级错误。
	_test_preview_contains_building(data, top_left)

	map.free()

	# 越界放置必须失败，并且报结构化错误
	var placer = BuildingPlacerScript.new()
	var manifest := load(DEMO_MAP_PATH) as PackedScene
	var probe_map := manifest.instantiate()
	var source_size: Vector2i = probe_map.call("get_map_size_cells")
	probe_map.free()
	var out_of_bounds: Array = placer.validator.validate_placement(
		BUILDING_ID, DEMO_MAP_PATH, Vector2i(source_size.x - 3, 3))
	var found := false
	for issue in out_of_bounds:
		if String((issue as Dictionary)["code"]) == "placement.out_of_bounds":
			found = true
	_check(found, "放在地图外时报 placement.out_of_bounds")


## 预览图核对：建筑必须出现在 metadata 声明的位置上，且像素与"把视觉各层按 z 叠起来"一致。
## 这条专门防「预览把建筑画到地图左上角 / 只画了一条缝」这类低级错误（曾经真的出现过）。
func _test_preview_contains_building(data: BuildingDataScript, top_left: Vector2i) -> void:
	var preview_image := _image_of(DEMO_MAP_PATH.get_basename() + "_preview.png")
	if preview_image == null:
		_check(false, "示例地图预览图可读")
		return
	_check(true, "示例地图预览图可读")
	preview_image.convert(Image.FORMAT_RGBA8)

	# 各视觉层按 z_index 升序读进来
	var layers: Array = []
	for layer in data.get_visual_layers():
		var l: Dictionary = layer
		var image := _image_of(String(l.get("path", "")))
		if image == null:
			_check(false, "视觉层可读：%s" % String(l.get("path", "")))
			return
		image.convert(Image.FORMAT_RGBA8)
		layers.append({"z": int(l.get("z_index", 0)), "image": image})
	layers.sort_custom(func(a, b): return int(a["z"]) < int(b["z"]))

	var padding := data.get_padding_tiles()
	var tile := data.get_tile_size()
	# 在 footprint 里按步长撒点采样，避免几十万次逐像素比较
	var step := maxi(1, data.get_footprint_size().x / 8)
	var checked := 0
	var matched := 0
	for cy in range(0, data.get_footprint_size().y, maxi(1, data.get_footprint_size().y / 8)):
		for cx in range(0, data.get_footprint_size().x, step):
			var local := Vector2i(cx, cy)
			# 视觉图内的像素下标 = 局部格 + 出血，取格中心
			var vis_px := (local + Vector2i(padding, padding)) * tile + tile / 2
			# 最上面的不透明层就是应当显示的内容
			var expected := Color(0, 0, 0, 0)
			var found := false
			for entry in layers:
				var image: Image = entry["image"]
				if vis_px.x < 0 or vis_px.y < 0 or vis_px.x >= image.get_width() or vis_px.y >= image.get_height():
					continue
				var color := image.get_pixelv(vis_px)
				if color.a > 0.5:
					expected = color
					found = true
			if not found:
				continue   # 这一格视觉上是透明的（占用区之外），预览里应当是地形
			var preview_px := (top_left + local) * tile + tile / 2
			if preview_px.x < 0 or preview_px.y < 0 \
					or preview_px.x >= preview_image.get_width() or preview_px.y >= preview_image.get_height():
				continue
			checked += 1
			var actual := preview_image.get_pixelv(preview_px)
			if absf(actual.r - expected.r) <= 0.01 and absf(actual.g - expected.g) <= 0.01 \
					and absf(actual.b - expected.b) <= 0.01:
				matched += 1
	_check(checked >= 40, "预览采样点足够多（实际 %d 个）" % checked)
	_check(matched == checked,
		"预览图里的建筑像素与 metadata 声明的位置逐点一致（%d/%d）" % [matched, checked])

	# 反向：建筑视觉透明的地方，预览里应当显示地图地形（= 建筑没糊住整张图）
	var outside_local := Vector2i(-1, -1)
	for cy in range(0, data.get_footprint_size().y, step):
		for cx in range(0, data.get_footprint_size().x, step):
			var cand := Vector2i(cx, cy)
			var px := (cand + Vector2i(padding, padding)) * tile + tile / 2
			var opaque := false
			for entry in layers:
				var image: Image = entry["image"]
				if px.x >= 0 and px.y >= 0 and px.x < image.get_width() and px.y < image.get_height() \
						and image.get_pixelv(px).a > 0.5:
					opaque = true
					break
			if not opaque:
				outside_local = cand
				break
		if outside_local.x >= 0:
			break
	if outside_local.x >= 0:
		var preview_px := (top_left + outside_local) * tile + tile / 2
		var terrain := preview_image.get_pixelv(preview_px)
		# 地形是草地/泥土/石砖（绿/棕系），不是建筑里的石灰岩亮面也不是纯黑
		_check(terrain.a > 0.5, "建筑视觉透明处显示的是地图地形（不透明，不是空洞）")
	else:
		_check(false, "找不到视觉透明的采样点（出血太小？）")


# ---------------------------------------------------------------- 12. 示例地图
func _test_demo_map() -> void:
	_check(FileAccess.file_exists(DEMO_MAP_PATH), "示例地图场景存在")
	_check(FileAccess.file_exists(DEMO_MAP_PATH.get_basename() + "_preview.png"),
		"示例地图预览图存在")
	var metadata := _load_json(METADATA_PATH)
	var map_meta: Array = []
	var packed := load(DEMO_MAP_PATH) as PackedScene
	if packed != null:
		var map := packed.instantiate()
		map_meta = map.get_meta("buildings", [])
		map.free()
	_check(map_meta.size() == 1, "地图 meta 里登记了建筑（剧情/任务可引用）")
	if map_meta.size() == 1:
		var entry: Dictionary = map_meta[0]
		var declared: Array = metadata["footprint"]["size_cells"]
		_check_eq(String(entry.get("building_id", "")), BUILDING_ID, "地图 meta 的 building_id 正确")
		_check_eq(entry.get("footprint", []), [int(declared[0]), int(declared[1])],
			"地图 meta 的 footprint 与 metadata 一致")


# ---------------------------------------------------------------- 13. 3/4 投影嵌图实验
func _test_projection_lab() -> void:
	_check(FileAccess.file_exists(PROJECTION_LAB_PATH), "大型建筑 3/4 投影实验场存在")
	var highland_metadata := _load_json(HIGHLAND_METADATA_PATH)
	_check_eq(String(highland_metadata.get("projection_id", "")), PROJECTION_ID,
		"高原修道院 metadata 声明统一投影契约")
	var highland_sorting: Dictionary = highland_metadata.get("sorting", {})
	var declared_bands: Array = highland_sorting.get("bands", [])
	_check_eq(declared_bands.size(), 5, "高原修道院声明 5 个语义遮挡带")
	var declared_ids: Array[String] = []
	for band_value in declared_bands:
		declared_ids.append(String((band_value as Dictionary).get("id", "")))
	_check_eq(declared_ids, ["north_range", "church", "cloister_north",
		"courtyard_and_wings", "south_gatehouse"], "语义遮挡带按建筑空间命名")

	var map_packed := load(HIGHLAND_MAP_PATH) as PackedScene
	_check(map_packed != null, "高原修道院地图可加载")
	if map_packed != null:
		var highland_map := map_packed.instantiate()
		_check_eq(String(highland_map.get_meta("projection_id", "")), PROJECTION_ID,
			"高原地图与建筑使用同一 projection_id")
		_check_eq(highland_map.scale, Vector2.ONE, "投影修正不缩放正交地图")
		_check(is_zero_approx(highland_map.rotation), "投影修正不旋转正交地图")
		highland_map.free()

	var main_packed := load(HIGHLAND_MAIN_PATH) as PackedScene
	_check(main_packed != null, "高原修道院生产验收场景可加载")
	if main_packed != null:
		var main := main_packed.instantiate()
		root.add_child(main)
		var runtime_map := main.get_node_or_null("MonasteryMap")
		var runtime_sort := runtime_map.call("get_building_root") as Node2D
		var runtime_player := main.find_child("PartyEntity", true, false) as Node2D
		_check(runtime_sort != null and runtime_sort.y_sort_enabled, "生产地图启用建筑 YSort 域")
		_check(runtime_player != null and runtime_player.get_parent() == runtime_sort,
			"生产玩家根节点与建筑进入同一 YSort 域")
		var npc_parents_ok := true
		for node in main.find_children("Npc_*", "Node2D", true, false):
			if node.get_parent() != runtime_sort:
				npc_parents_ok = false
		_check(npc_parents_ok, "生产 NPC 根节点与建筑进入同一 YSort 域")
		if runtime_player != null:
			var block := runtime_player.get_node_or_null("Visual/PlaceholderBlock") as ColorRect
			_check(block == null or is_equal_approx(block.position.y + block.size.y, 0.0),
				"生产角色视觉以根节点脚点为底边")
		main.free()

	var lab_packed := load(PROJECTION_LAB_PATH) as PackedScene
	_check(lab_packed != null, "投影实验场可加载")
	if lab_packed == null:
		return
	var lab := lab_packed.instantiate()
	root.add_child(lab)
	var sort_world := lab.call("get_projection_sort_world") as Node2D
	var probe := lab.call("get_projection_probe") as Node2D
	var bands: Array = lab.call("get_projection_bands")
	_check(sort_world != null and sort_world.y_sort_enabled, "实验场启用统一 YSort 容器")
	_check(probe != null and probe.get_parent() == sort_world, "角色探针与建筑切带处于同一排序域")
	_check(probe != null and probe.is_in_group("player"), "角色探针接入 player 组以驱动屋顶遮挡")
	_check_eq(bands.size(), 5, "完整 Base 在运行时生成 5 个正式语义绘制带")

	var previous_bottom := 0.0
	var bands_contiguous := true
	var all_band_children_valid := true
	var runtime_ids: Array[String] = []
	for index in bands.size():
		var band := bands[index] as Node2D
		if band == null or band.get_parent() != sort_world or band.z_index != 0:
			all_band_children_valid = false
			continue
		var rect: Rect2 = band.get_meta("source_rect_px", Rect2())
		runtime_ids.append(String(band.get_meta("semantic_band_id", "")))
		if index > 0 and not is_equal_approx(rect.position.y, previous_bottom):
			bands_contiguous = false
		previous_bottom = rect.end.y
		var region := band.get_node_or_null("Region") as Sprite2D
		if region == null or not region.region_enabled or region.region_rect != rect \
				or not is_equal_approx(region.position.y, -rect.size.y):
			all_band_children_valid = false
	_check(bands_contiguous, "绘制带连续覆盖源纹理，不留缝也不重叠")
	_check(all_band_children_valid, "每个切带用底边锚节点 + 向上偏移 Region，并保持 z_index=0")
	_check_eq(runtime_ids, declared_ids, "运行时切带逐一复用 metadata 语义 id")

	var original_base_hidden := false
	if sort_world != null:
		for child in sort_world.get_children():
			if child.has_method("get_building_data"):
				var base := child.get_node_or_null("Visual/Base") as Sprite2D
				original_base_hidden = base != null and not base.visible \
					and bool(base.get_meta("hidden_by_sort_bands", false))
				break
	_check(original_base_hidden, "生产语义带生成后隐藏原 Base 绘制，不改完整源资产")
	lab.free()

	# 可进入版本有独立 Roof：探针进 occlusion 格时收顶，离开后恢复。
	var viewer_packed := load("res://world/map/BuildingViewer.tscn") as PackedScene
	var roof_viewer := viewer_packed.instantiate()
	roof_viewer.set("projection_lab", true)
	root.add_child(roof_viewer)
	var roof_sort := roof_viewer.call("get_projection_sort_world") as Node2D
	var roof_probe := roof_viewer.call("get_projection_probe") as Node2D
	var roof_building: Node = null
	for child in roof_sort.get_children():
		if child.has_method("get_building_data"):
			roof_building = child
			break
	var roof_cycle_ok := false
	if roof_building != null and roof_probe != null:
		var roof_data: Variant = roof_building.call("get_building_data")
		var occluded_dict: Dictionary = roof_data.call("get_occlusion_cells")
		var occluded_cells: Array = occluded_dict.keys()
		if not occluded_cells.is_empty():
			roof_building.call("set_roof_visible", true)
			roof_probe.global_position = roof_building.call("local_cell_to_world_position", occluded_cells[0])
			roof_building.call("_process", 0.0)
			var hidden_inside := not bool(roof_building.call("is_roof_visible"))
			roof_probe.global_position = roof_building.call("local_cell_to_world_position", Vector2i(-2, -2))
			roof_building.call("_process", 0.0)
			roof_cycle_ok = hidden_inside and bool(roof_building.call("is_roof_visible"))
	_check(roof_cycle_ok, "独立 Roof 按 occlusion 掩码在进屋/离屋时收起并恢复")
	roof_viewer.free()


# ---------------------------------------------------------------- 14. 移除 / 搬迁

func _test_remove_and_move() -> void:
	# 用一份临时副本做可写测试，避免动到交付的示例地图
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tests_tmp"))
	var source := load(DEMO_MAP_PATH) as PackedScene
	if source == null:
		return
	var map := source.instantiate()
	var packed := PackedScene.new()
	packed.pack(map)
	map.free()
	var save_error := ResourceSaver.save(packed, TMP_MAP_PATH)
	_check_eq(save_error, OK, "临时地图副本写出成功")
	if save_error != OK:
		return

	var placer = BuildingPlacerScript.new()
	var initial: Dictionary = placer.validate_map_buildings(TMP_MAP_PATH)
	_check(bool(initial.get("ok", false)), "临时地图初始 validate-map 通过")
	_check_eq((initial.get("buildings", []) as Array).size(), 1, "临时地图里 1 座建筑")

	# 搬走
	var moved: Dictionary = placer.move_building(TMP_MAP_PATH, "IserraMonastery", Vector2i(1, 1))
	_check(bool(moved.get("ok", false)), "move_building 成功")
	if bool(moved.get("ok", false)):
		var reloaded := load(TMP_MAP_PATH) as PackedScene
		var map2 := reloaded.instantiate()
		var reloaded_list: Array = map2.call("get_buildings")
		var building := reloaded_list[0] as BuildingScript
		_check_eq(building.get_top_left_cell(), Vector2i(1, 1), "搬走后重新读回的放置格是 (1,1)")
		_check(reloaded_list.size() == 1, "搬走不会复制出第二座建筑")
		map2.free()

	# 拆掉
	var removed: Dictionary = placer.remove_building(TMP_MAP_PATH, "IserraMonastery")
	_check(bool(removed.get("ok", false)), "remove_building 成功")
	var reloaded3 := load(TMP_MAP_PATH) as PackedScene
	var map3 := reloaded3.instantiate()
	_check_eq((map3.call("get_buildings") as Array).size(), 0, "拆掉之后地图里没有建筑了")
	map3.free()

	# 拆干净之后，这张地图的通行判定回到纯图块规则（建筑逻辑不再干预）
	var after: Dictionary = placer.validate_map_buildings(TMP_MAP_PATH)
	_check(bool(after.get("ok", false)), "拆掉之后 validate-map 仍通过")

	# 收尾：删掉临时文件
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_MAP_PATH))


# ---------------------------------------------------------------- 工具

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
