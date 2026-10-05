class_name BattleManager
extends RefCounted

## 战斗流程管理器（逻辑层）。
## 只保留：回合流程、行动顺序、出牌入口、胜负判定、战利品。
## 效果结算（卡牌效果 / buff / 通用伤害）由 core/effect/effect_system.gd（EffectSystem）接管；
## 文件末尾保留同名私有转发方法，保证既有测试与调用方接口不变。
## 伤害公式（GDD 第 6 节）：攻击伤害 = 攻击卡面板 * (1 + 力量伤害补正 * (力量 - 10))。
## 整数计算：玩家对敌怪伤害向上取整，敌怪对玩家伤害向下取整。
## 战斗数据分类（2026-08-12 统一）：
## - 失去生命（lose_hp）：无伤害来源，无视格挡，不受力量/易伤影响（如中毒、自损）；
## - 受到伤害（take_damage）：有伤害来源（已含力量/虚弱修正），受易伤放大，可被格挡抵消。
## 格挡（block_value）：护盾与格挡统一为单一数值，轮次开始时清空（TurnSystem），先于生命抵消伤害。
## 生命变化发出 hp_changed（供 UI 刷新）；生命归零发出 unit_defeated（敌怪变尸骸等）。
## buff 实例：{"name","stacks","duration","value","data"}，数据来自 BuffDB。
## 触发时机（trigger_timing）说明（全部由 EffectSystem 统一结算）：
## - 下回合开始时    → 目标下一次行动开始时（预格挡）；
## - 下回合抽牌时    → 玩家下一次抽牌阶段（预抽牌 / 肾上腺素透支）；
## - 下回合获得费用时 → 玩家下一次获得费用阶段（费用预支）；
## - 下回合角色行动阶段 → 玩家行动阶段（疗愈，每次触发层数减一）；
## - 结束回合时      → 行动结束结算（中毒）；
## - 受到攻击时 / 造成攻击伤害时 → 攻击类时机，作为伤害修正钩子在 EffectSystem
##   的 take_damage / resolve_attack 中结算（易伤 +50%、虚弱 -25%），不消耗层数。
## buff 触发行为按名称注册为函数（EffectSystem 的 buff 行为注册表），本管理器仅转发。

signal round_started(round_number: int)
signal turn_started(unit: BattleUnit)
signal card_played(unit: BattleUnit, card: CardData)
signal card_choice_requested(prompt: String, options: Array)
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
var _effect_system: EffectSystem
var _pending_play: Dictionary = {}


func setup(battle_units: Array[BattleUnit], rng: RandomNumberGenerator = null, card_lookup: Callable = Callable()) -> void:
	units = battle_units
	_battle_over = false
	_pending_play.clear()
	_rng = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		_rng.randomize()
	_card_lookup = card_lookup
	if not _card_lookup.is_valid():
		_card_lookup = func(name: String) -> CardData:
			var db := _get_autoload("CardDB")
			return db.get_card(name) if db != null else null
	_effect_system = EffectSystem.new()
	_effect_system.setup(units, _rng, _card_lookup,
		battle_log, hp_changed, unit_defeated, Callable(self, "_check_battle_over"))
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
	if _battle_over or _effect_system.has_pending_card_choice():
		return
	var unit := turn_system.current_unit()
	if unit == null:
		return
	_effect_system.resolve_end_turn_buffs(unit)
	_effect_system.resolve_passives_by_timing(unit, "结束回合")
	if unit.redesign_dream_enabled and unit.redesign_dream_state == 0:
		unit.block_value += 3
		unit.refresh_block_display()
		battle_log.emit("沉梦：%s 结束行动获得 3 格挡" % unit.get_display_name())
	_effect_system.discard_hand(unit)
	for pile in [unit.hand, unit.draw_pile, unit.discard_pile, unit.exhaust_pile]:
		for card in pile:
			card.temporary_cost_override = -1
			card.temporary_cost_reduction = 0
	unit.tags_played_on_targets.clear()
	unit.played_cards_this_turn.clear()
	unit.active_discards_this_turn = 0
	unit.direct_hp_loss_targets.clear()
	unit.bled_this_turn = false
	unit.energy = 0
	unit.flank_trigger_damage = 0
	unit.pending_knockback = 0
	unit.moved_this_turn = false
	turn_system.end_current_turn()


