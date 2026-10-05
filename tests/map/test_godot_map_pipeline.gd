extends SceneTree

## Godot 地图编辑器管线自检：
##  1. 当前规格 48px 黑暗奇幻（多来源 + 自动打包图集 + 16 配置自动拼接 + 地形集）
##     素材来自 assets/dark48/（美术线交付），布局见 docs/art/style_guide.md
##  2. 场景与运行时接口：图层约定、标记、可通行判定、自动拼接正确性、画面级氛围 75/20/5
##  3. 主场景接线：main.gd 读地图尺寸 / display_scale / 标记
## 运行：godot --headless --path C:\游戏 --script tests\map\test_godot_map_pipeline.gd

## 用 preload 而不是全局类名：类名缓存要开过编辑器才刷新，测试必须能独立跑。
const MapSceneScript := preload("res://core/world/map_scene.gd")
const MapPalette := preload("res://maps/godot/tools/map_palette.gd")

# ---- 当前规格 48px 黑暗奇幻 ----
const DARK_TILESET_PATH := "res://maps/godot/tilesets/dark48.tres"
const DARK_SPEC_PATH := "res://maps/godot/tilesets/dark48.spec.json"
const DARK_INVENTORY_PATH := "res://maps/godot/tilesets/dark48_图块清单.md"
const DARK_TEMPLATE_PATH := "res://maps/godot/scenes/dark48_map_template.tscn"
const DARK_DEMO_PATH := "res://maps/godot/scenes/abbey_outskirts.tscn"
const DARK_PREVIEW_PATH := "res://maps/godot/scenes/abbey_outskirts_preview.png"
const DARK_TILE_SIZE := 48
const DARK_SIZE := Vector2i(26, 15)          # 1280×720 视口下 1:1 一屏
const DARK_SPAWN_CELL := Vector2i(11, 13)
const DARK_PREVIEW_SCALE := 2
## 材质配比标定表（美术线）：草 60 / 枯草 15 / 泥土 12 / 碎石 6 / 石砖路 7
const DARK_RATIO_TARGET := {"grass": 0.60, "grass_dry": 0.15, "dirt": 0.12, "dirt_rocky": 0.06, "road_stone": 0.07}
## 画面级氛围（美术线规范 75/20/5，容差 ±6%，测试放宽一档）
const DARK_MIN_DARK_PERCENT := 65.0
const DARK_MAX_DARK_PERCENT := 88.0

const MAIN_SCRIPT := "res://core/world/main.gd"

