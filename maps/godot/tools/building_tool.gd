extends SceneTree

## **Agent 的建筑工具（高层 CLI）** —— 地图编辑里要放/查/删建筑，只调这里。
##
## 每条子命令对应一个高层动作，**输出一律是单行 JSON**（机器读），
## 出错时 `ok = false` 且带 `errors: [{code, severity, path, message, detail}]`，
## Agent 按 `code` 分支，不用去猜中文。
##
## 用法：
##   :: 1. 有哪些建筑
##   godot --headless --path C:\游戏 --script maps/godot/tools/building_tool.gd -- list
##   :: 2. 看一座建筑（摘要 + 门 + 房间 + 文件）
##   … -- inspect --id iserra_monastery
##   :: 3. 查一座建筑（资产包 + Prefab，结构化错误）
##   … -- validate --id iserra_monastery
##   :: 4. 放进地图（自动占用格 / 碰撞 / 门 / 层级；越界会自动把地图撑大）
##   … -- place --id iserra_monastery --map res://maps/godot/scenes/monastery_grounds.tscn --at 4,4
##   :: 5. 搬走 / 拆掉
##   … -- move --map <场景> --node IserraMonastery --at 10,10
##   … -- remove --map <场景> --node IserraMonastery
##   … -- remove --map <场景> --at 30,40          （按所在地图格删）
##   :: 6. 查整张地图里的建筑
##   … -- validate-map --map <场景>
##   :: 7. 造一座测试/示例地图（地形 + 建筑 + 标记，一条命令出成品）
##   … -- demo --id iserra_monastery --map res://maps/godot/scenes/monastery_grounds.tscn --at 4,4
##
## 退出码：0 = ok，1 = 有 error。

const BuildingLibraryScript := preload("res://core/building/building_library.gd")
const BuildingPlacerScript := preload("res://core/building/building_placer.gd")
const BuildingDataScript := preload("res://core/building/building_data.gd")
const BuildingScript := preload("res://core/building/building.gd")
const MapSceneScript := preload("res://core/world/map_scene.gd")
const MapPalette := preload("res://maps/godot/tools/map_palette.gd")

const DEMO_TILESET := "res://maps/godot/tilesets/dark48.tres"
const DEMO_SCALE := 1.0
## 建筑四周留的空地（格）：太小会把门口堵住，太大地图会虚胖
const DEMO_MARGIN := 6
## 门朝向 → 相邻格偏移（多处共用，只定义一次）
const DOOR_OFFSETS := {"n": Vector2i(0, -1), "s": Vector2i(0, 1), "e": Vector2i(1, 0), "w": Vector2i(-1, 0)}

var _failed := 0
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var parsed := _parse_args()
	var command := String(parsed.get("command", "list"))
	match command:
		"list":
			_emit(_cmd_list())
		"inspect":
			_emit(_cmd_inspect(parsed))
		"validate":
			_emit(_cmd_validate(parsed))
		"place":
			_emit(_cmd_place(parsed))
		"remove":
			_emit(_cmd_remove(parsed))
		"move":
			_emit(_cmd_move(parsed))
		"validate-map":
			_emit(_cmd_validate_map(parsed))
		"demo":
			_emit(_cmd_demo(parsed))
		_:
			_emit({"ok": false, "errors": [{
				"code": "cli.unknown_command", "severity": "error", "path": "",
				"message": "未知子命令「%s」" % command,
				"detail": {"available": ["list", "inspect", "validate", "place", "remove", "move",
					"validate-map", "demo"]},
			}]})
	quit(1 if _failed > 0 else 0)
	return true


