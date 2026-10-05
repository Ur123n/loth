class_name AiConditionEvaluator
extends RefCounted

## 条件判定（《敌怪ai逻辑.txt》第 7 节 Conditions）。
##
## 回答“这个行动能不能做”，而不是“值不值得做”：
## HealAlly → AllyHP < 70%；BloodRitual → SelfHP > 30% 且未狂暴；
## PoisonCloud → 区域内敌人 >= 2；Summon → 召唤数 < 上限。
## 条件不满足的行动只保留 0 分壳候选（评分原因写明被拒条件），不生成目标/位置。

static func can_attack(target: BattleUnit, dist: int, attack_range: int) -> Dictionary:
	if target == null or target.current_hp <= 0:
		return {"ok": false, "reason": "目标无效"}
	if dist > attack_range:
		return {"ok": false, "reason": "目标不在攻击范围内（%d > %d）" % [dist, attack_range]}
	return {"ok": true, "reason": "目标在攻击范围内"}


static func can_approach(target: BattleUnit, dist: int, attack_range: int, unit: BattleUnit) -> Dictionary:
	if target == null or target.current_hp <= 0:
		return {"ok": false, "reason": "目标无效"}
	if dist <= attack_range:
		return {"ok": false, "reason": "目标已在攻击范围内"}
	if unit.get_max_move_points() <= 0:
		return {"ok": false, "reason": "无法移动"}
	return {"ok": true, "reason": "目标距离 %d 超出射程 %d" % [dist, attack_range]}


static func can_retreat(profile: AiProfile, unit: BattleUnit) -> Dictionary:
	if profile.never_retreats:
		return {"ok": false, "reason": "性格不倾向撤退"}
	if unit.get_max_move_points() <= 0:
		return {"ok": false, "reason": "无法移动"}
	return {"ok": true, "reason": "可尝试拉开距离"}


static func can_protect(profile: AiProfile, unit: BattleUnit) -> Dictionary:
	if not profile.protects_leader:
		return {"ok": false, "reason": "非护卫"}
	var leader := unit.pack_leader
	if leader == null or leader.current_hp <= 0:
		return {"ok": false, "reason": "首领已倒下"}
	return {"ok": true, "reason": "守护首领"}


static func can_support(profile: AiProfile, unit: BattleUnit, allies: Array) -> Dictionary:
	if not profile.protects_wounded:
		return {"ok": false, "reason": "非支援型"}
	if AiGoal.most_wounded_ally(unit, allies) == null:
		return {"ok": false, "reason": "无受伤友军"}
	return {"ok": true, "reason": "友军受伤，前往支援"}
