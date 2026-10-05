class_name AiGoal
extends RefCounted

## 战术目标（《敌怪ai逻辑.txt》第 22 节 Goal）。
##
## Goal 决定 Utility 的大方向，而不是直接规定唯一行动。
## 例如 Goal = ProtectPriest 时，靠近祭司、拦截敌人、攻击接近祭司的目标都会获得更高评分。
## Goal 只需在敌怪准备行动时解析一次，不需要每帧计算。

const ATTACK_PLAYER := "AttackPlayer"       # 常规进攻
const KILL_TARGET := "KillTarget"           # 集火可击杀目标
const PROTECT_LEADER := "ProtectLeader"     # 保护本队首领
const PROTECT_WOUNDED := "ProtectWounded"   # 支援受伤友军
const MAINTAIN_RANGE := "MaintainRange"     # 保持射程（风筝）
const SURVIVE := "Survive"                  # 保命（撤退/回避）
const HOLD := "Hold"                        # 无 AI（木桩/尸骸）


## 解析敌怪当前战术目标。players = 存活玩家；allies = 全部敌怪（含尸骸，供支援参考）。
static func resolve(unit: BattleUnit, profile: AiProfile, players: Array, allies: Array) -> String:
	if unit == null or profile.inert:
		return HOLD
	if profile.protects_leader:
		var leader := unit.pack_leader
		if leader != null and leader.current_hp > 0:
			return PROTECT_LEADER
	if profile.protects_wounded and most_wounded_ally(unit, allies) != null:
		return PROTECT_WOUNDED
	if _has_killable_target(unit, players, profile):
		return KILL_TARGET
	if profile.kites:
		return MAINTAIN_RANGE
	if not profile.never_retreats and profile.caution >= 45 \
			and unit.current_hp * 100 <= unit.get_max_hp_value() * 40:
		return SURVIVE
	return ATTACK_PLAYER


## 是否有值得集火的可击杀目标（低血且可一击击杀）。
static func _has_killable_target(unit: BattleUnit, players: Array, profile: AiProfile) -> bool:
	var expected := AiTargetSelector.expected_damage(unit)
	var attack_range := unit.get_attack_range()
	for player in players:
		if player.current_hp <= 0:
			continue
		if player.current_hp > expected:
			continue
		# 风筝型不会为了击杀冲进近战；只有目标已在射程内才进入集火目标
		if profile.kites and HexGrid.hex_distance(unit.hex_coords, player.hex_coords) > attack_range:
			continue
		return true
	return false


## 场上最需要支援的友军（受伤最重；排除自己与已倒下单位）。
static func most_wounded_ally(unit: BattleUnit, allies: Array) -> BattleUnit:
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


## 目标的中文展示名（调试面板用）。
static func display_name(goal: String) -> String:
	match goal:
		KILL_TARGET:
			return "集火可击杀目标"
		PROTECT_LEADER:
			return "保护首领"
		PROTECT_WOUNDED:
			return "支援受伤友军"
		MAINTAIN_RANGE:
			return "保持射程"
		SURVIVE:
			return "保命"
		HOLD:
			return "无行动"
		_:
			return "进攻玩家"
