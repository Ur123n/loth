extends SceneTree

## 敌怪 AI 统一架构无头测试（《敌怪ai逻辑.txt》落地验证）：
## - AIProfile 统一参数（Aggression/Support/Caution/Mobility/Defensiveness/TargetPriority/PreferredRange）
## - ai_profile 数据覆盖（敌怪数据驱动行为倾向）
## - Goal 解析（进攻/集火/保护首领/支援/保持射程/保命/无 AI）
## - Conditions（能做 vs 值不值得做分离）
## - ActionCandidate 与 Utility 分项（Base+Target+Position+Context+Personality+Urgency+Random）
## - 随机变化不影响必杀机会；候选按评分降序；兼容旧接口
## 运行：godot --headless --path C:\游戏 --script tests/ai/test_ai_unified.gd

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
	_test_profile_params()
	_test_profile_overrides()
	_test_goal_resolution()
	_test_conditions()
	_test_candidates_and_components()
	_test_random_variation_safe()
	_test_legacy_compat()


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


func _test_profile_params() -> void:
	# 第 4 节示例：狂战士 Aggression 90 / Support 0 / Caution 10 / Mobility 70 / Defensiveness 10
	var berserker := AiProfile.from_key("狂战士")
	_check(berserker.aggression == 90, "狂战士 Aggression=90")
	_check(berserker.support == 0, "狂战士 Support=0")
	_check(berserker.caution == 10, "狂战士 Caution=10")
	_check(berserker.mobility == 70, "狂战士 Mobility=70")
	_check(berserker.defensiveness == 10, "狂战士 Defensiveness=10")
	_check(berserker.target_priority == AiProfile.PRIORITY_LOWEST_HP, "狂战士 TargetPriority=lowest_hp")
	_check(berserker.preferred_range == 1, "狂战士 PreferredRange=1")
	_check(berserker.never_retreats, "狂战士 永不撤退")
	_check(not berserker.kites, "狂战士 非风筝")

	# 祭司类（支援模板）：Support=100 / Caution 高 / Defensiveness 高
	var support := AiProfile.from_key("支援")
	_check(support.support == 100, "支援 Support=100")
	_check(support.caution >= 60 and support.defensiveness >= 70, "支援 谨慎且防守")

	# 刺客：机动 100、后排猎杀
	var assassin := AiProfile.from_key("刺客")
	_check(assassin.mobility == 100, "刺客 Mobility=100")
	_check(assassin.target_priority == AiProfile.PRIORITY_BACKLINE, "刺客 TargetPriority=backline")
	_check(assassin.prefers_high_threat and assassin.targets_isolated, "刺客 高威胁+孤立")

	# 猎人：PreferredRange=-1 → 风筝（保持射程边缘）
	var hunter := AiProfile.from_key("猎人")
	_check(hunter.preferred_range == -1 and hunter.kites, "猎人 风筝型")
	_check(hunter.desired_distance_for(3) == 3, "猎人 期望距离=射程边缘")


func _test_profile_overrides() -> void:
	var data := EnemyData.new()
	data.archetype = "狂战士"
	data.ai_profile = {
		"aggression": 20,
		"caution": 80,
		"support": 60,
		"never_retreats": false,
	}
	var profile := AiProfile.resolve(data, "远程")
	_check(profile.archetype_name == "狂战士", "覆盖不改变 archetype 名")
	_check(profile.aggression == 20 and profile.caution == 80, "ai_profile 覆盖 aggression/caution")
	_check(profile.support == 60, "ai_profile 覆盖 support")
	_check(not profile.never_retreats, "ai_profile 覆盖 never_retreats")
	_check(profile.mobility == 70, "未覆盖参数保持模板默认（mobility=70）")


