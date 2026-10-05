class_name EffectSystem
extends RefCounted

## 效果结算系统（逻辑层，无场景依赖）。
## 接管战斗中的效果结算，battle_manager.gd 只保留回合流程与胜负战利品：
## - 卡牌效果：resolve_effects / resolve_attack（伤害、格挡、pierce）
## - buff 结算：resolve_buff_* 系列、buff 触发 / 衰减、按触发时机结算；
##   攻击类时机（受到攻击时 / 造成攻击伤害时）经伤害修正钩子统一结算
## - buff 行为函数化：buff 名称 → 函数注册表（触发 / 伤害修正 / 抽牌 / 费用），
##   新增 buff 在注册表登记对应函数即可接入统一结算
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
var _pending_card_choice: Dictionary = {}

## —— buff 行为注册表（buff 名称 → 函数）——
## BuffData 描述 buff 属性与触发时机，具体行为由这里登记的函数实现：
## - 触发函数：func(unit, buff, data) -> bool（返回是否触发后消失）
## - 伤害修正函数：func(unit, buff, data, amount) -> int（返回修正后的伤害）
## - 抽牌/费用修正函数：func(unit, buff, data) -> {"bonus": int, "remove": bool}
var _trigger_handlers: Dictionary = {}
var _damage_modifier_handlers: Dictionary = {}
var _draw_bonus_handlers: Dictionary = {}
var _energy_bonus_handlers: Dictionary = {}


func _init() -> void:
	_trigger_handlers = {
		"中毒": Callable(self, "_on_poison_trigger"),
		"预格挡": Callable(self, "_on_pre_block_trigger"),
		"疗愈": Callable(self, "_on_heal_trigger"),
	}
	_damage_modifier_handlers = {
		"易伤": Callable(self, "_modify_damage_taken"),
		"虚弱": Callable(self, "_modify_damage_dealt"),
	}
	_draw_bonus_handlers = {
		"预抽牌": Callable(self, "_draw_bonus_regular"),
		"肾上腺素透支": Callable(self, "_draw_bonus_overdraft"),
	}
	_energy_bonus_handlers = {
		"费用预支": Callable(self, "_energy_bonus_regular"),
	}


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
	_pending_card_choice.clear()


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
func resolve_effects(unit: BattleUnit, card: CardData, target = null) -> bool:
	var play_context := {"target_buffs_at_play": [], "target_had_debuff_at_play": false,
		"target_block_at_play": -1,
		"caster_dream_state_at_play": unit.redesign_dream_state,
		"caster_dream_enabled_at_play": unit.redesign_dream_enabled}
	if target is BattleUnit:
		play_context["target_block_at_play"] = target.block_value
		var buff_db := _get_autoload("BuffDB")
		for buff in target.buffs:
			var buff_name := str(buff.get("name", ""))
			play_context["target_buffs_at_play"].append(buff_name)
			var buff_data: BuffData = buff.get("data") as BuffData
			if buff_data == null and buff_db != null:
				buff_data = buff_db.get_buff(buff_name)
			if buff_data != null and buff_data.alignment == "负面":
				play_context["target_had_debuff_at_play"] = true
	return _resolve_effects_from(unit, card, target, 0, play_context)


func _resolve_effects_from(unit: BattleUnit, card: CardData, target, start_index: int,
		play_context: Dictionary) -> bool:
	for effect_index in range(start_index, card.effects.size()):
		var effect: Resource = card.effects[effect_index]
		if not effect_condition_met(unit, effect, target, play_context):
			_log("「%s」的条件未满足，跳过效果" % card.card_name)
			continue
		if effect is AttackEffect:
			resolve_attack(unit, card, effect as AttackEffect, target)
		elif effect is MoveEffect:
			var move := effect as MoveEffect
			var move_target: BattleUnit = target if move.target == "ally" and target is BattleUnit else unit
			move_target.remaining_move_points += move.distance
			_log("%s 获得额外移动力 %d（当前 %d/%d）" % [
				move_target.get_display_name(), move.distance,
				move_target.remaining_move_points, move_target.get_max_move_points()])
		elif effect is SetDreamStateEffect:
			var dream_state := effect as SetDreamStateEffect
			if unit.redesign_dream_enabled:
				unit.redesign_dream_state = dream_state.state
				_log("%s 进入%s" % [unit.get_display_name(), "沉梦" if dream_state.state == 0 else "幻梦"])
		elif effect is DefenseEffect:
			var defense := effect as DefenseEffect
			var defense_target: BattleUnit = target if defense.target == "ally" and target is BattleUnit else unit
			var defense_value := defense.alt_value if (defense.alt_value > 0 and unit.moved_this_turn) else defense.value
			# 装备「防御卡格挡 ±N」修正（铁剑：攻强守弱）
			var equip_defend := unit.character_data.get_equipment_mod_total("defend_bonus") if unit.character_data != null else 0
			if equip_defend != 0:
				defense_value = maxi(defense_value + equip_defend, 0)
				_log("装备修正：%s 的防御卡格挡 %+d" % [unit.get_display_name(), equip_defend])
			defense_target.block_value += defense_value
			_log("%s 获得 %d 点格挡（当前 %d）" % [
				defense_target.get_display_name(), defense_value, defense_target.block_value])
			defense_target.refresh_block_display()
		elif effect is HealEffect:
			var heal := effect as HealEffect
			var heal_target: BattleUnit = target if heal.target == "ally" and target is BattleUnit else unit
			heal_unit(heal_target, heal.value)
		elif effect is BuffEffect:
			resolve_buff_effect(unit, effect as BuffEffect, target)
		elif effect is TriggerBuffEffect:
			resolve_trigger_buff_effect(unit, effect as TriggerBuffEffect, target)
		elif effect is DrawEffect:
			var draw := effect as DrawEffect
			draw_cards(unit, draw.value)
			_log("%s 抽 %d 张牌" % [unit.get_display_name(), draw.value])
		elif effect is TransferRandomCardEffect:
			transfer_random_cards(unit, effect as TransferRandomCardEffect)
		elif effect is ChooseFromPileEffect:
			request_card_choice(unit, effect as ChooseFromPileEffect)
			if has_pending_card_choice():
				_pending_card_choice["continuation"] = {"card": card, "target": target,
					"next_index": effect_index + 1, "play_context": play_context}
				return false
		elif effect is ChooseHandDiscardEffect:
			request_hand_discard(unit, effect as ChooseHandDiscardEffect)
			if has_pending_card_choice():
				_pending_card_choice["continuation"] = {"card": card, "target": target,
					"next_index": effect_index + 1, "play_context": play_context}
				return false
		elif effect is InspectTopCardsEffect:
			request_top_inspection(unit, effect as InspectTopCardsEffect)
			if has_pending_card_choice():
				_pending_card_choice["continuation"] = {"card": card, "target": target,
					"next_index": effect_index + 1, "play_context": play_context}
				return false
		elif effect is MulliganHandEffect:
			mulligan_hand(unit)
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
	return true


