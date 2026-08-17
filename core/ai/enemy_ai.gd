class_name EnemyAI
extends RefCounted

## 敌怪 AI 决策引擎（纯逻辑，可无头测试）。
## 架构（《敌人 AI 重构方案》）：行为模板（Archetype）→ 战术目标 → 行动评分（Utility）
## → 六边形位置评价（Position Evaluation）→ 由 battle_map 执行。
## 设计原则：不追求“最聪明”，追求“可解释、可读懂”——每个决策带评分与原因，
## 调试面板（F4 / 点击敌怪）可查看“为什么它这么做”。
##
## 保留旧接口（desired_distance / is_ranged / should_retreat / goal_score）供测试与兼容。


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
	return absi(d - desired) * 1000 + d


## ---------- 新决策引擎 ----------

## 完整决策：返回 {action, target, move_cell, path, score, archetype, candidates, explain}。
## players = 存活玩家单位；allies = 全部敌怪单位（含尸骸，供支援/护卫参考）。
static func decide(unit: BattleUnit, players: Array, allies: Array,
		map_data: BattleMapData, occupied: Dictionary) -> Dictionary:
	if unit == null or unit.is_corpse or unit.is_removed or players.is_empty():
		return _wait_decision(unit, "无目标或无法行动")
	var archetype := AiArchetype.resolve(unit.enemy_data, unit.pack_role)
	if archetype.inert:
		return _wait_decision(unit, "木桩 / 无 AI")
	var target := select_target(unit, players, archetype)
	if target == null:
		return _wait_decision(unit, "找不到目标")
	var attack_range := unit.get_attack_range()
	var dist := HexGrid.hex_distance(unit.hex_coords, target.hex_coords)
	var candidates := _score_actions(unit, target, players, allies, archetype, dist, attack_range)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("score", 0)) > int(b.get("score", 0)))
	var best: Dictionary = candidates[0]
	var decision := {
		"action": str(best.get("action", "等待")),
		"target": target,
		"move_cell": unit.hex_coords,
		"path": [],
		"score": int(best.get("score", 0)),
		"archetype": archetype.archetype_name,
		"candidates": candidates,
		"explain": str(best.get("reason", "")),
	}
	if decision.action != "等待" and decision.action != "攻击":
		var plan := _plan_move(unit, decision, archetype, players, allies, map_data, occupied)
		decision["move_cell"] = plan.get("move_cell", unit.hex_coords)
		decision["path"] = plan.get("path", [])
		if (decision.path as Array).is_empty() and decision.move_cell == unit.hex_coords:
			# 无可移动目标格 → 原地等待（保留原行动名便于调试）
			decision["action"] = "等待"
			decision["explain"] = "无可到达的合适位置（%s）" % best.get("reason", "")
			decision["score"] = 0
	return decision


## 目标选择：护卫保护首领（打靠近首领的玩家）；其余按威胁评分选目标。
static func select_target(unit: BattleUnit, players: Array, archetype: AiArchetype) -> BattleUnit:
	if archetype.protects_leader:
		var leader := unit.pack_leader
		if leader != null and leader.current_hp > 0:
			return _nearest_player_to(players, leader.hex_coords)
	var best: BattleUnit = null
	var best_score := -(1 << 30)
	for player in players:
		if player.current_hp <= 0:
			continue
		var score := _target_score(unit, player, players, archetype)
		if score > best_score:
			best_score = score
			best = player
	return best


## 玩家威胁估值：30 + 力量×2 + 敏捷 + 意志（高意志角色（法师类）威胁更高，符合“先杀后排”直觉）。
static func estimate_threat(player: BattleUnit) -> int:
	var cd := player.character_data
	if cd == null:
		return 40
	return 30 + cd.strength * 2 + cd.agility + cd.willpower


## 期望伤害（攻击下限+上限取平均，用于“能否击杀”预估，避免随机抖动）。
static func expected_damage(unit: BattleUnit) -> int:
	if unit.enemy_data == null:
		return unit.get_attack_damage()
	return (unit.enemy_data.attack_min + unit.enemy_data.attack_max) / 2


## 目标评分：威胁 + 生命/距离/孤立/可击杀修正，按性格加权。
static func _target_score(unit: BattleUnit, player: BattleUnit, players: Array, archetype: AiArchetype) -> int:
	var threat := estimate_threat(player)
	var dist := HexGrid.hex_distance(unit.hex_coords, player.hex_coords)
	var hp_ratio := float(player.current_hp) / maxf(1.0, float(player.get_max_hp_value()))
	var score := threat
	if archetype.prefers_low_hp:
		score += int((1.0 - hp_ratio) * 60)
	if archetype.prefers_high_threat:
		# 后排猎杀：距离越远越像后排，给距离加分
		score += mini(dist, 8) * (3 if archetype.targets_isolated else 1)
	else:
		score -= dist * 2
	if player.current_hp <= expected_damage(unit):
		score += 50
	if archetype.targets_isolated:
		score += _isolation_bonus(player, players)
	return score


