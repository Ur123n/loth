extends SceneTree

## 管线附件：自动拼接修正 —— 把「地形」层上随手铺的材质，重算成正确的 16 配置边缘块
##
## 用途：在 Godot 编辑器里刷图时不必逐格挑边缘块 —— 先用任意一块材质平铺（或用地形集刷），
## 然后跑本工具，它会读每格的材质、按四邻算出掩码、把边缘块换成正确的那一张（幂等，可反复跑）。
##
## 用法：
##   godot --headless --path C:\游戏 --script maps/godot/tools/autotile_fixup.gd
##       → 修正 48px 示例地图（默认）
##   … -- res://maps/godot/scenes/<你的地图>.tscn [--layer 地形] [--check]
##       → 修正指定地图；--check 只检查不改写（用于 CI）
##
## 语义见 docs/world/map_pipeline.md 与交付素材说明：`auto_<补丁>_over_<底材>_<四邻掩码>_v<变体>`
## 属于底材，掩码 = "这四侧邻格是补丁材质"。

const MapPalette := preload("res://maps/godot/tools/map_palette.gd")
const MapSceneScript := preload("res://core/world/map_scene.gd")
const DEFAULT_SCENE := "res://maps/godot/scenes/abbey_outskirts.tscn"
const TILE_SET_PATH := "res://maps/godot/tilesets/dark48.tres"

var _failed := 0
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var args := _parse_args()
	var scene_path := String(args.get("scene", DEFAULT_SCENE))
	var layer_name := String(args.get("layer", MapSceneScript.LAYER_TERRAIN))
	var check_only := args.has("check")
	_fixup(scene_path, layer_name, check_only)
	print("RESULT: failed=%d" % _failed)
	quit(0 if _failed == 0 else 1)
	return true


func _fail(msg: String) -> void:
	_failed += 1
	print("FAIL  ", msg)


func _parse_args() -> Dictionary:
	var out := {}
	var argv := OS.get_cmdline_user_args()
	var i := 0
	var positional := 0
	while i < argv.size():
		var arg := argv[i]
		if arg.begins_with("--"):
			if arg == "--check":
				out["check"] = true
				i += 1
				continue
			if i + 1 < argv.size():
				out[arg.trim_prefix("--")] = argv[i + 1]
				i += 2
				continue
		out["scene" if positional == 0 else "extra%d" % positional] = arg
		positional += 1
		i += 1
	return out


func _fixup(scene_path: String, layer_name: String, check_only: bool) -> void:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_fail("场景加载失败：%s" % scene_path)
		return
	var map := packed.instantiate()
	var layer := map.get_node_or_null(NodePath(layer_name)) as TileMapLayer
	if layer == null:
		_fail("场景里没有图块层「%s」：%s" % [layer_name, scene_path])
		map.free()
		return
	var tile_set := layer.tile_set
	if tile_set == null:
		tile_set = load(TILE_SET_PATH) as TileSet
	if tile_set == null:
		_fail("拿不到 TileSet（图层没绑定，且默认图块集加载失败）")
		map.free()
		return

	var palette = MapPalette.new()
	if not palette.setup(tile_set):
		_fail("TileSet 缺少 pipeline 元数据（重跑 build_tileset.gd）")
		map.free()
		return

	var report: Dictionary = palette.apply_autotile(layer)
	var counts: Dictionary = report.get("counts", {})
	var total := 0
	for tag in counts:
		total += int(counts[tag])
	print("%s：%d 格，材质 %s，%s %d 格" % [
		scene_path.get_file(), total, str(counts),
		"需要修正" if check_only else "已修正", int(report["changed"])])
	for conflict in report.get("conflicts", []):
		_fail("材质冲突：%s" % conflict)
	if check_only and int(report["changed"]) > 0:
		_fail("%s 有 %d 格边缘块不对，跑一次不带 --check 的修正" % [scene_path.get_file(), int(report["changed"])])

	if not check_only and int(report["changed"]) > 0:
		var err := ResourceSaver.save(packed, scene_path)
		if err != OK:
			_fail("保存场景失败 err=%d：%s" % [err, scene_path])
		else:
			print("WROTE ", scene_path)
	map.free()