## 判断效果的挂载条件是否满足（无条件返回 true）。
func effect_condition_met(unit: BattleUnit, effect: Resource, target = null, play_context: Dictionary = {}) -> bool:
	if not effect.has_meta("condition"):
		return true
	var condition: Dictionary = effect.get_meta("condition", {})
	if condition.is_empty():
		return true
	var met := evaluate_condition(unit, condition, target, play_context)
	if bool(condition.get("negate", false)):
		met = not met
	return met


## 条件求值：类型见 卡牌/conditions.json；未知类型默认视为满足（不阻塞）。
func evaluate_condition(unit: BattleUnit, condition: Dictionary, target = null, play_context: Dictionary = {}) -> bool:
	match str(condition.get("type", "")):
		"played_card_tags_this_turn":
			var primary_tag := str(condition.get("tag", ""))
			if primary_tag.is_empty():
				return false
			var required_tags: Array[String] = [primary_tag]
			var other_tag := str(condition.get("other_tag", ""))
			if not other_tag.is_empty():
				required_tags.append(other_tag)
			var card_type := str(condition.get("card_type", ""))
			var used_indices: Array[int] = []
			for required_tag in required_tags:
				var found := false
				for index in unit.played_cards_this_turn.size():
					var played := unit.played_cards_this_turn[index]
					if not played.tags.has(required_tag) or (bool(condition.get("distinct", false)) and used_indices.has(index)):
						continue
					if card_type == "Attack" and played.card_type != CardData.CardType.ATTACK:
						continue
					if card_type != "" and card_type != "Attack":
						continue
					used_indices.append(index)
					found = true
					break
				if not found:
					return false
			return true
		"target_hp_at_most_pct":
			if not target is BattleUnit:
				return false
			var target_max_hp: int = target.get_max_hp_value()
			return target_max_hp > 0 and target.current_hp * 100 <= int(condition.get("pct", 50)) * target_max_hp
		"target_block_at_play_at_least":
			return target is BattleUnit and int(play_context.get("target_block_at_play", -1)) >= int(condition.get("threshold", 1))
		"target_block_at_play_at_most":
			return target is BattleUnit and int(play_context.get("target_block_at_play", -1)) >= 0 \
				and int(play_context.get("target_block_at_play", -1)) <= int(condition.get("threshold", 0))
		"target_buff_stacks_at_least":
			return target is BattleUnit and int(find_buff(target, str(condition.get("buff", ""))).get("stacks", 0)) >= int(condition.get("stacks", 1))
		"target_moved_this_turn":
			return target is BattleUnit and target.moved_this_turn
		"caster_target_adjacent":
			return target is BattleUnit and unit.hex_coords.x >= 0 and target.hex_coords.x >= 0 \
				and HexGrid.hex_distance(unit.hex_coords, target.hex_coords) == 1
		"adjacent_enemies_at_least":
			if unit.hex_coords.x < 0:
				return false
			var adjacent := 0
			for other in _units:
				if other.is_enemy != unit.is_enemy and other.current_hp > 0 and not other.is_corpse \
						and not other.is_removed and other.hex_coords.x >= 0 \
						and HexGrid.hex_distance(unit.hex_coords, other.hex_coords) == 1:
					adjacent += 1
			return adjacent >= int(condition.get("count", 1))
		"redesign_dream_state_is":
			return unit.redesign_dream_enabled and unit.redesign_dream_state == int(condition.get("state", -1))
		"redesign_dream_state_at_play_is":
			return bool(play_context.get("caster_dream_enabled_at_play", false)) \
				and int(play_context.get("caster_dream_state_at_play", -1)) == int(condition.get("state", -1))
		"target_has_buff_at_play":
			return target is BattleUnit and play_context.get("target_buffs_at_play", []).has(str(condition.get("buff_name", "")))
		"target_has_any_debuff_at_play":
			return target is BattleUnit and bool(play_context.get("target_had_debuff_at_play", false))
		"target_lost_direct_hp_this_turn":
			return target is BattleUnit and bool(unit.direct_hp_loss_targets.get(target.get_instance_id(), false))
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
		"hp_at_most_pct":
			var max_hp := unit.get_max_hp_value()
			return max_hp > 0 and unit.current_hp * 100 <= int(condition.get("pct", 50)) * max_hp
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
		if target.current_hp <= 0 or target.is_corpse or target.is_removed:
			return
		var basis := 100
		if unit.character_data != null:
			basis = unit.character_data.get_strength_damage_basis()
		var alt_met := unit.bled_this_turn if effect.alt_condition == "bloodlet_this_turn" else unit.moved_this_turn
		var attack_value := effect.alt_value if (effect.alt_value > 0 and alt_met) else effect.value
		if effect.alt_value > 0 and alt_met:
			_log("条件触发：攻击数值改为 %d" % attack_value)
		var damage := compute_damage(attack_value, basis, unit.is_enemy)
		damage = _apply_damage_modifiers(unit, damage, "造成攻击伤害时")   # 虚弱：造成伤害 -25%
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
		if not ignore_block and card.dream_mode == "three_dreams" and unit.redesign_dream_state == 1:
			ignore_block = true
			_log("幻梦：直接攻击伤害无视格挡")
		elif not ignore_block and card.phantom and unit.last_played_card != null and unit.last_played_card.dream:
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
		if data != null and data.decay_after_trigger:
			remaining.append(buff)
			continue
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
			if _resolve_buff_instance_once(unit, buff, data):
				to_remove.append(buff)
	for buff in to_remove:
		unit.buffs.erase(buff)


