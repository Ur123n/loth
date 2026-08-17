class_name BattleManager
extends RefCounted

## 战斗流程管理器（逻辑层）。
## 回合开始 → 计算行动次序 → 检查该次序 buff → 抽牌（基础 5 张 + 预抽牌）→ 获得费用（基础 3 + 费用预支）
## → 玩家行动（移动 / 出牌并按顺序结算效果）→ 结束回合（手牌入弃牌堆）→ 下一行动单位。
## 敌怪参与行动次序：其回合由 AI 驱动（靠近/远离，由 battle_map 执行）。
## 伤害公式（GDD 第 6 节）：攻击伤害 = 攻击卡面板 * (1 + 力量伤害补正 * (力量 - 10))。
## 整数计算：玩家对敌怪伤害向上取整，敌怪对玩家伤害向下取整。
## 战斗数据分类（2026-08-12 统一）：
## - 失去生命（lose_hp）：无伤害来源，无视格挡，不受力量/易伤影响（如中毒、自损）；
## - 受到伤害（take_damage）：有伤害来源（已含力量/虚弱修正），受易伤放大，可被格挡抵消。
## 格挡（block_value）：护盾与格挡统一为单一数值，轮次开始时清空（TurnSystem），先于生命抵消伤害。
## 生命变化发出 hp_changed（供 UI 刷新）；生命归零发出 unit_defeated（敌怪变尸骸等）。
## buff 实例：{"name","stacks","duration","value","data"}，数据来自 BuffDB。
## 触发时机（trigger_timing）说明：
## - 下回合开始时    → 目标下一次行动开始时（预格挡）；
## - 下回合抽牌时    → 玩家下一次抽牌阶段（预抽牌）；
## - 下回合获得费用时 → 玩家下一次获得费用阶段（费用预支）；
## - 下回合角色行动阶段 → 玩家行动阶段（疗愈，每次触发层数减一）；
## - 结束回合时      → 行动结束结算（中毒）。

signal round_started(round_number: int)
signal turn_started(unit: BattleUnit)
signal card_played(unit: BattleUnit, card: CardData)
signal unit_defeated(unit: BattleUnit)
signal hp_changed(unit: BattleUnit)
signal battle_log(message: String)
## 战斗结束（场上除玩家角色外只剩尸骸 / 全队倒地）：携带奖励（钱币/经验/战利品物品列表）。
## defeated=true 表示全队倒地（战斗失败，无奖励）。
signal battle_finished(coins: int, exp: int, loot: Array, defeated: bool)

const HAND_SIZE := 5
const MAX_HAND_SIZE := 10
const ENERGY_PER_TURN := 3
const BASIC_STRIKE_NAME := "打击"
const BASIC_DEFEND_NAME := "防御"
const BASIC_STRIKE_COUNT := 5
const BASIC_DEFEND_COUNT := 5

var turn_system: TurnSystem
var units: Array[BattleUnit] = []

var _rng: RandomNumberGenerator
var _card_lookup: Callable = Callable()
var _battle_over: bool = false


func setup(battle_units: Array[BattleUnit], rng: RandomNumberGenerator = null, card_lookup: Callable = Callable()) -> void:
	units = battle_units
	_battle_over = false
	_rng = rng if rng != null else RandomNumberGenerator.new()
	_card_lookup = card_lookup
	if not _card_lookup.is_valid():
		_card_lookup = func(name: String) -> CardData:
			var db := _get_autoload("CardDB")
			return db.get_card(name) if db != null else null
	turn_system = TurnSystem.new()
	turn_system.round_started.connect(_on_round_started)
	turn_system.turn_started.connect(_on_turn_started)
	turn_system.setup(units, _rng)
	_prepare_battle_decks()


func start_battle() -> void:
	turn_system.start_round()


func current_unit() -> BattleUnit:
	return turn_system.current_unit()


## 结束当前角色行动：先结算“结束回合时”触发的 buff（如中毒），
## 然后手牌入弃牌堆、费用清零，进入下一行动单位。
func end_turn() -> void:
	if _battle_over:
		return
	var unit := turn_system.current_unit()
	if unit == null:
		return
	_resolve_end_turn_buffs(unit)
	_resolve_passives_by_timing(unit, "结束回合")
	_discard_hand(unit)
	unit.energy = 0
	unit.flank_trigger_damage = 0
	unit.pending_knockback = 0
	unit.moved_this_turn = false
	turn_system.end_current_turn()


## 敌怪行动结束：结算“结束回合时”buff（如中毒）后进入下一行动单位。
func end_enemy_turn(unit: BattleUnit) -> void:
	if _battle_over or unit == null:
		return
	_resolve_end_turn_buffs(unit)
	turn_system.end_current_turn()