## 敌怪行动结束：结算“结束回合时”buff（如中毒）后进入下一行动单位。
func end_enemy_turn(unit: BattleUnit) -> void:
	if _battle_over or unit == null:
		return
	_effect_system.resolve_end_turn_buffs(unit)
	turn_system.end_current_turn()


## 打出卡牌：扣除费用 → 按 effects 顺序结算 → 入弃牌堆（能力牌自动消失）。
func play_card(card: CardData, target = null) -> bool:
	if _battle_over or _effect_system.has_pending_card_choice():
		return false
	var unit := turn_system.current_unit()
	if unit == null or not unit.hand.has(card):
		return false
	if card.target_type == CardData.TargetType.ENEMY or card.target_type == CardData.TargetType.ALLY:
		if not target is BattleUnit or target.current_hp <= 0 or target.is_corpse or target.is_removed:
			battle_log.emit("「%s」需要指定有效目标" % card.card_name)
			return false
		if (card.target_type == CardData.TargetType.ENEMY) != target.is_enemy:
			battle_log.emit("「%s」的目标阵营不符" % card.card_name)
			return false
	for condition in card.play_conditions:
		var met := _effect_system.evaluate_condition(unit, condition, target)
		if bool(condition.get("negate", false)):
			met = not met
		if not met:
			battle_log.emit("「%s」的出牌条件未满足" % card.card_name)
			return false
	var paid_cost := effective_card_cost(unit, card, target)
	if paid_cost > unit.energy:
		battle_log.emit("费用不足，无法打出「%s」" % card.card_name)
		return false
	if card.hp_payment > 0 and unit.current_hp <= card.hp_payment:
		battle_log.emit("生命不足，无法支付「%s」的 %d 点生命" % [card.card_name, card.hp_payment])
		return false
	if card.dream_mode == "three_dreams" and card.doom_dream and unit.redesign_dream_state != 1:
		battle_log.emit("「%s」只能在幻梦中打出" % card.card_name)
		return false
	if card.dream_mode != "three_dreams" and card.doom_dream and unit.dream_progress < 2:
		battle_log.emit("「%s」未解锁：需本场战斗先打出过沉梦牌，再打出过幻梦牌" % card.card_name)
		return false
	unit.energy -= paid_cost
	unit.hand.erase(card)
	if card.hp_payment > 0:
		_effect_system.lose_hp(unit, card.hp_payment)
		unit.bled_this_turn = true
	if card.dream_mode == "three_dreams":
		unit.redesign_dream_enabled = true
		if card.phantom:
			unit.redesign_dream_state = 1
			battle_log.emit("%s 进入幻梦" % unit.get_display_name())
	elif card.dream and unit.dream_progress == 0:
		unit.dream_progress = 1
		battle_log.emit("梦境觉醒（1/2）：已打出沉梦牌")
	elif card.phantom and unit.dream_progress == 1:
		unit.dream_progress = 2
		battle_log.emit("梦境觉醒（2/2）：沉梦→幻梦顺序完成，灾梦已解锁！")
	var resolved := _effect_system.resolve_effects(unit, card, target)
	if not resolved:
		_pending_play = {"unit": unit, "card": card, "target": target}
		card_choice_requested.emit(_effect_system.card_choice_prompt(), _effect_system.card_choice_options())
		return true
	_finalize_card_play(unit, card, target)
	return true


func _finalize_card_play(unit: BattleUnit, card: CardData, target) -> void:
	unit.played_cards_this_turn.append(card)
	unit.played_card_ids_in_battle[card.card_id] = true
	if target is BattleUnit and not card.tags.is_empty():
		var target_id: int = target.get_instance_id()
		var played_tags: Array = unit.tags_played_on_targets.get(target_id, [])
		for tag in card.tags:
			if not played_tags.has(tag):
				played_tags.append(tag)
		unit.tags_played_on_targets[target_id] = played_tags
	if card.dream_mode == "three_dreams" and card.doom_dream:
		unit.redesign_dream_state = 0
		battle_log.emit("%s 进入沉梦" % unit.get_display_name())
	unit.last_played_card = card
	if card.temporary_copy:
		battle_log.emit("临时复制品「%s」打出后消失" % card.card_name)
	elif card.should_exhaust_on_play():
		_exhaust_card(unit, card)
	else:
		unit.discard_pile.append(card)
		battle_log.emit("「%s」进入弃牌堆" % card.card_name)
	card_played.emit(unit, card)


