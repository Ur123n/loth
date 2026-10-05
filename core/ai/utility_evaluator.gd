class_name AiUtilityEvaluator
extends RefCounted

## Utility 评分（《敌怪ai逻辑.txt》第 8-19 节）。
##
## Utility = BaseScore + TargetScore + PositionScore + ContextScore + PersonalityScore
##         + UrgencyScore + RandomVariation
## 并非所有 Action 都必须使用全部评分项；每个候选记录分项与原因，保证可解释（调试面板展示）。
## 随机只用于在多个合理选择之间制造变化，不能导致 AI 无视必杀机会（Kill Potential 分项兜底）。

## 各行动基础评分（第 9 节：Attack=30、Heal=20、Buff=15、Move=5 的量级，×3 放大到行动分尺度）。
const BASE_SCORES := {
	"attack": 30, "approach": 15, "chase": 15, "retreat": 12,
	"protect": 18, "support": 20, "wait": 5,
}


## 对候选进行 Utility 评分并写入 candidate.score / components / reason。
## ctx 字段：unit / profile / goal / players / allies / dist / attack_range / rng（可选）。
static func score(candidate: ActionCandidate, ctx: Dictionary) -> void:
	var unit: BattleUnit = ctx.get("unit")
	var profile: AiProfile = ctx.get("profile")
	var goal: String = ctx.get("goal", AiGoal.ATTACK_PLAYER)
	var players: Array = ctx.get("players", [])
	var allies: Array = ctx.get("allies", [])
	var target: BattleUnit = candidate.target
	var dist: int = ctx.get("dist", 999)
	var attack_range: int = ctx.get("attack_range", 1)
	var parts: Array[String] = []

	var base := int(BASE_SCORES.get(candidate.action_key, 5)) * 3
	var target_s := 0
	var context := 0
	var personality := 0
	var urgency := 0

	match candidate.action_key:
		"attack":
			var kill := target != null and target.current_hp <= AiTargetSelector.expected_damage(unit)
			var hp_low := target != null and target.current_hp * 100 <= target.get_max_hp_value() * 35
			target_s += AiTargetSelector.estimate_threat(target) / 4
			if kill:
				target_s += 45
				parts.append("可击杀 +45")
			if hp_low:
				target_s += 18
				parts.append("目标低生命 +18")
			if goal == AiGoal.KILL_TARGET:
				urgency += 10
				parts.append("集火目标 +10")
			if _enraged(unit, profile):
				context += 20
				parts.append("Boss 狂暴 +20")
			personality += int(profile.aggression * 0.35)
		"approach", "chase":
			var hp_low_a := target != null and target.current_hp * 100 <= target.get_max_hp_value() * 35
			if profile.chases and hp_low_a:
				context += 25
				parts.append("追击低生命 +25")
			var distance_penalty := maxi(0, dist - attack_range - 2) * 8
			if distance_penalty > 0:
				context -= distance_penalty
				parts.append("距离过远 -%d" % distance_penalty)
			if _enraged(unit, profile):
				context += 20
				parts.append("Boss 狂暴 +20")
			if target != null and target.current_hp <= AiTargetSelector.expected_damage(unit):
				urgency += 15
				parts.append("目标可击杀，加速接近 +15")
			personality += int(profile.aggression * 0.4 + profile.mobility * 0.1)
		"retreat":
			var adjacent := AiPositionEvaluator.adjacent_player_count(unit, players)
			personality += int(profile.caution * 0.5 - profile.aggression * 0.3 + profile.defensiveness * 0.1)
			if adjacent > 0:
				context += adjacent * 30
				parts.append("被贴脸 +%d" % (adjacent * 30))
			if unit.current_hp * 100 <= unit.get_max_hp_value() * 40:
				context += 20
				parts.append("自身低生命 +20")
			if profile.kites and dist < attack_range:
				context += 40
				parts.append("保持射程 +40")
			if profile.kites and adjacent > 0:
				context += 30
			if profile.kites and dist <= 1:
				context += 60
				parts.append("被贴身 +60")
			if adjacent > 0 and profile.caution >= 50:
				urgency += 10
		"protect":
			personality += int(profile.support * 0.8)
			target_s += 10
			var leader := unit.pack_leader
			if leader != null and leader.current_hp > 0:
				var nearest := AiTargetSelector.nearest_player_to(players, leader.hex_coords)
				if nearest != null:
					var ld := HexGrid.hex_distance(leader.hex_coords, nearest.hex_coords)
					if ld <= 2:
						var danger := 80 - ld * 20
						context += danger
						urgency += 15
						parts.append("首领受威胁 +%d" % danger)
		"support":
			personality += int(profile.support * 0.8)
			var wounded := AiGoal.most_wounded_ally(unit, allies)
			if wounded != null:
				var missing_ratio := 1.0 - float(wounded.current_hp) / maxf(1.0, float(wounded.get_max_hp_value()))
				target_s += int(missing_ratio * 40)
				context += 20
				if missing_ratio > 0.65:
					urgency += 10
					parts.append("友军濒危 +10")
				else:
					parts.append("友军受伤 +20")
		"wait":
			personality += int(profile.caution * 0.12 - profile.aggression * 0.1)

	var position_s := int(candidate.params.get("position_score", 0))
	var random := 0
	var rng = ctx.get("rng")
	if rng != null:
		random = (rng as RandomNumberGenerator).randi_range(-6, 6)

	candidate.components = {
		"base": base,
		"target": target_s,
		"position": position_s,
		"context": context,
		"personality": personality,
		"urgency": urgency,
		"random": random,
	}
	candidate.score = base + target_s + position_s + context + personality + urgency + random
	candidate.reason = "；".join(parts) if not parts.is_empty() else "常规"


## Boss 半血狂暴判定（首领模板专属规则）。
static func _enraged(unit: BattleUnit, profile: AiProfile) -> bool:
	return profile.is_boss and unit.current_hp * 2 <= unit.get_max_hp_value()