## 打出卡牌：扣除费用 → 按 effects 顺序结算 → 入弃牌堆（能力牌自动消失）。
func play_card(card: CardData, target = null) -> bool:
	var unit := turn_system.current_unit()
	if unit == null or not unit.hand.has(card):
		return false
	if card.cost > unit.energy:
		battle_log.emit("费用不足，无法打出「%s」" % card.card_name)
		return false
	if card.doom_dream and unit.dream_progress < 2:
		battle_log.emit("「%s」未解锁：需本场战斗先打出过沉梦牌，再打出过幻梦牌" % card.card_name)
		return false
	unit.energy -= card.cost
	unit.hand.erase(card)
	if card.dream and unit.dream_progress == 0:
		unit.dream_progress = 1
		battle_log.emit("梦境觉醒（1/2）：已打出沉梦牌")
	elif card.phantom and unit.dream_progress == 1:
		unit.dream_progress = 2
		battle_log.emit("梦境觉醒（2/2）：沉梦→幻梦顺序完成，灾梦已解锁！")
	_resolve_effects(unit, card, target)
	unit.last_played_card = card
	if card.should_exhaust_on_play():
		_exhaust_card(unit, card)
	else:
		unit.discard_pile.append(card)
		battle_log.emit("「%s」进入弃牌堆" % card.card_name)
	card_played.emit(unit, card)
	return true


## 整数伤害计算：面板 * 基数 / 100。
## 玩家对敌怪向上取整；敌怪对玩家向下取整；结果不小于 0。
static func compute_damage(panel_value: int, basis: int, attacker_is_enemy: bool) -> int:
	var raw := panel_value * basis
	var damage := raw / 100
	if not attacker_is_enemy:
		damage = (raw + 99) / 100
	return maxi(damage, 0)


## 敌怪攻击：伤害在敌怪数据范围内随机，属于“受到伤害”，经过目标易伤/格挡/生命结算。
func enemy_attack(attacker: BattleUnit, target: BattleUnit) -> void:
	if attacker == null or target == null:
		return
	var damage := attacker.get_attack_damage()
	take_damage(target, damage)
	battle_log.emit("%s 攻击 %s，造成 %d 点伤害" % [
		attacker.get_display_name(), target.get_display_name(), damage])


func _on_round_started(round_number: int) -> void:
	battle_log.emit("—— 第 %d 回合开始 ——" % round_number)
	round_started.emit(round_number)


func _on_turn_started(unit: BattleUnit) -> void:
	if _battle_over:
		return
	# 倒地单位无法行动（GDD 第 17 节）：直接跳过其回合
	if unit.current_hp <= 0:
		battle_log.emit("%s 已倒地，跳过行动" % unit.get_display_name())
		turn_system.end_current_turn()
		return
	_resolve_turn_start_buffs(unit)    # 下回合开始时触发（预格挡），触发后消失
	_resolve_passives_by_timing(unit, "回合开始")   # 道途被动（沉梦等）
	var extra_draw := 0
	var extra_energy := 0
	if not unit.is_enemy:
		var passive := _get_passive(unit)
		if passive != null and turn_system.round_number == 1:
			if passive.trigger_timing.contains("抽牌"):
				# 先下手为强：固定额外抽 2 张（道途被动数值列已删除，按名称实现）
				var bonus_draw := 2 if passive.passive_name == "先下手为强" else maxi(passive.value, 0)
				extra_draw += bonus_draw
				battle_log.emit("「%s」被动：第一回合额外抽 %d 张牌" % [passive.passive_name, bonus_draw])
			if passive.passive_name == "先下手为强":
				unit.remaining_move_points += 1
				battle_log.emit("「先下手为强」被动：第一回合移动力 +1")
		extra_draw += _consume_draw_bonus(unit)       # 下回合抽牌时触发（预抽牌）
		extra_energy += _consume_energy_bonus(unit)   # 下回合获得费用时触发（费用预支）
	_resolve_turn_buffs(unit)          # 检查该次序结算的 buff（衰减/持续时间）
	if unit.is_enemy:
		battle_log.emit("%s 的回合" % unit.get_display_name())
		turn_started.emit(unit)        # AI 行动由 battle_map 执行
		return
	# 装备修正（有舍有得）：每回合抽牌/费用 ±N、回合开始获得格挡
	if unit.character_data != null:
		extra_draw += unit.character_data.get_equipment_mod_total("draw_modifier")
		extra_energy += unit.character_data.get_equipment_mod_total("energy_modifier")
		var equip_block := unit.character_data.get_equipment_mod_total("block_on_turn_start")
		if equip_block != 0:
			unit.block_value += equip_block
			unit.refresh_block_display()
			battle_log.emit("%s 因装备获得 %d 点格挡（当前 %d）" % [
				unit.get_display_name(), equip_block, unit.block_value])
	_draw_cards(unit, HAND_SIZE + extra_draw)       # 抽基础牌 + 预抽牌额外张数
	unit.energy = ENERGY_PER_TURN + extra_energy    # 基础费用 + 费用预支额外费用
	battle_log.emit("%s 行动：抽 %d 张牌，获得 %d 费用" % [
		unit.get_display_name(), HAND_SIZE + extra_draw, ENERGY_PER_TURN + extra_energy])
	_resolve_action_phase_buffs(unit)  # 角色行动阶段触发（疗愈，层数减一）
	turn_started.emit(unit)


