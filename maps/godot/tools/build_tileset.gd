extends SceneTree

## 管线第 1 步：本地 48px 素材（单张 PNG）→ Godot TileSet 资源
##
## 用法（无参数 = 重建 tilesets/ 下全部 spec）：
##   godot --headless --path C:\游戏 --script maps/godot/tools/build_tileset.gd
##   godot --headless --path C:\游戏 --script maps/godot/tools/build_tileset.gd -- res://maps/godot/tilesets/dark48.spec.json
##
## 每个 <名>.spec.json 产出（与 spec 同目录）：
##   <名>.tres                —— TileSet（含 solid/tag 自定义数据；自动拼接集另带地形集）
##   <名>_图块清单.md          —— 语义清单：图集坐标 / 名称 / tag / 是否阻挡
##   <名>_图块对照表.html      —— 放大、带坐标的对照表（刷图时对着看）
##   atlas/<名>_<来源>.png     —— 由单张素材打包出的图集（**生成物，别手改**）
##
## spec 使用 sources[]：items 给出单张 PNG 文件，工具自动打包装进图集；
## 声明 autotile 的来源会按 16 配置自动拼接集切块，并写出 Godot 地形集（terrain set）。
##
## ⚠ 新图集 / 新素材必须先让 Godot 导入一次，否则 .tres 引用不到纹理：
##   godot --headless --path C:\游戏 --import
##   本工具检测到未导入时会明确提示，导入后再跑一次即可（幂等，可反复重跑）。
##
## schema 说明见 docs/world/map_pipeline.md；改 schema 要同步更新 tests/map/test_godot_map_pipeline.gd。

const SPEC_DIR := "res://maps/godot/tilesets"
const ATLAS_DIR := "res://maps/godot/tilesets/atlas"
const SPEC_SUFFIX := ".spec.json"
const PREVIEW_ZOOM := 3
const SOLID_KEY := "solid"
const TAG_KEY := "tag"

## 16 配置的规范顺序：掩码值 = n(1) | e(2) | s(4) | w(8)，名字按 n→e→s→w 拼字母。
const MASK_LETTERS := ["n", "e", "s", "w"]
const MASK_BITS := {"n": 1, "e": 2, "s": 4, "w": 8}

var _failed := 0
var _done := false
var _need_import := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var specs := _collect_specs()
	if specs.is_empty():
		_fail("未找到任何 spec（%s/*%s）" % [SPEC_DIR, SPEC_SUFFIX])
	for spec_path in specs:
		_build(spec_path)
	if _need_import:
		print("")
		print("需要先导入素材，再用同一条命令重跑本工具：")
		print("  C:\\1\\Godot_v4.7.1-stable_win64_console.exe --headless --path C:\\游戏 --import")
	print("RESULT: failed=%d" % _failed)
	quit(0 if _failed == 0 else 1)
	return true


func _fail(msg: String) -> void:
	_failed += 1
	print("FAIL  ", msg)


func _warn(msg: String) -> void:
	print("WARN  ", msg)


func _collect_specs() -> PackedStringArray:
	var out := PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		if arg.ends_with(SPEC_SUFFIX):
			out.append(arg if arg.begins_with("res://") else "res://" + arg.trim_prefix("/"))
	if not out.is_empty():
		return out
	var dir := DirAccess.open(SPEC_DIR)
	if dir == null:
		return out
	var names := dir.get_files()
	names.sort()
	for name in names:
		if name.ends_with(SPEC_SUFFIX):
			out.append(SPEC_DIR.path_join(name))
	return out


# ---------------------------------------------------------------- 主流程