func _resolve_buff_instance_once(unit: BattleUnit, buff: Dictionary, data: BuffData) -> bool:
	var consumed := resolve_buff_trigger(unit, buff, data)
	if data.decay_after_trigger and not consumed:
		buff["stacks"] = maxi(int(buff.get("stacks", 1)) - maxi(data.decay_amount, 1), 0)
		buff["duration"] = maxi(int(buff.get("duration", 1)) - 1, 0)
		consumed = int(buff["stacks"]) <= 0 or int(buff["duration"]) <= 0
	return consumed


func resolve_trigger_buff_effect(unit: BattleUnit, effect: TriggerBuffEffect, target) -> void:
	var buff_target: BattleUnit = target if effect.target == "enemy" and target is BattleUnit else unit
	var buff := find_buff(buff_target, effect.buff_type)
	if buff.is_empty():
		return
	var data: BuffData = buff.get("data") as BuffData
	if data == null:
		var buff_db := _get_autoload("BuffDB")
		if buff_db != null:
			data = buff_db.get_buff(effect.buff_type)
	if data != null and _resolve_buff_instance_once(buff_target, buff, data):
		buff_target.buffs.erase(buff)


## “下回合抽牌时”触发的 buff（预抽牌 / 肾上腺素透支）：返回额外抽牌数，触发后消失。
## 行为由 _draw_bonus_handlers 注册表分发（buff 名称 → 函数，返回 {bonus, remove}）。
func consume_draw_bonus(unit: BattleUnit) -> int:
	var bonus := 0
	var to_remove: Array = []
	for buff in unit.buffs:
		var data: BuffData = buff.get("data")
		if data == null:
			continue
		if not data.trigger_timing.contains("抽牌"):
			continue
		var handler: Callable = _draw_bonus_handlers.get(data.buff_name, Callable())
		if not handler.is_valid():
			continue
		var result: Dictionary = handler.call(unit, buff, data)
		bonus += int(result.get("bonus", 0))
		if bool(result.get("remove", false)):
			to_remove.append(buff)
	for buff in to_remove:
		unit.buffs.erase(buff)
	return bonus


## “下回合获得费用时”触发的 buff（费用预支）：返回额外费用，触发后消失。
## 行为由 _energy_bonus_handlers 注册表分发（buff 名称 → 函数，返回 {bonus, remove}）。
func consume_energy_bonus(unit: BattleUnit) -> int:
	var bonus := 0
	var to_remove: Array = []
	for buff in unit.buffs:
		var data: BuffData = buff.get("data")
		if data == null:
			continue
		if not data.trigger_timing.contains("费用"):
			continue
		var handler: Callable = _energy_bonus_handlers.get(data.buff_name, Callable())
		if not handler.is_valid():
			continue
		var result: Dictionary = handler.call(unit, buff, data)
		bonus += int(result.get("bonus", 0))
		if bool(result.get("remove", false)):
			to_remove.append(buff)
	for buff in to_remove:
		unit.buffs.erase(buff)
	return bonus