var _passed := 0
var _failed := 0
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_test_runtime_api()
	_test_main_integration()
	_test_dark48_tileset()
	_test_dark48_scenes()
	_test_dark48_autotile()
	_test_dark48_preview()
	print("RESULT: passed=%d failed=%d" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
	return true


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("PASS  ", label)
	else:
		_failed += 1
		print("FAIL  ", label)


func _test_runtime_api() -> void:
	var demo := _instantiate(DARK_DEMO_PATH)
	if demo == null:
		_check(false, "运行时接口测试需要示例地图")
		return
	var rect: Rect2 = demo.get_map_rect()
	_check(rect.position == Vector2.ZERO, "地图矩形原点在地图左上角")
	_check(rect.size == Vector2(DARK_SIZE * DARK_TILE_SIZE), "48px 地图矩形 %s px" % str(rect.size))
	_check(demo.local_to_cell(Vector2(95, 95)) == Vector2i(1, 1), "像素 → 格换算正确")
	_check(demo.cell_to_local(Vector2i(1, 1)) == Vector2(72, 72), "格 → 像素（格中心）换算正确")
	_check(demo.get_marker_position("no_such_marker") == Vector2.INF, "不存在的标记返回 Vector2.INF")
	demo.free()


## main.gd 的地图接线：地图场景提供尺寸、倍率与关键标记。
func _test_main_integration() -> void:
	var main_script := load(MAIN_SCRIPT) as GDScript
	_check(main_script != null, "main.gd 可加载")
	if main_script == null:
		return
	var main: Node2D = main_script.new()
	var dark := _instantiate(DARK_DEMO_PATH)
	main.call("_apply_map_metadata", dark)
	var dark_rect := Rect2(Vector2(16, 0), Vector2(DARK_SIZE * DARK_TILE_SIZE))
	_check(main.get("_map_rect") == dark_rect, "48px 地图：1:1 居中矩形 = %s" % str(dark_rect))
	_check(main.get("_map_scale") == Vector2(1, 1), "48px 地图：显示倍率 1.0（像素 1:1）")
	_check(main.get("_spawn_position") == dark.cell_to_local(DARK_SPAWN_CELL) + Vector2(16, 0), "48px 地图：出生点取自地图标记")
	dark.free()
	main.free()


# ---------------------------------------------------------------- 当前规格：48px 黑暗奇幻

func _test_dark48_tileset() -> void:
	_check(FileAccess.file_exists(DARK_SPEC_PATH), "48px 图块 spec 存在")
	_check(FileAccess.file_exists(DARK_INVENTORY_PATH), "48px 图块清单 md 已生成")
	_check(FileAccess.file_exists(DARK_TEMPLATE_PATH), "48px 空白模板场景已生成")
	_check(FileAccess.file_exists(DARK_DEMO_PATH), "48px 示例地图场景已生成")

	var tile_set := load(DARK_TILESET_PATH) as TileSet
	_check(tile_set != null, "48px TileSet 可加载：%s" % DARK_TILESET_PATH)
	if tile_set == null:
		return
	_check(tile_set.tile_size == Vector2i(DARK_TILE_SIZE, DARK_TILE_SIZE), "48px 图块尺寸 48x48（1 格 = 1 米）")
	_check(tile_set.get_source_count() == 7, "48px 图块来源 7 个（地面 / 4 组自动拼接 / 单格道具 / 双格道具），实为 %d" % tile_set.get_source_count())

	var total_tiles := 0
	var sizes := {}
	for i in tile_set.get_source_count():
		var source := tile_set.get_source(tile_set.get_source_id(i)) as TileSetAtlasSource
		if source == null:
			continue
		total_tiles += source.get_tiles_count()
		sizes[source.texture_region_size] = int(sizes.get(source.texture_region_size, 0)) + source.get_tiles_count()
		_check(source.texture != null and String(source.texture.resource_path).begins_with("res://maps/godot/tilesets/atlas/"), "图块来源贴图在管线图集目录（第 %d 个）" % i)
	_check(total_tiles == 141, "48px 图块总数 %d（5 地面 + 128 自动拼接 + 4 补丁填充 + 2 单格道具 + 2 双格道具 = 141）" % total_tiles)

	# 双格道具（大树/立石）用 Godot 的大图块：2×2 网格单元
	var props_source := tile_set.get_source(tile_set.get_source_id(tile_set.get_source_count() - 1)) as TileSetAtlasSource
	_check(props_source != null and props_source.texture_region_size == Vector2i(48, 48), "双格道具来源按 48×48 网格切块")
	if props_source != null and props_source.get_tiles_count() > 0:
		var big_cell := props_source.get_tile_id(0)
		_check(props_source.get_tile_size_in_atlas(big_cell) == Vector2i(2, 2), "大树/立石占 2×2 格（%s，%d×%d 格）" % [
			str(big_cell), props_source.get_tile_size_in_atlas(big_cell).x, props_source.get_tile_size_in_atlas(big_cell).y])

	# 地形集：4 组材质对，模式 = 四边匹配
	_check(tile_set.get_terrain_sets_count() == 4, "地形集 4 个（4 组材质对），实为 %d" % tile_set.get_terrain_sets_count())
	if tile_set.get_terrain_sets_count() >= 4:
		_check(tile_set.get_terrain_set_mode(0) == TileSet.TERRAIN_MODE_MATCH_SIDES, "地形集模式 = 四边匹配（对应 16 配置）")
		_check(tile_set.get_terrains_count(0) == 2, "地形集 0 有 2 个地形（底材 + 补丁）")
		_check(tile_set.get_terrain_name(0, 0) == "草地" and tile_set.get_terrain_name(0, 1) == "泥土", "地形集 0 = 草地/泥土（泥土压草地）")
		var set_names := PackedStringArray()
		for i in tile_set.get_terrain_sets_count():
			set_names.append("%s(%s/%s)" % [tile_set.get_terrain_name(i, 0), tile_set.get_terrain_name(i, 0), tile_set.get_terrain_name(i, 1)])
		_check("草地" in set_names[0] and "泥土" in set_names[2], "地形集命名与材质对一致（%s）" % ", ".join(set_names))

	# 管线元数据（制图工具读的就是它）
	var palette = MapPalette.new()
	_check(palette.setup(tile_set), "TileSet 带 pipeline 元数据（材料/自动拼接映射）")
	for material in ["grass", "grass_dry", "dirt", "dirt_rocky", "road_stone", "dead_tree", "rock", "big_tree", "boulder"]:
		_check(palette.has_material(material), "元数据含材料/道具「%s」" % material)
	_check(palette.autotiles.size() == 4, "元数据含 4 组自动拼接集")
	if palette.autotiles.size() == 4:
		var pair: Dictionary = palette.autotiles[0]
		_check(String(pair["base_tag"]) == "grass" and String(pair["patch_tag"]) == "dirt", "自动拼接集 0 = 泥土压草地")
		_check((pair["tiles"] as Dictionary).size() == 16, "自动拼接集 0 覆盖 16 种四邻配置")
		_check((pair["tiles"] as Dictionary).get("0", []).size() == 2, "每种配置 2 个变体")
	var inventory := _read_text(DARK_INVENTORY_PATH)
	_check(inventory.contains("自动拼接") and inventory.contains("edge_dirt_over_grass"), "48px 清单含自动拼接条目与 tag")


func _test_dark48_scenes() -> void:
	var template := _instantiate(DARK_TEMPLATE_PATH)
	_check(template != null, "48px 模板场景可实例化")
	if template != null:
		_check(template.get_map_size_cells() == DARK_SIZE, "48px 模板尺寸 %s（一屏 26×15 = 1248×720）" % str(DARK_SIZE))
		_check(template.get_map_rect().size == Vector2(1248, 720), "48px 模板像素矩形 %s" % str(template.get_map_rect().size))
		_check(is_equal_approx(float(template.get("display_scale")), 1.0), "48px 模板显示倍率 1.0（1:1）")
		_check(template.validate().is_empty(), "48px 模板结构自检通过")
		template.free()

	var demo := _instantiate(DARK_DEMO_PATH)
	_check(demo != null, "48px 示例地图可实例化")
	if demo == null:
		return
	_check(demo.validate().is_empty(), "48px 示例地图结构自检通过")
	_check(demo.validate_spawn_walkable().is_empty(), "48px 示例地图出生点可通行")
	var terrain := demo.get_layer(MapSceneScript.LAYER_TERRAIN)
	_check(terrain.get_used_cells().size() == DARK_SIZE.x * DARK_SIZE.y, "48px 地形层铺满 %d 格" % (DARK_SIZE.x * DARK_SIZE.y))
	_check(demo.local_to_cell(demo.get_spawn_position()) == DARK_SPAWN_CELL, "48px spawn 标记 = 格 %s" % str(DARK_SPAWN_CELL))
	_check(demo.is_cell_walkable(DARK_SPAWN_CELL), "48px 出生点格可通行")
	_check(demo.is_cell_walkable(Vector2i(11, 8)), "石砖路可通行")
	_check(demo.is_cell_walkable(Vector2i(12, 4)), "石砖小广场可通行（skill_light 所在）")
	var vegetation := demo.get_layer(MapSceneScript.LAYER_VEGETATION)
	_check(not vegetation.get_used_cells().is_empty(), "植被层画了道具（枯树/大树）")
	_check(not demo.is_cell_walkable(Vector2i(3, 3)), "枯树所在格不可通行（solid）")
	_check(not demo.is_cell_walkable(Vector2i(0, 5)) and not demo.is_cell_walkable(Vector2i(1, 6)), "2×2 大树的两格都不可通行")
	_check(not demo.is_cell_walkable(Vector2i(-1, 5)), "地图外不可通行")
	demo.free()


## 自动拼接：材质配比、边缘块掩码、地形集 peering bit、幂等性
func _test_dark48_autotile() -> void:
	var tile_set := load(DARK_TILESET_PATH) as TileSet
	var palette = MapPalette.new()
	if tile_set == null or not palette.setup(tile_set):
		_check(false, "自动拼接测试需要 48px TileSet 与元数据")
		return
	var demo := _instantiate(DARK_DEMO_PATH)
	if demo == null:
		_check(false, "自动拼接测试需要示例地图")
		return
	var terrain := demo.get_layer(MapSceneScript.LAYER_TERRAIN)

	# 1) 材质配比：与美术线标定表（草60/枯15/土12/碎6/砖路7）逐项比对，容差 ±8%
	var counts: Dictionary = palette.count_materials(terrain)
	var total := DARK_SIZE.x * DARK_SIZE.y
	for tag in DARK_RATIO_TARGET:
		var actual := float(counts.get(tag, 0)) / float(total)
		var target := float(DARK_RATIO_TARGET[tag])
		_check(absf(actual - target) <= 0.08, "材质配比 %s = %.1f%%（目标 %.0f%%，容差 8%%）" % [tag, actual * 100.0, target * 100.0])

	# 2) 边界格：路西侧的泥土格应当出现「东侧是补丁」的路边块
	var road_palette_pair := {}
	for pair in palette.autotiles:
		if String(pair["pair"]) == "road_over_dirt":
			road_palette_pair = pair
	_check(not road_palette_pair.is_empty(), "元数据里有 road_over_dirt 材质对")
	if not road_palette_pair.is_empty():
		var boundary := Vector2i(10, 8)   # 泥土（西侧带），东邻 (11,8) 是石砖路
		_check(palette.material_of_cell(terrain, boundary) == "dirt", "边界格 (10,8) 的材质是泥土")
		var tag := palette.tag_of_cell(terrain, boundary)
		_check(tag.begins_with("edge_road_over_dirt_"), "边界格 (10,8) 用了路边块（tag=%s）" % tag)
		var tile_data := terrain.get_cell_tile_data(boundary)
		_check(tile_data != null, "边界块有 TileData")
		if tile_data != null:
			var set_index := tile_data.terrain_set
			var base_id := tile_data.terrain
			var patch_id := _terrain_id(tile_set, set_index, "石砖路")
			_check(patch_id >= 0, "地形集 %d 里有「石砖路」地形" % set_index)
			_check(tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE) == patch_id, "东侧 peering bit = 补丁地形（石砖路）→ 掩码方向正确")
			_check(tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE) == base_id, "西侧 peering bit = 底材地形（泥土）")
			_check(tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE) == base_id and tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE) == base_id, "南北两侧 peering bit = 底材（这两侧没有路）")

	# 3) 平铺格：远离边界的草地格应当是平铺块（tag 直接是材质）
	var inner := Vector2i(2, 8)
	_check(palette.material_of_cell(terrain, inner) == "grass", "内部格 (2,8) 材质是草地")
	_check(palette.tag_of_cell(terrain, inner) == "grass", "内部草地格用平铺块（tag=grass）")

	# 4) 幂等：再跑一次不应改动任何格
	var report: Dictionary = palette.apply_autotile(terrain)
	_check(int(report["changed"]) == 0, "自动拼接幂等（重跑改动 %d 格）" % int(report["changed"]))
	_check((report["conflicts"] as PackedStringArray).is_empty(), "示例地图无材质冲突%s" % _issue_text(report["conflicts"]))
	demo.free()


