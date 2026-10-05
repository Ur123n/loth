extends SceneTree

## 管线附件：把地图场景合成成 PNG 预览（不看编辑器也能过目一眼）
##
## 用法：
##   godot --headless --path C:\游戏 --script maps/godot/tools/preview_map.gd
##       → 生成 maps/godot/scenes/abbey_outskirts_preview.png（48px 示例地图）
##   godot --headless --path C:\游戏 --script maps/godot/tools/preview_map.gd -- res://maps/godot/scenes/<地图>.tscn
##       → 可加 --scale 2 指定放大倍数（默认 4），--out res://…png 指定输出
##
## 说明：按「地形 → 高差 → 建筑 → 装饰 → 植被」顺序自下而上叠加（碰撞层不画，它本来就不显示）；
## 透明像素按 alpha 混合，背景填深色以便看清留白。
## **大型建筑**（「建筑对象」容器下的 Building 节点）按同样自下而上的顺序叠在图块层之上，
## 屋顶层（z_index 更高）也一并画出；地图里没有建筑时这条路径不参与，输出与接入前一致。

const SCENE_DIR := "res://maps/godot/scenes"
const DEFAULT_SCENE := "res://maps/godot/scenes/abbey_outskirts.tscn"
const DEFAULT_SCALE := 4
const BACKDROP := Color(0.10, 0.12, 0.16)
## 预览不画的层（顺序同时也是绘制顺序）
const PREVIEW_LAYERS: Array[String] = ["地形", "高差", "建筑", "装饰", "植被"]
const BUILDING_ROOT := "建筑对象"

var _failed := 0
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var args := _parse_args()
	var scene_path := String(args.get("scene", DEFAULT_SCENE))
	var scale := maxi(1, int(args.get("scale", DEFAULT_SCALE)))
	var out_path := String(args.get("out", scene_path.get_basename() + "_preview.png"))
	_render(scene_path, out_path, scale)
	print("RESULT: failed=%d" % _failed)
	quit(0 if _failed == 0 else 1)
	return true


func _fail(msg: String) -> void:
	_failed += 1
	print("FAIL  ", msg)


func _parse_args() -> Dictionary:
	var out := {}
	var argv := OS.get_cmdline_user_args()
	var positional := 0
	var i := 0
	while i < argv.size():
		var arg := argv[i]
		if arg.begins_with("--") and i + 1 < argv.size():
			out[arg.trim_prefix("--")] = argv[i + 1]
			i += 2
			continue
		if not arg.begins_with("--"):
			out["scene" if positional == 0 else "extra%d" % positional] = arg
			positional += 1
		i += 1
	return out


func _render(scene_path: String, out_path: String, scale: int) -> void:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_fail("场景加载失败：%s" % scene_path)
		return
	var map := packed.instantiate()
	var layers: Array[TileMapLayer] = []
	var tile_size := Vector2i.ZERO
	var cells := Rect2i()
	for layer_name in PREVIEW_LAYERS:
		var layer := _find_layer(map, layer_name)
		if layer == null or layer.tile_set == null:
			_fail("地图缺少图块层「%s」" % layer_name)
			map.free()
			return
		layers.append(layer)
		tile_size = layer.tile_set.tile_size
		var used := layer.get_used_rect()
		cells = used if cells.size == Vector2i.ZERO else cells.merge(used)
	# 大型建筑也要算进画布范围（建筑可以比铺过的图块范围伸得更远）
	var buildings := _find_buildings(map)
	if cells.size == Vector2i.ZERO and buildings.is_empty():
		_fail("地图没有任何图块：%s" % scene_path)
		map.free()
		return
	# 建筑节点不在场景树里时 _ready() 不跑，靠 position 反解放置格
	for candidate in buildings:
		var rect: Rect2i = candidate.call("get_map_footprint_rect")
		cells = rect if cells.size == Vector2i.ZERO else cells.merge(rect)
	if cells.size == Vector2i.ZERO:
		cells = Rect2i(Vector2i.ZERO, Vector2i(1, 1))

	var canvas := Image.create(cells.size.x * tile_size.x, cells.size.y * tile_size.y, false, Image.FORMAT_RGBA8)
	canvas.fill(BACKDROP)
	var drawn := 0
	for layer in layers:
		for cell in layer.get_used_cells():
			var atlas := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
			if atlas == null:
				continue
			var region := Rect2i(layer.get_cell_atlas_coords(cell) * tile_size, tile_size)
			var source_image := _readable_image(atlas.texture)
			if source_image == null:
				_fail("贴图不可读：%s" % atlas.texture.resource_path)
				map.free()
				return
			canvas.blend_rect(source_image, region, (cell - cells.position) * tile_size)
			drawn += 1
	# 大型建筑：按 z_index 从低到高叠（屋顶盖在地面层之上）
	var building_layers := _building_layers(map, buildings)
	for entry in building_layers:
		var sprite: Sprite2D = entry["sprite"]
		var texture := sprite.texture
		if texture == null:
			continue
		var image := _readable_image(texture)
		if image == null:
			_fail("建筑贴图不可读：%s" % texture.resource_path)
			map.free()
			return
		# 贴图左上角在地图里的局部像素位置（相对地图根节点，逐级累加父节点位置）
		var top_left_local: Vector2 = entry["top_left"]
		var origin := Vector2i((top_left_local / Vector2(tile_size)).round()) - cells.position
		var offset := origin * tile_size
		# 部分越界就只贴相交部分
		var dest := Rect2i(offset, image.get_size())
		var canvas_rect := Rect2i(Vector2i.ZERO, canvas.get_size())
		var clipped := dest.intersection(canvas_rect)
		if clipped.size.x <= 0 or clipped.size.y <= 0:
			continue
		canvas.blend_rect(image, Rect2i(clipped.position - dest.position, clipped.size), clipped.position)
		drawn += 1
	if scale > 1:
		canvas.resize(canvas.get_width() * scale, canvas.get_height() * scale, Image.INTERPOLATE_NEAREST)

	var composition := _composition(canvas)
	print("COMPOSITION dark=%.1f%% light=%.1f%% accent=%.1f%%（美术线规范目标 75/20/5）" % [
		composition["dark"], composition["light"], composition["accent"]])

	var dir := DirAccess.open(out_path.get_base_dir())
	if dir == null:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
	var err := canvas.save_png(out_path)
	if err != OK:
		_fail("预览保存失败 err=%d：%s" % [err, out_path])
	else:
		print("WROTE %s（%d×%d，格 %s，叠了 %d 个元素，放大 %d 倍）" % [
			out_path, canvas.get_width(), canvas.get_height(), str(cells.size), drawn, scale])
	map.free()