func _prepare_battle_decks() -> void:
	for unit in units:
		if unit.is_enemy:
			continue
		unit.draw_pile.clear()
		unit.hand.clear()
		unit.discard_pile.clear()
		unit.exhaust_pile.clear()
		unit.energy = 0
		unit.block_value = 0
		unit.current_hp = unit.get_max_hp_value()
		unit.refresh_hp_display()
		unit.buffs.clear()
		unit.flank_trigger_damage = 0
		unit.pending_knockback = 0
		unit.dream_progress = 0
		unit.last_played_card = null
		unit.moved_this_turn = false
		# 抽牌堆 = 角色卡组（启动时已保证含 5 打击 + 5 防御）
		for card in unit.character_data.deck:
			unit.draw_pile.append(card)
		# 兜底：牌组为空（直接运行战斗场景等）时补入基础牌
		if unit.draw_pile.is_empty():
			battle_log.emit("%s 牌组为空，补入基础牌" % unit.get_display_name())
			for i in BASIC_STRIKE_COUNT:
				var strike := _get_card(BASIC_STRIKE_NAME)
				if strike != null:
					unit.draw_pile.append(strike)
			for i in BASIC_DEFEND_COUNT:
				var defend := _get_card(BASIC_DEFEND_NAME)
				if defend != null:
					unit.draw_pile.append(defend)
		_shuffle(unit.draw_pile)
		_put_innate_cards_in_hand(unit)


func _draw_cards(unit: BattleUnit, count: int) -> void:
	for i in count:
		if unit.hand.size() >= MAX_HAND_SIZE:
			battle_log.emit("%s 手牌已达上限 %d，停止抽牌" % [unit.get_display_name(), MAX_HAND_SIZE])
			break
		if unit.draw_pile.is_empty():
			_refill_draw_pile(unit)
			if unit.draw_pile.is_empty():
				break
		unit.hand.append(unit.draw_pile.pop_back())


func _refill_draw_pile(unit: BattleUnit) -> void:
	if unit.discard_pile.is_empty():
		return
	battle_log.emit("%s 的弃牌堆洗回抽牌堆" % unit.get_display_name())
	for card in unit.discard_pile:
		unit.draw_pile.append(card)
	unit.discard_pile.clear()
	_shuffle(unit.draw_pile)


## 回合结束处理手牌：虚无牌被消耗；保留牌留在手牌；其余进入弃牌堆。
func _discard_hand(unit: BattleUnit) -> void:
	var kept: Array[CardData] = []
	var discarded := 0
	var exhausted := 0
	for card in unit.hand:
		if card.ethereal:
			_exhaust_card(unit, card, "虚无")
			exhausted += 1
		elif card.retain:
			kept.append(card)
		else:
			unit.discard_pile.append(card)
			discarded += 1
	unit.hand = kept
	if discarded > 0:
		battle_log.emit("%s 弃掉手牌 %d 张" % [unit.get_display_name(), discarded])
	if exhausted > 0:
		battle_log.emit("%s 的 %d 张虚无牌被消耗" % [unit.get_display_name(), exhausted])


## 回合开始时检查该单位 buff：
## - 每回合衰减的 buff 层数减少（decay_amount，不低于 1）
## - 持续时间 -1，归零后移除
func _resolve_turn_buffs(unit: BattleUnit) -> void:
	if unit.buffs.is_empty():
		return
	var remaining: Array = []
	for buff in unit.buffs:
		var data: BuffData = buff.get("data")
		if data != null and data.decay_per_turn and int(buff.get("stacks", 1)) > 1:
			var decay_amount := data.decay_amount
			buff["stacks"] = maxi(int(buff["stacks"]) - decay_amount, 1)
			battle_log.emit("「%s」的 buff「%s」层数衰减至 %d" % [
				unit.get_display_name(), buff.get("name", ""), buff["stacks"]])
		buff["duration"] = int(buff.get("duration", 0)) - 1
		if int(buff["duration"]) > 0:
			remaining.append(buff)
		else:
			battle_log.emit("「%s」的 buff「%s」到期消失" % [
				unit.get_display_name(), buff.get("name", "")])
	unit.buffs = remaining


