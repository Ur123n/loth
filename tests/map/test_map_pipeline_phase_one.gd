extends SceneTree

const MapSceneScript := preload("res://core/world/map_scene.gd")
const PatternLibraryScript := preload("res://core/world/map_pattern_library.gd")
const MapPaletteScript := preload("res://maps/godot/tools/map_palette.gd")

const LAB_PATH := "res://dev/map_pipeline_test/map_pipeline_test.tscn"
const INTERIOR_PATH := "res://dev/map_pipeline_test/interior_test.tscn"

var _passed := 0
var _failed := 0
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_run()
	print("RESULT: passed=%d failed=%d" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
	return true


func _run() -> void:
	_check(FileAccess.file_exists(LAB_PATH), "第一阶段实验场存在")
	_check(FileAccess.file_exists(INTERIOR_PATH), "独立 Interior Scene 存在")
	var packed := load(LAB_PATH) as PackedScene
	_check(packed != null, "第一阶段实验场可加载")
	if packed == null:
		return
	var map := packed.instantiate() as MapSceneScript
	_check(map != null, "实验场根节点实现 MapScene")
	if map == null:
		return
	root.add_child(map)

	_check((map.call("validate") as PackedStringArray).is_empty(), "实验场结构自检通过")
	_check((map.call("validate_spawn_walkable") as PackedStringArray).is_empty(), "出生点可通行")
	var palette := MapPaletteScript.new()
	palette.setup(map.call("get_layer", "地形").tile_set)
	_check(palette.material_of_cell(map.call("get_layer", "地形"), Vector2i(80, 72)) == "road_stone",
		"实验场包含 TileMap 道路")

	var library := PatternLibraryScript.new()
	_check(library.list_pattern_ids().has("house_a"), "Pattern Library 收录 house_a")
	var pattern_data := library.load_pattern("house_a")
	_check(not pattern_data.is_empty(), "house_a 数据可读取")
	_check((library.validate_pattern(pattern_data) as PackedStringArray).is_empty(), "house_a 数据校验通过")
	var temporary_parent := Node2D.new()
	map.add_child(temporary_parent)
	var stamped := library.place_pattern(temporary_parent, "house_a", Vector2(240, 240))
	_check(stamped != null and String(stamped.get_meta("pattern_id", "")) == "house_a",
		"一次调用放置完整 House_A Pattern")
	temporary_parent.queue_free()
	var house := map.get_node_or_null(NodePath("建筑对象/HouseA"))
	_check(house != null and house.has_method("get_footprint_cells"), "实验场包含完整小屋 Pattern")
	_check(house != null and house.get_node_or_null(NodePath("Collision")) is StaticBody2D,
		"小屋 Pattern 的碰撞与视觉分离")

	var buildings: Array = map.call("get_buildings")
	_check(buildings.size() == 1, "实验场包含一座已放置的大型建筑")
	var building: Node = buildings[0] if not buildings.is_empty() else null
	_check(building != null and String(building.call("get_building_id")) == "iserra_monastery",
		"大型建筑以 PackedScene 接入")
	_check(building != null and building.call("get_top_left_cell") == Vector2i(75, 5),
		"大型建筑 Anchor/放置格一致")
	_check(building != null and building.get_node_or_null(NodePath("Visual")) != null
		and building.get_node_or_null(NodePath("Collision")) is StaticBody2D,
		"大型建筑视觉与碰撞分离")
	if building != null:
		building.call("set_roof_visible", false)
		_check(not bool(building.call("is_roof_visible")), "大型建筑 Roof 可隐藏")
		building.call("set_roof_visible", true)
		_check(bool(building.call("is_roof_visible")), "大型建筑 Roof 可恢复")

	var ghost := map.get_node_or_null(NodePath("BuildingGhost"))
	_check(ghost != null and ghost.call("get_preview_node") != null, "大型建筑 Ghost 显示完整 Prefab")
	_check(ghost != null and bool(ghost.call("is_placement_valid")), "Ghost 初始位置通过统一放置校验")
	_check(ghost != null and (ghost.call("get_footprint_rect_cells") as Rect2i).size == Vector2i(57, 66),
		"Ghost 显示真实 Footprint")
	_check(ghost != null and (ghost.call("get_entrance_map_cells") as Array).size() >= 1,
		"Ghost 暴露 Entrance 标记")
	if ghost != null:
		var placed: Node2D = ghost.call("place_runtime")
		_check(placed != null, "Ghost 可一键实例化大型建筑（运行时、不写盘）")
		if placed != null:
			placed.get_parent().remove_child(placed)
			placed.free()
			ghost.call("refresh_validation")

	var prop := map.get_node_or_null(NodePath("建筑对象/RoadsideRock"))
	_check(prop != null and prop.has_method("get_prop_id"), "实验场包含自由摆放 Prop")
	_check(prop != null and bool(prop.call("has_independent_collision")), "自由 Prop 自带独立碰撞")
	_check(prop != null and not (prop is TileMapLayer), "自由 Prop 不依赖 TileMap")

	var player := map.get_node_or_null(NodePath("建筑对象/Player"))
	_check(player is CharacterBody2D and player.is_in_group("player"), "实验场包含可移动玩家")
	_check(player != null and building != null and player.get_parent() == building.get_parent(),
		"玩家与大型建筑处于同一 YSort 域")

	var door := map.get_node_or_null(NodePath("Gameplay/HouseDoor"))
	var transition: Dictionary = door.call("describe_transition") if door != null else {}
	_check(door is Area2D and bool(transition.get("exists", false)), "House Door 指向独立 Interior Scene")
	var interior_packed := load(INTERIOR_PATH) as PackedScene
	var interior := interior_packed.instantiate() if interior_packed != null else null
	_check(interior != null and interior.get_node_or_null(NodePath("ReturnDoor")) != null,
		"Interior Scene 提供返回门")
	if interior != null:
		var return_transition: Dictionary = interior.get_node("ReturnDoor").call("describe_transition")
		_check(String(return_transition.get("scene", "")) == LAB_PATH,
			"Interior 返回门指回第一阶段实验场")
		interior.free()

	_check(map.get_node_or_null(NodePath("Navigation")) != null,
		"Navigation 语义独立预留，不与视觉/碰撞耦合")
	map.free()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("PASS  ", label)
	else:
		_failed += 1
		print("FAIL  ", label)
