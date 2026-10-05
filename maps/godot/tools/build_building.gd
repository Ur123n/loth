extends SceneTree

## 大型建筑管线 · 第 1 步：`building.spec.json` + 美术原图 → 标准建筑资产包。
##
## 用法：
##   :: 先让 Godot 认识新素材（新建的建筑资产包首次必须跑一次）
##   godot --headless --path C:\游戏 --import
##   :: 生成全部建筑
##   godot --headless --path C:\游戏 --script maps/godot/tools/build_building.gd
##   :: 只做一座 / 只做某一段
##   … -- --id iserra_monastery
##   … -- --id iserra_monastery --phase masks     只重算掩码 + metadata
##   … -- --id iserra_monastery --phase visual    只重切视觉大图
##   … -- --id iserra_monastery --phase prefab    只重建 Prefab
##   … -- --from-masks --id iserra_monastery      反过来：以手改过的掩码 PNG 为准，
####                                               重算 metadata（视觉与逻辑独立修改）
##
## 产出（全部落在 `assets/buildings/<id>/`，见 docs/world/building_pipeline.md）：
##   masks/*.png            5 张逻辑掩码（1 像素 = 1 格），见 core/building/building_mask.gd
##   masks/legend.json      掩码颜色/通道规范（给人和 Agent 看）
##   collision/collision_rects.json  碰撞矩形（掩码的贪心分解）
##   metadata/building.json Agent 唯一需要读的文件
##   visual/base.png        主视觉（已按占用区裁切 + 出血 + 区外透明）
##   visual/roof.png        屋顶叠加层
##   preview/preview.png    缩小预览
##   preview/debug_overlay.png  视觉 + 掩码叠加（自查对齐）
##   <PascalCase>.tscn      Building Prefab
##
## 设计要点：
## - **视觉与逻辑彻底分开**：逻辑只来自 spec 的 rooms/doors，跟那张大图无关；
##   换一张视觉图不用动任何逻辑数据。
## - **视觉尺寸 ≠ 逻辑尺寸**：spec 只写逻辑 footprint，视觉按占用区自动裁切，
##   两者不必相等（本项目里是 60×69 格的逻辑 vs 2880×3312 像素的图）。

const BUILDINGS_DIR := "res://assets/buildings"
const BuildingMaskScript := preload("res://core/building/building_mask.gd")
const BuildingDataScript := preload("res://core/building/building_data.gd")
const BuildingScript := preload("res://core/building/building.gd")

## 掩码图例：写进 masks/legend.json，给人和 Agent 当规范读。
const LEGEND := {
	"format": "1 像素 = 1 格；宽高 = metadata.footprint.size_cells",
	"coordinates": "左上角为 (0,0)，x 向东、y 向南，单位是格",
	"channel": "只认 alpha：alpha > 0.5 表示「该格属于这张掩码」（doors.png 例外，用颜色表示朝向）",
	"masks": {
		"occupancy.png": "建筑占用哪些格（含墙、含院内）。其它掩码都必须是它的子集",
		"walkable.png": "占用区里哪些格可以走（室内地板 / 院子）",
		"collision.png": "占用区里哪些格是实体（墙、柱、水面），与 walkable 互斥",
		"occlusion.png": "哪些格会被建筑遮挡（屋顶挑檐压住的可通行格），用于角色进屋时收屋顶",
		"doors.png": "门/入口所在格；颜色 = 门朝外的方向",
	},
	"door_colors": {
		"n": [90, 160, 255],
		"s": [255, 140, 60],
		"e": [120, 220, 120],
		"w": [220, 120, 255],
	},
	"regenerate": "掩码是生成物（改 building.spec.json 后重跑本工具）；也支持手改掩码后用 --from-masks 回灌 metadata",
}

var _failed := 0
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var args := _parse_args()
	var from_masks := args.has("from_masks")
	var ids := _resolve_ids(String(args.get("id", "")))
	if ids.is_empty():
		print("FAIL  没有找到任何建筑资产包（%s/*/building.spec.json）" % BUILDINGS_DIR)
		_failed += 1
	for building_id in ids:
		if from_masks:
			_rebuild_metadata_from_masks(building_id)
		else:
			_build(building_id, String(args.get("phase", "all")))
	print("RESULT: failed=%d" % _failed)
	quit(0 if _failed == 0 else 1)
	return true


func _fail(message: String) -> void:
	_failed += 1
	print("FAIL  ", message)


func _info(message: String) -> void:
	print("INFO  ", message)


func _parse_args() -> Dictionary:
	var out := {}
	var argv := OS.get_cmdline_user_args()
	var i := 0
	while i < argv.size():
		var arg := argv[i]
		if arg.begins_with("--"):
			var key := arg.trim_prefix("--")
			if i + 1 < argv.size() and not argv[i + 1].begins_with("--"):
				out[key] = argv[i + 1]
				i += 2
				continue
			out[key] = true
		i += 1
	return out