## 结算“结束回合时”触发的 buff（如中毒），并处理“触发后消失”。
func _resolve_end_turn_buffs(unit: BattleUnit) -> void:
	_resolve_buffs_by_timing(unit, "结束回合")


## 结算“下回合开始时”触发的 buff（如预格挡），并处理“触发后消失”。
func _resolve_turn_start_buffs(unit: BattleUnit) -> void:
	_resolve_buffs_by_timing(unit, "回合开始")


## 结算“下回合角色行动阶段”触发的 buff（如疗愈，层数减一）。
func _resolve_action_phase_buffs(unit: BattleUnit) -> void:
	_resolve_buffs_by_timing(unit, "行动阶段")


## 按触发时机关键词结算 buff；`_resolve_buff_trigger` 返回 true 的立即移除。
func _resolve_buffs_by_timing(unit: BattleUnit, timing_keyword: String) -> void:
	if unit.buffs.is_empty():
		return
	var to_remove: Array = []
	for buff in unit.buffs:
		var data: BuffData = buff.get("data")
		if data == null:
			continue
		if data.trigger_timing.contains(timing_keyword):
			if _resolve_buff_trigger(unit, buff, data):
				to_remove.append(buff)
	for buff in to_remove:
		unit.buffs.erase(buff)


## “下回合抽牌时”触发的 buff（预抽牌）：返回额外抽牌数，触发后消失。
func _consume_draw_bonus(unit: BattleUnit) -> int:
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
				battle_log.emit("「肾上腺素透支」还有 %d 回合生效" % (remain - 1))
				continue
			var penalty := int(buff.get("stacks", -2))
			bonus += penalty
			battle_log.emit("「肾上腺素透支」发作：本回合少抽 %d 张牌" % abs(penalty))
			to_remove.append(buff)
			continue
		var stacks := int(buff.get("stacks", 1))
		bonus += stacks
		battle_log.emit("「%s」的 buff「%s」触发：额外抽 %d 张牌" % [
			unit.get_display_name(), data.buff_name, stacks])
		to_remove.append(buff)
	for buff in to_remove:
		unit.buffs.erase(buff)
	return bonus


## “下回合获得费用时”触发的 buff（费用预支）：返回额外费用，触发后消失。
func _consume_energy_bonus(unit: BattleUnit) -> int:
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
		battle_log.emit("「%s」的 buff「%s」触发：额外获得 %d 点费用" % [
			unit.get_display_name(), data.buff_name, stacks])
		to_remove.append(buff)
	for buff in to_remove:
		unit.buffs.erase(buff)
	return bonus


## 按 buff 名称执行触发效果；返回是否应“触发后消失”。
func _resolve_buff_trigger(unit: BattleUnit, buff: Dictionary, data: BuffData) -> bool:
	match data.buff_name:
		"中毒":
			var damage := int(buff.get("stacks", 1))
			# 失去生命：无伤害来源，无视格挡，不受力量/易伤影响
			battle_log.emit("%s 因中毒失去 %d 点生命" % [unit.get_display_name(), damage])
			lose_hp(unit, damage)
		"预格挡":
			var amount := int(buff.get("stacks", 1))
			unit.block_value += amount
			unit.refresh_block_display()
			battle_log.emit("%s 获得 %d 点格挡（来自「预格挡」，当前 %d）" % [
				unit.get_display_name(), amount, unit.block_value])
		"疗愈":
			var heal := int(buff.get("stacks", 1))
			heal_unit(unit, heal)
			buff["stacks"] = int(buff.get("stacks", 1)) - 1
			if int(buff["stacks"]) <= 0:
				battle_log.emit("「%s」的 buff「疗愈」层数耗尽，消失" % unit.get_display_name())
				return true
			battle_log.emit("「%s」的 buff「疗愈」层数减至 %d" % [
				unit.get_display_name(), buff["stacks"]])
		_:
			battle_log.emit("buff「%s」触发（效果待定义）" % data.buff_name)
	return data.consumed_on_trigger