func _build(spec_path: String) -> void:
	var spec := _read_spec(spec_path)
	if spec.is_empty():
		return
	var out_name := String(spec.get("tileset_name", spec_path.get_file().trim_suffix(SPEC_SUFFIX)))
	var out_dir := spec_path.get_base_dir()
	var declared := PackedStringArray()
	for layer_def in spec.get("custom_data", []):
		declared.append(String((layer_def as Dictionary).get("name", "")))
	for required in [SOLID_KEY, TAG_KEY]:
		if not declared.has(required):
			_fail("%s：spec.custom_data 必须声明 %s（管线约定）" % [out_name, required])
			return

	var sources: Array[Dictionary] = _normalize_sources(spec, out_name)
	if sources.is_empty():
		_fail("%s：spec 里没有任何图块来源" % out_name)
		return

	var tile_set := TileSet.new()
	tile_set.tile_size = _to_vector2i(spec.get("tile_size", [48, 48]))
	for layer_def in spec.get("custom_data", []):
		tile_set.add_custom_data_layer()
		var index := tile_set.get_custom_data_layers_count() - 1
		tile_set.set_custom_data_layer_name(index, String((layer_def as Dictionary).get("name", "")))
		tile_set.set_custom_data_layer_type(index, _custom_data_type(String((layer_def as Dictionary).get("type", "bool"))))

	# ---- 逐来源：打包图集 → 建 TileSetAtlasSource → 写自定义数据 ----
	var reports: Array[Dictionary] = []
	var terrain_sets: Dictionary = {}   # 地形集名 → 索引
	var pending_terrain: Array[Dictionary] = []   # 待绑定地形信息（瓦片建好后再写）
	for source_spec in sources:
		var texture := _prepare_texture(source_spec, out_name)
		if texture == null:
			continue
		var source := TileSetAtlasSource.new()
		source.texture = texture
		var source_tile_size := _to_vector2i(source_spec.get("tile_size", [48, 48]))
		if source_tile_size.x <= 0 or source_tile_size.y <= 0:
			source_tile_size = tile_set.tile_size
			_warn("%s：来源「%s」未声明合理的 tile_size，回退到 %s" % [out_name, String(source_spec.get("name", "")), str(source_tile_size)])
		source.texture_region_size = source_tile_size
		var tiles: Array[Dictionary] = source_spec.get("tiles", [])
		for tile in tiles:
			var cell: Vector2i = tile.get("cell", Vector2i.ZERO)
			if not source.has_tile(cell):
				source.create_tile(cell, _to_vector2i(tile.get("size", [1, 1])))
		tile_set.add_source(source)   # 必须先入 TileSet：TileData 的 tile_set 才有效（自定义数据要靠它）
		var source_id := tile_set.get_source_id(tile_set.get_source_count() - 1)
		for tile in tiles:
			var cell: Vector2i = tile.get("cell", Vector2i.ZERO)
			var tile_data := source.get_tile_data(cell, 0)
			if tile_data == null:
				_fail("%s：图块 %s 建不出来" % [out_name, str(cell)])
				continue
			tile_data.set_custom_data(SOLID_KEY, bool(tile.get("solid", false)))
			tile_data.set_custom_data(TAG_KEY, String(tile.get("tag", "")))
			if tile.has("terrain_set"):
				pending_terrain.append({
					"source": source,
					"cell": cell,
					"terrain_set": String(tile["terrain_set"]),
					"terrain": String(tile.get("terrain", "")),
					"peering": tile.get("peering", {}),
				})
		reports.append({
			"name": String(source_spec.get("name", "")),
			"source_id": source_id,
			"texture": texture.resource_path,
			"tile_size": source.texture_region_size,
			"count": source.get_tiles_count(),
			"columns": int(source_spec.get("columns", 8)),
			"tiles": tiles,
			"blank": int(source_spec.get("blank", 0)),
			"blank_ranges": source_spec.get("blank_ranges", {}),
		})

	# ---- 地形集：先建 set/terrain，再把瓦片挂上去 ----
	var terrain_errors := _apply_terrain_sets(tile_set, pending_terrain, terrain_sets)
	for err in terrain_errors:
		_fail("%s：%s" % [out_name, err])

	# ---- 管线元数据：材料 → 图块坐标、自动拼接集的掩码表（制图工具与测试的唯一事实来源）----
	tile_set.set_meta("pipeline", _pipeline_metadata(out_name, reports))

	var err := ResourceSaver.save(tile_set, out_dir.path_join(out_name + ".tres"))
	if err != OK:
		_fail("%s：TileSet 保存失败 err=%d" % [out_name, err])
		return
	_write_inventory(out_dir.path_join(out_name + "_图块清单.md"), spec, out_name, reports, terrain_sets)
	_write_contact_sheet(out_dir.path_join(out_name + "_图块对照表.html"), spec, out_name, reports)
	var total := 0
	for report in reports:
		total += int(report["count"])
	print("BUILD %s：%d 个来源 / %d 块图块 / %d 个地形集（%d 层自定义数据）" % [
		out_name, reports.size(), total, terrain_sets.size(), tile_set.get_custom_data_layers_count()])