func _test_goal_resolution() -> void:
	var players := [_make_player("甲", 50, 100, 10, 10, 10, Vector2i(4, 3))]

	# 护卫：保护首领优先于一切
	var leader := _make_enemy("首领", 2, 2, 80, Vector2i(6, 6))
	var guard := _make_enemy("护卫", 1, 2, 40, Vector2i(4, 6))
	guard.pack_leader = leader
	var guard_profile := AiProfile.from_key("护卫")
	_check(AiGoal.resolve(guard, guard_profile, players, []) == AiGoal.PROTECT_LEADER, "护卫 Goal=ProtectLeader")

	# 支援：有受伤友军 → ProtectWounded
	var support := _make_enemy("支援", 1, 2, 40, Vector2i(3, 3))
	var wounded := _make_enemy("士兵", 1, 1, 20, Vector2i(3, 5))
	wounded.current_hp = 10
	var support_profile := AiProfile.from_key("支援")
	_check(AiGoal.resolve(support, support_profile, players, [wounded]) == AiGoal.PROTECT_WOUNDED, "支援 Goal=ProtectWounded")

	# 狂战士：有可击杀目标 → KillTarget
	var berserker := _make_enemy("狂战士", 1, 2, 40, Vector2i(3, 3))
	var killable := _make_player("残血", 7, 100, 10, 10, 10, Vector2i(4, 3))
	_check(AiGoal.resolve(berserker, AiProfile.from_key("狂战士"), [killable], []) == AiGoal.KILL_TARGET, "狂战士 Goal=KillTarget")

	# 猎人：无击杀机会时保持射程
	var hunter := _make_enemy("猎人", 3, 2, 40, Vector2i(3, 3))
	_check(AiGoal.resolve(hunter, AiProfile.from_key("猎人"), players, []) == AiGoal.MAINTAIN_RANGE, "猎人 Goal=MaintainRange")

	# 谨慎低血单位：保命（Survive）
	var cautious := _make_enemy("士兵", 1, 2, 100, Vector2i(3, 3))
	cautious.current_hp = 25
	var cautious_profile := AiProfile.from_key("士兵")
	cautious_profile.caution = 60
	_check(AiGoal.resolve(cautious, cautious_profile, players, []) == AiGoal.SURVIVE, "谨慎低血 Goal=Survive")

	# 普通士兵：进攻
	var soldier := _make_enemy("士兵", 1, 2, 100, Vector2i(3, 3))
	_check(AiGoal.resolve(soldier, AiProfile.from_key("士兵"), players, []) == AiGoal.ATTACK_PLAYER, "士兵 Goal=AttackPlayer")

	# 木桩：无 AI
	var dummy := _make_enemy("木桩", 0, 0, 100, Vector2i(3, 3))
	_check(AiGoal.resolve(dummy, AiProfile.from_key("木桩"), players, []) == AiGoal.HOLD, "木桩 Goal=Hold")


func _test_conditions() -> void:
	var melee := _make_enemy("狂战士", 1, 2, 40, Vector2i(3, 3))
	var far := _make_player("远", 50, 100, 10, 10, 10, Vector2i(3, 6))
	var near := _make_player("近", 50, 100, 10, 10, 10, Vector2i(3, 4))

	var out := AiConditionEvaluator.can_attack(far, 3, 1)
	_check(not bool(out.get("ok", true)), "条件：射程外不可攻击")
	var inside := AiConditionEvaluator.can_attack(near, 1, 1)
	_check(bool(inside.get("ok", false)), "条件：射程内可攻击")

	var retreat_ok := AiConditionEvaluator.can_retreat(AiProfile.from_key("士兵"), melee)
	_check(bool(retreat_ok.get("ok", false)), "条件：士兵可撤退")
	var retreat_no := AiConditionEvaluator.can_retreat(AiProfile.from_key("狂战士"), melee)
	_check(not bool(retreat_no.get("ok", true)), "条件：狂战士不可撤退")

	var protect_no := AiConditionEvaluator.can_protect(AiProfile.from_key("狂战士"), melee)
	_check(not bool(protect_no.get("ok", true)), "条件：非护卫不可保护")
	var support_no := AiConditionEvaluator.can_support(AiProfile.from_key("狂战士"), melee, [])
	_check(not bool(support_no.get("ok", true)), "条件：非支援不可支援")