## 按 effects 顺序结算卡牌效果；挂载条件的效果在条件不满足时跳过。
func _resolve_effects(unit: BattleUnit, card: CardData, target = null) -> void:
	for effect in card.effects:
		if not _effect_condition_met(unit, effect):
			battle_log.emit("「%s」的条件未满足，跳过效果" % card.card_name)
			continue
		if effect is AttackEffect:
			_resolve_attack(unit, card, effect as AttackEffect, target)
		elif effect is MoveEffect:
			var move := effect as MoveEffect
			unit.remaining_move_points += move.distance
			battle_log.emit("%s 获得额外移动力 %d（当前 %d/%d）" % [
				unit.get_display_name(), move.distance,
				unit.remaining_move_points, unit.get_max_move_points()])
		elif effect is DefenseEffect:
			var defense := effect as DefenseEffect
			var defense_value := defense.alt_value if (defense.alt_value > 0 and unit.moved_this_turn) else defense.value
			# 装备「防御卡格挡 ±N」修正（铁剑：攻强守弱）
			var equip_defend := unit.character_data.get_equipment_mod_total("defend_bonus") if unit.character_data != null else 0
			if equip_defend != 0:
				defense_value = maxi(defense_value + equip_defend, 0)
				battle_log.emit("装备修正：%s 的防御卡格挡 %+d" % [unit.get_display_name(), equip_defend])
			unit.block_value += defense_value
			battle_log.emit("%s 获得 %d 点格挡（当前 %d）" % [
				unit.get_display_name(), defense_value, unit.block_value])
			unit.refresh_block_display()
		elif effect is BuffEffect:
			_resolve_buff_effect(unit, effect as BuffEffect, target)
		elif effect is DrawEffect:
			var draw := effect as DrawEffect
			_draw_cards(unit, draw.value)
			battle_log.emit("%s 抽 %d 张牌" % [unit.get_display_name(), draw.value])
		elif effect is DiscardEffect:
			_resolve_discard_effect(unit, effect as DiscardEffect)
		elif effect is AddToHandEffect:
			var add_hand := effect as AddToHandEffect
			_add_cards_to_pile(unit, "hand", add_hand.card_name, add_hand.value, "shuffle")
		elif effect is AddToDrawEffect:
			var add_draw := effect as AddToDrawEffect
			_add_cards_to_pile(unit, "draw", add_draw.card_name, add_draw.value, add_draw.position)
		elif effect is AddToDiscardEffect:
			var add_discard := effect as AddToDiscardEffect
			_add_cards_to_pile(unit, "discard", add_discard.card_name, add_discard.value, "shuffle")
		elif effect is GenerateEffect:
			_resolve_generate_effect(unit, effect as GenerateEffect)
		elif effect is CopyEffect:
			var copy := effect as CopyEffect
			_add_cards_to_pile(unit, copy.pile, card.card_name, copy.value, "shuffle")
			battle_log.emit("%s 将「%s」的 %d 张复制品放入%s" % [
				unit.get_display_name(), card.card_name, copy.value, _pile_label(copy.pile)])
		elif effect is LoseHpEffect:
			_resolve_lose_hp_effect(unit, effect as LoseHpEffect, target)
		elif effect is GainEnergyEffect:
			var gain := effect as GainEnergyEffect
			unit.energy += gain.value
			battle_log.emit("%s 获得 %d 点费用（当前 %d）" % [
				unit.get_display_name(), gain.value, unit.energy])
		elif effect is FlankEffect:
			var flank := effect as FlankEffect
			unit.flank_trigger_damage = maxi(unit.flank_trigger_damage, flank.value)
			battle_log.emit("%s 获得「伺机」：本回合离开攻击范围时造成 %d 点伤害" % [
				unit.get_display_name(), flank.value])
		elif effect is KnockbackEffect:
			var knock := effect as KnockbackEffect
			unit.pending_knockback = maxi(unit.pending_knockback, knock.value)
			battle_log.emit("%s 获得击退 %d 格效果" % [unit.get_display_name(), knock.value])


## 判断效果的挂载条件是否满足（无条件返回 true）。
func _effect_condition_met(unit: BattleUnit, effect: Resource) -> bool:
	if not effect.has_meta("condition"):
		return true
	var condition: Dictionary = effect.get_meta("condition", {})
	if condition.is_empty():
		return true
	var met := _evaluate_condition(unit, condition)
	if bool(condition.get("negate", false)):
		met = not met
	return met


## 条件求值：类型见 卡牌/conditions.json；未知类型默认视为满足（不阻塞）。
func _evaluate_condition(unit: BattleUnit, condition: Dictionary) -> bool:
	match str(condition.get("type", "")):
		"enemies_in_range":
			var count := 0
			for other in units:
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
			return _has_buff(unit, str(condition.get("buff_name", "")))
		"enemies_alive_at_least":
			var alive := 0
			for other in units:
				if other.is_enemy and not other.is_corpse and not other.is_removed:
					alive += 1
			return alive >= int(condition.get("count", 1))
		"last_card_keyword":
			var last := unit.last_played_card
			return last != null and last.keyword_labels().has(str(condition.get("keyword", "")))
	return true