## 所有输出走这一个口子：单行 JSON，Agent 直接 JSON.parse。
func _emit(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		_failed += 1
	print("BUILDING_RESULT ", JSON.stringify(result))


func _parse_args() -> Dictionary:
	var out := {"_positional": []}
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
			continue
		(out["_positional"] as Array).append(arg)
		i += 1
	if not out.has("command"):
		var positional: Array = out["_positional"]
		if not positional.is_empty():
			out["command"] = String(positional[0])
	return out


func _parse_cell(text: String) -> Vector2i:
	var parts := text.split(",")
	if parts.size() != 2:
		return Vector2i(-1, -1)
	var cell := Vector2i(int(parts[0].strip_edges()), int(parts[1].strip_edges()))
	return cell


# ================================================================ 子命令

func _cmd_list() -> Dictionary:
	var library := BuildingLibraryScript.new()
	var buildings := library.list_buildings()
	return {"ok": true, "command": "list", "count": buildings.size(), "buildings": buildings}


func _cmd_inspect(args: Dictionary) -> Dictionary:
	var building_id := String(args.get("id", ""))
	if building_id.is_empty():
		return _missing_arg("inspect 需要 --id <building_id>")
	var placer := BuildingPlacerScript.new()
	var result := placer.inspect_building(building_id)
	result["command"] = "inspect"
	return result


func _cmd_validate(args: Dictionary) -> Dictionary:
	var building_id := String(args.get("id", ""))
	if building_id.is_empty():
		return _missing_arg("validate 需要 --id <building_id>")
	var placer := BuildingPlacerScript.new()
	var result := placer.validate_building(building_id, not args.has("no_prefab"))
	result["command"] = "validate"
	return result


func _cmd_place(args: Dictionary) -> Dictionary:
	var building_id := String(args.get("id", ""))
	var map_path := String(args.get("map", ""))
	if building_id.is_empty() or map_path.is_empty():
		return _missing_arg("place 需要 --id <building_id> 与 --map <res://…tscn>")
	var cell := _parse_cell(String(args.get("at", "")))
	if cell.x < 0:
		return _missing_arg("place 需要 --at <x,y>（建筑地基左上角所在地图格）")
	var options := {}
	if args.has("node"):
		options["name"] = String(args["node"])
	if args.has("force"):
		options["force"] = true
	var placer := BuildingPlacerScript.new()
	var result := placer.place_building(map_path, building_id, cell, options)
	result["command"] = "place"
	return result


func _cmd_remove(args: Dictionary) -> Dictionary:
	var map_path := String(args.get("map", ""))
	if map_path.is_empty():
		return _missing_arg("remove 需要 --map <res://…tscn>")
	var selector: Variant = null
	if args.has("node"):
		selector = String(args["node"])
	elif args.has("at"):
		var cell := _parse_cell(String(args["at"]))
		if cell.x < 0:
			return _missing_arg("--at 需要写成 <x,y>")
		selector = cell
	else:
		return _missing_arg("remove 需要 --node <节点名> 或 --at <x,y>")
	var placer := BuildingPlacerScript.new()
	var result := placer.remove_building(map_path, selector)
	result["command"] = "remove"
	return result


func _cmd_move(args: Dictionary) -> Dictionary:
	var map_path := String(args.get("map", ""))
	var node_name := String(args.get("node", ""))
	if map_path.is_empty() or node_name.is_empty():
		return _missing_arg("move 需要 --map <res://…tscn> 与 --node <节点名>")
	var cell := _parse_cell(String(args.get("at", "")))
	if cell.x < 0:
		return _missing_arg("move 需要 --at <x,y>")
	var placer := BuildingPlacerScript.new()
	var result := placer.move_building(map_path, node_name, cell)
	result["command"] = "move"
	return result


func _cmd_validate_map(args: Dictionary) -> Dictionary:
	var map_path := String(args.get("map", ""))
	if map_path.is_empty():
		return _missing_arg("validate-map 需要 --map <res://…tscn>")
	var placer := BuildingPlacerScript.new()
	var result := placer.validate_map_buildings(map_path)
	result["command"] = "validate-map"
	return result


## 一条命令造出一张能直接开跑的示例地图：地形 + 建筑 + 必需标记。
## 地图尺寸按"建筑 + 四周留白"自适应，所以换一座更大的建筑也不用改这里。
func _cmd_demo(args: Dictionary) -> Dictionary:
	var building_id := String(args.get("id", ""))
	var map_path := String(args.get("map", "res://maps/godot/scenes/monastery_grounds.tscn"))
	if building_id.is_empty():
		return _missing_arg("demo 需要 --id <building_id>")
	var library := BuildingLibraryScript.new()
	var data := library.load_building(building_id)
	if data == null:
		return {"ok": false, "errors": [{
			"code": "building.not_found", "severity": "error",
			"path": library.get_metadata_path(building_id),
			"message": "建筑「%s」不存在" % building_id, "detail": {}}]}

	var tile_set := load(DEMO_TILESET) as TileSet
	if tile_set == null:
		return {"ok": false, "errors": [{
			"code": "demo.tileset_missing", "severity": "error", "path": DEMO_TILESET,
			"message": "图块集加载失败（先跑 build_tileset.gd）", "detail": {}}]}
	var palette = MapPalette.new()
	if not palette.setup(tile_set):
		return {"ok": false, "errors": [{
			"code": "demo.tileset_no_pipeline", "severity": "error", "path": DEMO_TILESET,
			"message": "TileSet 缺少 pipeline 元数据（重跑 build_tileset.gd）", "detail": {}}]}

	var footprint := data.get_footprint_size()
	var placed_at := Vector2i(-1, -1)
	if args.has("at"):
		placed_at = _parse_cell(String(args["at"]))
	if placed_at.x < 0:
		placed_at = Vector2i(DEMO_MARGIN, DEMO_MARGIN)
	var map_size := placed_at + footprint + Vector2i(DEMO_MARGIN, DEMO_MARGIN)
	# 至少一屏（26×15），免得小建筑配出一张比视口还小的地图
	map_size.x = maxi(map_size.x, 26)
	map_size.y = maxi(map_size.y, 15)

	var map := _build_map_skeleton(map_path.get_file().get_basename(), map_size, tile_set)
	_paint_demo_terrain(map, palette, data, placed_at)
	_place_demo_markers(map, data, placed_at, map_size)
	_apply_demo_quest_hooks(map, data, placed_at)
	var error := _save(map, map_path)
	map.free()
	if error != OK:
		return {"ok": false, "errors": [{
			"code": "demo.save_failed", "severity": "error", "path": map_path,
			"message": "地图保存失败 err=%d" % error, "detail": {}}]}

	var placer := BuildingPlacerScript.new()
	var placed := placer.place_building(map_path, building_id, placed_at)
	placed["command"] = "demo"
	placed["map_size_cells"] = [map_size.x, map_size.y]
	if bool(placed.get("ok", false)):
		placed["validate"] = placer.validate_map_buildings(map_path)
		placed["ok"] = bool(placed["validate"].get("ok", false))
	return placed


func _missing_arg(message: String) -> Dictionary:
	return {"ok": false, "errors": [{
		"code": "cli.missing_argument", "severity": "error", "path": "",
		"message": message, "detail": {},
	}]}


# ================================================================ 示例地图

func _build_map_skeleton(map_name: String, cells: Vector2i, tile_set: TileSet) -> Node2D:
	var root := Node2D.new()
	root.name = map_name
	root.set_script(load("res://core/world/map_scene.gd"))
	root.set("map_size_cells", cells)
	root.set("display_scale", DEMO_SCALE)
	for layer_name in MapSceneScript.LAYERS:
		var layer := TileMapLayer.new()
		layer.name = layer_name
		layer.tile_set = tile_set
		layer.y_sort_enabled = false
		root.add_child(layer)
		layer.owner = root
		if layer_name == MapSceneScript.LAYER_COLLISION:
			layer.visible = false
	var markers := Node2D.new()
	markers.name = MapSceneScript.MARKER_ROOT
	root.add_child(markers)
	markers.owner = root
	return root


## 地形：草地底 + 建筑南/西门外的石砖路 + 建筑周围泥土环。
## 顺序很关键：**先铺路、再铺环、环跳过路面** —— 否则环里的碎石会与石砖路相邻，
## 触发自动拼接的"材质冲突"（一个格同时挨着两种补丁，边界条带必然缺一块）。
func _paint_demo_terrain(map: Node2D, palette, data: BuildingDataScript, placed_at: Vector2i) -> void:
	var terrain := _layer(map, MapSceneScript.LAYER_TERRAIN)
	var cells: Vector2i = map.get("map_size_cells")
	var materials := {}
	for y in cells.y:
		for x in cells.x:
			materials[Vector2i(x, y)] = "grass"
	var footprint := Rect2i(placed_at, data.get_footprint_size())

	# 1) 从建筑每一道门向地图边缘铺一条石砖路（保证门外有铺装、走得到）
	var road_cells := {}
	for door in data.get_doors():
		var cell_array: Array = (door as Dictionary).get("cell", [0, 0])
		var local := Vector2i(int(cell_array[0]), int(cell_array[1]))
		var side := String((door as Dictionary).get("outward_side", "n"))
		var start := placed_at + local
		var step: Vector2i = DOOR_OFFSETS.get(side, Vector2i.ZERO)
		var cursor: Vector2i = start + step
		var guard := 0
		while guard < 40 and cursor.x >= 0 and cursor.y >= 0 and cursor.x < cells.x and cursor.y < cells.y:
			if footprint.has_point(cursor):
				break
			road_cells[cursor] = true
			road_cells[cursor + Vector2i(step.y, step.x)] = true   # 2 格宽
			cursor += step
			guard += 1
	for cell in road_cells:
		if materials.has(cell):
			materials[cell] = "road_stone"

	# 2) 建筑周围的泥土环（跳过路面，避免与石砖路相邻产生材质冲突）
	var ring := footprint.grow(3)
	for y in range(maxi(0, ring.position.y), mini(cells.y, ring.position.y + ring.size.y)):
		for x in range(maxi(0, ring.position.x), mini(cells.x, ring.position.x + ring.size.x)):
			var cell := Vector2i(x, y)
			if footprint.has_point(cell) or road_cells.has(cell):
				continue
			materials[cell] = "dirt"

	for cell in materials:
		palette.set_material(terrain, cell, String(materials[cell]))
	var report: Dictionary = palette.apply_autotile(terrain)
	for conflict in report.get("conflicts", []):
		print("INFO   自动拼接冲突：%s" % conflict)


## 标记：出生点放在建筑正门外的路上，教堂/回廊/钟楼等地标直接取建筑的房间矩形中心。
func _place_demo_markers(map: Node2D, data: BuildingDataScript, placed_at: Vector2i,
		map_size: Vector2i) -> void:
	var markers := map.get_node_or_null(NodePath(MapSceneScript.MARKER_ROOT))
	if markers == null:
		return
	var tile := Vector2(data.get_tile_size())
	var cells := {}

	# 主入口 = 第一道"朝外"的门（门外那一格不属于建筑本体）
	var footprint_rect := Rect2i(placed_at, data.get_footprint_size())
	var main_door_cell := Vector2i(-1, -1)
	var main_side := "n"
	for door in data.get_doors():
		var d: Dictionary = door
		var cell_array: Array = d.get("cell", [0, 0])
		var local := Vector2i(int(cell_array[0]), int(cell_array[1]))
		var side := String(d.get("outward_side", "n"))
		var map_cell := placed_at + local
		var outward: Vector2i = map_cell + DOOR_OFFSETS.get(side, Vector2i.ZERO)
		if footprint_rect.has_point(outward):
			continue   # 内门，不是建筑入口
		if not Rect2i(Vector2i.ZERO, map_size).has_point(outward):
			continue
		main_door_cell = outward
		main_side = side
		break
	if main_door_cell.x < 0:
		main_door_cell = Vector2i(
			clampi(placed_at.x + 2, 1, map_size.x - 2),
			clampi(placed_at.y + footprint_rect.size.y + 1, 1, map_size.y - 2))
		main_side = "s"
	var step: Vector2i = DOOR_OFFSETS.get(main_side, Vector2i(0, 1))
	cells["spawn"] = _clamp_cell(main_door_cell + step * 3, map_size)
	cells["gate"] = main_door_cell
	cells["skill_light"] = _clamp_cell(main_door_cell + step * 2, map_size)

	cells["battle_trigger"] = Vector2i(
		clampi(footprint_rect.position.x + footprint_rect.size.x + 3, 1, map_size.x - 2),
		clampi(footprint_rect.position.y + footprint_rect.size.y - 3, 1, map_size.y - 2))
	cells["story_trigger"] = _clamp_cell(main_door_cell + step, map_size)
	for room_id in ["nave", "cloister", "west_tower"]:
		var room := data.get_room(room_id)
		if room.is_empty():
			continue
		var rect: Array = room.get("rect", [0, 0, 0, 0])
		var center := placed_at + Vector2i(int(rect[0]) + int(rect[2]) / 2, int(rect[1]) + int(rect[3]) / 2)
		if room_id == "nave":
			cells["church"] = center
		elif room_id == "cloister":
			cells["cloister"] = center
		elif room_id == "west_tower":
			cells["bell_tower"] = center
	# 菜园/药草园：挑建筑外围两处空地（避开建筑本体）
	cells["kitchen_garden"] = Vector2i(
		clampi(footprint_rect.position.x - 3, 1, map_size.x - 2),
		clampi(footprint_rect.position.y + 4, 1, map_size.y - 2))
	cells["herb_garden"] = Vector2i(
		clampi(footprint_rect.position.x - 3, 1, map_size.x - 2),
		clampi(footprint_rect.position.y + 10, 1, map_size.y - 2))

	for marker_id in cells:
		var cell: Vector2i = cells[marker_id]
		var marker := Marker2D.new()
		marker.name = String(marker_id)
		marker.position = (Vector2(cell) + Vector2(0.5, 0.5)) * tile
		markers.add_child(marker)
		marker.owner = map


## 把建筑的房间/门挂成地图元数据，剧情/任务侧以后可以直接引用。
func _apply_demo_quest_hooks(map: Node2D, data: BuildingDataScript, placed_at: Vector2i) -> void:
	map.set_meta("buildings", [{
		"building_id": data.building_id,
		"display_name": data.display_name,
		"top_left_cell": [placed_at.x, placed_at.y],
		"footprint": [data.get_footprint_size().x, data.get_footprint_size().y],
	}])
	map.set_meta("generated_by", "maps/godot/tools/building_tool.gd -- demo")


func _layer(map: Node2D, layer_name: String) -> TileMapLayer:
	return map.get_node_or_null(NodePath(layer_name)) as TileMapLayer


func _clamp_cell(cell: Vector2i, map_size: Vector2i) -> Vector2i:
	return Vector2i(clampi(cell.x, 0, map_size.x - 1), clampi(cell.y, 0, map_size.y - 1))


func _save(map: Node2D, path: String) -> int:
	var dir := path.get_base_dir()
	if DirAccess.open(dir) == null:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var packed := PackedScene.new()
	var pack_error := packed.pack(map)
	if pack_error != OK:
		return pack_error
	return ResourceSaver.save(packed, path)