## 孤立加成：目标周围（2 格内）存活玩家越少越孤立。
static func _isolation_bonus(player: BattleUnit, players: Array) -> int:
	var near := 0
	for other in players:
		if other == player:
			continue
		if other.current_hp <= 0:
			continue
		if HexGrid.hex_distance(player.hex_coords, other.hex_coords) <= 2:
			near += 1
	return maxi(0, 4 - near) * 8


## 行动候选评分（战术层）。每个候选：{action, score, reason}。
static func _score_actions(unit: BattleUnit, target: BattleUnit, players: Array,
		allies: Array, archetype: AiArchetype, dist: int, attack_range: int) -> Array:
	var candidates: Array = []
	var aggression := archetype.aggression
	var caution := archetype.caution
	var enraged := archetype.is_boss and unit.current_hp * 2 <= unit.get_max_hp_value()
	var can_attack := dist <= attack_range

	# 攻击
	if can_attack:
		var score := 120 + int(aggression * 0.35)
		var kill := target.current_hp <= expected_damage(unit)
		var hp_low := target.current_hp * 100 <= target.get_max_hp_value() * 35
		var parts: Array[String] = ["目标在攻击范围内"]
		if kill:
			score += 40
			parts.append("可击杀 +40")
		if hp_low:
			score += 15
			parts.append("目标低生命 +15")
		if enraged:
			score += 20
			parts.append("Boss 狂暴 +20")
		candidates.append({"action": "攻击", "score": score, "reason": "；".join(parts)})
	else:
		candidates.append({"action": "攻击", "score": 0, "reason": "目标不在攻击范围内"})

	# 接近 / 追击
	var approach := 60 + int(aggression * 0.4)
	var chase := 0
	if archetype.chases and target.current_hp * 100 <= target.get_max_hp_value() * 35:
		chase = 25
		approach += chase
	var distance_penalty := maxi(0, dist - attack_range - 2) * 8
	approach -= distance_penalty
	if enraged:
		approach += 20
	var approach_parts: Array[String] = ["向目标移动（距离 %d / 攻击范围 %d）" % [dist, attack_range]]
	if chase > 0:
		approach_parts.append("追击低生命 +25")
	if distance_penalty > 0:
		approach_parts.append("距离过远 -%d" % distance_penalty)
	if enraged:
		approach_parts.append("Boss 狂暴 +20")
	candidates.append({
		"action": "追击" if chase > 0 else "接近",
		"score": maxi(approach, 0),
		"reason": "；".join(approach_parts),
	})

	# 撤退（性格决定；狂战士/鲁莽/护卫/首领永不撤退）
	var retreat := 0
	if not archetype.never_retreats:
		retreat = int(caution * 0.5) - int(aggression * 0.3)
		var adjacent := _adjacent_player_count(unit, players)
		retreat += adjacent * 30
		if unit.current_hp * 100 <= unit.get_max_hp_value() * 40:
			retreat += 20
		if archetype.kites and dist < attack_range:
			retreat += 40
		if archetype.kites and adjacent > 0:
			retreat += 30
		# 风筝型被贴脸（1 格）：优先拉开距离而非原地攻击（可击杀除外，攻击分更高）
		if archetype.kites and dist <= 1:
			retreat += 60
	var retreat_parts: Array[String] = ["谨慎 %d - 进攻 %d" % [int(caution * 0.5), int(aggression * 0.3)]]
	if _adjacent_player_count(unit, players) > 0:
		retreat_parts.append("被贴脸")
	if archetype.kites and dist < attack_range:
		retreat_parts.append("保持射程")
	candidates.append({
		"action": "撤退",
		"score": maxi(retreat, 0),
		"reason": "；".join(retreat_parts) if retreat > 0 else "性格不倾向撤退",
	})

	# 保护（护卫：围绕首领站位/攻击靠近首领的玩家）
	if archetype.protects_leader:
		var protect_score := int(archetype.protectiveness * 0.8)
		var leader := unit.pack_leader
		var leader_danger := 0
		if leader != null:
			var nearest := _nearest_player_to(players, leader.hex_coords)
			if nearest != null:
				var ld := HexGrid.hex_distance(leader.hex_coords, nearest.hex_coords)
				if ld <= 2:
					leader_danger = 80 - ld * 20
		protect_score += leader_danger
		var protect_parts: Array[String] = ["守护首领"]
		if leader_danger > 0:
			protect_parts.append("首领受威胁 +%d" % leader_danger)
		candidates.append({"action": "保护", "score": protect_score, "reason": "；".join(protect_parts)})
	else:
		candidates.append({"action": "保护", "score": 0, "reason": "非护卫"})

	# 支援（贴近受伤友军；祭司类预留）
	if archetype.protects_wounded:
		var wounded := _most_wounded_ally(unit, allies)
		if wounded != null and wounded.current_hp < wounded.get_max_hp_value():
			candidates.append({"action": "支援", "score": 70, "reason": "友军受伤，前往支援"})
		else:
			candidates.append({"action": "支援", "score": 0, "reason": "无受伤友军"})
	else:
		candidates.append({"action": "支援", "score": 0, "reason": "非支援型"})

	# 使用技能（SkillSet 预留：敌人拥有技能集而非玩家式牌组）
	candidates.append({"action": "使用技能", "score": 0, "reason": "暂无技能（SkillSet 预留）"})

	# 等待
	var wait := 8 + int(caution * 0.12) - int(aggression * 0.1)
	candidates.append({"action": "等待", "score": maxi(wait, 0), "reason": "观望"})
	return candidates