func has_pending_card_choice() -> bool:
	return _effect_system != null and _effect_system.has_pending_card_choice()


func card_choice_options() -> Array:
	return _effect_system.card_choice_options() if _effect_system != null else []


func card_choice_prompt() -> String:
	return _effect_system.card_choice_prompt() if _effect_system != null else ""


func card_choice_can_skip() -> bool:
	return _effect_system.card_choice_can_skip() if _effect_system != null else false


func card_choice_skip_label() -> String:
	return _effect_system.card_choice_skip_label() if _effect_system != null else ""


func choose_card_option(index: int) -> bool:
	if _effect_system == null or not _effect_system.choose_card_option(index):
		return false
	if _effect_system.has_pending_card_choice():
		card_choice_requested.emit(_effect_system.card_choice_prompt(), _effect_system.card_choice_options())
	elif not _pending_play.is_empty():
		var play := _pending_play.duplicate()
		_pending_play.clear()
		_finalize_card_play(play["unit"], play["card"], play["target"])
	return true


func effective_card_cost(unit: BattleUnit, card: CardData, target) -> int:
	var reduction := 0
	for rule in card.cost_rules:
		var met := false
		if str(rule.get("type", "")) == "caster_moved_this_turn":
			met = unit.moved_this_turn
		elif str(rule.get("type", "")) == "played_card_tags_this_turn":
			met = _effect_system.evaluate_condition(unit, rule, target)
		elif target is BattleUnit:
			match str(rule.get("type", "")):
				"target_has_buff":
					met = _effect_system.has_buff(target, str(rule.get("buff", "")))
				"target_buff_stacks_at_least":
					var buff := _effect_system.find_buff(target, str(rule.get("buff", "")))
					met = int(buff.get("stacks", 0)) >= int(rule.get("stacks", 1))
				"used_tag_on_target_this_turn":
					var played_tags: Array = unit.tags_played_on_targets.get(target.get_instance_id(), [])
					met = played_tags.has(str(rule.get("tag", "")))
				"target_lost_direct_hp_this_turn":
					met = bool(unit.direct_hp_loss_targets.get(target.get_instance_id(), false))
		if met:
			reduction += maxi(int(rule.get("amount", 0)), 0)
	if card.temporary_cost_override >= 0:
		return card.temporary_cost_override
	return maxi(card.cost - reduction - card.temporary_cost_reduction, 0)


## 整数伤害计算：面板 * 基数 / 100。
## 玩家对敌怪向上取整；敌怪对玩家向下取整；结果不小于 0。
static func compute_damage(panel_value: int, basis: int, attacker_is_enemy: bool) -> int:
	return EffectSystem.compute_damage(panel_value, basis, attacker_is_enemy)


## 敌怪攻击：伤害在敌怪数据范围内随机，属于“受到伤害”，经过目标易伤/格挡/生命结算。
func enemy_attack(attacker: BattleUnit, target: BattleUnit) -> void:
	if attacker == null or target == null:
		return
	var damage := attacker.get_attack_damage()
	_effect_system.take_damage(target, damage)
	battle_log.emit("%s 攻击 %s，造成 %d 点伤害" % [
		attacker.get_display_name(), target.get_display_name(), damage])


func _on_round_started(round_number: int) -> void:
	battle_log.emit("—— 第 %d 回合开始 ——" % round_number)
	round_started.emit(round_number)


