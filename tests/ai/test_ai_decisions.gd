extends SceneTree

## AI 决策引擎无头测试（《敌人 AI 重构方案》落地验证）：
## - 行为模板解析（显式 archetype > 小队角色 > 旧 ai 字段 > 默认士兵）
## - 目标选择（低生命集火 / 高威胁后排 / 护卫保护首领 / 可击杀优先）
## - 行动评分（攻击 / 接近 / 追击 / 撤退 / 等待；狂战士不撤退；猎人被贴脸先拉开）
## - Boss 规则（首领不撤退、半血狂暴）
## - 位置评价（接近选更近格、撤退选更远格；候选按评分降序）
## 运行：godot --headless --path C:\游戏 --script tests/ai/test_ai_decisions.gd

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


func _check(cond: bool, name: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: " + name)


func _run_all() -> void:
	_test_archetype_resolution()
	_test_enemy_db_archetype()
	_test_target_selection()
	_test_guardian_target()
	_test_action_scoring()
	_test_boss_rules()
	_test_position_planning()


## 全普通地形的 12x12 地图（测试可控）。
func _open_map() -> BattleMapData:
	var map := BattleMapData.new()
	map.cols = 12
	map.rows = 12
	map.cells = []
	for i in map.cols * map.rows:
		map.cells.append(TerrainData.create(TerrainData.TerrainType.NORMAL))
	return map


func _make_enemy(archetype: String, attack_range: int, move_points: int,
		hp: int, pos: Vector2i) -> BattleUnit:
	var data := EnemyData.new()
	data.enemy_name = "测试敌怪"
	data.hp_min = hp
	data.hp_max = hp
	data.attack_min = 8
	data.attack_max = 8
	data.attack_range = attack_range
	data.move_points = move_points
	data.agility = 5
	data.archetype = archetype
	var unit := BattleUnit.new()
	unit.configure_enemy(data)
	unit.hex_coords = pos
	return unit


func _make_player(name: String, hp: int, max_hp: int, strength: int,
		agility: int, willpower: int, pos: Vector2i) -> BattleUnit:
	var cd := CharacterData.new()
	cd.character_name = name
	cd.strength = strength
	cd.agility = agility
	cd.willpower = willpower
	cd.base_hp = max_hp
	var unit := BattleUnit.new()
	unit.character_data = cd
	unit.is_enemy = false
	unit.current_hp = hp
	unit.hex_coords = pos
	return unit


func _candidate(decision: Dictionary, action: String) -> Dictionary:
	for c in decision.get("candidates", []):
		if str(c.get("action", "")) == action:
			return c
	return {}


func _test_archetype_resolution() -> void:
	_check(AiArchetype.resolve(null, "远程").archetype_name == "猎人", "小队角色 远程→猎人")
	_check(AiArchetype.resolve(null, "护卫").archetype_name == "护卫", "小队角色 护卫→护卫")
	_check(AiArchetype.resolve(null, "炮灰").archetype_name == "鲁莽", "小队角色 炮灰→鲁莽")
	_check(AiArchetype.resolve(null, "侧翼").archetype_name == "刺客", "小队角色 侧翼→刺客")
	_check(AiArchetype.resolve(null, "首领").archetype_name == "首领", "小队角色 首领→首领")
	_check(AiArchetype.resolve(null, "前排").archetype_name == "士兵", "小队角色 前排→士兵")
	var explicit := _make_enemy("狂战士", 1, 1, 40, Vector2i(3, 3))
	_check(AiArchetype.resolve(explicit.enemy_data, "远程").archetype_name == "狂战士",
		"显式 archetype 优先于小队角色")
	var legacy := EnemyData.new()
	legacy.ai_mode = "远离"
	_check(AiArchetype.resolve(legacy, "").archetype_name == "猎人", "旧 ai=远离 兜底为猎人")
	var dummy := EnemyData.new()
	dummy.ai_mode = "无"
	_check(AiArchetype.resolve(dummy, "").archetype_name == "木桩", "旧 ai=无 兜底为木桩")
	var unknown := EnemyData.new()
	unknown.archetype = "不存在"
	_check(AiArchetype.resolve(unknown, "").archetype_name == "士兵", "未知 archetype 回退为士兵")


## 集成：EnemyDB 解析 content/enemies/*.json 时应带上 archetype 字段。
func _test_enemy_db_archetype() -> void:
	var db := get_root().get_node_or_null("EnemyDB")
	if db == null:
		db = load("res://core/battle/enemy_database.gd").new()
		db.load_all()
	var skeleton = db.get_enemy("骷髅")
	_check(skeleton != null and skeleton.archetype == "狂战士", "EnemyDB 解析 archetype（骷髅→狂战士）")
	var archer = db.get_enemy("骷髅弓箭手")
	_check(archer != null and archer.archetype == "猎人", "EnemyDB 解析 archetype（骷髅弓箭手→猎人）")
	var boss = db.get_enemy("终焉惧像·残影")
	_check(boss != null and boss.archetype == "首领", "EnemyDB 解析 archetype（终焉惧像→首领）")
	var dummy = db.get_enemy("木桩")
	_check(dummy != null and dummy.archetype == "木桩", "EnemyDB 解析 archetype（木桩）")


func _test_target_selection() -> void:
	# 狂战士：集火低生命目标（低血 + 可击杀加成）
	var berserker := _make_enemy("狂战士", 1, 2, 40, Vector2i(3, 3))
	var tank := _make_player("甲", 30, 100, 12, 10, 10, Vector2i(4, 3))
	var weak := _make_player("乙", 8, 100, 10, 10, 10, Vector2i(5, 5))
	var target := EnemyAI.select_target(berserker, [tank, weak], AiArchetype.from_key("狂战士"))
	_check(target == weak, "狂战士优先低生命目标")

	# 刺客：猎杀高威胁后排（距离加分）
	var assassin := _make_enemy("刺客", 2, 3, 40, Vector2i(3, 3))
	var mage := _make_player("法师", 50, 100, 8, 8, 20, Vector2i(8, 3))
	var knight := _make_player("骑士", 50, 100, 18, 8, 8, Vector2i(4, 3))
	var target2 := EnemyAI.select_target(assassin, [mage, knight], AiArchetype.from_key("刺客"))
	_check(target2 == mage, "刺客优先高威胁后排目标")

	# 鲁莽：可击杀目标优先
	var reckless := _make_enemy("鲁莽", 1, 2, 40, Vector2i(3, 3))
	var healthy := _make_player("丙", 40, 100, 10, 10, 10, Vector2i(3, 4))
	var killable := _make_player("丁", 7, 100, 10, 10, 10, Vector2i(3, 6))
	var target3 := EnemyAI.select_target(reckless, [healthy, killable], AiArchetype.from_key("鲁莽"))
	_check(target3 == killable, "可击杀目标优先")


func _test_guardian_target() -> void:
	var leader := _make_enemy("首领", 2, 2, 80, Vector2i(6, 6))
	var guard := _make_enemy("护卫", 1, 2, 40, Vector2i(4, 6))
	guard.pack_leader = leader
	var near := _make_player("近", 50, 100, 10, 10, 10, Vector2i(6, 5))
	var far := _make_player("远", 50, 100, 10, 10, 10, Vector2i(1, 1))
	var target := EnemyAI.select_target(guard, [near, far], AiArchetype.from_key("护卫"))
	_check(target == near, "护卫攻击靠近首领的玩家")


func _test_action_scoring() -> void:
	# 攻击：目标在攻击范围内
	var melee := _make_enemy("狂战士", 1, 1, 40, Vector2i(3, 3))
	var p1 := _make_player("甲", 30, 100, 12, 10, 10, Vector2i(3, 4))
	var d1 := EnemyAI.decide(melee, [p1], [], _open_map(), {})
	_check(str(d1.get("action", "")) == "攻击", "范围内狂战士选择攻击")
	_check(int(d1.get("score", 0)) > 0, "攻击评分 > 0")

	# 接近：范围外（狂战士不会撤退）
	var melee2 := _make_enemy("狂战士", 1, 2, 40, Vector2i(3, 3))
	var p2 := _make_player("乙", 30, 100, 12, 10, 10, Vector2i(3, 6))
	var d2 := EnemyAI.decide(melee2, [p2], [], _open_map(), {})
	_check(str(d2.get("action", "")) in ["接近", "追击"], "范围外狂战士选择接近/追击")
	var retreat_cand := _candidate(d2, "撤退")
	_check(int(retreat_cand.get("score", -1)) == 0, "狂战士撤退评分为 0（不撤退）")

	# 猎人被贴脸：先拉开（撤退评分 > 攻击）
	var hunter := _make_enemy("猎人", 3, 2, 40, Vector2i(3, 3))
	var p3 := _make_player("丙", 50, 100, 10, 10, 10, Vector2i(3, 4))
	var d3 := EnemyAI.decide(hunter, [p3], [], _open_map(), {})
	_check(str(d3.get("action", "")) == "撤退", "猎人被贴脸优先撤退")
	var attack_cand := _candidate(d3, "攻击")
	var retreat_score := int(_candidate(d3, "撤退").get("score", 0))
	_check(retreat_score > int(attack_cand.get("score", 0)), "猎人撤退分高于站桩攻击分")

	# 木桩：等待
	var dummy := _make_enemy("木桩", 0, 0, 100, Vector2i(3, 3))
	var p4 := _make_player("丁", 50, 100, 10, 10, 10, Vector2i(3, 4))
	var d4 := EnemyAI.decide(dummy, [p4], [], _open_map(), {})
	_check(str(d4.get("action", "")) == "等待", "木桩始终等待")

	# 无玩家：等待
	var d5 := EnemyAI.decide(melee, [], [], _open_map(), {})
	_check(str(d5.get("action", "")) == "等待", "无目标时等待")


func _test_boss_rules() -> void:
	# 首领范围外：接近而非撤退（永不撤退）
	var boss := _make_enemy("首领", 2, 2, 80, Vector2i(3, 3))
	var p1 := _make_player("甲", 50, 100, 12, 10, 10, Vector2i(3, 6))
	var d1 := EnemyAI.decide(boss, [p1], [], _open_map(), {})
	_check(str(d1.get("action", "")) in ["接近", "追击"], "首领范围外选择接近")
	_check(int(_candidate(d1, "撤退").get("score", -1)) == 0, "首领撤退评分为 0")

	# 首领半血狂暴：攻击候选带狂暴加成
	var boss2 := _make_enemy("首领", 2, 2, 80, Vector2i(3, 3))
	boss2.current_hp = 30
	var p2 := _make_player("乙", 50, 100, 12, 10, 10, Vector2i(3, 4))
	var d2 := EnemyAI.decide(boss2, [p2], [], _open_map(), {})
	_check(str(d2.get("action", "")) == "攻击", "首领半血狂暴仍攻击")
	_check(str(_candidate(d2, "攻击").get("reason", "")).contains("狂暴"), "首领半血攻击带狂暴加成")


func _test_position_planning() -> void:
	# 接近：移动目标格比当前更接近目标，且存在路径
	var melee := _make_enemy("狂战士", 1, 2, 40, Vector2i(3, 3))
	var p1 := _make_player("甲", 50, 100, 12, 10, 10, Vector2i(3, 6))
	var d1 := EnemyAI.decide(melee, [p1], [], _open_map(), {})
	var before := HexGrid.hex_distance(melee.hex_coords, p1.hex_coords)
	var after := HexGrid.hex_distance(d1.get("move_cell", Vector2i(-1, -1)), p1.hex_coords)
	_check(after < before, "接近时移动目标更接近目标")
	_check((d1.get("path", []) as Array).size() > 0, "接近决策带移动路径")

	# 撤退：移动目标格比当前更远
	var hunter := _make_enemy("猎人", 3, 2, 40, Vector2i(3, 3))
	var p2 := _make_player("乙", 50, 100, 10, 10, 10, Vector2i(3, 4))
	var d2 := EnemyAI.decide(hunter, [p2], [], _open_map(), {})
	var after2 := HexGrid.hex_distance(d2.get("move_cell", Vector2i(-1, -1)), p2.hex_coords)
	_check(str(d2.get("action", "")) == "撤退", "猎人撤退决策")
	_check(after2 > 1, "撤退移动目标远离目标")

	# 候选按评分降序
	var cands: Array = d1.get("candidates", [])
	var sorted_ok := true
	for i in cands.size() - 1:
		if int(cands[i].get("score", 0)) < int(cands[i + 1].get("score", 0)):
			sorted_ok = false
	_check(sorted_ok, "候选行动按评分降序")