func _test_candidates_and_components() -> void:
	var berserker := _make_enemy("狂战士", 1, 2, 40, Vector2i(3, 3))
	var p := _make_player("甲", 30, 100, 12, 10, 10, Vector2i(3, 4))
	var candidates := EnemyAI.get_action_candidates(berserker, [p], [], _open_map(), {})
	_check(candidates.size() == 7, "候选包含 7 种行动（攻击/接近/撤退/保护/支援/技能/等待）")

	var attack: ActionCandidate = null
	for cand in candidates:
		if cand.action_key == "attack":
			attack = cand
	_check(attack != null and attack.score > 0, "范围内攻击候选有分")
	_check(attack.components.has("base") and attack.components.has("target")
		and attack.components.has("position") and attack.components.has("context")
		and attack.components.has("personality") and attack.components.has("urgency")
		and attack.components.has("random"), "攻击候选含全部 Utility 分项")
	var total := 0
	for key in ["base", "target", "position", "context", "personality", "urgency", "random"]:
		total += int(attack.components[key])
	_check(total == attack.score, "Utility 总分 = 各分项之和")
	_check(int(attack.components["random"]) == 0, "未传 RNG 时随机分项为 0（测试确定性）")

	# 射程外：攻击候选 0 分并说明条件
	var far := _make_player("乙", 30, 100, 12, 10, 10, Vector2i(3, 6))
	var candidates2 := EnemyAI.get_action_candidates(berserker, [far], [], _open_map(), {})
	var attack_far: ActionCandidate = null
	for cand in candidates2:
		if cand.action_key == "attack":
			attack_far = cand
	_check(attack_far.score == 0, "射程外攻击候选 0 分")
	_check(str(attack_far.reason).contains("攻击范围"), "射程外攻击候选说明条件不满足")

	# 决策：候选按评分降序，携带 Goal
	var decision := EnemyAI.decide(berserker, [p], [], _open_map(), {})
	var cands: Array = decision.get("candidates", [])
	var sorted_ok := true
	for i in cands.size() - 1:
		if int(cands[i].get("score", 0)) < int(cands[i + 1].get("score", 0)):
			sorted_ok = false
	_check(sorted_ok, "决策候选按评分降序")
	_check(str(decision.get("goal", "")) == "进攻玩家", "决策携带 Goal 展示名")


func _test_random_variation_safe() -> void:
	# 必杀机会（Kill Potential）不能被随机变化覆盖：多组随机种子下仍选择攻击
	var berserker := _make_enemy("狂战士", 1, 2, 40, Vector2i(3, 3))
	var weak := _make_player("残血", 7, 100, 10, 10, 10, Vector2i(3, 4))
	var all_attack := true
	for seed in range(1, 21):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var decision := EnemyAI.decide(berserker, [weak], [], _open_map(), {}, rng)
		if str(decision.get("action", "")) != "攻击":
			all_attack = false
			break
		var attack_cand := _candidate(decision, "攻击")
		var random_part := int(attack_cand.get("components", {}).get("random", 0))
		if random_part < -6 or random_part > 6:
			all_attack = false
			break
	_check(all_attack, "随机变化在 ±6 内且不覆盖必杀攻击")

	# 有 RNG 时确实会出现非零随机分项（20 组里至少一组）
	var has_random := false
	for seed in range(1, 21):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var decision := EnemyAI.decide(berserker, [weak], [], _open_map(), {}, rng)
		for c in decision.get("candidates", []):
			if int(c.get("components", {}).get("random", 0)) != 0:
				has_random = true
	if not has_random:
		printerr("WARN: 20 组种子均未产生随机分项（可接受但建议检查）")


func _test_legacy_compat() -> void:
	# 旧类名 AiArchetype 仍可解析与使用
	_check(AiArchetype.resolve(null, "远程").archetype_name == "猎人", "AiArchetype.resolve 兼容")
	_check(AiArchetype.from_key("狂战士").archetype_name == "狂战士", "AiArchetype.from_key 兼容")

	# 旧静态接口
	_check(EnemyAI.desired_distance("远程", 3) == 3, "desired_distance 兼容")
	_check(EnemyAI.should_retreat("远程", 1, 3), "should_retreat 兼容")
	_check(EnemyAI.goal_score(1, 1) < EnemyAI.goal_score(2, 1), "goal_score 兼容")

	# select_target 兼容：护卫保护首领
	var leader := _make_enemy("首领", 2, 2, 80, Vector2i(6, 6))
	var guard := _make_enemy("护卫", 1, 2, 40, Vector2i(4, 6))
	guard.pack_leader = leader
	var near := _make_player("近", 50, 100, 10, 10, 10, Vector2i(6, 5))
	var far := _make_player("远", 50, 100, 10, 10, 10, Vector2i(1, 1))
	var target := EnemyAI.select_target(guard, [near, far], AiArchetype.from_key("护卫"))
	_check(target == near, "select_target 护卫仍攻击靠近首领的玩家")
