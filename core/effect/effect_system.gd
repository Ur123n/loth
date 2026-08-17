class_name EffectSystem
extends RefCounted

## 效果结算系统（逻辑层，无场景依赖）。
## 接管战斗中的效果结算，battle_manager.gd 只保留回合流程与胜负战利品：
## - 卡牌效果：resolve_effects / resolve_attack（伤害、格挡、pierce）
## - buff 结算：resolve_buff_* 系列、buff 触发 / 衰减、按触发时机结算
## - 通用伤害：lose_hp / take_damage / heal_unit
## - 牌堆辅助：抽牌 / 弃牌 / 消耗 / 生成 / 复制 / 固有牌
## 通过 setup() 注入单位列表、RNG、卡牌查询与 BattleManager 的信号/回调，对外接口不变。

## 手牌上限（与 BattleManager 同步；GDD 第 11 节）。
const MAX_HAND_SIZE := 10

var _units: Array[BattleUnit] = []
var _rng: RandomNumberGenerator
var _card_lookup: Callable = Callable()
var _battle_log: Signal
var _hp_changed: Signal
var _unit_defeated: Signal
var _battle_over_check: Callable = Callable()


func setup(units: Array[BattleUnit], rng: RandomNumberGenerator, card_lookup: Callable,
		battle_log: Signal, hp_changed: Signal, unit_defeated: Signal,
		battle_over_check: Callable) -> void:
	_units = units
	_rng = rng
	_card_lookup = card_lookup
	_battle_log = battle_log
	_hp_changed = hp_changed
	_unit_defeated = unit_defeated
	_battle_over_check = battle_over_check


func _log(message: String) -> void:
	_battle_log.emit(message)


## 整数伤害计算：面板 * 基数 / 100。
## 玩家对敌怪向上取整；敌怪对玩家向下取整；结果不小于 0。
static func compute_damage(panel_value: int, basis: int, attacker_is_enemy: bool) -> int:
	var raw := panel_value * basis
	var damage := raw / 100
	if not attacker_is_enemy:
		damage = (raw + 99) / 100
	return maxi(damage, 0)


## 按 effects 顺序结算卡牌效果；挂载条件的效果在条件不满足时跳过。
func resolve_effects(unit: BattleUnit, card: CardData, target = null) -> void:
	for effect in card.effects:
		if not effect_condition_met(unit, effect):
			_log("「%s」的条件未满足，跳过效果" % card.card_name)
			continue
		if effect is AttackEffect:
			resolve_attack(unit, card, effect as AttackEffect, target)
		elif effect is MoveEffect:
			var move := effect as MoveEffect
			unit.remaining_move_points += move.distance
			_log("%s 获得额外移动力 %d（当前 %d/%d）" % [
				unit.get_display_name(), move.distance,
				unit.remaining_move_points, unit.get_max_move_points()])
		elif effect is DefenseEffect:
			var defense := effect as DefenseEffect
			var defense_value := defense.alt_value if (defense.alt_value > 0 and unit.moved_this_turn) else defense.value
			# 装备「防御卡格挡 ±N」修正（铁剑：攻强守弱）
			var equip_defend := unit.character_data.get_equipment_mod_total("defend_bonus") if unit.character_data != null else 0
			if equip_defend != 0:
				defense_value = maxi(defense_value + equip_defend, 0)
				_log("装备修正：%s 的防御卡格挡 %+d" % [unit.get_display_name(), equip_defend])
			unit.block_value += defense_value
			_log("%s 获得 %d 点格挡（当前 %d）" % [
				unit.get_display_name(), defense_value, unit.block_value])
			unit.refresh_block_display()
		elif effect is BuffEffect:
			resolve_buff_effect(unit, effect as BuffEffect, target)
		elif effect is DrawEffect:
			var draw := effect as DrawEffect
			draw_cards(unit, draw.value)
			_log("%s 抽 %d 张牌" % [unit.get_display_name(), draw.value])
		elif effect is DiscardEffect:
			resolve_discard_effect(unit, effect as DiscardEffect)
		elif effect is AddToHandEffect:
			var add_hand := effect as AddToHandEffect
			add_cards_to_pile(unit, "hand", add_hand.card_name, add_hand.value, "shuffle")
		elif effect is AddToDrawEffect:
			var add_draw := effect as AddToDrawEffect
			add_cards_to_pile(unit, "draw", add_draw.card_name, add_draw.value, add_draw.position)
		elif effect is AddToDiscardEffect:
			var add_discard := effect as AddToDiscardEffect
			add_cards_to_pile(unit, "discard", add_discard.card_name, add_discard.value, "shuffle")
		elif effect is GenerateEffect:
			resolve_generate_effect(unit, effect as GenerateEffect)
		elif effect is CopyEffect:
			var copy := effect as CopyEffect
			add_cards_to_pile(unit, copy.pile, card.card_name, copy.value, "shuffle")
			_log("%s 将「%s」的 %d 张复制品放入%s" % [
				unit.get_display_name(), card.card_name, copy.value, pile_label(copy.pile)])
		elif effect is LoseHpEffect:
			resolve_lose_hp_effect(unit, effect as LoseHpEffect, target)
		elif effect is GainEnergyEffect:
			var gain := effect as GainEnergyEffect
			unit.energy += gain.value
			_log("%s 获得 %d 点费用（当前 %d）" % [
				unit.get_display_name(), gain.value, unit.energy])
		elif effect is FlankEffect:
			var flank := effect as FlankEffect
			unit.flank_trigger_damage = maxi(unit.flank_trigger_damage, flank.value)
			_log("%s 获得「伺机」：本回合离开攻击范围时造成 %d 点伤害" % [
				unit.get_display_name(), flank.value])
		elif effect is KnockbackEffect:
			var knock := effect as KnockbackEffect
			unit.pending_knockback = maxi(unit.pending_knockback, knock.value)
			_log("%s 获得击退 %d 格效果" % [unit.get_display_name(), knock.value])


