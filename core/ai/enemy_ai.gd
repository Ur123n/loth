class_name EnemyAI
extends RefCounted

## 敌怪 AI 决策引擎（纯逻辑，可无头测试）。
## 架构（《敌怪ai逻辑.txt》）：AIProfile → Goal → Conditions → ActionCandidates
## → Target Selection → Position Selection → Utility Evaluation → Best Action
## → 提交 battle_map 执行（BattleManager → EffectSystem → BattleState）。
##
## AI 只负责“选择行动”，不直接修改 HP/Buff/位置等任何战斗数据；
## 决策单位是 ActionCandidate（Action + Target + Position + Parameters）。
## 每次执行行动后由 battle_map 重新调用 decide 重新评估战场（不跨回合缓存）。
## 调试面板（F4 / 点击敌怪）可查看 Goal、候选行动与 Utility 分项。
##
## 保留旧静态接口（desired_distance / is_ranged / should_retreat / goal_score /
## select_target / estimate_threat / expected_damage）供测试与兼容。

const MOVE_ACTIONS := ["approach", "chase", "retreat", "protect", "support"]


## ---------- 旧接口（兼容，仍被 tests/test_enemy_packs.gd 使用） ----------

## 角色对应的期望站位距离（格）：远程=射程边缘，侧翼=2，其余贴身。
static func desired_distance(role: String, attack_range: int) -> int:
	match role:
		"远程":
			return maxi(attack_range, 1)
		"侧翼":
			return 2
		_:
			return 1


static func is_ranged(role: String) -> bool:
	return role == "远程"


## 远程角色贴脸时应先拉开距离。
static func should_retreat(role: String, dist: int, attack_range: int) -> bool:
	return is_ranged(role) and attack_range > 1 and dist < attack_range


## 站位评分：距离越接近期望站位越好（先满足期望距离，其次越近越好）。
static func goal_score(d: int, desired: int) -> int:
	return AiPositionEvaluator.position_cost(d, desired)


## 玩家威胁估值（动态，见 AiTargetSelector.estimate_threat）。
static func estimate_threat(player: BattleUnit) -> int:
	return AiTargetSelector.estimate_threat(player)


## 期望伤害（攻击下限+上限取平均，用于“能否击杀”预估）。
static func expected_damage(unit: BattleUnit) -> int:
	return AiTargetSelector.expected_damage(unit)


## 旧版目标选择入口（兼容测试）：按 Goal + TargetPriority 评分选目标。
static func select_target(unit: BattleUnit, players: Array, archetype: AiProfile) -> BattleUnit:
	var goal := AiGoal.resolve(unit, archetype, players, [])
	return AiTargetSelector.pick(unit, players, archetype, goal)


## ---------- 新决策引擎（《敌怪ai逻辑.txt》第 31 节推荐接口） ----------

## 生成全部行动候选（含目标、位置与 Utility 分项），供 evaluate / decide 使用。
## players = 存活玩家单位；allies = 全部敌怪单位（含尸骸，供支援/护卫参考）。
## rng 传入时为决策加入小幅随机变化（不传则确定性评分，便于测试）。
static func get_action_candidates(unit: BattleUnit, players: Array, allies: Array,
		map_data: BattleMapData, occupied: Dictionary, rng: RandomNumberGenerator = null) -> Array[ActionCandidate]:
	var result: Array[ActionCandidate] = []
	if unit == null or players.is_empty():
		return result
	var profile := AiProfile.resolve(unit.enemy_data, unit.pack_role)
	if profile.inert:
		return result
	var goal := AiGoal.resolve(unit, profile, players, allies)
	var target := AiTargetSelector.pick(unit, players, profile, goal)
	if target == null:
		return result
	var dist := HexGrid.hex_distance(unit.hex_coords, target.hex_coords)
	var attack_range := unit.get_attack_range()
	var reachable := _compute_reachable(unit, map_data, occupied)
	var ctx := {
		"unit": unit, "profile": profile, "goal": goal,
		"players": players, "allies": allies,
		"dist": dist, "attack_range": attack_range, "rng": rng,
	}
	result.append(_attack_candidate(unit, target, ctx))
	result.append(_approach_candidate(unit, target, profile, ctx, reachable, map_data, occupied))
	result.append(_retreat_candidate(unit, target, profile, ctx, reachable, map_data, occupied))
	result.append(_protect_candidate(unit, target, profile, ctx, reachable, map_data, occupied))
	result.append(_support_candidate(unit, target, profile, ctx, allies, reachable, map_data, occupied))
	result.append(_skill_candidate(unit))
	result.append(_wait_candidate(unit, ctx))
	return result