# ---------------------------------------------------------------- spec → 内部结构

## 把 spec 归一成 sources[]：
## {name, tile_size, columns, texture(已有纹理，直接用), tiles:[{cell, tag, solid, name, terrain_set?, terrain?, peering?}]}
func _normalize_sources(spec: Dictionary, out_name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not spec.has("sources"):
		_fail("%s：spec 缺少 sources[]" % out_name)
		return out
	for entry in spec.get("sources", []):
		var source_spec: Dictionary = entry
		var name := String(source_spec.get("name", "source%d" % out.size()))
		var tile_size := _to_vector2i(source_spec.get("tile_size", [48, 48]))
		var columns := int(source_spec.get("columns", 8))
		var items: Array = source_spec.get("items", [])
		var autotile: Variant = source_spec.get("autotile", null)
		var terrain: Variant = source_spec.get("terrain", null)
		var tiles: Array[Dictionary] = []
		var file_list: Array[String] = []
		var index := 0
		if autotile != null:
			var generated := _autotile_items(autotile, terrain, tile_size, columns, index)
			for item in generated:
				tiles.append(item)
				file_list.append(String(item["file"]))
			index += generated.size()
		for extra in source_spec.get("extras", []):
			var e: Dictionary = extra
			var item := {
				"cell": Vector2i(index % columns, index / columns),
				"tag": String(e.get("tag", "")),
				"name": String(e.get("name", String(e.get("tag", "")))),
				"solid": bool(e.get("solid", false)),
				"file": String(e.get("file", "")),
				"note": String(e.get("note", "")),
				"kind": "material",
				"size": e.get("size", [1, 1]),
			}
			if terrain != null and e.has("terrain"):
				item["terrain_set"] = String((terrain as Dictionary).get("set", ""))
				item["terrain"] = String(e.get("terrain", ""))
			tiles.append(item)
			file_list.append(String(item["file"]))
			index += 1
		for entry_item in items:
			var it: Dictionary = entry_item
			var item := {
				"cell": Vector2i(index % columns, index / columns),
				"tag": String(it.get("tag", "")),
				"name": String(it.get("name", String(it.get("tag", "")))),
				"solid": bool(it.get("solid", false)),
				"file": String(it.get("file", "")),
				"note": String(it.get("note", "")),
				"kind": "material",
				"size": it.get("size", [1, 1]),
			}
			tiles.append(item)
			file_list.append(String(item["file"]))
			index += 1
		out.append({
			"name": name,
			"tile_size": tile_size,
			"columns": columns,
			"files": file_list,
			"tiles": _assign_cells(tiles, columns),
			"direct_texture": String(source_spec.get("texture", "")),
		})
	return out


## 按 items 的占用格数（size）做行式排布，写入每项的图集坐标。
## 一格 = 一个 tile_size；2×2 的道具占 2×2 格（Godot 的大图块）。
func _assign_cells(tiles: Array[Dictionary], columns: int) -> Array[Dictionary]:
	var x := 0
	var y := 0
	var row_height := 1
	for tile in tiles:
		var size := _to_vector2i(tile.get("size", [1, 1]))
		if size.x <= 0 or size.y <= 0:
			size = Vector2i(1, 1)
		if x + size.x > columns:
			x = 0
			y += row_height
			row_height = 1
		tile["cell"] = Vector2i(x, y)
		tile["size"] = [size.x, size.y]
		x += size.x
		row_height = maxi(row_height, size.y)
	return tiles


## 16 配置自动拼接集：按 `<prefix>_<掩码>_v<变体>.png` 生成 32 个图块项（掩码按 n/e/s/w 位序）。
## 图块语义：属于**底材**，掩码表示"这四侧邻格是补丁材质"（交付素材已实测：`_none` 与底材地面同图）。
func _autotile_items(autotile: Variant, terrain: Variant, tile_size: Vector2i, columns: int, start_index: int) -> Array[Dictionary]:
	var a: Dictionary = autotile
	var dir := String(a.get("dir", ""))
	var prefix := String(a.get("prefix", ""))
	var pair := String(a.get("pair", ""))
	var base_tag := String(a.get("base_tag", ""))
	var patch_tag := String(a.get("patch_tag", ""))
	var variants := int(a.get("variants", 2))
	var terrain_set := ""
	var base_terrain := ""
	var patch_terrain := ""
	if terrain != null:
		var t: Dictionary = terrain
		terrain_set = String(t.get("set", ""))
		base_terrain = String(t.get("base", ""))
		patch_terrain = String(t.get("patch", ""))
	var out: Array[Dictionary] = []
	var index := start_index
	for mask_value in 16:
		var mask := mask_name(mask_value)
		for variant in range(1, variants + 1):
			var file := "%s/%s_%s_v%d.png" % [dir, prefix, mask, variant]
			out.append({
				"cell": Vector2i(index % columns, index / columns),
				"tag": "edge_%s_%s_v%d" % [pair, mask, variant],
				"name": "自动拼接 %s：%s（v%d）" % [pair, _mask_desc(mask_value), variant],
				"solid": false,
				"file": file,
				"note": "底材=%s；掩码 %s(%d)" % [base_tag, mask, mask_value],
				"kind": "edge",
				"pair": pair,
				"mask": mask_value,
				"variant": variant,
				"variants": variants,
				"base_tag": base_tag,
				"patch_tag": patch_tag,
				"size": [1, 1],
				"terrain_set": terrain_set,
				"terrain": base_terrain,
				"peering": {"mask": mask_value, "patch_terrain": patch_terrain},
			})
			index += 1
	return out


static func mask_name(mask_value: int) -> String:
	var name := ""
	for i in MASK_LETTERS.size():
		if mask_value & int(MASK_BITS[MASK_LETTERS[i]]) != 0:
			name += MASK_LETTERS[i]
	return name if not name.is_empty() else "none"


static func mask_value(mask: String) -> int:
	var value := 0
	for i in MASK_LETTERS.size():
		if mask.contains(MASK_LETTERS[i]):
			value |= int(MASK_BITS[MASK_LETTERS[i]])
	return value


func _mask_desc(mask_value: int) -> String:
	var parts := PackedStringArray()
	var labels := {"n": "北", "e": "东", "s": "南", "w": "西"}
	for i in MASK_LETTERS.size():
		if mask_value & int(MASK_BITS[MASK_LETTERS[i]]) != 0:
			parts.append(labels[MASK_LETTERS[i]])
	return "四邻都" if parts.is_empty() else "、".join(parts)


# ---------------------------------------------------------------- 图集打包 / 纹理

## 已有纹理直接用；否则把单张 PNG 打包成图集（写入 ATLAS_DIR）并返回导入后的纹理。
func _prepare_texture(source_spec: Dictionary, out_name: String) -> Texture2D:
	var direct := String(source_spec.get("direct_texture", ""))
	if not direct.is_empty():
		var texture := load(direct) as Texture2D
		if texture == null:
			_fail("%s：纹理加载失败 %s（先跑 --import 导入素材）" % [out_name, direct])
			_need_import = true
		return texture

	var tile_size: Vector2i = source_spec.get("tile_size", Vector2i(48, 48))
	var columns: int = int(source_spec.get("columns", 8))
	var files: Array = source_spec.get("files", [])
	var tiles: Array[Dictionary] = source_spec.get("tiles", [])
	var rows := 1
	for tile in tiles:
		var cell: Vector2i = tile.get("cell", Vector2i.ZERO)
		var size := _to_vector2i(tile.get("size", [1, 1]))
		rows = maxi(rows, cell.y + maxi(1, size.y))
	var atlas_path := ATLAS_DIR.path_join("%s_%s.png" % [out_name, String(source_spec.get("name", "atlas"))])
	var sidecar_path := ATLAS_DIR.path_join("%s_%s.pack.json" % [out_name, String(source_spec.get("name", "atlas"))])

	# 素材指纹（路径 + 大小 + 修改时间）没变就复用已有图集，避免每次重跑都重写文件、触发重新导入
	var fingerprint := _fingerprint(files, tile_size, columns)
	var need_pack := true
	var previous := _read_json_file(sidecar_path)
	var existing: Image = null
	if FileAccess.file_exists(atlas_path):
		existing = _readable_image_from_file(atlas_path)
	if existing != null \
			and existing.get_width() == columns * tile_size.x \
			and existing.get_height() == rows * tile_size.y \
			and String(previous.get("fingerprint", "")) == fingerprint:
		need_pack = false
	if need_pack:
		var atlas := Image.create(columns * tile_size.x, rows * tile_size.y, false, Image.FORMAT_RGBA8)
		atlas.fill(Color(0, 0, 0, 0))
		for i in files.size():
			var img := _readable_image_from_file(String(files[i]))
			if img == null:
				_fail("%s：素材读不出 %s" % [out_name, String(files[i])])
				return null
			var size := _to_vector2i(tiles[i].get("size", [1, 1]))
			var wanted := Vector2i(maxi(1, size.x) * tile_size.x, maxi(1, size.y) * tile_size.y)
			if img.get_width() != wanted.x or img.get_height() != wanted.y:
				_fail("%s：%s 尺寸 %dx%d 应为 %dx%d（tile_size %s × size %s）" % [
					out_name, String(files[i]), img.get_width(), img.get_height(), wanted.x, wanted.y,
					str(tile_size), str(size)])
				return null
			var cell: Vector2i = tiles[i].get("cell", Vector2i.ZERO)
			atlas.blit_rect(img, Rect2i(Vector2i.ZERO, wanted), cell * tile_size)
		if DirAccess.open(ATLAS_DIR) == null:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ATLAS_DIR))
		var err := atlas.save_png(atlas_path)
		if err != OK:
			_fail("%s：图集保存失败 err=%d（%s）" % [out_name, err, atlas_path])
			return null
		_write_json_file(sidecar_path, {"fingerprint": fingerprint, "tiles": files.size(), "tile_size": [tile_size.x, tile_size.y], "columns": columns})
		print("PACK  %s（%d 块 %dx%d → %dx%d）" % [atlas_path, files.size(), tile_size.x, tile_size.y, atlas.get_width(), atlas.get_height()])
		_need_import = true

	var texture := load(atlas_path) as Texture2D
	if texture == null:
		_warn("%s：图集尚未被 Godot 导入，本次跳过该来源（%s）" % [out_name, atlas_path])
		_need_import = true
	return texture


