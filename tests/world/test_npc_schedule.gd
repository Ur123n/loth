extends SceneTree

## NPC 行动轨迹（时间轴）纯逻辑无头测试：
## - 空 schedule / 单时间点 / 整点命中 / 相邻时间点线性插值 / 跨零点衔接
## - validate：缺字段 / hour 越界 / 未递增 / 位置越界
## 运行：godot --headless --path C:\游戏 --script tests\world\test_npc_schedule.gd

const _Sched := preload("res://core/world/npc_schedule.gd")

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


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("PASS  ", label)
	else:
		_failed += 1
		print("FAIL  ", label)


func _near(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < 0.001


func _run_all() -> void:
	_test_empty_and_single()
	_test_between()
	_test_exact_hour()
	_test_wrap_midnight()
	_test_validate()
	print("RESULT2: done")


func _test_empty_and_single() -> void:
	_check(_Sched.compute_position([], 8.0) == Vector2.INF, "空 schedule → INF")
	var single := [{"hour": 8, "position": [100, 200]}]
	for h in [0.0, 8.0, 12.0, 23.5]:
		_check(_near(_Sched.compute_position(single, h), Vector2(100, 200)), "单时间点恒在该点（%s 时）" % h)


func _test_between() -> void:
	var sched := [
		{"hour": 6, "position": [0, 0]},
		{"hour": 12, "position": [120, 0]},
		{"hour": 18, "position": [120, 120]},
	]
	_check(_near(_Sched.compute_position(sched, 9.0), Vector2(60, 0)), "6→12 中点插值")
	_check(_near(_Sched.compute_position(sched, 15.0), Vector2(120, 60)), "12→18 中点插值")
	_check(_near(_Sched.compute_position(sched, 7.5), Vector2(30, 0)), "1/4 处插值")


func _test_exact_hour() -> void:
	var sched := [
		{"hour": 6, "position": [0, 0]},
		{"hour": 12, "position": [120, 0]},
		{"hour": 18, "position": [120, 120]},
	]
	_check(_near(_Sched.compute_position(sched, 6.0), Vector2(0, 0)), "整点 6 命中")
	_check(_near(_Sched.compute_position(sched, 12.0), Vector2(120, 0)), "整点 12 命中")
	_check(_near(_Sched.compute_position(sched, 18.0), Vector2(120, 120)), "整点 18 命中")


func _test_wrap_midnight() -> void:
	var sched := [
		{"hour": 6, "position": [0, 0]},
		{"hour": 12, "position": [120, 0]},
		{"hour": 18, "position": [120, 120]},
	]
	# 21 时：18→6（跨零点）中途
	var p21 := _Sched.compute_position(sched, 21.0)
	_check(_near(p21, Vector2(90, 90)), "21 时跨零点插值（%s）" % p21)
	# 3 时：仍在 18→6 的行程上（3/4 处）
	var p3 := _Sched.compute_position(sched, 3.0)
	_check(_near(p3, Vector2(30, 30)), "3 时跨零点插值（%s）" % p3)


func _test_validate() -> void:
	var problems: Array[String] = []
	_Sched.validate([], problems, "空")
	_check(problems.size() == 1, "空 schedule 报错")
	problems.clear()
	_Sched.validate([
		{"hour": 6, "position": [10, 10]},
		{"hour": 12, "position": [20, 20]},
	], problems, "好人")
	_check(problems.is_empty(), "合法 schedule 无问题")
	problems.clear()
	_Sched.validate([
		{"hour": 12, "position": [20, 20]},
		{"hour": 6, "position": [10, 10]},
	], problems, "乱序")
	_check(problems.size() == 1, "hour 未递增报错")
	problems.clear()
	_Sched.validate([
		{"hour": 24, "position": [10, 10]},
	], problems, "越界")
	_check(problems.size() >= 1, "hour=24 越界报错")
	problems.clear()
	_Sched.validate([
		{"hour": 6, "position": [700, 10]},
	], problems, "位置")
	_check(problems.size() == 1, "位置越界报错")
	problems.clear()
	_Sched.validate([
		{"hour": 6},
	], problems, "缺位置")
	_check(problems.size() == 1, "缺少 position 报错")