## 攻击结算：整数计算，玩家对敌怪向上取整、敌怪对玩家向下取整；
## 攻击者带“虚弱”时造成伤害 -25%。
func _resolve_attack(unit: BattleUnit, card: CardData, effect: AttackEffect, target) -> void:
	if target is BattleUnit:
		var basis := 100
		if unit.character_data != null:
			basis = unit.character_data.get_strength_damage_basis()
		var attack_value := effect.alt_value if (effect.alt_value > 0 and unit.moved_this_turn) else effect.value
		if effect.alt_value > 0 and unit.moved_this_turn:
			battle_log.emit("条件触发：本回合已移动，攻击数值 %d" % attack_value)
		var damage := compute_damage(attack_value, basis, unit.is_enemy)
		if _has_buff(unit, "虚弱"):
			damage = damage * 75 / 100
			battle_log.emit("%s 受「虚弱」影响，造成伤害降至 %d" % [unit.get_display_name(), damage])
		var passive := _get_passive(unit)
		if passive != null:
			if passive.passive_name == "孢子怪力":
				damage = (damage * 125 + 99) / 100
				battle_log.emit("「孢子怪力」被动：伤害以 1.25 倍结算（%d）" % damage)
			if passive.passive_name == "药理精通" and _has_buff(target, "中毒"):
				var level_bonus := (unit.character_data.level / 5) if unit.character_data != null else 0
				var bonus := maxi(passive.value, 1) + level_bonus
				damage += bonus
				battle_log.emit("「药理精通」被动：对中毒敌人额外造成 %d 点伤害" % bonus)
		var ignore_block := effect.pierce
		if not ignore_block and card.phantom and unit.last_played_card != null and unit.last_played_card.dream:
			ignore_block = true
			battle_log.emit("「幻梦」：上一张为沉梦牌，本次攻击无视护甲")
		var dealt := take_damage(target, damage, ignore_block)
		battle_log.emit("%s 对 %s 造成 %d 点伤害" % [
			unit.get_display_name(), target.get_display_name(), damage])
		if card.lifesteal and dealt > 0:
			heal_unit(unit, dealt)
			battle_log.emit("「吸血」：%s 恢复 %d 点生命（等量于造成的伤害）" % [
				unit.get_display_name(), dealt])
	else:
		battle_log.emit("「%s」没有目标，未造成伤害" % card.card_name)


## 按触发时机结算道途基础被动（回合开始/结束回合等）。
func _resolve_passives_by_timing(unit: BattleUnit, timing_keyword: String) -> void:
	var passive := _get_passive(unit)
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
			battle_log.emit("「沉梦」被动：%s 获得 %d 点格挡（当前 %d）" % [
				unit.get_display_name(), amount, unit.block_value])
		"孢子怪力":
			if timing_keyword != "回合开始":
				return
			unit.block_value += 1
			unit.refresh_block_display()
			battle_log.emit("「孢子怪力」被动：%s 获得 1 点护甲（当前 %d）" % [
				unit.get_display_name(), unit.block_value])
		_:
			battle_log.emit("被动「%s」触发（效果待定义）" % passive.passive_name)


## 角色的基础被动（道途接口）；未设置道途/被动返回 null。
func _get_passive(unit: BattleUnit) -> PassiveData:
	if unit == null or unit.character_data == null:
		return null
	return unit.character_data.get_passive()


## 直接给目标施加/叠加 buff（不经过卡牌效果，用于被动等）。
func _apply_buff_direct(target: BattleUnit, buff_name: String, stacks: int = 1) -> void:
	if target == null:
		return
	var existing := _find_buff(target, buff_name)
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
	hp_changed.emit(target)
	if target.current_hp <= 0:
		unit_defeated.emit(target)
		_check_battle_over()


