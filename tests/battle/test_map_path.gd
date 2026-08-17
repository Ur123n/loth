extends SceneTree

## 地图寻路无头测试：障碍格应被绕过，路径不穿过障碍，预算内可达。
## 运行：godot --headless --path C:\游戏 --script tests\battle\test_map_path.gd

var _passed := 0
var _failed := 0
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_run_all()
	print("RESULT: passed=%d failed=%d" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
	return true


func _run_all() -> void:
	_test_straight_path()
	_test_obstacle_bypass()
	_test_occupied_block()


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("PASS  ", label)
	else:
		_failed += 1
		print("FAIL  ", label)


func _make_map(obstacles: Array = []) -> BattleMapData:
	var map := BattleMapData.new()
	map.cols = 7
	map.rows = 5
	map.cells.clear()
	for row in map.rows:
		for col in map.cols:
			map.cells.append(TerrainData.create(TerrainData.TerrainType.NORMAL))
	for cell in obstacles:
		map.cells[cell.y * map.cols + cell.x] = TerrainData.create(TerrainData.TerrainType.OBSTACLE)
	return map


func _test_straight_path() -> void:
	var map := _make_map()
	var occupied := {}
	var path: Array = map.find_movement_path(
		Vector2i(0, 2), Vector2i(6, 2), 10, occupied, null).get("path", [])
	_check(not path.is_empty() and path[-1] == Vector2i(6, 2), "无障碍：可直达目标")
	_check(path.size() <= 6, "无障碍：路径不绕路（%d 步）" % path.size())


func _test_obstacle_bypass() -> void:
	# 起点 (0,2) 与目标 (6,2) 之间放一排障碍 (3,2)
	var map := _make_map([Vector2i(3, 2)])
	var occupied := {}
	var path: Array = map.find_movement_path(
		Vector2i(0, 2), Vector2i(6, 2), 12, occupied, null).get("path", [])
	_check(not path.is_empty() and path[-1] == Vector2i(6, 2), "障碍格可绕过并到达目标")
	var hit_obstacle := false
	for cell in path:
		if cell == Vector2i(3, 2):
			hit_obstacle = true
	_check(not hit_obstacle, "路径不穿过障碍格")
	var reachable := map.compute_reachable(Vector2i(0, 2), 12, occupied, null)
	_check(reachable.has(Vector2i(6, 2)), "预算内障碍后可达")


func _test_occupied_block() -> void:
	var map := _make_map()
	# 目标格被占用（如玩家），不应把目标格当作路径终点，但仍能到达其相邻格
	var occupied := {Vector2i(6, 2): "player"}
	var reachable := map.compute_reachable(Vector2i(0, 2), 10, occupied, null)
	_check(not reachable.has(Vector2i(6, 2)), "被占用格不可进入")
	_check(reachable.has(Vector2i(5, 2)) or reachable.has(Vector2i(6, 3)) \
			or reachable.has(Vector2i(6, 1)) or reachable.has(Vector2i(5, 3)) \
			or reachable.has(Vector2i(5, 1)), "目标相邻格仍可达（可贴身）")