## 判断效果的挂载条件是否满足（无条件返回 true）。
func effect_condition_met(unit: BattleUnit, effect: Resource) -> bool:
	if not effect.has_meta("condition"):
		return true
	var condition: Dictionary = effect.get_meta("condition", {})
	if condition.is_empty():
		return true
	var met := evaluate_condition(unit, condition)
	if bool(condition.get("negate", false)):
		met = not met
	return met


## 条件求值：类型见 卡牌/conditions.json；未知类型默认视为满足（不阻塞）。
func evaluate_condition(unit: BattleUnit, condition: Dictionary) -> bool:
	match str(condition.get("type", "")):
		"enemies_in_range":
			var count := 0
			for other in _units:
				if other.is_enemy and other != unit and not other.is_corpse and not other.is_removed:
					if HexGrid.hex_distance(unit.hex_coords, other.hex_coords) <= unit.get_attack_range():
						count += 1
			return count >= int(condition.get("count", 1))
		"moved_this_turn":
			return unit.moved_this_turn
		"not_moved_this_turn":
			return not unit.moved_this_turn
		"hp_below_pct":
			var max_hp := unit.get_max_hp_value()
			return max_hp > 0 and unit.current_hp * 100 < int(condition.get("pct", 50)) * max_hp
		"hand_size_at_least":
			return unit.hand.size() >= int(condition.get("count", 1))
		"energy_at_least":
			return unit.energy >= int(condition.get("value", 1))
		"has_buff":
			return has_buff(unit, str(condition.get("buff_name", "")))
		"enemies_alive_at_least":
			var alive := 0
			for other in _units:
				if other.is_enemy and not other.is_corpse and not other.is_removed:
					alive += 1
			return alive >= int(condition.get("count", 1))
		"last_card_keyword":
			var last := unit.last_played_card
			return last != null and last.keyword_labels().has(str(condition.get("keyword", "")))
	return true