func _on_turn_started(unit: BattleUnit) -> void:
	if _battle_over:
		return
	# 尸骸/移除/倒地单位无法行动：直接跳过其回合。
	if unit.is_corpse or unit.is_removed or unit.current_hp <= 0:
		battle_log.emit("%s 已成为尸骸，跳过行动" % unit.get_display_name())
		turn_system.end_current_turn()
		return
	_effect_system.resolve_turn_start_buffs(unit)    # 下回合开始时触发（预格挡），触发后消失
	_effect_system.resolve_passives_by_timing(unit, "回合开始")   # 道途被动（沉梦等）
	var extra_draw := 0
	var extra_energy := 0
	if not unit.is_enemy:
		var passive := _effect_system.get_passive(unit)
		if passive != null and turn_system.round_number == 1:
			if passive.trigger_timing.contains("抽牌"):
				# 先下手为强：固定额外抽 2 张（道途被动数值列已删除，按名称实现）
				var bonus_draw := 2 if passive.passive_name == "先下手为强" else maxi(passive.value, 0)
				extra_draw += bonus_draw
				battle_log.emit("「%s」被动：第一回合额外抽 %d 张牌" % [passive.passive_name, bonus_draw])
			if passive.passive_name == "先下手为强":
				unit.remaining_move_points += 1
				battle_log.emit("「先下手为强」被动：第一回合移动力 +1")
		extra_draw += _effect_system.consume_draw_bonus(unit)       # 下回合抽牌时触发（预抽牌）
		extra_energy += _effect_system.consume_energy_bonus(unit)   # 下回合获得费用时触发（费用预支）
	_effect_system.resolve_turn_buffs(unit)          # 检查该次序结算的 buff（衰减/持续时间）
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
	_effect_system.draw_cards(unit, HAND_SIZE + extra_draw)       # 抽基础牌 + 预抽牌额外张数
	unit.energy = ENERGY_PER_TURN + extra_energy    # 基础费用 + 费用预支额外费用
	battle_log.emit("%s 行动：抽 %d 张牌，获得 %d 费用" % [
		unit.get_display_name(), HAND_SIZE + extra_draw, ENERGY_PER_TURN + extra_energy])
	_effect_system.resolve_action_phase_buffs(unit)  # 角色行动阶段触发（疗愈，层数减一）
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
		unit.redesign_dream_state = 0
		unit.redesign_dream_enabled = false
		unit.last_played_card = null
		unit.tags_played_on_targets.clear()
		unit.played_cards_this_turn.clear()
		unit.active_discards_this_turn = 0
		unit.played_card_ids_in_battle.clear()
		unit.direct_hp_loss_targets.clear()
		unit.bled_this_turn = false
		unit.moved_this_turn = false
		# 抽牌堆 = 角色卡组（启动时已保证含 5 打击 + 5 防御）
		for card in unit.character_data.deck:
			unit.draw_pile.append(card.duplicate(true) as CardData)
			if card.dream_mode == "three_dreams":
				unit.redesign_dream_enabled = true
		# 兜底：牌组为空（直接运行战斗场景等）时补入基础牌
		if unit.draw_pile.is_empty():
			battle_log.emit("%s 牌组为空，补入基础牌" % unit.get_display_name())
			for i in BASIC_STRIKE_COUNT:
				var strike := _effect_system.get_card(BASIC_STRIKE_NAME)
				if strike != null:
					unit.draw_pile.append(strike.duplicate(true) as CardData)
			for i in BASIC_DEFEND_COUNT:
				var defend := _effect_system.get_card(BASIC_DEFEND_NAME)
				if defend != null:
					unit.draw_pile.append(defend.duplicate(true) as CardData)
		_effect_system.shuffle(unit.draw_pile)
		_effect_system.put_innate_cards_in_hand(unit)


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
		elif not unit.is_enemy and not unit.is_corpse and not unit.is_removed and unit.current_hp > 0:
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


## 从场景树获取自动加载单例（CardDB/BuffDB 等）。
## 无头脚本模式（--script）下自动加载可能未注册，此时返回 null，由调用方兜底。
static func _get_autoload(name: String) -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(name)
	return null


# ============================================================
# 兼容转发（效果结算已移至 EffectSystem）
# 既有测试与调用方仍通过这些私有方法访问，行为与拆分前一致。
# ============================================================

func _resolve_effects(unit: BattleUnit, card: CardData, target = null) -> void:
	_effect_system.resolve_effects(unit, card, target)


func _resolve_attack(unit: BattleUnit, card: CardData, effect: AttackEffect, target) -> void:
	_effect_system.resolve_attack(unit, card, effect, target)


func _effect_condition_met(unit: BattleUnit, effect: Resource) -> bool:
	return _effect_system.effect_condition_met(unit, effect)


