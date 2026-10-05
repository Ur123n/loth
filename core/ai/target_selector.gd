class_name AiTargetSelector
extends RefCounted

## 目标选择（《敌怪ai逻辑.txt》第 10-12、21 节）。
##
## 回答“打谁？”：按 TargetPriority（最近/低生命/高威胁/孤立/后排/可击杀/均衡）评分，
## 并叠加 Kill Potential（可直接击杀的目标明显加分），而不是简单固定“最近的人”。
## 玩家威胁（Threat）是动态估值：伤害能力 + 辅助能力 + 当前状态（易伤等），不简单等于攻击力。

## 玩家威胁估值：30 + 力量×2 + 敏捷 + 意志（高意志角色（法师类）威胁更高，符合“先杀后排”直觉）
## + 装备伤害修正 + 易伤状态（更容易被击穿）。
static func estimate_threat(player: BattleUnit) -> int:
	var cd := player.character_data
	if cd == null:
		return 40
	var threat := 30 + cd.strength * 2 + cd.agility + cd.willpower
	threat += int(cd.get_equipment_mod_total("attack_damage_pct") / 10.0)
	if _has_buff(player, "易伤"):
		threat += 20
	return threat


## 期望伤害（攻击下限+上限取平均，用于“能否击杀”预估，避免随机抖动）。
static func expected_damage(unit: BattleUnit) -> int:
	if unit.enemy_data == null:
		return unit.get_attack_damage()
	return (unit.enemy_data.attack_min + unit.enemy_data.attack_max) / 2


## 主入口：按当前 Goal 与 TargetPriority 选择目标。
static func pick(unit: BattleUnit, players: Array, profile: AiProfile, goal: String) -> BattleUnit:
	if unit == null or players.is_empty():
		return null
	match goal:
		AiGoal.KILL_TARGET:
			var killable := _find_killable_target(unit, players, profile)
			if killable != null:
				return killable
		AiGoal.PROTECT_LEADER:
			var leader := unit.pack_leader
			if leader != null and leader.current_hp > 0:
				var nearest := nearest_player_to(players, leader.hex_coords)
				if nearest != null:
					return nearest
	var best: BattleUnit = null
	var best_score := -(1 << 30)
	for player in players:
		if player.current_hp <= 0:
			continue
		var score := target_score(unit, player, players, profile)
		if score > best_score:
			best_score = score
			best = player
	return best


## 目标评分：威胁 + 生命/距离/孤立/可击杀修正，按 TargetPriority 加权。
static func target_score(unit: BattleUnit, player: BattleUnit, players: Array, profile: AiProfile) -> int:
	var threat := estimate_threat(player)
	var dist := HexGrid.hex_distance(unit.hex_coords, player.hex_coords)
	var hp_ratio := float(player.current_hp) / maxf(1.0, float(player.get_max_hp_value()))
	var score := threat
	match profile.target_priority:
		AiProfile.PRIORITY_LOWEST_HP, AiProfile.PRIORITY_KILLABLE:
			score += int((1.0 - hp_ratio) * 60)
			score -= dist * 2
		AiProfile.PRIORITY_HIGHEST_THREAT, AiProfile.PRIORITY_BACKLINE:
			# 后排猎杀：距离越远越像后排，给距离加分
			score += mini(dist, 8) * (3 if profile.targets_isolated else 1)
		AiProfile.PRIORITY_NEAREST:
			score -= dist * 3
		AiProfile.PRIORITY_ISOLATED:
			score -= dist * 2
		_:
			score -= dist * 2
	if player.current_hp <= expected_damage(unit):
		score += 50
	if profile.targets_isolated:
		score += _isolation_bonus(player, players)
	return score


## 最近的可击杀目标（Kill Potential 第 12 节）。
static func _find_killable_target(unit: BattleUnit, players: Array, profile: AiProfile) -> BattleUnit:
	var expected := expected_damage(unit)
	var attack_range := unit.get_attack_range()
	var best: BattleUnit = null
	var best_dist := 1 << 30
	for player in players:
		if player.current_hp <= 0 or player.current_hp > expected:
			continue
		var d := HexGrid.hex_distance(unit.hex_coords, player.hex_coords)
		if profile.kites and d > attack_range:
			continue
		if d < best_dist:
			best_dist = d
			best = player
	return best


## 孤立加成：目标周围（2 格内）存活玩家越少越孤立（第 10 节）。
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


static func nearest_player_to(players: Array, anchor: Vector2i) -> BattleUnit:
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


static func _has_buff(unit: BattleUnit, buff_name: String) -> bool:
	if unit == null:
		return false
	for buff in unit.buffs:
		if buff is Dictionary and str(buff.get("name", "")) == buff_name:
			return true
	return false