## 画面级氛围占比：深色 L<90 / 浅色 90–185 / 亮色 L≥185（美术线规范 75/20/5，±6% 容差）。
## 注意背景底色（深色）也计入深色，未铺满的地图会被算得更暗。
func _composition(image: Image) -> Dictionary:
	var dark := 0
	var light := 0
	var accent := 0
	var total := 0
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			var c := image.get_pixel(x, y)
			var luma := 0.299 * c.r * 255.0 + 0.587 * c.g * 255.0 + 0.114 * c.b * 255.0
			total += 1
			if luma < 90.0:
				dark += 1
			elif luma < 185.0:
				light += 1
			else:
				accent += 1
	var safe := maxi(1, total)
	return {
		"dark": float(dark) * 100.0 / float(safe),
		"light": float(light) * 100.0 / float(safe),
		"accent": float(accent) * 100.0 / float(safe),
	}


func _find_layer(map: Node, layer_name: String) -> TileMapLayer:
	for child in map.get_children():
		if child is TileMapLayer and child.name == layer_name:
			return child
	return null


## 「建筑对象」容器下的全部建筑（挂了 Building 脚本的节点）。
func _find_buildings(map: Node) -> Array:
	var out: Array = []
	var root := map.get_node_or_null(NodePath(BUILDING_ROOT))
	if root == null:
		return out
	for child in root.get_children():
		if child.has_method("get_building_data") and child is Node2D:
			out.append(child)
	return out


## 收集所有建筑的可见 Sprite2D，按 z_index 排序（低的下、高的上）。
## `top_left` = 该贴图左上角相对**地图根节点**的局部像素位置。
## 注意：必须逐级累加父节点位置（建筑挂在「建筑对象」容器下、贴图又在 Visual 下），
## 只取 sprite.position 会把整栋楼画到地图左上角去。
func _building_layers(map: Node, buildings: Array) -> Array:
	var entries: Array = []
	for candidate in buildings:
		var building: Node2D = candidate
		for node in building.find_children("*", "Sprite2D", true, false):
			var sprite := node as Sprite2D
			if sprite == null or not sprite.visible or sprite.texture == null:
				continue
			entries.append({
				"sprite": sprite,
				"top_left": _position_relative_to(sprite, map) - _sprite_half_size(sprite),
				"z": sprite.z_index,
				"y": _position_relative_to(building, map).y,
			})
	# 排序：先 z_index，再按建筑 Y（Y 轴排序的近似），保证屋顶压在地面层之上
	entries.sort_custom(func(a, b):
		if int(a["z"]) != int(b["z"]):
			return int(a["z"]) < int(b["z"])
		return float(a["y"]) < float(b["y"]))
	return entries


## 节点位置逐级累加到 `ancestor` 为止（= 相对 ancestor 的局部位置）。
func _position_relative_to(node: Node2D, ancestor: Node) -> Vector2:
	var total := Vector2.ZERO
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node2D:
			total += (current as Node2D).position
		current = current.get_parent()
	return total


## Sprite2D 若不居中，节点位置就是贴图左上角；居中时要减掉半个贴图。
func _sprite_half_size(sprite: Sprite2D) -> Vector2:
	if not sprite.centered or sprite.texture == null:
		return Vector2.ZERO
	return Vector2(sprite.texture.get_size()) * 0.5


func _readable_image(texture: Texture2D) -> Image:
	var image := texture.get_image()
	if image == null or image.is_empty():
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image