## 按 buff 名称执行触发效果；返回是否应“触发后消失”。
## 行为由 _trigger_handlers 注册表分发（buff 名称 → 函数），未注册的 buff 仅记录日志。
func resolve_buff_trigger(unit: BattleUnit, buff: Dictionary, data: BuffData) -> bool:
	var handler: Callable = _trigger_handlers.get(data.buff_name, Callable())
	if handler.is_valid():
		return handler.call(unit, buff, data)
	_log("buff「%s」触发（效果待定义）" % data.buff_name)
	return data.consumed_on_trigger


## ============================================================
## buff 行为函数（由 _init 注册到各注册表，按 buff 名称分发）
## ============================================================

## 中毒：结束回合时失去等于层数的生命（无伤害来源，无视格挡），不消失。
func _on_poison_trigger(unit: BattleUnit, buff: Dictionary, data: BuffData) -> bool:
	var damage := int(buff.get("stacks", 1))
	_log("%s 因中毒失去 %d 点生命" % [unit.get_display_name(), damage])
	lose_hp(unit, damage)
	return data.consumed_on_trigger


## 预格挡：回合开始时获得等于层数的格挡，触发后消失。
func _on_pre_block_trigger(unit: BattleUnit, buff: Dictionary, data: BuffData) -> bool:
	var amount := int(buff.get("stacks", 1))
	unit.block_value += amount
	unit.refresh_block_display()
	_log("%s 获得 %d 点格挡（来自「预格挡」，当前 %d）" % [
		unit.get_display_name(), amount, unit.block_value])
	return data.consumed_on_trigger


## 疗愈：结束回合时恢复等于层数的生命；层数由通用触发后衰减规则处理。
func _on_heal_trigger(unit: BattleUnit, buff: Dictionary, data: BuffData) -> bool:
	var heal := int(buff.get("stacks", 1))
	heal_unit(unit, heal)
	return data.consumed_on_trigger


## 易伤：受到攻击时伤害 +50%（格挡结算前放大），不消耗层数。
func _modify_damage_taken(unit: BattleUnit, buff: Dictionary, data: BuffData, amount: int) -> int:
	var amplified := (amount * 150 + 99) / 100
	_log("%s 受「%s」影响，伤害提升至 %d" % [
		unit.get_display_name(), data.buff_name, amplified])
	return amplified


## 虚弱：造成攻击伤害时 -25%（被动修正前降低），不消耗层数。
func _modify_damage_dealt(unit: BattleUnit, buff: Dictionary, data: BuffData, amount: int) -> int:
	var reduced := amount * 75 / 100
	_log("%s 受「%s」影响，造成伤害降至 %d" % [
		unit.get_display_name(), data.buff_name, reduced])
	return reduced


## 预抽牌：抽牌阶段额外抽等于层数的牌，触发后消失。
func _draw_bonus_regular(unit: BattleUnit, buff: Dictionary, data: BuffData) -> Dictionary:
	var stacks := int(buff.get("stacks", 1))
	_log("「%s」的 buff「%s」触发：额外抽 %d 张牌" % [
		unit.get_display_name(), data.buff_name, stacks])
	return {"bonus": stacks, "remove": true}


## 肾上腺素透支：到期前抽牌阶段不发作，到期发作抽牌 -2（stacks），触发后消失。
func _draw_bonus_overdraft(unit: BattleUnit, buff: Dictionary, _data: BuffData) -> Dictionary:
	var remain := int(buff.get("duration", 1))
	if remain > 1:
		_log("「肾上腺素透支」还有 %d 回合生效" % (remain - 1))
		return {"bonus": 0, "remove": false}
	var penalty := int(buff.get("stacks", -2))
	_log("「肾上腺素透支」发作：本回合少抽 %d 张牌" % abs(penalty))
	return {"bonus": penalty, "remove": true}


## 费用预支：获得费用阶段额外获得等于层数的费用，触发后消失。
func _energy_bonus_regular(unit: BattleUnit, buff: Dictionary, data: BuffData) -> Dictionary:
	var stacks := int(buff.get("stacks", 1))
	_log("「%s」的 buff「%s」触发：额外获得 %d 点费用" % [
		unit.get_display_name(), data.buff_name, stacks])
	return {"bonus": stacks, "remove": true}


## 应用指定攻击类时机（受到攻击时 / 造成攻击伤害时）的伤害修正 buff（易伤 / 虚弱等）。
## 遍历单位现有 buff，命中 trigger_timing 者逐个调用注册表里的修正函数。
func _apply_damage_modifiers(unit: BattleUnit, amount: int, timing_keyword: String) -> int:
	if unit == null or unit.buffs.is_empty():
		return amount
	var result := amount
	for buff in unit.buffs:
		var data: BuffData = buff.get("data")
		if data == null or not data.trigger_timing.contains(timing_keyword):
			continue
		var handler: Callable = _damage_modifier_handlers.get(data.buff_name, Callable())
		if handler.is_valid():
			result = handler.call(unit, buff, data, result)
	return result