## 攻击结算：整数计算，玩家对敌怪向上取整、敌怪对玩家向下取整；
## 攻击者带“虚弱”时造成伤害 -25%。
func resolve_attack(unit: BattleUnit, card: CardData, effect: AttackEffect, target) -> void:
	if target is BattleUnit:
		var basis := 100
		if unit.character_data != null:
			basis = unit.character_data.get_strength_damage_basis()
		var attack_value := effect.alt_value if (effect.alt_value > 0 and unit.moved_this_turn) else effect.value
		if effect.alt_value > 0 and unit.moved_this_turn:
			_log("条件触发：本回合已移动，攻击数值 %d" % attack_value)
		var damage := compute_damage(attack_value, basis, unit.is_enemy)
		if has_buff(unit, "虚弱"):
			damage = damage * 75 / 100
			_log("%s 受「虚弱」影响，造成伤害降至 %d" % [unit.get_display_name(), damage])
		var passive := get_passive(unit)
		if passive != null:
			if passive.passive_name == "孢子怪力":
				damage = (damage * 125 + 99) / 100
				_log("「孢子怪力」被动：伤害以 1.25 倍结算（%d）" % damage)
			if passive.passive_name == "药理精通" and has_buff(target, "中毒"):
				var level_bonus := (unit.character_data.level / 5) if unit.character_data != null else 0
				var bonus := maxi(passive.value, 1) + level_bonus
				damage += bonus
				_log("「药理精通」被动：对中毒敌人额外造成 %d 点伤害" % bonus)
		var ignore_block := effect.pierce
		if not ignore_block and card.phantom and unit.last_played_card != null and unit.last_played_card.dream:
			ignore_block = true
			_log("「幻梦」：上一张为沉梦牌，本次攻击无视护甲")
		var dealt := take_damage(target, damage, ignore_block)
		_log("%s 对 %s 造成 %d 点伤害" % [
			unit.get_display_name(), target.get_display_name(), damage])
		if card.lifesteal and dealt > 0:
			heal_unit(unit, dealt)
			_log("「吸血」：%s 恢复 %d 点生命（等量于造成的伤害）" % [
				unit.get_display_name(), dealt])
	else:
		_log("「%s」没有目标，未造成伤害" % card.card_name)


## 按触发时机结算道途基础被动（回合开始/结束回合等）。
func resolve_passives_by_timing(unit: BattleUnit, timing_keyword: String) -> void:
	var passive := get_passive(unit)
	if passive == null:
		return
	if passive.passive_name != "孢子怪力" and not passive.trigger_timing.contains(timing_keyword):
		return
	var level_bonus := (unit.character_data.level / 5) if unit.character_data != null else 0
	match passive.passive_name:
		"沉梦":
			var amount := maxi(passive.value, 2) + level_bonus
			unit.block_value += amount
			unit.refresh_block_display()
			_log("「沉梦」被动：%s 获得 %d 点格挡（当前 %d）" % [
				unit.get_display_name(), amount, unit.block_value])
		"孢子怪力":
			if timing_keyword != "回合开始":
				return
			unit.block_value += 1
			unit.refresh_block_display()
			_log("「孢子怪力」被动：%s 获得 1 点护甲（当前 %d）" % [
				unit.get_display_name(), unit.block_value])
		_:
			_log("被动「%s」触发（效果待定义）" % passive.passive_name)


## 角色的基础被动（道途接口）；未设置道途/被动返回 null。
func get_passive(unit: BattleUnit) -> PassiveData:
	if unit == null or unit.character_data == null:
		return null
	return unit.character_data.get_passive()


## 回合开始时检查该单位 buff：
## - 每回合衰减的 buff 层数减少（decay_amount，不低于 1）
## - 持续时间 -1，归零后移除
func resolve_turn_buffs(unit: BattleUnit) -> void:
	if unit.buffs.is_empty():
		return
	var remaining: Array = []
	for buff in unit.buffs:
		var data: BuffData = buff.get("data")
		if data != null and data.decay_per_turn and int(buff.get("stacks", 1)) > 1:
			var decay_amount := data.decay_amount
			buff["stacks"] = maxi(int(buff["stacks"]) - decay_amount, 1)
			_log("「%s」的 buff「%s」层数衰减至 %d" % [
				unit.get_display_name(), buff.get("name", ""), buff["stacks"]])
		buff["duration"] = int(buff.get("duration", 0)) - 1
		if int(buff["duration"]) > 0:
			remaining.append(buff)
		else:
			_log("「%s」的 buff「%s」到期消失" % [
				unit.get_display_name(), buff.get("name", "")])
	unit.buffs = remaining


## 结算“结束回合时”触发的 buff（如中毒），并处理“触发后消失”。
func resolve_end_turn_buffs(unit: BattleUnit) -> void:
	resolve_buffs_by_timing(unit, "结束回合")


## 结算“下回合开始时”触发的 buff（如预格挡），并处理“触发后消失”。
func resolve_turn_start_buffs(unit: BattleUnit) -> void:
	resolve_buffs_by_timing(unit, "回合开始")


## 结算“下回合角色行动阶段”触发的 buff（如疗愈，层数减一）。
func resolve_action_phase_buffs(unit: BattleUnit) -> void:
	resolve_buffs_by_timing(unit, "行动阶段")


