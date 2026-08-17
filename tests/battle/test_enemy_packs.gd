extends SceneTree

## 敌方小队表无头测试：
## - EnemyPackDB 解析、各强度小队数量与成员数（3~4 只）
## - 成员均为有效敌怪且不含训练木桩；强度约束（普通队全普通等）
## - 按强度随机抽取；DemoComposer 各场次返回小队且强度正确
## - 小队角色（role/leader）：每队 3~4 只、角色齐全、护卫绑定首领、
##   同一种敌怪可在不同小队担任不同角色；EnemyAI 站位策略
## 运行：godot --headless --path C:\游戏 --script tests\battle\test_enemy_packs.gd

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
	_ensure_enemy_db()
	_ensure_pack_db()
	_test_pack_data()
	_test_random_pack()
	_test_compose_uses_packs()
	_test_pack_roles()
	_test_enemy_ai()


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("PASS  ", label)
	else:
		_failed += 1
		print("FAIL  ", label)


func _ensure_enemy_db() -> void:
	if root.get_node_or_null("EnemyDB") == null:
		var db := EnemyDatabase.new()
		db.name = "EnemyDB"
		root.add_child(db)


func _ensure_pack_db() -> void:
	if root.get_node_or_null("EnemyPackDB") == null:
		var db := EnemyPackDatabase.new()
		db.name = "EnemyPackDB"
		root.add_child(db)


func _test_pack_data() -> void:
	var db := root.get_node("EnemyPackDB") as EnemyPackDatabase
	_check(db.packs.size() >= 9, "小队总数充足（%d）" % db.packs.size())
	for tier in ["普通", "精英", "Boss"]:
		_check(not db.get_packs_by_tier(tier).is_empty(), "%s 强度至少 1 支小队" % tier)
	for pack in db.packs:
		var resolved := db.resolve_pack(pack)
		var size := resolved.size()
		_check(size >= 3 and size <= 4, "小队「%s」成员 3~4 只（%d）" % [pack.get("name", ""), size])
		_check(resolved.all(func(e): return e.enemy_name != "木桩"), "小队「%s」不含木桩" % pack.get("name", ""))
		match str(pack.get("tier", "")):
			"普通":
				_check(resolved.all(func(e): return e.tier == "普通"), "普通小队「%s」全为普通怪" % pack.get("name", ""))
			"精英":
				_check(resolved.any(func(e): return e.tier == "精英") \
						and resolved.all(func(e): return e.tier != "Boss"),
					"精英小队「%s」含精英且无 Boss" % pack.get("name", ""))
			"Boss":
				_check(resolved.any(func(e): return e.tier == "Boss"), "Boss 小队「%s」含 Boss" % pack.get("name", ""))


func _test_random_pack() -> void:
	var db := root.get_node("EnemyPackDB") as EnemyPackDatabase
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for tier in ["普通", "精英", "Boss"]:
		var pack := db.random_pack(tier, rng)
		_check(not pack.is_empty() and str(pack.get("tier", "")) == tier, "random_pack：%s 抽取正确" % tier)
	var missing := db.random_pack("不存在", rng)
	_check(missing.is_empty(), "random_pack：未知强度返回空")


func _test_compose_uses_packs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var normal := DemoComposer.compose_battle(1, rng)
	_check(normal.size() >= 3 and normal.size() <= 4, "第 1 场小队 3~4 只（%d）" % normal.size())
	_check(normal.all(func(e): return e.tier == "普通"), "第 1 场：全部普通怪")
	var elite := DemoComposer.compose_battle(3, rng)
	_check(elite.any(func(e): return e.tier == "精英"), "第 3 场：含精英")
	var boss := DemoComposer.compose_battle(6, rng)
	_check(boss.any(func(e): return e.tier == "Boss"), "第 6 场：含 Boss")
	_check(boss.size() >= 3 and boss.size() <= 4, "Boss 战小队 3~4 只（%d）" % boss.size())


func _test_pack_roles() -> void:
	var db := root.get_node("EnemyPackDB") as EnemyPackDatabase
	var role_by_enemy: Dictionary = {}
	var all_roles: Array[String] = []
	for pack in db.packs:
		var entries := db.pack_member_entries(pack)
		var leader_found := false
		var guard_count := 0
		for entry in entries:
			var role := str(entry.get("role", ""))
			all_roles.append(role)
			_check(not role.is_empty(), "小队「%s」成员角色齐全（%s）" % [pack.get("name", ""), role])
			if bool(entry.get("leader", false)):
				leader_found = true
			if role == "护卫":
				guard_count += 1
			var enemy_name: String = (entry.get("enemy") as EnemyData).enemy_name
			if not role_by_enemy.has(enemy_name):
				role_by_enemy[enemy_name] = []
			if not (role_by_enemy[enemy_name] as Array).has(role):
				(role_by_enemy[enemy_name] as Array).append(role)
		if guard_count > 0:
			_check(leader_found, "含护卫的小队「%s」有首领" % pack.get("name", ""))
	# 同一种敌怪可出现在不同小队担任不同角色（核心需求）
	var multi := false
	for enemy_name in role_by_enemy:
		if (role_by_enemy[enemy_name] as Array).size() >= 2:
			multi = true
			break
	_check(multi, "存在同种敌怪担任多种角色（如 骷髅：前排/近战/炮灰）")
	_check(all_roles.has("前排") and all_roles.has("近战") and all_roles.has("远程")
			and all_roles.has("护卫") and all_roles.has("侧翼") and all_roles.has("炮灰")
			and all_roles.has("首领"), "七种小队角色均已使用")


func _test_enemy_ai() -> void:
	_check(EnemyAI.desired_distance("远程", 3) == 3, "远程：期望距离=射程（3）")
	_check(EnemyAI.desired_distance("侧翼", 1) == 2, "侧翼：期望距离=2")
	_check(EnemyAI.desired_distance("前排", 1) == 1, "前排：期望距离=1")
	_check(EnemyAI.desired_distance("首领", 2) == 1, "首领：期望距离=1")
	_check(EnemyAI.should_retreat("远程", 1, 3), "远程贴脸（1<3）应拉开")
	_check(not EnemyAI.should_retreat("远程", 3, 3), "远程在射程边缘不拉开")
	_check(not EnemyAI.should_retreat("近战", 1, 3), "近战贴脸不拉开")
	_check(EnemyAI.is_ranged("远程") and not EnemyAI.is_ranged("近战"), "远程判定")
	_check(EnemyAI.goal_score(1, 1) < EnemyAI.goal_score(2, 1), "站位评分：贴身优于 2 格")
	_check(EnemyAI.goal_score(3, 3) < EnemyAI.goal_score(2, 3), "站位评分：射程边缘优先")
