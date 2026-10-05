extends RefCounted

## 制图调色板：读 TileSet 里的 `pipeline` 元数据，把「材质」变成可刷的图块，并做 16 配置自动拼接。
##
## 元数据由 maps/godot/tools/build_tileset.gd 写进 .tres（`tile_set.get_meta("pipeline")`），
## 所以制图工具、修正工具、测试都从同一处取事实，不需要各自解析 tag 字符串。
##
## 用法：
##   const MapPalette := preload("res://maps/godot/tools/map_palette.gd")
##   var palette := MapPalette.new()
##   palette.setup(tile_set)
##   palette.set_material(terrain_layer, Vector2i(3, 4), "grass")   # 铺材质
##   palette.apply_autotile(terrain_layer)                          # 按四邻重算边缘块
##
## 自动拼接语义（与交付素材一致）：`edge_<补丁>_over_<底材>_<四邻掩码>_v<变体>`
## 属于**底材**，掩码表示"这四侧邻格是补丁材质"；补丁格用普通材质块平铺。

const SOLID_KEY := "solid"
const TAG_KEY := "tag"
const MASK_LETTERS := ["n", "e", "s", "w"]
const MASK_BITS := {"n": 1, "e": 2, "s": 4, "w": 8}
## 四邻偏移（n=北即 y-1）
const NEIGHBOR_OFFSETS := {"n": Vector2i(0, -1), "e": Vector2i(1, 0), "s": Vector2i(0, 1), "w": Vector2i(-1, 0)}

var tile_set: TileSet
## tag → {source, cell}：所有非边缘图块（地面材质 + 道具）
var tiles: Dictionary = {}
## 自动拼接集：[{pair, base_tag, patch_tag, terrain_set, source, variants, tiles:{掩码字符串: [{variant, cell}]}}]
var autotiles: Array = []
## edge tag → base_tag（把已画的边缘块反查回材质）
var _edge_base_tags: Dictionary = {}


func setup(source_tile_set: TileSet) -> bool:
	tile_set = source_tile_set
	if tile_set == null:
		return false
	var meta: Dictionary = tile_set.get_meta("pipeline", {})
	tiles = meta.get("materials", {})
	autotiles = meta.get("autotiles", [])
	_edge_base_tags.clear()
	for pair in autotiles:
		for mask_key in (pair.get("tiles", {}) as Dictionary):
			for variant in pair["tiles"][mask_key]:
				_edge_base_tags[_edge_tag(pair["pair"], int(mask_key), int(variant["variant"]))] = String(pair["base_tag"])
	return not tiles.is_empty()


func has_material(tag: String) -> bool:
	return tiles.has(tag)


## 铺一格材质（用该材质的平铺块；边缘块由 apply_autotile 之后决定）。
func set_material(layer: TileMapLayer, cell: Vector2i, tag: String) -> bool:
	if layer == null or not tiles.has(tag):
		return false
	var entry: Dictionary = tiles[tag]
	layer.set_cell(cell, int(entry["source"]), entry["cell"], 0)
	return true


## 读一格的 tag（无图块返回空串）。
func tag_of_cell(layer: TileMapLayer, cell: Vector2i) -> String:
	if layer == null or layer.get_cell_tile_data(cell) == null:
		return ""
	return String(layer.get_cell_tile_data(cell).get_custom_data(TAG_KEY))


## 读一格的材质：平铺块返回自身 tag；边缘块返回它所属的底材 tag。
func material_of_cell(layer: TileMapLayer, cell: Vector2i) -> String:
	var tag := tag_of_cell(layer, cell)
	if tag.is_empty():
		return ""
	if tiles.has(tag):
		return tag
	return String(_edge_base_tags.get(tag, ""))


## 材质统计（用于核对铺图配比：草 60 / 枯 15 / 土 12 / 碎 6 / 砖路 7）。
func count_materials(layer: TileMapLayer) -> Dictionary:
	var counts := {}
	for cell in layer.get_used_cells():
		var material := material_of_cell(layer, cell)
		if material.is_empty():
			continue
		counts[material] = int(counts.get(material, 0)) + 1
	return counts


## 按四邻重算「地形」层的边缘块（幂等，可反复跑）。
## 返回 {"changed": 改写格数, "conflicts": [材质冲突说明], "counts": 材质→格数}。
func apply_autotile(layer: TileMapLayer) -> Dictionary:
	var result := {"changed": 0, "conflicts": [], "counts": {}}
	if layer == null or autotiles.is_empty():
		return result
	var materials := {}
	for cell in layer.get_used_cells():
		var material := material_of_cell(layer, cell)
		if not material.is_empty():
			materials[cell] = material
	if materials.is_empty():
		return result

	var changed := 0
	var conflicts := PackedStringArray()
	for cell in materials:
		var target := _resolve_cell(cell, String(materials[cell]), materials, conflicts)
		if target.is_empty():
			continue
		var source_id := int(target["source"])
		var atlas_cell: Vector2i = target["cell"]
		if layer.get_cell_source_id(cell) == source_id and layer.get_cell_atlas_coords(cell) == atlas_cell:
			continue   # 已经是这块，跳过（便于判定幂等）
		layer.set_cell(cell, source_id, atlas_cell, 0)
		changed += 1
	var counts := {}
	for cell in materials:
		var material: String = materials[cell]
		counts[material] = int(counts.get(material, 0)) + 1
	result["changed"] = changed
	result["conflicts"] = conflicts
	result["counts"] = counts
	return result


## 单格该用哪块图块：若某「底材材质对」的补丁出现在四邻，就用对应的掩码块；否则用平铺块。
func _resolve_cell(cell: Vector2i, material: String, materials: Dictionary, conflicts: PackedStringArray) -> Dictionary:
	var matched: Array[Dictionary] = []
	for pair in autotiles:
		if String(pair["base_tag"]) != material:
			continue
		var mask := 0
		for letter in MASK_LETTERS:
			var neighbor: Vector2i = cell + NEIGHBOR_OFFSETS[letter]
			if String(materials.get(neighbor, "")) == String(pair["patch_tag"]):
				mask |= int(MASK_BITS[letter])
		if mask != 0:
			matched.append({"pair": pair, "mask": mask})
	if matched.size() > 1:
		var pairs := PackedStringArray()
		for item in matched:
			pairs.append(String(item["pair"]["pair"]))
		conflicts.append("%s 同时挨着多种补丁（%s）：只按第一种画，另一种边界会缺失" % [str(cell), ", ".join(pairs)])
	if matched.is_empty():
		return tiles.get(material, {})
	var chosen: Dictionary = matched[0]
	var variants: Array = (chosen["pair"]["tiles"] as Dictionary).get(str(int(chosen["mask"])), [])
	if variants.is_empty():
		return tiles.get(material, {})
	var variant: Dictionary = variants[_variant_index(cell, variants.size())]
	return {"source": int(chosen["pair"]["source"]), "cell": variant["cell"]}


## 变体挑选：按格坐标散开（确定性、无可见条纹），让重复感被打散。
func _variant_index(cell: Vector2i, variants: int) -> int:
	if variants <= 1:
		return 0
	var hash_value := absi(cell.x * 73856093 + cell.y * 19349663)
	return hash_value % variants


func _edge_tag(pair: String, mask: int, variant: int) -> String:
	return "edge_%s_%s_v%d" % [pair, mask_name(mask), variant]


static func mask_name(mask: int) -> String:
	var name := ""
	for letter in MASK_LETTERS:
		if mask & int(MASK_BITS[letter]) != 0:
			name += letter
	return name if not name.is_empty() else "none"