## 按触发时机关键词结算 buff；`resolve_buff_trigger` 返回 true 的立即移除。
func resolve_buffs_by_timing(unit: BattleUnit, timing_keyword: String) -> void:
	if unit.buffs.is_empty():
		return
	var to_remove: Array = []
	for buff in unit.buffs:
		var data: BuffData = buff.get("data")
		if data == null:
			continue
		if data.trigger_timing.contains(timing_keyword):
			if resolve_buff_trigger(unit, buff, data):
				to_remove.append(buff)
	for buff in to_remove:
		unit.buffs.erase(buff)


## “下回合抽牌时”触发的 buff（预抽牌）：返回额外抽牌数，触发后消失。
func consume_draw_bonus(unit: BattleUnit) -> int:
	var bonus := 0
	var to_remove: Array = []
	for buff in unit.buffs:
		var data: BuffData = buff.get("data")
		if data == null:
			continue
		if not data.trigger_timing.contains("抽牌"):
			continue
		if data.buff_name == "肾上腺素透支":
			var remain := int(buff.get("duration", 1))
			if remain > 1:
				_log("「肾上腺素透支」还有 %d 回合生效" % (remain - 1))
				continue
			var penalty := int(buff.get("stacks", -2))
			bonus += penalty
			_log("「肾上腺素透支」发作：本回合少抽 %d 张牌" % abs(penalty))
			to_remove.append(buff)
			continue
		var stacks := int(buff.get("stacks", 1))
		bonus += stacks
		_log("「%s」的 buff「%s」触发：额外抽 %d 张牌" % [
			unit.get_display_name(), data.buff_name, stacks])
		to_remove.append(buff)
	for buff in to_remove:
		unit.buffs.erase(buff)
	return bonus


## “下回合获得费用时”触发的 buff（费用预支）：返回额外费用，触发后消失。
func consume_energy_bonus(unit: BattleUnit) -> int:
	var bonus := 0
	var to_remove: Array = []
	for buff in unit.buffs:
		var data: BuffData = buff.get("data")
		if data == null:
			continue
		if not data.trigger_timing.contains("费用"):
			continue
		var stacks := int(buff.get("stacks", 1))
		bonus += stacks
		_log("「%s」的 buff「%s」触发：额外获得 %d 点费用" % [
			unit.get_display_name(), data.buff_name, stacks])
		to_remove.append(buff)
	for buff in to_remove:
		unit.buffs.erase(buff)
	return bonus


## 按 buff 名称执行触发效果；返回是否应“触发后消失”。
func resolve_buff_trigger(unit: BattleUnit, buff: Dictionary, data: BuffData) -> bool:
	match data.buff_name:
		"中毒":
			var damage := int(buff.get("stacks", 1))
			# 失去生命：无伤害来源，无视格挡，不受力量/易伤影响
			_log("%s 因中毒失去 %d 点生命" % [unit.get_display_name(), damage])
			lose_hp(unit, damage)
		"预格挡":
			var amount := int(buff.get("stacks", 1))
			unit.block_value += amount
			unit.refresh_block_display()
			_log("%s 获得 %d 点格挡（来自「预格挡」，当前 %d）" % [
				unit.get_display_name(), amount, unit.block_value])
		"疗愈":
			var heal := int(buff.get("stacks", 1))
			heal_unit(unit, heal)
			buff["stacks"] = int(buff.get("stacks", 1)) - 1
			if int(buff["stacks"]) <= 0:
				_log("「%s」的 buff「疗愈」层数耗尽，消失" % unit.get_display_name())
				return true
			_log("「%s」的 buff「疗愈」层数减至 %d" % [
				unit.get_display_name(), buff["stacks"]])
		_:
			_log("buff「%s」触发（效果待定义）" % data.buff_name)
	return data.consumed_on_trigger