## 直接给目标施加/叠加 buff（不经过卡牌效果，用于被动等）。
func apply_buff_direct(target: BattleUnit, buff_name: String, stacks: int = 1) -> void:
	if target == null:
		return
	var existing := find_buff(target, buff_name)
	if not existing.is_empty():
		var buff_data: BuffData = existing.get("data")
		var new_stacks := int(existing.get("stacks", 1)) + stacks
		if buff_data != null and buff_data.max_stacks > 0:
			new_stacks = mini(new_stacks, buff_data.max_stacks)
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
	if data != null and data.max_stacks > 0:
		apply_stacks = mini(apply_stacks, data.max_stacks)
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
	final_amount = _apply_damage_modifiers(target, final_amount, "受到攻击时")   # 易伤：所受伤害 +50%
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
	if target == null or target.is_corpse or target.is_removed:
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
		if buff_data != null and buff_data.max_stacks > 0:
			new_stacks = mini(new_stacks, buff_data.max_stacks)
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
	if buff_data != null and buff_data.max_stacks > 0:
		stacks = mini(stacks, buff_data.max_stacks)
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


func transfer_random_cards(unit: BattleUnit, effect: TransferRandomCardEffect) -> void:
	if effect.source == effect.destination or effect.count <= 0:
		return
	var source: Array[CardData] = []
	var destination: Array[CardData] = []
	match effect.source:
		"draw": source = unit.draw_pile
		"discard": source = unit.discard_pile
		"hand": source = unit.hand
		_: return
	match effect.destination:
		"draw": destination = unit.draw_pile
		"discard": destination = unit.discard_pile
		"hand": destination = unit.hand
		_: return
	var candidates: Array[int] = []
	for source_index in source.size():
		if effect.exclude_card_type == "Power" and source[source_index].card_type == CardData.CardType.ABILITY:
			continue
		candidates.append(source_index)
	var moved := 0
	for i in mini(effect.count, candidates.size()):
		var index := _rng.randi_range(0, candidates.size() - 1)
		var source_index: int = candidates[index]
		var card: CardData = source[source_index]
		candidates.remove_at(index)
		source.remove_at(source_index)
		for candidate_index in candidates.size():
			if candidates[candidate_index] > source_index:
				candidates[candidate_index] -= 1
		if effect.destination == "draw" and effect.position == "bottom":
			destination.insert(0, card)
		else:
			destination.append(card)
		moved += 1
	if effect.destination == "draw" and effect.position == "shuffle" and moved > 0:
		shuffle(destination)
	if moved > 0:
		_log("%s 随机将 %d 张实体牌从%s移至%s" % [unit.get_display_name(), moved,
			pile_label(effect.source), pile_label(effect.destination)])


func request_card_choice(unit: BattleUnit, effect: ChooseFromPileEffect) -> void:
	if not _pending_card_choice.is_empty() or (not effect.show_all and effect.sample_count <= 0):
		return
	var source: Array[CardData] = []
	match effect.source:
		"draw": source = unit.draw_pile
		"discard": source = unit.discard_pile
		"hand": source = unit.hand
		"deck":
			if unit.character_data == null:
				return
			source = unit.character_data.deck
		"library":
			if unit.character_data == null:
				return
			for skill in unit.character_data.skill_library:
				var owned_card: CardData = _card_lookup.call(skill.skill_name) as CardData
				if owned_card != null:
					source.append(owned_card)
		_: return
	if not effect.selection_destinations.is_empty():
		if effect.source not in ["deck", "library"]:
			return
		for next_destination in effect.selection_destinations:
			if next_destination not in ["hand", "draw_top", "draw_bottom", "discard"]:
				return
		if effect.selection_destinations[0] == "hand" and unit.hand.size() >= MAX_HAND_SIZE:
			return
	else:
		if effect.destination not in ["draw", "hand"] or effect.position != "top":
			return
		if effect.destination == "hand" and effect.source != "hand" and unit.hand.size() >= MAX_HAND_SIZE:
			return
	var remaining: Array[int] = []
	for i in source.size():
		if _card_choice_candidate_matches(unit, source[i], effect):
			remaining.append(i)
	if effect.distinct_by_card_id:
		var seen_card_ids: Dictionary = {}
		var distinct_indices: Array[int] = []
		for source_index in remaining:
			var source_card: CardData = source[source_index]
			var card_key := source_card.card_id if not source_card.card_id.is_empty() else source_card.card_name
			if seen_card_ids.has(card_key):
				continue
			seen_card_ids[card_key] = true
			distinct_indices.append(source_index)
		remaining = distinct_indices
	var indices: Array[int] = []
	var options: Array[CardData] = []
	if effect.show_all:
		for source_index in remaining:
			indices.append(source_index)
			options.append(source[source_index])
	else:
		for i in mini(effect.sample_count, remaining.size()):
			var picked := _rng.randi_range(0, remaining.size() - 1)
			var source_index: int = remaining[picked]
			remaining.remove_at(picked)
			indices.append(source_index)
			options.append(source[source_index])
	if options.is_empty():
		_log("%s 的%s没有可展示的牌" % [unit.get_display_name(), pile_label(effect.source)])
		return
	_pending_card_choice = {"unit": unit, "source": effect.source,
		"destination": effect.destination,
		"exhaust_selected_on_play": effect.exhaust_selected_on_play,
		"selected_cost_override": effect.selected_cost_override,
		"selected_cost_reduction": effect.selected_cost_reduction,
		"grant_retain_selected": effect.grant_retain_selected,
		"temporary_copy": effect.temporary_copy,
		"selection_destinations": effect.selection_destinations.duplicate(), "selection_step": 0,
		"indices": indices, "options": options}