## 位置评价（行动层）：在移动力内选最符合“期望站位”的可达格。
static func _plan_move(unit: BattleUnit, decision: Dictionary, archetype: AiArchetype,
		players: Array, allies: Array, map_data: BattleMapData, occupied: Dictionary) -> Dictionary:
	var action := str(decision.get("action", ""))
	var target: BattleUnit = decision.get("target")
	var anchor: Vector2i = target.hex_coords if target != null else unit.hex_coords
	var desired := archetype.desired_distance_for(unit.get_attack_range())
	if action == "保护" and unit.pack_leader != null:
		anchor = unit.pack_leader.hex_coords
		desired = 1
	elif action == "支援":
		var wounded := _most_wounded_ally(unit, allies)
		if wounded != null:
			anchor = wounded.hex_coords
			desired = 1
	var budget := unit.get_max_move_points()
	var reachable: Dictionary = map_data.compute_reachable(unit.hex_coords, budget, occupied, unit)
	var best_cell := unit.hex_coords
	var best_score := 1 << 30
	var current_dist := HexGrid.hex_distance(unit.hex_coords, anchor)
	for cell in reachable:
		var d := HexGrid.hex_distance(cell, anchor)
		if action == "撤退" and d <= current_dist:
			continue
		var score := goal_score(d, desired)
		# 危险惩罚：谨慎型避免进入玩家相邻格
		var danger := _adjacent_player_count_at(cell, players)
		score += int(danger * 70 * (archetype.caution / 100.0))
		# 保护站位：护卫在围绕首领的同时靠近最近的玩家（阻挡）
		if action == "保护":
			var nearest := _nearest_player_to(players, cell)
			if nearest != null:
				score += HexGrid.hex_distance(cell, nearest.hex_coords) * 20
		if score < best_score:
			best_score = score
			best_cell = cell
	if best_cell == unit.hex_coords:
		return {"move_cell": best_cell, "path": []}
	var path_data: Dictionary = map_data.find_movement_path(
		unit.hex_coords, best_cell, budget, occupied, unit)
	return {
		"move_cell": best_cell,
		"path": path_data.get("path", []),
	}


static func _wait_decision(unit: BattleUnit, reason: String) -> Dictionary:
	return {
		"action": "等待",
		"target": null,
		"move_cell": unit.hex_coords if unit != null else Vector2i(-1, -1),
		"path": [],
		"score": 0,
		"archetype": AiArchetype.resolve(unit.enemy_data, unit.pack_role).archetype_name if unit != null else "",
		"candidates": [],
		"explain": reason,
	}


## 单位相邻的存活玩家数（用于撤退/危险评估）。
static func _adjacent_player_count(unit: BattleUnit, players: Array) -> int:
	var count := 0
	for player in players:
		if player.current_hp <= 0:
			continue
		if HexGrid.hex_distance(unit.hex_coords, player.hex_coords) <= 1:
			count += 1
	return count


## 某格相邻的存活玩家数（位置评价的危险惩罚）。
static func _adjacent_player_count_at(cell: Vector2i, players: Array) -> int:
	var count := 0
	for player in players:
		if player.current_hp <= 0:
			continue
		if HexGrid.hex_distance(cell, player.hex_coords) <= 1:
			count += 1
	return count


static func _nearest_player_to(players: Array, anchor: Vector2i) -> BattleUnit:
	var best: BattleUnit = null
	var best_dist := 1 << 30
	for player in players:
		if player.current_hp <= 0:
			continue
		var d := HexGrid.hex_distance(anchor, player.hex_coords)
		if d < best_dist:
			best_dist = d
			best = player
	return best


static func _most_wounded_ally(unit: BattleUnit, allies: Array) -> BattleUnit:
	var best: BattleUnit = null
	var best_ratio := 1.0
	for ally in allies:
		if ally == unit or ally.current_hp <= 0:
			continue
		var ratio := float(ally.current_hp) / maxf(1.0, float(ally.get_max_hp_value()))
		if ratio < best_ratio:
			best_ratio = ratio
			best = ally
	return best


## 辅助：把当前玩家的引用补进评分（隔离判定用）。保留函数以隔离玩家数组取值差异。