func _evaluate_condition(unit: BattleUnit, condition: Dictionary) -> bool:
	return _effect_system.evaluate_condition(unit, condition)


func _resolve_passives_by_timing(unit: BattleUnit, timing_keyword: String) -> void:
	_effect_system.resolve_passives_by_timing(unit, timing_keyword)


func _get_passive(unit: BattleUnit) -> PassiveData:
	return _effect_system.get_passive(unit)


func _resolve_turn_buffs(unit: BattleUnit) -> void:
	_effect_system.resolve_turn_buffs(unit)


func _resolve_end_turn_buffs(unit: BattleUnit) -> void:
	_effect_system.resolve_end_turn_buffs(unit)


func _resolve_turn_start_buffs(unit: BattleUnit) -> void:
	_effect_system.resolve_turn_start_buffs(unit)


func _resolve_action_phase_buffs(unit: BattleUnit) -> void:
	_effect_system.resolve_action_phase_buffs(unit)


func _resolve_buffs_by_timing(unit: BattleUnit, timing_keyword: String) -> void:
	_effect_system.resolve_buffs_by_timing(unit, timing_keyword)


func _resolve_buff_trigger(unit: BattleUnit, buff: Dictionary, data: BuffData) -> bool:
	return _effect_system.resolve_buff_trigger(unit, buff, data)


func _consume_draw_bonus(unit: BattleUnit) -> int:
	return _effect_system.consume_draw_bonus(unit)


func _consume_energy_bonus(unit: BattleUnit) -> int:
	return _effect_system.consume_energy_bonus(unit)


func _apply_buff_direct(target: BattleUnit, buff_name: String, stacks: int = 1) -> void:
	_effect_system.apply_buff_direct(target, buff_name, stacks)


func lose_hp(target: BattleUnit, amount: int) -> void:
	_effect_system.lose_hp(target, amount)


func take_damage(target: BattleUnit, amount: int, ignore_block: bool = false) -> int:
	return _effect_system.take_damage(target, amount, ignore_block)


func heal_unit(target: BattleUnit, amount: int) -> void:
	_effect_system.heal_unit(target, amount)


func _resolve_buff_effect(unit: BattleUnit, effect: BuffEffect, target) -> void:
	_effect_system.resolve_buff_effect(unit, effect, target)


func _find_buff(unit: BattleUnit, buff_name: String) -> Dictionary:
	return _effect_system.find_buff(unit, buff_name)


func _has_buff(unit: BattleUnit, buff_name: String) -> bool:
	return _effect_system.has_buff(unit, buff_name)


func _get_card(card_name: String) -> CardData:
	return _effect_system.get_card(card_name)


func _put_innate_cards_in_hand(unit: BattleUnit) -> void:
	_effect_system.put_innate_cards_in_hand(unit)


func _draw_cards(unit: BattleUnit, count: int) -> void:
	_effect_system.draw_cards(unit, count)


func _refill_draw_pile(unit: BattleUnit) -> void:
	_effect_system.refill_draw_pile(unit)


func _discard_hand(unit: BattleUnit) -> void:
	_effect_system.discard_hand(unit)


func _exhaust_card(unit: BattleUnit, card: CardData, reason: String = "打出") -> void:
	_effect_system.exhaust_card(unit, card, reason)


func _resolve_discard_effect(unit: BattleUnit, effect: DiscardEffect) -> void:
	_effect_system.resolve_discard_effect(unit, effect)


func _add_cards_to_pile(unit: BattleUnit, pile: String, card_name: String, value: int, position: String = "shuffle") -> void:
	_effect_system.add_cards_to_pile(unit, pile, card_name, value, position)


func _resolve_generate_effect(unit: BattleUnit, effect: GenerateEffect) -> void:
	_effect_system.resolve_generate_effect(unit, effect)


func _random_card_from_pool(pool: String) -> CardData:
	return _effect_system.random_card_from_pool(pool)


func _resolve_lose_hp_effect(unit: BattleUnit, effect: LoseHpEffect, target) -> void:
	_effect_system.resolve_lose_hp_effect(unit, effect, target)


func _pile_label(pile: String) -> String:
	return _effect_system.pile_label(pile)


func _shuffle(items: Array) -> void:
	_effect_system.shuffle(items)