## 预览图：尺寸、确实画了东西、画面级氛围 75/20/5
func _test_dark48_preview() -> void:
	_check(FileAccess.file_exists(DARK_PREVIEW_PATH), "48px 示例地图预览图已生成")
	var image := Image.load_from_file(ProjectSettings.globalize_path(DARK_PREVIEW_PATH))
	if image == null:
		_check(false, "48px 预览图可读")
		return
	var expected := DARK_SIZE * DARK_TILE_SIZE * DARK_PREVIEW_SCALE
	_check(Vector2i(image.get_width(), image.get_height()) == expected, "48px 预览图尺寸 %s" % str(expected))

	var dark := 0
	var light := 0
	var accent := 0
	var samples := 0
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			var c := image.get_pixel(x, y)
			var luma := 0.299 * c.r * 255.0 + 0.587 * c.g * 255.0 + 0.114 * c.b * 255.0
			samples += 1
			if luma < 90.0:
				dark += 1
			elif luma < 185.0:
				light += 1
			else:
				accent += 1
	var dark_percent := float(dark) * 100.0 / float(maxi(1, samples))
	var accent_percent := float(accent) * 100.0 / float(maxi(1, samples))
	_check(dark_percent >= DARK_MIN_DARK_PERCENT and dark_percent <= DARK_MAX_DARK_PERCENT, "画面级深色占比 %.1f%%（规范 75%%，容差内 %.0f–%.0f%%）" % [dark_percent, DARK_MIN_DARK_PERCENT, DARK_MAX_DARK_PERCENT])
	_check(accent_percent <= 8.0, "画面级亮色占比 %.1f%%（规范 5%%，亮色必须稀有）" % accent_percent)
	_check(float(light) * 100.0 / float(maxi(1, samples)) >= 5.0, "画面级浅色占比 %.1f%%（铺装可辨认）" % (float(light) * 100.0 / float(maxi(1, samples))))


# ---------------------------------------------------------------- 工具

func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""


func _instantiate(path: String) -> MapSceneScript:
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var inst := scene.instantiate() as MapSceneScript
	if inst == null:
		return null
	root.add_child(inst)   # 进树才会跑 _ready()（碰撞层隐藏等）
	return inst


func _issue_text(issues: PackedStringArray) -> String:
	return "" if issues.is_empty() else "（%s）" % "; ".join(issues)


## 按名字找地形 id（找不到返回 -1）。
func _terrain_id(tile_set: TileSet, set_index: int, terrain_name: String) -> int:
	if set_index < 0 or set_index >= tile_set.get_terrain_sets_count():
		return -1
	for i in tile_set.get_terrains_count(set_index):
		if tile_set.get_terrain_name(set_index, i) == terrain_name:
			return i
	return -1