## 直接给目标施加/叠加 buff（不经过卡牌效果，用于被动等）。
func apply_buff_direct(target: BattleUnit, buff_name: String, stacks: int = 1) -> void:
	if target == null:
		return
	var existing := find_buff(target, buff_name)
	if not existing.is_empty():
		var buff_data: BuffData = existing.get("data")
		var new_stacks := int(existing.get("stacks", 1)) + stacks
		if buff_data != null and buff_data.buff_type.contains("层数持续"):
			existing["duration"] = int(existing.get("duration", 1)) + buff_data.duration_per_stack * maxi(stacks, 1)
		# 层数无上限；层数增益型且不消失的 buff（如疗愈）持续时间跟随层数，避免提前到期
		if buff_data != null and buff_data.buff_type.contains("层数增益") and not buff_data.consumed_on_trigger:
			existing["duration"] = maxi(int(existing.get("duration", 1)), new_stacks)
		existing["stacks"] = new_stacks
		return
	var buff_db := _get_autoload("BuffDB")
	var data: BuffData = buff_db.get_buff(buff_name) if buff_db != null else null
	var apply_stacks := maxi(stacks, 1)
	var duration := data.base_duration if data != null else 1
	if data != null and data.buff_type.contains("层数持续"):
		duration = data.base_duration + maxi(apply_stacks - 1, 0) * data.duration_per_stack
	if data != null and data.buff_type.contains("层数增益") and not data.consumed_on_trigger:
		duration = maxi(duration, apply_stacks)
	target.buffs.append({
		"name": buff_name,
		"stacks": apply_stacks,
		"duration": duration,
		"value": data.value if data != null else 0,
		"data": data,
	})


## 失去生命：无伤害来源，无视格挡，不受力量/易伤影响，直接扣除生命。
## 生命变化发出 hp_changed，归零发出 unit_defeated。
func lose_hp(target: BattleUnit, amount: int) -> void:
	if target == null:
		return
	var final_amount := maxi(amount, 0)
	target.current_hp = maxi(0, target.current_hp - final_amount)
	target.refresh_hp_display()
	_hp_changed.emit(target)
	if target.current_hp <= 0:
		_unit_defeated.emit(target)
		_notify_defeat()


## 受到伤害：有伤害来源（已含力量/虚弱修正），受易伤放大，
## 可被格挡抵消，最后扣除生命；生命变化发出 hp_changed，归零发出 unit_defeated。
func take_damage(target: BattleUnit, amount: int, ignore_block: bool = false) -> int:
	if target == null:
		return 0
	var final_amount := maxi(amount, 0)
	if has_buff(target, "易伤"):
		final_amount = (final_amount * 150 + 99) / 100
		_log("%s 受「易伤」影响，伤害提升至 %d" % [target.get_display_name(), final_amount])
	var remaining := final_amount
	if not ignore_block and target.block_value > 0:
		var absorbed := mini(target.block_value, remaining)
		target.block_value -= absorbed
		remaining -= absorbed
		_log("%s 的格挡抵消 %d 点伤害（剩余格挡 %d）" % [
			target.get_display_name(), absorbed, target.block_value])
		target.refresh_block_display()
	if ignore_block and final_amount > 0:
		_log("%s 的护甲被无视，直接承受 %d 点伤害" % [target.get_display_name(), remaining])
	var hp_before := target.current_hp
	target.current_hp = maxi(0, target.current_hp - remaining)
	var dealt := hp_before - target.current_hp
	target.refresh_hp_display()
	_hp_changed.emit(target)
	if target.current_hp <= 0:
		_unit_defeated.emit(target)
		_notify_defeat()
	return dealt


## 恢复生命：不超过最大生命，发出 hp_changed 供 UI 刷新。
func heal_unit(target: BattleUnit, amount: int) -> void:
	if target == null:
		return
	var healed := mini(amount, target.get_max_hp_value() - target.current_hp)
	if healed <= 0:
		_log("%s 生命已满，未恢复" % target.get_display_name())
		return
	target.current_hp += healed
	target.refresh_hp_display()
	_hp_changed.emit(target)
	_log("%s 恢复 %d 点生命（%d/%d）" % [
		target.get_display_name(), healed, target.current_hp, target.get_max_hp_value()])