## 从候选列表选择 Utility 最高的行动（第 8 节）。
static func evaluate(candidates: Array) -> ActionCandidate:
	if candidates.is_empty():
		return null
	var best: ActionCandidate = candidates[0]
	for cand in candidates:
		if cand.score > best.score:
			best = cand
	return best


## 完整决策：返回 {action, action_key, goal, target, move_cell, path, score,
## archetype, candidates, explain}，由 battle_map 执行。
static func decide(unit: BattleUnit, players: Array, allies: Array,
		map_data: BattleMapData, occupied: Dictionary,
		rng: RandomNumberGenerator = null) -> Dictionary:
	if unit == null or unit.is_corpse or unit.is_removed or players.is_empty():
		return _wait_decision(unit, "无目标或无法行动")
	var profile := AiProfile.resolve(unit.enemy_data, unit.pack_role)
	if profile.inert:
		return _wait_decision(unit, "木桩 / 无 AI")
	var candidates := get_action_candidates(unit, players, allies, map_data, occupied, rng)
	var best := evaluate(candidates)
	if best == null:
		return _wait_decision(unit, "找不到目标")
	candidates.sort_custom(func(a: ActionCandidate, b: ActionCandidate) -> bool:
		return a.score > b.score)
	var goal := AiGoal.resolve(unit, profile, players, allies)
	var decision := {
		"action": best.label,
		"action_key": best.action_key,
		"goal": AiGoal.display_name(goal),
		"target": best.target,
		"move_cell": best.move_cell,
		"path": best.path,
		"score": best.score,
		"archetype": profile.archetype_name,
		"candidates": _summaries(candidates),
		"explain": best.reason,
	}
	if best.action_key in MOVE_ACTIONS \
			and (best.path as Array).is_empty() and best.move_cell == unit.hex_coords:
		# 无可移动目标格 → 原地等待（保留原行动名便于调试）
		decision["action"] = "等待"
		decision["action_key"] = "wait"
		decision["explain"] = "无可到达的合适位置（%s）" % best.reason
		decision["score"] = 0
	return decision


## ---------- 候选构建 ----------

static func _attack_candidate(unit: BattleUnit, target: BattleUnit, ctx: Dictionary) -> ActionCandidate:
	var cand := ActionCandidate.new("attack", "攻击", target)
	cand.move_cell = unit.hex_coords
	var cond := AiConditionEvaluator.can_attack(target, int(ctx["dist"]), int(ctx["attack_range"]))
	if not bool(cond.get("ok", false)):
		cand.reason = str(cond.get("reason", "条件不满足"))
		return cand
	AiUtilityEvaluator.score(cand, ctx)
	return cand


static func _approach_candidate(unit: BattleUnit, target: BattleUnit, profile: AiProfile,
		ctx: Dictionary, reachable: Dictionary, map_data: BattleMapData, occupied: Dictionary) -> ActionCandidate:
	var chase := profile.chases and target.current_hp * 100 <= target.get_max_hp_value() * 35
	var cand := ActionCandidate.new("chase" if chase else "approach", "追击" if chase else "接近", target)
	var cond := AiConditionEvaluator.can_approach(target, int(ctx["dist"]), int(ctx["attack_range"]), unit)
	if not bool(cond.get("ok", false)):
		cand.reason = str(cond.get("reason", "条件不满足"))
		cand.move_cell = unit.hex_coords
		return cand
	var plan := AiPositionEvaluator.plan(unit, cand.action_key, target.hex_coords,
		profile.desired_distance_for(int(ctx["attack_range"])), profile, ctx["players"],
		map_data, occupied, reachable)
	cand.move_cell = plan.get("move_cell", unit.hex_coords)
	cand.path = plan.get("path", [])
	cand.params["position_score"] = int(plan.get("position_score", 0))
	AiUtilityEvaluator.score(cand, ctx)
	return cand