func request_hand_discard(unit: BattleUnit, effect: ChooseHandDiscardEffect) -> void:
	if not _pending_card_choice.is_empty() or effect.max_count <= 0 or unit.hand.is_empty():
		return
	var available := mini(effect.max_count, unit.hand.size())
	_pending_card_choice = {"kind": "active_discard", "unit": unit,
		"options": unit.hand.duplicate(), "min_left": mini(maxi(effect.min_count, 0), available),
		"max_left": available, "block_per_card": maxi(effect.block_per_card, 0)}


func request_top_inspection(unit: BattleUnit, effect: InspectTopCardsEffect) -> void:
	if not _pending_card_choice.is_empty() or effect.count <= 0 or unit.draw_pile.is_empty():
		return
	if effect.pick_to_hand and unit.hand.size() >= MAX_HAND_SIZE:
		return
	var options: Array[CardData] = []
	for i in mini(effect.count, unit.draw_pile.size()):
		options.append(unit.draw_pile.pop_back())
	var phase := "hand" if effect.pick_to_hand else (
		"discard" if effect.pick_to_discard > 0 or effect.discard_up_to > 0 else "order")
	_pending_card_choice = {"kind": "inspect_top", "unit": unit, "options": options,
		"phase": phase, "discard_left": effect.pick_to_discard,
		"discard_optional_left": effect.discard_up_to,
		"reorder": effect.reorder_remaining, "ordered": []}
	if phase == "order" and (not effect.reorder_remaining or options.size() <= 1):
		_finish_top_inspection()


func _card_choice_candidate_matches(unit: BattleUnit, card: CardData, effect: ChooseFromPileEffect) -> bool:
	if effect.required_card_type == "Skill" and card.card_type != CardData.CardType.ACTION:
		return false
	if effect.required_card_type == "Attack" and card.card_type != CardData.CardType.ATTACK:
		return false
	if effect.exclude_card_type == "Power" and card.card_type == CardData.CardType.ABILITY:
		return false
	if not effect.required_rarity.is_empty() and card.rarity != effect.required_rarity:
		return false
	if effect.base_cost >= 0 and card.cost != effect.base_cost:
		return false
	if not effect.required_tags.is_empty():
		var has_tag := false
		for tag in effect.required_tags:
			if card.tags.has(tag):
				has_tag = true
				break
		if not has_tag:
			return false
	if effect.played_in_battle and not unit.played_card_ids_in_battle.has(card.card_id):
		return false
	if effect.not_played_this_turn:
		for played in unit.played_cards_this_turn:
			if played.card_id == card.card_id:
				return false
	return true


func has_pending_card_choice() -> bool:
	return not _pending_card_choice.is_empty()


func card_choice_options() -> Array:
	return _pending_card_choice.get("options", []).duplicate()


func card_choice_can_skip() -> bool:
	if _pending_card_choice.get("kind", "") == "active_discard":
		return int(_pending_card_choice.get("min_left", 0)) == 0 \
			and int(_pending_card_choice.get("max_left", 0)) > 0
	return _pending_card_choice.get("kind", "") == "inspect_top" \
		and _pending_card_choice.get("phase", "") == "discard" \
		and int(_pending_card_choice.get("discard_left", 0)) == 0 \
		and int(_pending_card_choice.get("discard_optional_left", 0)) > 0


func card_choice_skip_label() -> String:
	return "结束弃牌" if _pending_card_choice.get("kind", "") == "active_discard" \
		else "结束弃牌，开始排序"


func card_choice_prompt() -> String:
	if _pending_card_choice.is_empty():
		return ""
	if _pending_card_choice.get("kind", "") == "active_discard":
		return "选择其他手牌主动弃置（还可弃 %d 张）%s" % [
			int(_pending_card_choice["max_left"]), "；可结束弃牌" if card_choice_can_skip() else ""]
	if _pending_card_choice.get("kind", "pile") == "inspect_top":
		match _pending_card_choice["phase"]:
			"hand": return "从查看的顶牌中选择 1 张加入手牌"
			"discard":
				return "可选择 1 张弃置，或结束弃牌" if card_choice_can_skip() \
					else "从查看的顶牌中选择 1 张加入弃牌堆"
			"order": return "选择下一张置于最上方（按牌顶到牌底排序）"
	var sequence: Array = _pending_card_choice.get("selection_destinations", [])
	if not sequence.is_empty():
		var step: int = _pending_card_choice["selection_step"]
		var destination_name: String = str({"hand": "手牌", "draw_top": "抽牌堆顶",
			"draw_bottom": "抽牌堆底", "discard": "弃牌堆"}.get(sequence[step], "牌区"))
		return "从%s选择第%d张置入%s" % [pile_label(str(_pending_card_choice["source"])),
			step + 1, destination_name]
	if _pending_card_choice["source"] == "hand" and _pending_card_choice["grant_retain_selected"]:
		return "选择 1 张其他手牌获得保留"
	var destination := "手牌" if _pending_card_choice["destination"] == "hand" else "抽牌堆顶"
	return "从%s选择 1 张加入%s" % [pile_label(str(_pending_card_choice["source"])), destination]


