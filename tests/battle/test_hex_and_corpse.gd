extends SceneTree

## 战斗六边形边长与统一尸骸状态回归测试。
## 运行：godot --headless --path C:\游戏 --script tests\battle\test_hex_and_corpse.gd

var _passed := 0
var _failed := 0
var _done := false
var _battle_defeated := false
var _nodes_to_free: Array[Node] = []


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_run_all()
	print("RESULT: passed=%d failed=%d" % [_passed, _failed])
	for node in _nodes_to_free:
		if is_instance_valid(node):
			node.free()
	_nodes_to_free.clear()
	quit(0 if _failed == 0 else 1)
	return true


func _run_all() -> void:
	_test_hex_side_length_contract()
	_test_corpse_data_contract()
	_test_player_becomes_corpse_without_gray_tint()
	_test_corpse_is_not_living_player()
	_test_corpse_second_defeat_removes_unit()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("PASS  ", label)
	else:
		_failed += 1
		print("FAIL  ", label)


func _test_hex_side_length_contract() -> void:
	_check(is_equal_approx(HexGrid.DEFAULT_SIDE_LENGTH, 20.0), "六边形唯一默认边长为 20")
	var map_data := BattleMapData.new()
	var map_view := BattleMapView.new()
	_nodes_to_free.append(map_view)
	_check(is_equal_approx(map_data.tile_size, 20.0), "BattleMapData 默认继承边长 20")
	_check(is_equal_approx(map_view.tile_size, 20.0), "BattleMapView 默认继承边长 20")
	var origin := HexGrid.hex_to_world(0, 0)
	var same_row := HexGrid.hex_to_world(1, 0)
	var next_row := HexGrid.hex_to_world(0, 1)
	_check(is_equal_approx(origin.distance_to(same_row), HexGrid.SQRT3 * 20.0),
		"同行相邻格中心距为 sqrt(3)×20")
	_check(is_equal_approx(next_row.y - origin.y, 30.0), "相邻行中心纵距为 30")
	var points := map_view._hex_points(20.0)
	var all_vertices_on_radius := points.size() == 6
	for point in points:
		all_vertices_on_radius = all_vertices_on_radius and is_equal_approx(point.length(), 20.0)
	_check(all_vertices_on_radius, "六个顶点均使用边长/外接圆半径 20")


func _test_corpse_data_contract() -> void:
	var database := EnemyDatabase.new()
	_nodes_to_free.append(database)
	var parsed := database._parse_enemy({
		"name": "测试敌怪",
		"corpse_art_a": "res://corpse_a.png",
		"corpse_art_b": "res://corpse_b.png",
	})
	_check(parsed.corpse_art_a_path == "res://corpse_a.png", "EnemyDB 解析尸骸 A")
	_check(parsed.corpse_art_b_path == "res://corpse_b.png", "EnemyDB 解析尸骸 B")
	_check(parsed.get_corpse_art_paths().size() == 2, "敌怪数据提供两种尸骸候选")
	var character := CharacterData.new()
	character.corpse_art_b_path = "res://character_corpse_b.png"
	_check(character.get_corpse_art_paths() == ["res://character_corpse_b.png"],
		"角色数据同样提供尸骸候选")


func _make_player(name: String = "测试角色") -> BattleUnit:
	var unit := BattleUnit.new()
	var data := CharacterData.new()
	data.character_name = name
	unit.character_data = data
	unit.hex_coords = Vector2i(2, 3)
	root.add_child(unit)
	_nodes_to_free.append(unit)
	return unit


func _test_player_becomes_corpse_without_gray_tint() -> void:
	var unit := _make_player()
	var map_script = load("res://core/battle/battle_map.gd")
	var battle_map = map_script.new()
	_nodes_to_free.append(battle_map)
	battle_map._on_unit_defeated(unit)
	_check(unit.is_corpse, "玩家首次死亡统一转为尸骸")
	_check(unit.current_hp == unit.corpse_max_hp and unit.corpse_max_hp > 0,
		"尸骸获得独立可破坏生命")
	_check(unit._visual.visual_state == "corpse_placeholder", "缺失尸骸素材时切换独立骨堆占位")
	_check(unit._visual.placeholder_color == unit.character_data.block_color,
		"死亡不会把存活占位色染灰")


func _test_corpse_is_not_living_player() -> void:
	var corpse := _make_player("尸骸角色")
	corpse.become_corpse()
	var living := _make_player("存活角色")
	var map_script = load("res://core/battle/battle_map.gd")
	var battle_map = map_script.new()
	_nodes_to_free.append(battle_map)
	battle_map._units.append(corpse)
	battle_map._units.append(living)
	_check(battle_map._living_players() == [living], "AI 存活目标排除玩家尸骸")

	var enemy := BattleUnit.new()
	_nodes_to_free.append(enemy)
	enemy.configure_enemy(EnemyData.new())
	var manager := BattleManager.new()
	manager.setup([corpse, enemy], RandomNumberGenerator.new())
	_battle_defeated = false
	manager.battle_finished.connect(_on_battle_finished)
	manager._check_battle_over()
	_check(_battle_defeated, "仅剩玩家尸骸时正确判定全队失败")


func _on_battle_finished(_coins: int, _exp: int, _loot: Array, defeated: bool) -> void:
	_battle_defeated = defeated


func _test_corpse_second_defeat_removes_unit() -> void:
	var unit := _make_player("二次击破")
	var map_script = load("res://core/battle/battle_map.gd")
	var battle_map = map_script.new()
	_nodes_to_free.append(battle_map)
	battle_map._occupied[unit.hex_coords] = unit
	battle_map._on_unit_defeated(unit)
	unit.current_hp = 0
	battle_map._on_unit_defeated(unit)
	_check(unit.is_removed and not unit.visible, "尸骸再次归零后从战场移除")
	_check(not battle_map._occupied.has(unit.hex_coords), "移除尸骸会释放所占图格")