static func _retreat_candidate(unit: BattleUnit, target: BattleUnit, profile: AiProfile,
		ctx: Dictionary, reachable: Dictionary, map_data: BattleMapData, occupied: Dictionary) -> ActionCandidate:
	var cand := ActionCandidate.new("retreat", "撤退", target)
	var cond := AiConditionEvaluator.can_retreat(profile, unit)
	if not bool(cond.get("ok", false)):
		cand.reason = str(cond.get("reason", "性格不倾向撤退"))
		cand.move_cell = unit.hex_coords
		return cand
	# 非风筝型撤退：越远越好；风筝型：退到射程边缘即可
	var desired := profile.desired_distance_for(int(ctx["attack_range"])) if profile.kites else 999
	var plan := AiPositionEvaluator.plan(unit, "retreat", target.hex_coords,
		desired, profile, ctx["players"], map_data, occupied, reachable)
	cand.move_cell = plan.get("move_cell", unit.hex_coords)
	cand.path = plan.get("path", [])
	cand.params["position_score"] = int(plan.get("position_score", 0))
	AiUtilityEvaluator.score(cand, ctx)
	return cand


static func _protect_candidate(unit: BattleUnit, target: BattleUnit, profile: AiProfile,
		ctx: Dictionary, reachable: Dictionary, map_data: BattleMapData, occupied: Dictionary) -> ActionCandidate:
	var cand := ActionCandidate.new("protect", "保护", target)
	var cond := AiConditionEvaluator.can_protect(profile, unit)
	if not bool(cond.get("ok", false)):
		cand.reason = str(cond.get("reason", "非护卫"))
		cand.move_cell = unit.hex_coords
		return cand
	var leader := unit.pack_leader
	var plan := AiPositionEvaluator.plan(unit, "protect", leader.hex_coords,
		1, profile, ctx["players"], map_data, occupied, reachable)
	cand.move_cell = plan.get("move_cell", unit.hex_coords)
	cand.path = plan.get("path", [])
	cand.params["position_score"] = int(plan.get("position_score", 0))
	AiUtilityEvaluator.score(cand, ctx)
	return cand


static func _support_candidate(unit: BattleUnit, target: BattleUnit, profile: AiProfile,
		ctx: Dictionary, allies: Array, reachable: Dictionary,
		map_data: BattleMapData, occupied: Dictionary) -> ActionCandidate:
	var cand := ActionCandidate.new("support", "支援", target)
	var cond := AiConditionEvaluator.can_support(profile, unit, allies)
	if not bool(cond.get("ok", false)):
		cand.reason = str(cond.get("reason", "非支援型"))
		cand.move_cell = unit.hex_coords
		return cand
	var wounded := AiGoal.most_wounded_ally(unit, allies)
	var plan := AiPositionEvaluator.plan(unit, "support", wounded.hex_coords,
		1, profile, ctx["players"], map_data, occupied, reachable)
	cand.move_cell = plan.get("move_cell", unit.hex_coords)
	cand.path = plan.get("path", [])
	cand.params["position_score"] = int(plan.get("position_score", 0))
	AiUtilityEvaluator.score(cand, ctx)
	return cand


static func _skill_candidate(unit: BattleUnit) -> ActionCandidate:
	var cand := ActionCandidate.new("skill", "使用技能", null)
	cand.move_cell = unit.hex_coords
	var skills: Array = unit.enemy_data.skills if unit.enemy_data != null else []
	cand.reason = "技能集待接入 ActionSystem（%d 个）" % skills.size() if not skills.is_empty() \
		else "暂无技能（SkillSet 预留）"
	return cand


static func _wait_candidate(unit: BattleUnit, ctx: Dictionary) -> ActionCandidate:
	var cand := ActionCandidate.new("wait", "等待", null)
	cand.move_cell = unit.hex_coords
	AiUtilityEvaluator.score(cand, ctx)
	if cand.reason == "常规":
		cand.reason = "观望"
	return cand


static func _summaries(candidates: Array) -> Array:
	var result: Array = []
	for cand in candidates:
		result.append((cand as ActionCandidate).summarize())
	return result


static func _compute_reachable(unit: BattleUnit, map_data: BattleMapData, occupied: Dictionary) -> Dictionary:
	if map_data == null or unit.get_max_move_points() <= 0:
		return {}
	return map_data.compute_reachable(unit.hex_coords, unit.get_max_move_points(), occupied, unit)


static func _wait_decision(unit: BattleUnit, reason: String) -> Dictionary:
	return {
		"action": "等待",
		"action_key": "wait",
		"goal": AiGoal.display_name(AiGoal.HOLD),
		"target": null,
		"move_cell": unit.hex_coords if unit != null else Vector2i(-1, -1),
		"path": [],
		"score": 0,
		"archetype": AiProfile.resolve(unit.enemy_data, unit.pack_role).archetype_name if unit != null else "",
		"candidates": [],
		"explain": reason,
	}