func choose_card_option(index: int) -> bool:
	if _pending_card_choice.is_empty():
		return false
	if index == -2:
		return skip_card_choice()
	var options: Array = _pending_card_choice["options"]
	if index < 0 or index >= options.size():
		return false
	if _pending_card_choice.get("kind", "pile") == "inspect_top":
		return _choose_top_inspection_option(index)
	if _pending_card_choice.get("kind", "") == "active_discard":
		return _choose_active_discard_option(index)
	if not _pending_card_choice.get("selection_destinations", []).is_empty():
		return _choose_persistent_sequence_option(index)
	var unit: BattleUnit = _pending_card_choice["unit"]
	var source: Array[CardData]
	match _pending_card_choice["source"]:
		"draw": source = unit.draw_pile
		"discard": source = unit.discard_pile
		"hand": source = unit.hand
		"deck": source = unit.character_data.deck
		"library": source = options
		_: return false
	var source_index: int = _pending_card_choice["indices"][index]
	var is_persistent_source: bool = _pending_card_choice["source"] in ["deck", "library"]
	var selected: CardData = options[index] if is_persistent_source else source[source_index]
	var stays_in_hand: bool = _pending_card_choice["source"] == "hand" and _pending_card_choice["destination"] == "hand"
	if not stays_in_hand and not is_persistent_source:
		source.remove_at(source_index)
	if is_persistent_source or _pending_card_choice["exhaust_selected_on_play"] or int(_pending_card_choice["selected_cost_override"]) >= 0 or int(_pending_card_choice["selected_cost_reduction"]) > 0 or _pending_card_choice["grant_retain_selected"]:
		selected = selected.duplicate(true) as CardData
	if _pending_card_choice["exhaust_selected_on_play"]:
		selected.exhaust_on_play = true
	if int(_pending_card_choice["selected_cost_override"]) >= 0:
		selected.temporary_cost_override = int(_pending_card_choice["selected_cost_override"])
	if int(_pending_card_choice["selected_cost_reduction"]) > 0:
		selected.temporary_cost_reduction += int(_pending_card_choice["selected_cost_reduction"])
	if _pending_card_choice["grant_retain_selected"]:
		selected.retain = true
	if _pending_card_choice["temporary_copy"]:
		selected.temporary_copy = true
	var destination: String = _pending_card_choice["destination"]
	var continuation: Dictionary = _pending_card_choice.get("continuation", {})
	if stays_in_hand:
		unit.hand[source_index] = selected
	elif destination == "hand":
		unit.hand.append(selected)
	else:
		unit.draw_pile.append(selected)
	_pending_card_choice.clear()
	_log("%s 选择「%s」加入%s" % [unit.get_display_name(), selected.card_name,
		"手牌" if destination == "hand" else "抽牌堆顶"])
	if not continuation.is_empty():
		_resolve_effects_from(unit, continuation["card"], continuation["target"],
			continuation["next_index"], continuation["play_context"])
	return true


func _choose_persistent_sequence_option(index: int) -> bool:
	var unit: BattleUnit = _pending_card_choice["unit"]
	var options: Array = _pending_card_choice["options"]
	var destinations: Array = _pending_card_choice["selection_destinations"]
	var step: int = _pending_card_choice["selection_step"]
	var destination: String = destinations[step]
	if destination == "hand" and unit.hand.size() >= MAX_HAND_SIZE:
		return false
	var selected: CardData = (options[index] as CardData).duplicate(true) as CardData
	match destination:
		"hand": unit.hand.append(selected)
		"draw_top": unit.draw_pile.append(selected)
		"draw_bottom": unit.draw_pile.insert(0, selected)
		"discard": unit.discard_pile.append(selected)
	options.remove_at(index)
	_pending_card_choice["selection_step"] = step + 1
	_log("%s 选择「%s」置入%s" % [unit.get_display_name(), selected.card_name,
		{"hand": "手牌", "draw_top": "抽牌堆顶", "draw_bottom": "抽牌堆底",
			"discard": "弃牌堆"}[destination]])
	if step + 1 >= destinations.size() or options.is_empty():
		var continuation: Dictionary = _pending_card_choice.get("continuation", {})
		_pending_card_choice.clear()
		if not continuation.is_empty():
			_resolve_effects_from(unit, continuation["card"], continuation["target"],
				continuation["next_index"], continuation["play_context"])
	elif options.size() == 1:
		return _choose_persistent_sequence_option(0)
	return true


func skip_card_choice() -> bool:
	if not card_choice_can_skip():
		return false
	if _pending_card_choice.get("kind", "") == "active_discard":
		_finish_active_discard()
		return true
	_pending_card_choice["discard_optional_left"] = 0
	var options: Array = _pending_card_choice["options"]
	if _pending_card_choice["reorder"] and options.size() > 1:
		_pending_card_choice["phase"] = "order"
	else:
		_finish_top_inspection()
	return true