func _resolve_ids(explicit: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not explicit.is_empty():
		out.append(explicit)
		return out
	var dir := DirAccess.open(BUILDINGS_DIR)
	if dir == null:
		return out
	for sub in dir.get_directories():
		if FileAccess.file_exists("%s/%s/building.spec.json" % [BUILDINGS_DIR, sub]):
			out.append(sub)
	return out


# ================================================================ 主流程

## 阶段顺序有讲究：
##   masks → visual → metadata（此时几何与视觉都齐了，写出来的 metadata 才是完整的）→ prefab
## metadata 必须在 prefab **之前**写完，否则 Prefab 生成器读到的是一份"还没有视觉层"的 metadata，
## 会产出一座看不见的建筑。
func _build(building_id: String, phase: String) -> void:
	var spec := _load_spec(building_id)
	if spec.is_empty():
		return
	var raster := _rasterize(spec, building_id)
	if raster.is_empty():
		return

	# 已有 metadata 的视觉信息（只跑部分阶段时要保住它，别被覆盖成空）
	if phase != "all":
		_seed_visual_from_existing(building_id, raster)

	if phase == "all" or phase == "masks":
		_write_masks(building_id, raster)
		_write_collision(building_id, raster)
	if phase == "all" or phase == "visual":
		_write_visual(building_id, spec, raster)
	_write_metadata(building_id, spec, raster, _prefab_path(building_id))
	if phase == "all" or phase == "prefab":
		_write_prefab(building_id, spec, raster)


## 只跑部分阶段时，把已有 metadata 里的视觉信息搬回来，避免写出一份没有视觉层的 metadata。
func _seed_visual_from_existing(building_id: String, raster: Dictionary) -> void:
	if not FileAccess.file_exists("%s/%s/metadata/building.json" % [BUILDINGS_DIR, building_id]):
		return
	var existing := BuildingDataScript.load_from_json(
		"%s/%s/metadata/building.json" % [BUILDINGS_DIR, building_id])
	if existing == null:
		return
	var origin_array: Array = existing.visual.get("origin_tile", [0, 0])
	var size_tiles := existing.get_visual_size_tiles()
	if size_tiles.x <= 0 or size_tiles.y <= 0:
		return
	raster["visual_rect"] = Rect2i(int(origin_array[0]), int(origin_array[1]),
		size_tiles.x, size_tiles.y)
	raster["visual_layers"] = existing.visual.get("layers", [])


# ================================================================ spec

func _load_spec(building_id: String) -> Dictionary:
	var path := "%s/%s/building.spec.json" % [BUILDINGS_DIR, building_id]
	if not FileAccess.file_exists(path):
		_fail("建筑 spec 不存在：%s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("建筑 spec 不是合法 JSON：%s" % path)
		return {}
	var spec: Dictionary = parsed
	if String(spec.get("building_id", "")) != building_id:
		_fail("spec 的 building_id（%s）与目录名（%s）不一致" % [spec.get("building_id", ""), building_id])
		return {}
	return spec


# ================================================================ 光栅化：逻辑几何

## spec → 掩码格集合。**这里就是"逻辑"的全部来源**，不读视觉图。
##
## 规则（正方形网格，1 格 = 1 米）：
## - `occupied` = 所有 room 矩形的并集
## - `walkable` = 每个 room 向内缩 1 格的并集（缩出来的那一圈就是墙）
## - `blocked`  = `occupied - walkable`
## - 门：把门所在的那格（可跨多格）强制设为可行走，从而在墙上开洞
## - `occlusion` = 有 roof 的 room 矩形（屋顶盖住的格）
func _rasterize(spec: Dictionary, building_id: String) -> Dictionary:
	var plan: Dictionary = spec.get("plan", {})
	var rooms: Array = plan.get("rooms", [])
	if rooms.is_empty():
		_fail("spec.plan.rooms 为空：没有房间就没有几何")
		return {}

	var occupied := {}
	var walkable := {}
	var occlusion := {}
	var room_records: Array = []
	for room in rooms:
		var r: Dictionary = room
		var rect := _rect_from_m(plan, r)
		var solid := bool(r.get("solid", false))
		if rect.size.x <= 0 or rect.size.y <= 0:
			_fail("房间 %s 的尺寸非法：%s" % [String(r.get("id", "?")), str(rect)])
			continue
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			for x in range(rect.position.x, rect.position.x + rect.size.x):
				occupied[Vector2i(x, y)] = true
		# solid 用于城墙、不可进入的建筑体块：占地存在，但不会从贴图反推可走区。
		if not solid:
			# 向内缩 1 格 = 去掉墙
			var inner := Rect2i(rect.position + Vector2i.ONE, rect.size - Vector2i(2, 2))
			if inner.size.x <= 0 or inner.size.y <= 0:
				# 太窄（1~2 格宽）的房间：整块留空，避免算出负尺寸
				inner = rect
			for y in range(inner.position.y, inner.position.y + inner.size.y):
				for x in range(inner.position.x, inner.position.x + inner.size.x):
					walkable[Vector2i(x, y)] = true
		if r.get("roof", null) != null:
			for y in range(rect.position.y, rect.position.y + rect.size.y):
				for x in range(rect.position.x, rect.position.x + rect.size.x):
					occlusion[Vector2i(x, y)] = true
		room_records.append({
			"id": String(r.get("id", "")),
			"label": String(r.get("label", "")),
			"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
			"roofed": r.get("roof", null) != null,
			"solid": solid,
		})

	# 柱廊/敞廊等"画上是柱列、逻辑上要能走"的开口：强制设为可通行
	var opening_cells := {}
	for opening in plan.get("openings", []):
		var o: Dictionary = opening
		var rect := Rect2i(int(o.get("x_m", 0)), int(o.get("y_m", 0)),
			maxi(1, int(o.get("w_m", 1))), maxi(1, int(o.get("h_m", 1))))
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			for x in range(rect.position.x, rect.position.x + rect.size.x):
				var cell := Vector2i(x, y)
				if not occupied.has(cell):
					continue   # 只开在建筑自己身上，别开出一片悬空的通路
				walkable[cell] = true
				opening_cells[cell] = true

	# 门：在墙上开洞
	var doors: Array = []
	var door_cells := {}
	var sides := {}
	var pre_door_blocked := BuildingMaskScript.subtract(occupied, walkable)
	for door in plan.get("doors", []):
		var d: Dictionary = door
		var opened := _resolve_door_cells(plan, d, occupied, pre_door_blocked)
		if opened.is_empty():
			_fail("门 %s 找不到可以开洞的墙" % str(d))
			continue
		for cell in opened:
			walkable[cell] = true
			door_cells[cell] = true
			sides[cell] = String(d.get("side", "n"))
		var tile := _tile_size(plan)
		var extent := _door_extent(opened, String(d.get("side", "n")))
		doors.append({
			"id": String(d.get("id", "door_%d" % doors.size())),
			"label": String(d.get("note", "")),
			"cell": [opened[0].x, opened[0].y],
			"width_tiles": extent.x,
			"thickness_tiles": extent.y,
			"outward_side": String(d.get("side", "n")),
			"target": String(d.get("target", "outside")),
			"interact": String(d.get("interact", "enter_building")),
			"local_px": [opened[0].x * tile.x, opened[0].y * tile.y],
		})

	var blocked := BuildingMaskScript.subtract(occupied, walkable)
	var occlusion_cells := BuildingMaskScript.intersect(occlusion, walkable)

	if blocked.is_empty():
		_fail("blocked 为空：每个房间缩 1 格之后没有剩下墙，spec 的房间划分多半有问题")

	return {
		"plan": plan,
		"rooms": room_records,
		"doors": doors,
		"occupancy": occupied,
		"walkable": walkable,
		"blocked": blocked,
		"occlusion": occlusion_cells,
		"door_cells": door_cells,
		"door_sides": sides,
		"footprint": BuildingMaskScript.bounds(occupied),
		"tile_size": _tile_size(plan),
	}


func _tile_size(plan: Dictionary) -> Vector2i:
	var scale: Dictionary = plan.get("scale", {})
	var tile := int(scale.get("tile_px", 48))
	return Vector2i(tile, tile)


## 节点原点在局部像素坐标系里的位置（与 BuildingData.get_anchor_local_px 同一套规则）。
func _anchor_local_px(mode: String, size: Vector2i, tile: Vector2i) -> Vector2:
	match mode:
		"top_left":
			return Vector2.ZERO
		"center":
			return Vector2(size) * 0.5 * Vector2(tile)
		"bottom_left":
			return Vector2(0, size.y) * Vector2(tile)
		_:
			return Vector2(size.x * 0.5, float(size.y)) * Vector2(tile)


## 房间矩形：spec 以「米（= 格）」描述，这里换算成格坐标；可选 `origin_m` 平移。
func _rect_from_m(plan: Dictionary, room: Dictionary) -> Rect2i:
	var origin: Array = plan.get("origin_m", [0, 0])
	var ox := int(origin[0])
	var oy := int(origin[1])
	return Rect2i(
		int(room.get("x_m", 0)) - ox,
		int(room.get("y_m", 0)) - oy,
		maxi(1, int(room.get("w_m", 1))),
		maxi(1, int(room.get("h_m", 1))))


## 门开在哪几格。语义：**在墙上打通一条路**，不只是挖一格。
## 1. 从声明坐标出发，沿门的朝向在附近找到"正好是墙"的那一格（美术给的坐标是开洞位置，可能有 ±2 格误差）
## 2. 沿墙的方向按 `w_m` 展开（双开门）
## 3. 每一列/行再沿墙的**法线方向**把整堵墙打穿 —— 否则门只挖掉半堵墙，两边房间还是不通
func _resolve_door_cells(plan: Dictionary, door: Dictionary, occupied: Dictionary,
		blocked: Dictionary) -> Array:
	var origin: Array = plan.get("origin_m", [0, 0])
	var ox := int(origin[0])
	var oy := int(origin[1])
	var side := String(door.get("side", "n"))
	var width := maxi(1, int(door.get("w_m", 1)))
	var start := Vector2i(int(door.get("x_m", 0)) - ox, int(door.get("y_m", 0)) - oy)

	var along_x := side in ["n", "s"]
	var along := Vector2i(1, 0) if along_x else Vector2i(0, 1)
	var normal := Vector2i(0, 1) if along_x else Vector2i(1, 0)
	var preferred := 1 if side in ["s", "e"] else -1

	# ---- 第 1 步：找到墙格
	var wall_cell := Vector2i(-1, -1)
	var offsets: Array = [0]
	for step in range(1, 7):
		offsets.append(preferred * step)
		if step <= 3:
			offsets.append(-preferred * step)
	for offset in offsets:
		var candidate: Vector2i = start + normal * offset
		if blocked.has(candidate):
			wall_cell = candidate
			break
	if wall_cell.x < 0:
		return []

	# ---- 第 2、3 步：沿墙展开 + 打穿墙厚
	var opened := {}
	for i in width:
		var base: Vector2i = wall_cell + along * i
		if not occupied.has(base):
			continue
		opened[base] = true
		for direction in [normal, -normal]:
			var probe: Vector2i = base
			while true:
				probe += direction
				if not blocked.has(probe):
					break
				opened[probe] = true
	var cells: Array = opened.keys()
	cells.sort_custom(func(a, b): return (a.y < b.y) if a.y != b.y else (a.x < b.x))
	return cells


## 门洞的 (沿墙宽度, 穿墙厚度)：按两个轴上各有多少个不同坐标算，
## 不是按总数 —— 否则"2 格宽 + 1 格厚"和"1 格宽 + 2 格厚"会算成同一个数。
func _door_extent(cells: Array, side: String) -> Vector2i:
	if cells.is_empty():
		return Vector2i(1, 1)
	var along_x := side in ["n", "s"]
	var along_values := {}
	var thickness_values := {}
	for cell in cells:
		var c: Vector2i = cell
		if along_x:
			along_values[c.x] = true
			thickness_values[c.y] = true
		else:
			along_values[c.y] = true
			thickness_values[c.x] = true
	return Vector2i(along_values.size(), thickness_values.size())


# ================================================================ 掩码落盘

func _write_masks(building_id: String, raster: Dictionary) -> void:
	var base := "%s/%s/masks" % [BUILDINGS_DIR, building_id]
	_ensure_dir(base)
	var size: Vector2i = raster["footprint"].size
	_write_mask_image(base.path_join("occupancy.png"), size, raster["occupancy"])
	_write_mask_image(base.path_join("walkable.png"), size, raster["walkable"])
	_write_mask_image(base.path_join("collision.png"), size, raster["blocked"])
	_write_mask_image(base.path_join("occlusion.png"), size, raster["occlusion"])
	_write_mask_image(base.path_join("doors.png"), size, raster["door_cells"], raster["door_sides"])
	var legend := LEGEND.duplicate(true)
	legend["anchor_note"] = "掩码的 (0,0) 格 = metadata.footprint 的左上角格；占用区包围盒即 footprint"
	_write_json(base.path_join("legend.json"), legend)
	print("WROTE %s/{occupancy,walkable,collision,occlusion,doors}.png + legend.json（%d×%d 格）"
		% [base, size.x, size.y])


func _write_mask_image(path: String, size: Vector2i, cells: Dictionary, sides: Dictionary = {}) -> void:
	var image := BuildingMaskScript.new_image(size)
	var mask_name := path.get_file().get_basename()
	BuildingMaskScript.write_cells(image, cells, mask_name, sides)
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		_fail("掩码写入失败 err=%d：%s" % [error, path])


func _write_collision(building_id: String, raster: Dictionary) -> void:
	var base := "%s/%s/collision" % [BUILDINGS_DIR, building_id]
	_ensure_dir(base)
	var rects := BuildingMaskScript.greedy_rects(raster["blocked"])
	var tile := Vector2i(raster["tile_size"])
	var rect_arrays: Array = []
	for rect in rects:
		rect_arrays.append([rect.position.x, rect.position.y, rect.size.x, rect.size.y])
	_write_json(base.path_join("collision_rects.json"), {
		"note": "collision.png 的贪心矩形分解（不重不漏，面积 = 实体格数）；Prefab 的 CollisionShape2D 就按它生成",
		"tile_size": [tile.x, tile.y],
		"blocked_cells": raster["blocked"].size(),
		"rect_count": rect_arrays.size(),
		"rects": rect_arrays,
	})
	print("WROTE %s/collision_rects.json（%d 个矩形覆盖 %d 个实体格）"
		% [base, rect_arrays.size(), raster["blocked"].size()])


# ================================================================ 视觉：裁切 + 出血 + 透明化

func _write_visual(building_id: String, spec: Dictionary, raster: Dictionary) -> void:
	var visual_spec: Dictionary = spec.get("visual", {})
	var base_dir := "%s/%s/visual" % [BUILDINGS_DIR, building_id]
	_ensure_dir(base_dir)
	var padding := int(visual_spec.get("padding_tiles", 1))
	# 美术原图里 footprint(0,0) 落在画布的第几格（画布可能比 footprint 大很多）
	var source_origin_array: Array = visual_spec.get("source_origin_tile", [0, 0])
	var source_origin := Vector2i(int(source_origin_array[0]), int(source_origin_array[1]))
	var region: Rect2i = raster["footprint"]
	# 视觉范围 = 占用区包围盒 + 出血（默认 1 格），这样图比逻辑略大一点点，
	# 墙脚阴影/挑檐不会被裁掉，但不会糊住整张地图。
	var visual_rect := Rect2i(region.position - Vector2i(padding, padding),
		region.size + Vector2i(padding, padding) * 2)

	var tile := Vector2i(raster["tile_size"])
	var alpha_region := BuildingMaskScript.grow(raster["occupancy"], padding)
	var clip_to_logic := bool(visual_spec.get("clip_to_logic", true))
	var layers: Array = []

	for layer in visual_spec.get("layers", []):
		var l: Dictionary = layer
		var source_path := String(l.get("source", ""))
		if source_path.is_empty():
			continue
		var image := _load_image(source_path)
		if image == null:
			_fail("视觉原图读不出来：%s（先跑一次 --import？）" % source_path)
			continue
		image.convert(Image.FORMAT_RGBA8)
		# 1) 区外透明：只保留「占用区 + 出血」内的像素，其余让地图自己的地形透出来
		if bool(l.get("clip_to_logic", clip_to_logic)):
			_make_outside_transparent(image, visual_rect, alpha_region, tile, source_origin)
		# 2) 裁到视觉范围（出血可能伸到原图之外 → 取交集，缺的部分留透明）
		var dst_size := visual_rect.size * tile
		var src_rect := Rect2i((visual_rect.position + source_origin) * tile, dst_size)
		var cropped := Image.create(dst_size.x, dst_size.y, false, Image.FORMAT_RGBA8)
		cropped.fill(Color(0, 0, 0, 0))
		var source_bounds := Rect2i(0, 0, image.get_width(), image.get_height())
		var clipped := src_rect.intersection(source_bounds)
		if clipped.size.x > 0 and clipped.size.y > 0:
			cropped.blit_rect(image, clipped, clipped.position - src_rect.position)
		var out_name := String(l.get("output", "%s.png" % String(l.get("name", "layer"))))
		var out_path := base_dir.path_join(out_name)
		cropped.save_png(ProjectSettings.globalize_path(out_path))
		layers.append({
			"name": String(l.get("name", "base")),
			"role": String(l.get("role", "base")),
			"path": out_path,
			"source": source_path,
			"size_px": [cropped.get_width(), cropped.get_height()],
			"size_tiles": [visual_rect.size.x, visual_rect.size.y],
			"origin_tile": [visual_rect.position.x, visual_rect.position.y],
			"z_index": int(l.get("z_index", 0)),
			"visible": bool(l.get("visible", true)),
		})
		print("WROTE %s（%d×%d，来自 %s）" % [out_path, cropped.get_width(), cropped.get_height(), source_path])

	raster["visual_rect"] = visual_rect
	raster["visual_layers"] = layers
	_write_previews(building_id, raster, layers)


## 把 visual_rect + alpha_region 之外的像素清成透明（视觉只负责建筑自己那一块）。
func _make_outside_transparent(image: Image, visual_rect: Rect2i, alpha_region: Dictionary,
		tile: Vector2i, source_origin: Vector2i) -> void:
	var transparent := Color(0, 0, 0, 0)
	var width := image.get_width()
	var height := image.get_height()
	for y in range(visual_rect.position.y, visual_rect.position.y + visual_rect.size.y):
		for x in range(visual_rect.position.x, visual_rect.position.x + visual_rect.size.x):
			if alpha_region.has(Vector2i(x, y)):
				continue
			var px := (Vector2i(x, y) + source_origin) * tile
			for dy in tile.y:
				for dx in tile.x:
					var point := px + Vector2i(dx, dy)
					if point.x < 0 or point.y < 0 or point.x >= width or point.y >= height:
						continue
					image.set_pixelv(point, transparent)


func _write_previews(building_id: String, raster: Dictionary, layers: Array) -> void:
	var preview_dir := "%s/%s/preview" % [BUILDINGS_DIR, building_id]
	_ensure_dir(preview_dir)
	if layers.is_empty():
		return
	var base_image := _load_image(String((layers[0] as Dictionary)["path"]))
	if base_image == null:
		return
	# 1) 缩小预览（最长边 640）
	var preview: Image = base_image.duplicate()
	var longest := maxi(preview.get_width(), preview.get_height())
	if longest > 640:
		var factor := float(longest) / 640.0
		preview.resize(maxi(1, int(preview.get_width() / factor)), maxi(1, int(preview.get_height() / factor)),
			Image.INTERPOLATE_NEAREST)
	preview.save_png(ProjectSettings.globalize_path(preview_dir.path_join("preview.png")))
	print("WROTE %s（%d×%d）" % [preview_dir.path_join("preview.png"), preview.get_width(), preview.get_height()])

	# 2) 调试叠加：视觉压暗 + 掩码上色（一眼看出逻辑有没有对准画）
	var overlay: Image = base_image.duplicate()
	overlay.convert(Image.FORMAT_RGBA8)
	var tile := Vector2i(raster["tile_size"])
	var visual_rect: Rect2i = raster["visual_rect"]
	var footprint: Rect2i = raster["footprint"]
	var origin := (footprint.position - visual_rect.position) * tile
	for y in overlay.get_height():
		for x in overlay.get_width():
			var c := overlay.get_pixel(x, y)
			overlay.set_pixel(x, y, Color(c.r * 0.45, c.g * 0.45, c.b * 0.45, c.a))
	var cell_origin := Vector2i.ZERO
	_paint_overlay(overlay, raster["occupancy"], origin, cell_origin, footprint, tile, Color(0.3, 0.7, 1.0, 0.16))
	_paint_overlay(overlay, raster["blocked"], origin, cell_origin, footprint, tile, Color(1.0, 0.15, 0.15, 0.42))
	_paint_overlay(overlay, raster["walkable"], origin, cell_origin, footprint, tile, Color(0.2, 1.0, 0.3, 0.22))
	_paint_overlay(overlay, raster["door_cells"], origin, cell_origin, footprint, tile, Color(1.0, 1.0, 0.2, 0.95))
	if overlay.get_width() > 1280:
		var factor := float(overlay.get_width()) / 1280.0
		overlay.resize(int(overlay.get_width() / factor), int(overlay.get_height() / factor),
			Image.INTERPOLATE_NEAREST)
	overlay.save_png(ProjectSettings.globalize_path(preview_dir.path_join("debug_overlay.png")))
	print("WROTE %s（%d×%d）" % [preview_dir.path_join("debug_overlay.png"),
		overlay.get_width(), overlay.get_height()])


func _paint_overlay(image: Image, cells: Dictionary, origin: Vector2i, cell_origin: Vector2i,
		footprint: Rect2i, tile: Vector2i, color: Color) -> void:
	for cell in cells:
		if not footprint.has_point(cell):
			continue
		var px := origin + Vector2i((cell.x - cell_origin.x) * tile.x, (cell.y - cell_origin.y) * tile.y)
		for dy in tile.y:
			for dx in tile.x:
				var point := px + Vector2i(dx, dy)
				if point.x < 0 or point.y < 0 or point.x >= image.get_width() or point.y >= image.get_height():
					continue
				var under := image.get_pixelv(point)
				image.set_pixelv(point, under.lerp(Color(color.r, color.g, color.b, 1.0),
					color.a * under.a))


func _load_image(path: String) -> Image:
	var global := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(global):
		global = path
	if not FileAccess.file_exists(global):
		return null
	var image := Image.new()
	if image.load(global) != OK:
		return null
	return image


# ================================================================ metadata

func _write_metadata(building_id: String, spec: Dictionary, raster: Dictionary,
		prefab_path: String) -> void:
	var base := "%s/%s/metadata" % [BUILDINGS_DIR, building_id]
	_ensure_dir(base)
	var visual_spec: Dictionary = spec.get("visual", {})
	var visual_rect: Rect2i = raster.get("visual_rect", raster["footprint"])
	var footprint: Rect2i = raster["footprint"]
	var layers: Array = raster.get("visual_layers", [])
	var tile := Vector2i(raster["tile_size"])
	var size := footprint.size
	var collision: Dictionary = spec.get("collision", {})

	var rects := BuildingMaskScript.greedy_rects(raster["blocked"])
	var rect_arrays: Array = []
	for rect in rects:
		rect_arrays.append([rect.position.x, rect.position.y, rect.size.x, rect.size.y])

	var anchor_px := _anchor_local_px(String(spec.get("anchor_mode", "bottom_center")), size, tile)
	var offset := Vector2(visual_rect.position * tile) - anchor_px
	var source_origin_array: Array = visual_spec.get("source_origin_tile", [0, 0])
	var source_origin := Vector2i(int(source_origin_array[0]), int(source_origin_array[1]))

	var metadata := {
		"schema": BuildingDataScript.SCHEMA,
		"projection_id": String(spec.get("projection_id", "orthogonal_3q_48_v1")),
		"building_id": building_id,
		"display_name": String(spec.get("display_name", building_id)),
		"display_name_en": String(spec.get("display_name_en", "")),
		"kind": String(spec.get("kind", "large_building")),
		"tile_size": [tile.x, tile.y],
		"asset_path": "%s/%s" % [BUILDINGS_DIR, building_id],
		"prefab_path": prefab_path,
		"anchor": {
			"mode": String(spec.get("anchor_mode", "bottom_center")),
			"note": "节点原点落在 footprint 的底部中心，Y 轴排序才会按「脚下」前后遮挡",
			"origin_cell": [size.x * 0.5, float(size.y)],
		},
		"visual": {
			"tile_size": [tile.x, tile.y],
			"size_px": [visual_rect.size.x * tile.x, visual_rect.size.y * tile.y],
			"size_tiles": [visual_rect.size.x, visual_rect.size.y],
			"padding_tiles": int(visual_spec.get("padding_tiles", 1)),
			"clip_to_logic": bool(visual_spec.get("clip_to_logic", true)),
			"origin_tile": [visual_rect.position.x, visual_rect.position.y],
			"source_origin_tile": [source_origin.x, source_origin.y],
			"origin_px_in_source": [(visual_rect.position.x + source_origin.x) * tile.x,
				(visual_rect.position.y + source_origin.y) * tile.y],
			"anchor_offset_px": [offset.x, offset.y],
			"note": "视觉尺寸与逻辑 footprint 故意不绑定（本建筑视觉 %d×%d 像素，逻辑 %d×%d 格）；anchor_offset_px = 贴图相对节点原点的偏移" % [
				visual_rect.size.x * tile.x, visual_rect.size.y * tile.y, size.x, size.y],
			"layers": layers,
		},
		"footprint": {
			"origin_cell": [0, 0],
			"size_cells": [size.x, size.y],
			"size_px": [size.x * tile.x, size.y * tile.y],
			"note": "逻辑地基。左上角为 (0,0)，与视觉图的 (0,0) 像素对齐",
		},
		"occupied_cells": {
			"count": raster["occupancy"].size(),
			"runs": BuildingMaskScript.runs_from_cells(raster["occupancy"]),
			"note": "游程编码 [[y, x起, 长度], …]；完整格集合 = 掩码 masks/occupancy.png",
		},
		"walkable_cells": {
			"count": raster["walkable"].size(),
			"runs": BuildingMaskScript.runs_from_cells(raster["walkable"]),
		},
		"blocked_cells": {
			"count": raster["blocked"].size(),
			"runs": BuildingMaskScript.runs_from_cells(raster["blocked"]),
		},
		"occlusion_cells": {
			"count": raster["occlusion"].size(),
			"runs": BuildingMaskScript.runs_from_cells(raster["occlusion"]),
		},
		"doors": raster["doors"],
		"rooms": raster["rooms"],
		"collision": {
			"layer": int(collision.get("layer", 2)),
			"mask": int(collision.get("mask", 1)),
			"rects": rect_arrays,
			"rect_count": rect_arrays.size(),
			"note": "由 masks/collision.png 贪心分解而来，面积等于 blocked_cells.count",
		},
		"tactical": spec.get("tactical", {}),
		"sorting": spec.get("sorting", {}),
		"masks": {
			"occupancy": "res://assets/buildings/%s/masks/occupancy.png" % building_id,
			"walkable": "res://assets/buildings/%s/masks/walkable.png" % building_id,
			"collision": "res://assets/buildings/%s/masks/collision.png" % building_id,
			"occlusion": "res://assets/buildings/%s/masks/occlusion.png" % building_id,
			"doors": "res://assets/buildings/%s/masks/doors.png" % building_id,
			"legend": "res://assets/buildings/%s/masks/legend.json" % building_id,
		},
		"source": {
			"spec": "res://assets/buildings/%s/building.spec.json" % building_id,
			"plan": String(spec.get("plan_source", "")),
			"generated_by": "maps/godot/tools/build_building.gd",
			"generated_for": "godot --headless --path C:\\游戏 --script maps/godot/tools/build_building.gd",
		},
	}
	_write_json(base.path_join("building.json"), metadata)
	print("WROTE %s（占用 %d 格 / 可走 %d 格 / 实体 %d 格 / 门 %d / 碰撞矩形 %d）" % [
		base.path_join("building.json"), raster["occupancy"].size(), raster["walkable"].size(),
		raster["blocked"].size(), raster["doors"].size(), rect_arrays.size()])


## `--from-masks`：以掩码 PNG 为准重算 metadata。
## 给"更想直接画掩码"的人用：视觉与逻辑可以完全分开改，改完这里回灌。
func _rebuild_metadata_from_masks(building_id: String) -> void:
	var spec := _load_spec(building_id)
	if spec.is_empty():
		return
	var base := "%s/%s" % [BUILDINGS_DIR, building_id]
	var occupancy_path := base.path_join("masks/occupancy.png")
	if not FileAccess.file_exists(occupancy_path):
		_fail("没有 masks/occupancy.png，无法从掩码回灌：%s" % occupancy_path)
		return
	var occupancy := BuildingMaskScript.read_cells(_load_image(occupancy_path))
	var walkable := BuildingMaskScript.read_cells(_load_image(base.path_join("masks/walkable.png")))
	var blocked := BuildingMaskScript.read_cells(_load_image(base.path_join("masks/collision.png")))
	var occlusion := BuildingMaskScript.read_cells(_load_image(base.path_join("masks/occlusion.png")))
	var door_image := _load_image(base.path_join("masks/doors.png"))
	var door_cells := {}
	var door_sides := {}
	if door_image != null:
		for y in door_image.get_height():
			for x in door_image.get_width():
				var color := door_image.get_pixel(x, y)
				if color.a <= 0.5:
					continue
				door_cells[Vector2i(x, y)] = true
				door_sides[Vector2i(x, y)] = BuildingMaskScript.side_from_color(color)

	var raster := {
		"plan": spec.get("plan", {}),
		"rooms": _rooms_from_spec_only(spec, spec.get("plan", {})),
		"doors": _doors_from_masks(spec, door_cells, door_sides),
		"occupancy": occupancy,
		"walkable": walkable,
		"blocked": blocked,
		"occlusion": occlusion,
		"door_cells": door_cells,
		"door_sides": door_sides,
		"footprint": BuildingMaskScript.bounds(occupancy),
		"tile_size": _tile_size(spec.get("plan", {})),
	}
	# 视觉范围沿用已有 metadata（视觉文件不动）
	var existing := BuildingDataScript.load_from_json(base.path_join("metadata/building.json"))
	if existing != null:
		var origin: Array = existing.visual.get("origin_tile",
			existing.visual.get("origin_tile_in_source", [0, 0]))
		var visual_rect := Rect2i(int(origin[0]), int(origin[1]),
			int(existing.get_visual_size_tiles().x), int(existing.get_visual_size_tiles().y))
		raster["visual_rect"] = visual_rect
		raster["visual_layers"] = existing.visual.get("layers", [])
	_write_collision(building_id, raster)
	_write_metadata(building_id, spec, raster, _prefab_path(building_id))
	print("INFO   已按掩码 PNG 重算 metadata（视觉未改动）")


func _rooms_from_spec_only(spec: Dictionary, plan: Dictionary) -> Array:
	var out: Array = []
	for room in plan.get("rooms", []):
		var r: Dictionary = room
		var rect := _rect_from_m(plan, r)
		out.append({
			"id": String(r.get("id", "")),
			"label": String(r.get("label", "")),
			"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
			"roofed": r.get("roof", null) != null,
		})
	return out


func _doors_from_masks(spec: Dictionary, door_cells: Dictionary, door_sides: Dictionary) -> Array:
	if door_cells.is_empty():
		return _doors_from_spec(spec)
	# 把连成一片的门格并成一个门（双开门）
	var by_side := {}
	for cell in door_cells:
		var side := String(door_sides.get(cell, "n"))
		if not by_side.has(side):
			by_side[side] = []
		(by_side[side] as Array).append(cell)
	var out: Array = []
	for side in by_side:
		var cells: Array = by_side[side]
		cells.sort_custom(func(a, b): return a.y < b.y if a.y != b.y else a.x < b.x)
		out.append({
			"id": "door_%s_%d" % [side, out.size()],
			"label": "",
			"cell": [cells[0].x, cells[0].y],
			"width_tiles": cells.size(),
			"outward_side": String(side),
			"target": "outside",
			"interact": "enter_building",
			"local_px": [cells[0].x * 48, cells[0].y * 48],
		})
	return out


func _doors_from_spec(spec: Dictionary) -> Array:
	return []


# ================================================================ Prefab

func _prefab_path(building_id: String) -> String:
	return "%s/%s/%s" % [BUILDINGS_DIR, building_id, BuildingDataScript.prefab_file_name(building_id)]


func _write_prefab(building_id: String, spec: Dictionary, raster: Dictionary) -> void:
	var metadata_path := "%s/%s/metadata/building.json" % [BUILDINGS_DIR, building_id]
	if not FileAccess.file_exists(metadata_path):
		_fail("metadata 还没生成，先跑 --phase masks")
		return
	var data := BuildingDataScript.load_from_json(metadata_path)
	if data == null:
		_fail("metadata 解析失败：%s" % metadata_path)
		return
	# 贴图必须先被 Godot 导入过，否则 PackedScene 引用不到纹理
	var missing: Array = []
	for layer in data.get_visual_layers():
		var path := String((layer as Dictionary).get("path", ""))
		if path.is_empty():
			continue
		if ResourceLoader.exists(path) == false:
			missing.append(path)
	if not missing.is_empty():
		_fail("视觉贴图还没被 Godot 导入：%s\n      先跑一次：godot --headless --path C:\\游戏 --import，然后重跑本工具"
			% ", ".join(PackedStringArray(missing)))
		return

	var root := BuildingScript.new()
	root.name = BuildingDataScript.prefab_file_name(building_id).get_basename()
	root.set("building_id", building_id)
	root.set("data_path", metadata_path)

	var visual := Node2D.new()
	visual.name = BuildingScript.CHILD_VISUAL
	root.add_child(visual)
	var first_sprite: Sprite2D = null
	for layer in data.get_visual_layers():
		var l: Dictionary = layer
		var sprite := Sprite2D.new()
		sprite.name = String(l.get("name", "layer"))
		var texture := load(String(l.get("path", ""))) as Texture2D
		if texture == null:
			_fail("贴图加载失败：%s" % String(l.get("path", "")))
			continue
		sprite.texture = texture
		sprite.centered = false
		sprite.offset = Vector2.ZERO
		sprite.z_index = int(l.get("z_index", 0))
		visual.add_child(sprite)
		if first_sprite == null:
			first_sprite = sprite

	var collision := StaticBody2D.new()
	collision.name = BuildingScript.CHILD_COLLISION
	collision.collision_layer = int(data.collision.get("layer", 2))
	collision.collision_mask = int(data.collision.get("mask", 1))
	root.add_child(collision)
	var tile := Vector2(data.get_tile_size())
	for index in data.get_collision_rects().size():
		var r: Array = data.get_collision_rects()[index]
		var rect := Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))
		var shape_node := CollisionShape2D.new()
		shape_node.name = "Shape%03d" % index
		var shape := RectangleShape2D.new()
		shape.size = Vector2(rect.size) * tile
		shape_node.shape = shape
		shape_node.position = (Vector2(rect.position) + Vector2(rect.size) * 0.5) * tile
		collision.add_child(shape_node)

	var occupancy := Node2D.new()
	occupancy.name = BuildingScript.CHILD_OCCUPANCY
	occupancy.set_meta("count", data.get_occupied_count())
	occupancy.set_meta("mask", data.masks.get("occupancy", ""))
	root.add_child(occupancy)

	var walkable := Node2D.new()
	walkable.name = BuildingScript.CHILD_WALKABLE
	walkable.set_meta("count", data.get_walkable_count())
	walkable.set_meta("mask", data.masks.get("walkable", ""))
	root.add_child(walkable)

	var doors := Node2D.new()
	doors.name = BuildingScript.CHILD_DOORS
	root.add_child(doors)
	var interaction := Node2D.new()
	interaction.name = BuildingScript.CHILD_INTERACTION
	root.add_child(interaction)
	for door in data.get_doors():
		var d: Dictionary = door
		var cell_array: Array = d.get("cell", [0, 0])
		var cell := Vector2i(int(cell_array[0]), int(cell_array[1]))
		var width := int(d.get("width_tiles", 1))
		var side := String(d.get("outward_side", "n"))
		var marker := Marker2D.new()
		marker.name = String(d.get("id", "door"))
		marker.position = data.cell_center_local_px(cell) + Vector2(tile) * (
			Vector2(width - 1, 0) * 0.5 if side in ["n", "s"] else Vector2(0, width - 1) * 0.5)
		marker.set_meta("outward_side", side)
		marker.set_meta("label", String(d.get("label", "")))
		marker.set_meta("target", String(d.get("target", "")))
		doors.add_child(marker)
		var area := Area2D.new()
		area.name = String(d.get("id", "door"))
		area.position = marker.position
		area.collision_layer = 0
		area.collision_mask = 1
		area.monitoring = true
		area.set_meta("door_id", String(d.get("id", "door")))
		area.set_meta("interact", String(d.get("interact", "enter_building")))
		var area_shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = float(tile.x) * 0.75
		area_shape.shape = circle
		area.add_child(area_shape)
		interaction.add_child(area)

	var tactical := Node.new()
	tactical.name = BuildingScript.CHILD_TACTICAL
	tactical.set_meta("cover", data.tactical.get("cover", 0.0))
	tactical.set_meta("cover_level", data.tactical.get("cover_level", "none"))
	tactical.set_meta("height_level", data.tactical.get("height_level", 0))
	tactical.set_meta("blocks_los", data.tactical.get("blocks_los", false))
	tactical.set_meta("enterable", data.tactical.get("enterable", true))
	root.add_child(tactical)

	# 每层视觉都在锚点处对齐：节点原点 = 底部中心，贴图按 metadata 里的偏移往左上摆
	var anchor_offset := data.get_visual_offset_px()
	for child_name in [BuildingScript.CHILD_COLLISION, BuildingScript.CHILD_DOORS, BuildingScript.CHILD_INTERACTION]:
		(root.get_node(NodePath(child_name)) as Node2D).position = -data.get_anchor_local_px()
	for child in visual.get_children():
		(child as Node2D).position = anchor_offset

	for node in root.get_children():
		node.owner = root
		for grandchild in node.get_children():
			grandchild.owner = root
			for great in grandchild.get_children():
				great.owner = root

	root.y_sort_enabled = true
	var packed := PackedScene.new()
	var pack_error := packed.pack(root)
	if pack_error != OK:
		_fail("Prefab 打包失败 err=%d" % pack_error)
		root.free()
		return
	var path := _prefab_path(building_id)
	var save_error := ResourceSaver.save(packed, path)
	if save_error != OK:
		_fail("Prefab 保存失败 err=%d：%s" % [save_error, path])
	else:
		print("WROTE %s（视觉层 %d / 碰撞形状 %d / 门 %d）" % [
			path, data.get_visual_layers().size(), data.get_collision_rects().size(), data.get_doors().size()])
	root.free()


# ================================================================ 文件工具

func _ensure_dir(path: String) -> void:
	if DirAccess.open(path) != null:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _write_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	if file == null:
		_fail("写文件失败：%s" % path)
		return
	file.store_string(JSON.stringify(value, " ", true))
	file.close()