## 受到伤害：有伤害来源（已含力量/虚弱修正），受易伤放大，
## 可被格挡抵消，最后扣除生命；生命变化发出 hp_changed，归零发出 unit_defeated。
func take_damage(target: BattleUnit, amount: int, ignore_block: bool = false) -> int:
	if target == null:
		return 0
	var final_amount := maxi(amount, 0)
	if _has_buff(target, "易伤"):
		final_amount = (final_amount * 150 + 99) / 100
		battle_log.emit("%s 受「易伤」影响，伤害提升至 %d" % [target.get_display_name(), final_amount])
	var remaining := final_amount
	if not ignore_block and target.block_value > 0:
		var absorbed := mini(target.block_value, remaining)
		target.block_value -= absorbed
		remaining -= absorbed
		battle_log.emit("%s 的格挡抵消 %d 点伤害（剩余格挡 %d）" % [
			target.get_display_name(), absorbed, target.block_value])
		target.refresh_block_display()
	if ignore_block and final_amount > 0:
		battle_log.emit("%s 的护甲被无视，直接承受 %d 点伤害" % [target.get_display_name(), remaining])
	var hp_before := target.current_hp
	target.current_hp = maxi(0, target.current_hp - remaining)
	var dealt := hp_before - target.current_hp
	target.refresh_hp_display()
	hp_changed.emit(target)
	if target.current_hp <= 0:
		unit_defeated.emit(target)
		_check_battle_over()
	return dealt


## 战斗结束判定：场上除了玩家操控角色以外只剩尸骸/已移除单位时结束。
## 结束即按已击败敌怪的掉落表结算奖励（钱币/经验/战利品），只结算一次。
func _check_battle_over() -> void:
	if _battle_over:
		return
	var living_enemy := false
	var living_player := false
	for unit in units:
		if unit.is_enemy and not unit.is_corpse and not unit.is_removed:
			living_enemy = true
		elif not unit.is_enemy and unit.current_hp > 0:
			living_player = true
	if living_enemy and living_player:
		return
	_battle_over = true
	if not living_player:
		# 全队倒地：战斗失败，无奖励（GDD 第 17 节）
		battle_log.emit("全队倒地，战斗失败")
		battle_finished.emit(0, 0, [], true)
		return
	var coins := 0
	var exp := 0
	var loot: Array[ItemData] = []
	for unit in units:
		if not unit.is_enemy:
			continue
		var enemy_data := unit.enemy_data
		if enemy_data == null:
			continue
		coins += enemy_data.roll_coins()
		exp += enemy_data.exp
		_roll_loot(enemy_data, loot)
	battle_log.emit("战斗结束：获得 %d 钱币、%d 经验" % [coins, exp])
	battle_finished.emit(coins, exp, loot, false)


## 按敌怪战利品表掷骰：每条目 chance%（1-100）判定，命中则加入 count 件。
func _roll_loot(enemy_data: EnemyData, loot: Array[ItemData]) -> void:
	var item_db := _get_autoload("ItemDB")
	if item_db == null:
		return
	for entry in enemy_data.loot_table:
		if not entry is Dictionary:
			continue
		var chance := int(entry.get("chance", 0))
		if _rng.randi_range(1, 100) > chance:
			continue
		var item: ItemData = item_db.get_item(str(entry.get("item", "")))
		if item == null:
			continue
		var count := maxi(int(entry.get("count", 1)), 1)
		for i in count:
			loot.append(item)


## 恢复生命：不超过最大生命，发出 hp_changed 供 UI 刷新。
func heal_unit(target: BattleUnit, amount: int) -> void:
	if target == null:
		return
	var healed := mini(amount, target.get_max_hp_value() - target.current_hp)
	if healed <= 0:
		battle_log.emit("%s 生命已满，未恢复" % target.get_display_name())
		return
	target.current_hp += healed
	target.refresh_hp_display()
	hp_changed.emit(target)
	battle_log.emit("%s 恢复 %d 点生命（%d/%d）" % [
		target.get_display_name(), healed, target.current_hp, target.get_max_hp_value()])