## buff 结算：数据来自 BuffDB；重复施加时叠层（无上限），
## 层数持续型每次叠层增加 duration_per_stack 回合。
func resolve_buff_effect(unit: BattleUnit, effect: BuffEffect, target) -> void:
	var buff_target: BattleUnit = null
	if effect.target == "ally":
		buff_target = target if target is BattleUnit else unit
	elif effect.target == "enemy":
		buff_target = target if target is BattleUnit else null
	else:
		buff_target = unit
	if buff_target == null:
		_log("buff 没有目标")
		return
	var buff_name := effect.buff_type if not effect.buff_type.is_empty() else "占位buff"
	var buff_data: BuffData = null
	var buff_db := _get_autoload("BuffDB")
	if buff_db != null:
		buff_data = buff_db.get_buff(buff_name)
	var existing := find_buff(buff_target, buff_name)
	if not existing.is_empty():
		var new_stacks := int(existing["stacks"]) + effect.stacks
		existing["stacks"] = new_stacks
		if buff_data != null and buff_data.buff_type.contains("层数持续"):
			existing["duration"] = int(existing["duration"]) + buff_data.duration_per_stack * maxi(effect.stacks, 0)
		# 层数无上限；层数增益型且不消失的 buff（如疗愈）持续时间跟随层数，避免提前到期
		if buff_data != null and buff_data.buff_type.contains("层数增益") and not buff_data.consumed_on_trigger:
			existing["duration"] = maxi(int(existing["duration"]), new_stacks)
		_log("%s 的 buff「%s」层数提升至 %d" % [
			buff_target.get_display_name(), buff_name, new_stacks])
		return
	var duration := effect.duration
	var value := 0
	var stacks := effect.stacks if effect.stacks != 0 else 1
	if buff_data != null:
		if duration <= 0:
			duration = buff_data.base_duration
			if buff_data.buff_type.contains("层数持续"):
				duration += maxi(stacks - 1, 0) * buff_data.duration_per_stack
			elif buff_data.buff_type.contains("层数增益") and not buff_data.consumed_on_trigger:
				duration = maxi(duration, stacks)
		value = buff_data.value
	buff_target.buffs.append({
		"name": buff_name,
		"stacks": stacks,
		"duration": duration,
		"value": value,
		"data": buff_data,
	})
	_log("%s 获得 buff「%s」，持续 %d 回合" % [
		buff_target.get_display_name(), buff_name, duration])


func find_buff(unit: BattleUnit, buff_name: String) -> Dictionary:
	for buff in unit.buffs:
		if buff.get("name", "") == buff_name:
			return buff
	return {}


func has_buff(unit: BattleUnit, buff_name: String) -> bool:
	return not find_buff(unit, buff_name).is_empty()


func get_card(card_name: String) -> CardData:
	return _card_lookup.call(card_name) as CardData


## 固有牌：战斗开始时直接进入手牌（受手牌上限约束）。
func put_innate_cards_in_hand(unit: BattleUnit) -> void:
	var innate_cards: Array[CardData] = []
	for card in unit.draw_pile:
		if card.innate:
			innate_cards.append(card)
	var placed := 0
	for card in innate_cards:
		if unit.hand.size() >= MAX_HAND_SIZE:
			break
		unit.draw_pile.erase(card)
		unit.hand.append(card)
		placed += 1
	if placed > 0:
		_log("%s 的 %d 张固有牌开局入手" % [unit.get_display_name(), placed])


func draw_cards(unit: BattleUnit, count: int) -> void:
	for i in count:
		if unit.hand.size() >= MAX_HAND_SIZE:
			_log("%s 手牌已达上限 %d，停止抽牌" % [unit.get_display_name(), MAX_HAND_SIZE])
			break
		if unit.draw_pile.is_empty():
			refill_draw_pile(unit)
			if unit.draw_pile.is_empty():
				break
		unit.hand.append(unit.draw_pile.pop_back())


func refill_draw_pile(unit: BattleUnit) -> void:
	if unit.discard_pile.is_empty():
		return
	_log("%s 的弃牌堆洗回抽牌堆" % unit.get_display_name())
	for card in unit.discard_pile:
		unit.draw_pile.append(card)
	unit.discard_pile.clear()
	shuffle(unit.draw_pile)


## 回合结束处理手牌：虚无牌被消耗；保留牌留在手牌；其余进入弃牌堆。
func discard_hand(unit: BattleUnit) -> void:
	var kept: Array[CardData] = []
	var discarded := 0
	var exhausted := 0
	for card in unit.hand:
		if card.ethereal:
			exhaust_card(unit, card, "虚无")
			exhausted += 1
		elif card.retain:
			kept.append(card)
		else:
			unit.discard_pile.append(card)
			discarded += 1
	unit.hand = kept
	if discarded > 0:
		_log("%s 弃掉手牌 %d 张" % [unit.get_display_name(), discarded])
	if exhausted > 0:
		_log("%s 的 %d 张虚无牌被消耗" % [unit.get_display_name(), exhausted])