## 素材指纹：文件路径 + 大小 + 修改时间（不需要读像素）。
func _fingerprint(files: Array, tile_size: Vector2i, columns: int) -> String:
	var parts := PackedStringArray(["%dx%d/%d" % [tile_size.x, tile_size.y, columns]])
	for file in files:
		var path := String(file)
		var size := 0
		if FileAccess.file_exists(path):
			size = int(FileAccess.open(path, FileAccess.READ).get_length())
		parts.append("%s:%d:%d" % [path, size, FileAccess.get_modified_time(path)])
	return String("|".join(parts)).md5_text()


func _read_json_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _write_json_file(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("写入失败：%s" % path)
		return
	file.store_string(JSON.stringify(data, "  "))


func _readable_image_from_file(path: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image


# ---------------------------------------------------------------- 管线元数据

## 组装写进 TileSet 的 pipeline 元数据：材料 tag → 图块坐标、自动拼接集（掩码 → 各变体图块坐标）。
## 制图工具（make_map / 自动拼接修正）与测试都读它，避免各处重复解析 tag 字符串。
func _pipeline_metadata(out_name: String, reports: Array[Dictionary]) -> Dictionary:
	var materials := {}
	var autotiles := {}
	for report in reports:
		var source_id := int(report["source_id"])
		for tile in report["tiles"]:
			var cell: Vector2i = tile.get("cell", Vector2i.ZERO)
			if String(tile.get("kind", "material")) == "edge":
				var pair := String(tile.get("pair", ""))
				if not autotiles.has(pair):
					autotiles[pair] = {
						"pair": pair,
						"base_tag": String(tile.get("base_tag", "")),
						"patch_tag": String(tile.get("patch_tag", "")),
						"terrain_set": String(tile.get("terrain_set", "")),
						"source": source_id,
						"variants": int(tile.get("variants", 2)),
						"tiles": {},
					}
				var masks: Dictionary = autotiles[pair]["tiles"]
				var mask_key := str(int(tile.get("mask", 0)))
				if not masks.has(mask_key):
					masks[mask_key] = []
				masks[mask_key].append({"variant": int(tile.get("variant", 1)), "cell": cell})
			else:
				materials[String(tile.get("tag", ""))] = {"source": source_id, "cell": cell}
	return {
		"generator": "maps/godot/tools/build_tileset.gd",
		"tileset": out_name,
		"materials": materials,
		"autotiles": autotiles.values(),
	}


# ---------------------------------------------------------------- 地形集
## 建地形集并把自动拼接图块挂上去：底材图块的四个边按掩码写 peering bit（补丁或底材），
## 补丁填充图块四个边都留空（-1 = 任意材质都算匹配）。
func _apply_terrain_sets(tile_set: TileSet, pending: Array[Dictionary], terrain_sets: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if pending.is_empty():
		return errors
	var terrain_ids: Dictionary = {}   # "地形集|地形名" → id
	var set_indices: Dictionary = {}   # 地形集名 → 索引
	for item in pending:
		var set_name: String = item["terrain_set"]
		if set_name.is_empty():
			continue
		if not set_indices.has(set_name):
			tile_set.add_terrain_set()
			var set_index := tile_set.get_terrain_sets_count() - 1
			tile_set.set_terrain_set_mode(set_index, TileSet.TERRAIN_MODE_MATCH_SIDES)
			set_indices[set_name] = set_index
			terrain_sets[set_name] = set_index
		var set_index: int = set_indices[set_name]
		for terrain_name in [String(item["terrain"]), String((item.get("peering", {}) as Dictionary).get("patch_terrain", ""))]:
			var key := "%s|%s" % [set_name, terrain_name]
			if terrain_name.is_empty() or terrain_ids.has(key):
				continue
			tile_set.add_terrain(set_index)
			var terrain_id := tile_set.get_terrains_count(set_index) - 1
			tile_set.set_terrain_name(set_index, terrain_id, terrain_name)
			tile_set.set_terrain_color(set_index, terrain_id, _terrain_color(terrain_name))
			terrain_ids[key] = terrain_id

	for item in pending:
		var set_name: String = item["terrain_set"]
		if set_name.is_empty() or not set_indices.has(set_name):
			continue
		var set_index: int = set_indices[set_name]
		var source: TileSetAtlasSource = item["source"]
		var cell: Vector2i = item["cell"]
		if not source.has_tile(cell):
			errors.append("地形集 %s：图块 %s 不存在" % [set_name, str(cell)])
			continue
		var tile_data := source.get_tile_data(cell, 0)
		var base_key := "%s|%s" % [set_name, String(item["terrain"])]
		if not terrain_ids.has(base_key):
			errors.append("地形集 %s：底材地形「%s」未登记" % [set_name, String(item["terrain"])])
			continue
		tile_data.terrain_set = set_index
		tile_data.terrain = int(terrain_ids[base_key])
		var peering: Dictionary = item.get("peering", {})
		if peering.has("mask"):
			var patch_key := "%s|%s" % [set_name, String(peering.get("patch_terrain", ""))]
			if not terrain_ids.has(patch_key):
				errors.append("地形集 %s：补丁地形「%s」未登记" % [set_name, String(peering.get("patch_terrain", ""))])
				continue
			var patch_id := int(terrain_ids[patch_key])
			for letter in MASK_LETTERS:
				var bit := _peering_bit(letter)
				var is_patch := int(peering["mask"]) & int(MASK_BITS[letter]) != 0
				tile_data.set_terrain_peering_bit(bit, patch_id if is_patch else int(terrain_ids[base_key]))
		else:
			# 补丁填充图块（纯补丁材质）：四边都不设要求（-1 = 任意材质都算匹配）
			for letter in MASK_LETTERS:
				tile_data.set_terrain_peering_bit(_peering_bit(letter), -1)
	return errors


func _peering_bit(letter: String) -> int:
	match letter:
		"n":
			return TileSet.CELL_NEIGHBOR_TOP_SIDE
		"e":
			return TileSet.CELL_NEIGHBOR_RIGHT_SIDE
		"s":
			return TileSet.CELL_NEIGHBOR_BOTTOM_SIDE
		_:
			return TileSet.CELL_NEIGHBOR_LEFT_SIDE


func _terrain_color(terrain_name: String) -> Color:
	var palette := {
		"草地": Color(0.29, 0.35, 0.20),
		"枯草": Color(0.55, 0.48, 0.22),
		"泥土": Color(0.42, 0.26, 0.16),
		"碎石": Color(0.44, 0.44, 0.42),
		"石砖路": Color(0.55, 0.56, 0.58),
	}
	return palette.get(terrain_name, Color(0.5, 0.5, 0.5, 0.35))


# ---------------------------------------------------------------- 输出：清单 / 对照表

func _write_inventory(path: String, spec: Dictionary, out_name: String, reports: Array[Dictionary], terrain_sets: Dictionary) -> void:
	var lines := PackedStringArray()
	lines.append("# 图块清单：%s" % String(spec.get("display_name", out_name)))
	lines.append("")
	lines.append("- 生成源：`maps/godot/tools/build_tileset.gd` + `%s%s`（**手改本文件无效：改 spec 后重跑工具**）" % [out_name, SPEC_SUFFIX])
	lines.append("- 图集（生成物）：`%s/%s_<来源>.png`" % [ATLAS_DIR, out_name])
	lines.append("- 坐标 = 图集第 (col,row) 格；Godot 的 TileSet 面板按同一坐标选块（对照表 html 看得更直观）。")
	lines.append("- 每块图块的 `tag`（语义）与 `solid`（是否阻挡）存在 TileSet 自定义数据里。")
	if not terrain_sets.is_empty():
		lines.append("- 地形集（Godot terrain set，模式 = 四边匹配）：%s —— 用 TileMap 面板的「地形」模式刷图会自动选对边缘块。" % ", ".join(terrain_sets.keys()))
	lines.append("")
	for report in reports:
		lines.append("## %s（%s，%d 块）" % [String(report["name"]), String(report["texture"]), int(report["count"])])
		lines.append("")
		lines.append("| 坐标 (col,row) | 名称 | tag | 阻挡 | 备注 |")
		lines.append("| --- | --- | --- | --- | --- |")
		for tile in report["tiles"]:
			var cell: Vector2i = tile["cell"]
			lines.append("| (%d,%d) | %s | `%s` | %s | %s |" % [
				cell.x, cell.y, String(tile.get("name", "")), String(tile.get("tag", "")),
				"是" if tile.get("solid", false) else "否", String(tile.get("note", ""))])
		lines.append("")
		var blank_ranges: Dictionary = report.get("blank_ranges", {})
		if not blank_ranges.is_empty():
			lines.append("**空白格（可追加新图块）**：贴图里还没有像素的格子 —— 新图块请追加在这里，不要改动已占用格子的坐标")
			lines.append("")
			for row in blank_ranges.keys():
				lines.append("- 行 %s：列 %s" % [row, String(blank_ranges[row])])
			lines.append("")
	lines.append("## 追加新图块 / 新素材")
	lines.append("")
	lines.append("1. 新素材按 `docs/art/style_guide.md` 的规格生产（尺寸、色板、视角、命名），放进 `assets/`。")
	lines.append("2. 在 `%s%s` 里追加条目（单张 PNG 会自动打包进图集）。" % [out_name, SPEC_SUFFIX])
	lines.append("3. 重跑本工具（新素材要先 `--import` 导入一次）。")
	lines.append("4. 缺什么素材按 `docs/art/asset_request.md` 提需求。")
	lines.append("")
	_write_text(path, lines)


func _write_contact_sheet(path: String, spec: Dictionary, out_name: String, reports: Array[Dictionary]) -> void:
	var html := PackedStringArray()
	html.append("<!doctype html><html lang=\"zh-CN\"><head><meta charset=\"utf-8\">")
	html.append("<title>图块对照表 %s</title>" % out_name)
	html.append("<style>")
	html.append("body{background:#0b0c10;color:#dfe3ec;font:12px/1.6 'Segoe UI',system-ui,sans-serif;margin:16px}")
	html.append("h1{font-size:16px;margin:0 0 4px}h2{font-size:13px;margin:20px 0 6px;color:#c9d2e0}p{margin:0 0 12px;color:#98a0b2}")
	html.append(".row{display:flex;flex-wrap:wrap;gap:2px;max-width:1400px}")
	html.append(".t{position:relative;border:1px solid #2b2f3a;background-color:#14161c;image-rendering:pixelated}")
	html.append(".t span{position:absolute;left:2px;top:1px;color:#ffd479;text-shadow:0 0 3px #000,0 0 3px #000;font-size:10px}")
	html.append(".t i{position:absolute;left:2px;bottom:1px;right:2px;color:#9fe6a0;text-shadow:0 0 3px #000,0 0 3px #000;font-size:9px;font-style:normal;overflow:hidden;white-space:nowrap}")
	html.append(".solid{border-color:#e05555}.solid i{color:#ff9c9c}")
	html.append("</style></head><body>")
	html.append("<h1>%s —— %s</h1>" % [out_name, String(spec.get("display_name", ""))])
	html.append("<p>每块左上角 = 图集坐标 (col,row)，与 Godot 的 TileSet 面板一致。绿字 = tag，红框 = solid（阻挡）。放大 %d 倍显示。</p>" % PREVIEW_ZOOM)
	for report in reports:
		var tile_size: Vector2i = report["tile_size"]
		var columns: int = int(report["columns"])
		var rel := _relative_url(path.get_base_dir(), String(report["texture"]))
		var w := tile_size.x * PREVIEW_ZOOM
		var h := tile_size.y * PREVIEW_ZOOM
		html.append("<h2>%s（%s）</h2>" % [String(report["name"]), String(report["texture"])])
		html.append("<div class=\"row\">")
		for tile in report["tiles"]:
			var cell: Vector2i = tile["cell"]
			var cls := "t"
			if bool(tile.get("solid", false)):
				cls += " solid"
			html.append("<div class=\"%s\" style=\"width:%dpx;height:%dpx;background-image:url('%s');background-repeat:no-repeat;background-position:-%dpx -%dpx;background-size:%dpx %dpx\" title=\"(%d,%d) %s\"><span>%d,%d</span><i>%s</i></div>" % [
				cls, w, h, rel, cell.x * w, cell.y * h,
				columns * w, int(ceil(float(report["tiles"].size()) / float(columns))) * h,
				cell.x, cell.y, String(tile.get("name", "")), cell.x, cell.y, String(tile.get("tag", ""))])
		html.append("</div>")
	html.append("</body></html>")
	_write_text(path, html)


## HTML 里引用图集要用相对路径（HTML 与图集不同目录）。
func _relative_url(from_dir: String, to_path: String) -> String:
	var from := from_dir.trim_prefix("res://").split("/")
	var to := to_path.trim_prefix("res://").split("/")
	var common := 0
	while common < from.size() and common < to.size() - 1 and from[common] == to[common]:
		common += 1
	var parts := PackedStringArray()
	for i in range(common, from.size()):
		parts.append("..")
	for i in range(common, to.size()):
		parts.append(to[i])
	return "/".join(parts)


func _write_text(path: String, lines: PackedStringArray) -> void:
	if DirAccess.open(path.get_base_dir()) == null:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("写入失败：%s" % path)
		return
	file.store_string("\n".join(lines) + "\n")
	print("WROTE ", path)


func _custom_data_type(type_name: String) -> int:
	match type_name:
		"int":
			return TYPE_INT
		"float":
			return TYPE_FLOAT
		"string":
			return TYPE_STRING
		_:
			return TYPE_BOOL


func _to_vector2i(value: Variant) -> Vector2i:
	if typeof(value) == TYPE_VECTOR2I:
		return value
	if typeof(value) == TYPE_VECTOR2:
		return Vector2i(value)
	if typeof(value) == TYPE_ARRAY and (value as Array).size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO


func _read_spec(spec_path: String) -> Dictionary:
	var file := FileAccess.open(spec_path, FileAccess.READ)
	if file == null:
		_fail("spec 打不开：%s" % spec_path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("spec 不是合法 JSON 对象：%s" % spec_path)
		return {}
	return parsed