func _choose_active_discard_option(index: int) -> bool:
	var unit: BattleUnit = _pending_card_choice["unit"]
	if index >= unit.hand.size():
		return false
	var selected: CardData = unit.hand[index]
	unit.hand.remove_at(index)
	unit.discard_pile.append(selected)
	unit.active_discards_this_turn += 1
	_pending_card_choice["min_left"] = maxi(int(_pending_card_choice["min_left"]) - 1, 0)
	_pending_card_choice["max_left"] = int(_pending_card_choice["max_left"]) - 1
	var block_gain: int = _pending_card_choice["block_per_card"]
	if block_gain > 0:
		unit.block_value += block_gain
		unit.refresh_block_display()
	_log("%s 主动弃置「%s」%s" % [unit.get_display_name(), selected.card_name,
		"，获得 %d 格挡" % block_gain if block_gain > 0 else ""])
	if int(_pending_card_choice["max_left"]) <= 0 or unit.hand.is_empty():
		_finish_active_discard()
	else:
		_pending_card_choice["options"] = unit.hand.duplicate()
	return true


func _finish_active_discard() -> void:
	var unit: BattleUnit = _pending_card_choice["unit"]
	var continuation: Dictionary = _pending_card_choice.get("continuation", {})
	_pending_card_choice.clear()
	if not continuation.is_empty():
		_resolve_effects_from(unit, continuation["card"], continuation["target"],
			continuation["next_index"], continuation["play_context"])


func _choose_top_inspection_option(index: int) -> bool:
	var unit: BattleUnit = _pending_card_choice["unit"]
	var options: Array = _pending_card_choice["options"]
	var selected: CardData = options[index]
	options.remove_at(index)
	match _pending_card_choice["phase"]:
		"hand":
			unit.hand.append(selected)
			_log("%s 将查看的「%s」加入手牌" % [unit.get_display_name(), selected.card_name])
			if (int(_pending_card_choice["discard_left"]) > 0
				or int(_pending_card_choice["discard_optional_left"]) > 0) and not options.is_empty():
				_pending_card_choice["phase"] = "discard"
			elif _pending_card_choice["reorder"] and options.size() > 1:
				_pending_card_choice["phase"] = "order"
			else:
				_finish_top_inspection()
		"discard":
			unit.discard_pile.append(selected)
			_log("%s 将查看的「%s」置入弃牌堆" % [unit.get_display_name(), selected.card_name])
			if int(_pending_card_choice["discard_left"]) > 0:
				_pending_card_choice["discard_left"] = int(_pending_card_choice["discard_left"]) - 1
			else:
				_pending_card_choice["discard_optional_left"] = int(_pending_card_choice["discard_optional_left"]) - 1
			if (int(_pending_card_choice["discard_left"]) > 0
				or int(_pending_card_choice["discard_optional_left"]) > 0) and not options.is_empty():
				pass
			elif _pending_card_choice["reorder"] and options.size() > 1:
				_pending_card_choice["phase"] = "order"
			else:
				_finish_top_inspection()
		"order":
			var ordered: Array = _pending_card_choice["ordered"]
			ordered.append(selected)
			if options.size() <= 1:
				_finish_top_inspection()
	return true


func _finish_top_inspection() -> void:
	var unit: BattleUnit = _pending_card_choice["unit"]
	var top_first: Array = _pending_card_choice["ordered"]
	top_first.append_array(_pending_card_choice["options"])
	for i in range(top_first.size() - 1, -1, -1):
		unit.draw_pile.append(top_first[i])
	var continuation: Dictionary = _pending_card_choice.get("continuation", {})
	_pending_card_choice.clear()
	if not continuation.is_empty():
		_resolve_effects_from(unit, continuation["card"], continuation["target"],
			continuation["next_index"], continuation["play_context"])


func mulligan_hand(unit: BattleUnit) -> void:
	var count := unit.hand.size()
	if count <= 0:
		return
	for card in unit.hand:
		unit.draw_pile.append(card)
	unit.hand.clear()
	shuffle(unit.draw_pile)
	draw_cards(unit, count)
	_log("%s 将 %d 张其他手牌洗回抽牌堆并重抽" % [unit.get_display_name(), count])


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
	var prototype := get_card(card_name)
	if prototype == null:
		_log("卡牌「%s」不存在，无法加入%s" % [card_name, pile_label(pile)])
		return
	var count := maxi(value, 0)
	for i in count:
		var card := prototype.duplicate(true) as CardData
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
	var hp_before := hp_target.current_hp
	var amount := effect.value
	if not effect.value_from_target_buff_stacks.is_empty():
		amount = int(find_buff(hp_target, effect.value_from_target_buff_stacks).get("stacks", 0))
	lose_hp(hp_target, amount)
	if effect.target == "enemy" and hp_target.current_hp < hp_before:
		unit.direct_hp_loss_targets[hp_target.get_instance_id()] = true


func pile_label(pile: String) -> String:
	match pile:
		"hand":
			return "手牌"
		"draw":
			return "抽牌堆"
		"discard":
			return "弃牌堆"
		"deck":
			return "卡组"
		"library":
			return "牌库"
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