## 消耗一张牌：进入消耗堆（本场战斗移除，不会洗回抽牌堆）。
func exhaust_card(unit: BattleUnit, card: CardData, reason: String = "打出") -> void:
	if card == null:
		return
	unit.exhaust_pile.append(card)
	_log("「%s」被消耗（%s）" % [card.card_name, reason])


## 弃牌效果：mode = all 弃掉全部手牌；mode = random 随机弃掉 value 张。
func resolve_discard_effect(unit: BattleUnit, effect: DiscardEffect) -> void:
	if effect.mode == "all":
		var count := unit.hand.size()
		for card in unit.hand:
			unit.discard_pile.append(card)
		unit.hand.clear()
		_log("%s 弃掉全部手牌 %d 张" % [unit.get_display_name(), count])
		return
	var discard_count := mini(maxi(effect.value, 0), unit.hand.size())
	for i in discard_count:
		var index := _rng.randi_range(0, unit.hand.size() - 1)
		unit.discard_pile.append(unit.hand[index])
		unit.hand.remove_at(index)
	_log("%s 随机弃掉 %d 张手牌" % [unit.get_display_name(), discard_count])


## 把指定卡牌的 value 张复制放入指定牌堆。
## pile: hand / draw / discard；draw 时 position = top（置于抽牌堆顶，后抽到）或 shuffle（洗入）。
func add_cards_to_pile(unit: BattleUnit, pile: String, card_name: String, value: int, position: String = "shuffle") -> void:
	var card := get_card(card_name)
	if card == null:
		_log("卡牌「%s」不存在，无法加入%s" % [card_name, pile_label(pile)])
		return
	var count := maxi(value, 0)
	for i in count:
		if pile == "hand":
			unit.hand.append(card)
		elif pile == "draw":
			unit.draw_pile.append(card)
		elif pile == "discard":
			unit.discard_pile.append(card)
	if pile == "draw" and position != "top":
		shuffle(unit.draw_pile)
	_log("%s 将 %d 张「%s」加入%s" % [unit.get_display_name(), count, card_name, pile_label(pile)])


## 生成牌效果：card_name 为空时按 pool（攻击/行动/能力/全部）随机生成一张。
func resolve_generate_effect(unit: BattleUnit, effect: GenerateEffect) -> void:
	var pile: String = effect.pile if not effect.pile.is_empty() else "hand"
	if effect.card_name.is_empty():
		var random_card := random_card_from_pool(effect.pool)
		if random_card == null:
			_log("随机牌池为空，无法生成牌")
			return
		add_cards_to_pile(unit, pile, random_card.card_name, effect.value, "shuffle")
		return
	add_cards_to_pile(unit, pile, effect.card_name, effect.value, "shuffle")


## 从牌池随机选一张卡：pool = 攻击 / 行动 / 能力 / 全部（空）。
func random_card_from_pool(pool: String) -> CardData:
	var db := _get_autoload("CardDB")
	if db == null:
		return null
	var candidates: Array[CardData] = []
	for card in db.cards:
		if pool == "攻击" and card.card_type != CardData.CardType.ATTACK:
			continue
		if pool == "行动" and card.card_type != CardData.CardType.ACTION:
			continue
		if pool == "能力" and card.card_type != CardData.CardType.ABILITY:
			continue
		candidates.append(card)
	if candidates.is_empty():
		return null
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


## 失去生命效果：target = enemy 时作用于目标（无视格挡），否则作用于出牌者自身。
func resolve_lose_hp_effect(unit: BattleUnit, effect: LoseHpEffect, target) -> void:
	if effect.target == "enemy" and not (target is BattleUnit):
		_log("「失去生命」没有敌方目标")
		return
	var hp_target: BattleUnit = target if (effect.target == "enemy" and target is BattleUnit) else unit
	lose_hp(hp_target, effect.value)


func pile_label(pile: String) -> String:
	match pile:
		"hand":
			return "手牌"
		"draw":
			return "抽牌堆"
		"discard":
			return "弃牌堆"
	return pile


func shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp


func _notify_defeat() -> void:
	if _battle_over_check.is_valid():
		_battle_over_check.call()


## 从场景树获取自动加载单例（CardDB/BuffDB 等）。
## 无头脚本模式（--script）下自动加载可能未注册，此时返回 null，由调用方兜底。
static func _get_autoload(name: String) -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(name)
	return null