## buff 结算：数据来自 BuffDB；重复施加时叠层（无上限），
## 层数持续型每次叠层增加 duration_per_stack 回合。
func _resolve_buff_effect(unit: BattleUnit, effect: BuffEffect, target) -> void:
	var buff_target: BattleUnit = null
	if effect.target == "ally":
		buff_target = target if target is BattleUnit else unit
	elif effect.target == "enemy":
		buff_target = target if target is BattleUnit else null
	else:
		buff_target = unit
	if buff_target == null:
		battle_log.emit("buff 没有目标")
		return
	var buff_name := effect.buff_type if not effect.buff_type.is_empty() else "占位buff"
	var buff_data: BuffData = null
	var buff_db := _get_autoload("BuffDB")
	if buff_db != null:
		buff_data = buff_db.get_buff(buff_name)
	var existing := _find_buff(buff_target, buff_name)
	if not existing.is_empty():
		var new_stacks := int(existing["stacks"]) + effect.stacks
		existing["stacks"] = new_stacks
		if buff_data != null and buff_data.buff_type.contains("层数持续"):
			existing["duration"] = int(existing["duration"]) + buff_data.duration_per_stack * maxi(effect.stacks, 0)
		# 层数无上限；层数增益型且不消失的 buff（如疗愈）持续时间跟随层数，避免提前到期
		if buff_data != null and buff_data.buff_type.contains("层数增益") and not buff_data.consumed_on_trigger:
			existing["duration"] = maxi(int(existing["duration"]), new_stacks)
		battle_log.emit("%s 的 buff「%s」层数提升至 %d" % [
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
	battle_log.emit("%s 获得 buff「%s」，持续 %d 回合" % [
		buff_target.get_display_name(), buff_name, duration])


func _find_buff(unit: BattleUnit, buff_name: String) -> Dictionary:
	for buff in unit.buffs:
		if buff.get("name", "") == buff_name:
			return buff
	return {}


func _has_buff(unit: BattleUnit, buff_name: String) -> bool:
	return not _find_buff(unit, buff_name).is_empty()


func _get_card(card_name: String) -> CardData:
	return _card_lookup.call(card_name) as CardData


## 从场景树获取自动加载单例（CardDB/BuffDB 等）。
## 无头脚本模式（--script）下自动加载不注册，此时返回 null，由调用方兜底。
static func _get_autoload(name: String) -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(name)
	return null


## 固有牌：战斗开始时直接进入手牌（受手牌上限约束）。
func _put_innate_cards_in_hand(unit: BattleUnit) -> void:
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
		battle_log.emit("%s 的 %d 张固有牌开局入手" % [unit.get_display_name(), placed])


## 消耗一张牌：进入消耗堆（本场战斗移除，不会洗回抽牌堆）。
func _exhaust_card(unit: BattleUnit, card: CardData, reason: String = "打出") -> void:
	if card == null:
		return
	unit.exhaust_pile.append(card)
	battle_log.emit("「%s」被消耗（%s）" % [card.card_name, reason])


## 弃牌效果：mode = all 弃掉全部手牌；mode = random 随机弃掉 value 张。
func _resolve_discard_effect(unit: BattleUnit, effect: DiscardEffect) -> void:
	if effect.mode == "all":
		var count := unit.hand.size()
		for card in unit.hand:
			unit.discard_pile.append(card)
		unit.hand.clear()
		battle_log.emit("%s 弃掉全部手牌 %d 张" % [unit.get_display_name(), count])
		return
	var discard_count := mini(maxi(effect.value, 0), unit.hand.size())
	for i in discard_count:
		var index := _rng.randi_range(0, unit.hand.size() - 1)
		unit.discard_pile.append(unit.hand[index])
		unit.hand.remove_at(index)
	battle_log.emit("%s 随机弃掉 %d 张手牌" % [unit.get_display_name(), discard_count])


## 把指定卡牌的 value 张复制放入指定牌堆。
## pile: hand / draw / discard；draw 时 position = top（置于抽牌堆顶，后抽到）或 shuffle（洗入）。
func _add_cards_to_pile(unit: BattleUnit, pile: String, card_name: String, value: int, position: String = "shuffle") -> void:
	var card := _get_card(card_name)
	if card == null:
		battle_log.emit("卡牌「%s」不存在，无法加入%s" % [card_name, _pile_label(pile)])
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
		_shuffle(unit.draw_pile)
	battle_log.emit("%s 将 %d 张「%s」加入%s" % [unit.get_display_name(), count, card_name, _pile_label(pile)])


## 生成牌效果：card_name 为空时按 pool（攻击/行动/能力/全部）随机生成一张。
func _resolve_generate_effect(unit: BattleUnit, effect: GenerateEffect) -> void:
	var pile: String = effect.pile if not effect.pile.is_empty() else "hand"
	if effect.card_name.is_empty():
		var random_card := _random_card_from_pool(effect.pool)
		if random_card == null:
			battle_log.emit("随机牌池为空，无法生成牌")
			return
		_add_cards_to_pile(unit, pile, random_card.card_name, effect.value, "shuffle")
		return
	_add_cards_to_pile(unit, pile, effect.card_name, effect.value, "shuffle")


## 从牌池随机选一张卡：pool = 攻击 / 行动 / 能力 / 全部（空）。
func _random_card_from_pool(pool: String) -> CardData:
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
func _resolve_lose_hp_effect(unit: BattleUnit, effect: LoseHpEffect, target) -> void:
	if effect.target == "enemy" and not (target is BattleUnit):
		battle_log.emit("「失去生命」没有敌方目标")
		return
	var hp_target: BattleUnit = target if (effect.target == "enemy" and target is BattleUnit) else unit
	lose_hp(hp_target, effect.value)


func _pile_label(pile: String) -> String:
	match pile:
		"hand":
			return "手牌"
		"draw":
			return "抽牌堆"
		"discard":
			return "弃牌堆"
	return pile


func _shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp
