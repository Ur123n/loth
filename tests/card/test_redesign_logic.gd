extends SceneTree

var _db: CardDatabase
var _manager: BattleManager
var _caster: BattleUnit
var _ally: BattleUnit
var _enemy: BattleUnit
var _enemy2: BattleUnit
var _passed := 0
var _failed := 0
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_setup()
	_test_attack_then_move()
	_test_ally_block_and_heal()
	_test_direct_hp_loss()
	_test_hp_payment()
	_test_low_hp_block()
	_test_healing_block()
	_test_precision_cost()
	_test_direct_loss_precision()
	_test_bloodlet_attack()
	_test_multi_hit_and_dual_buffs()
	_test_move_block_healing()
	_test_conditional_poison()
	_test_conditional_block_heal_energy()
	_test_three_dreams()
	_test_ally_spatial_mechanics()
	_test_played_tag_and_target_hp_mechanics()
	_test_poison_stack_direct_loss()
	_test_poison_tick_and_simple_doom()
	_test_ally_move_and_dream_return()
	_test_push_and_surgery_cost()
	_test_mechanism_composition_batch()
	_test_card_zone_and_play_condition_batch()
	_test_card_choice_batch()
	_test_filtered_card_choice_batch()
	_test_card_choice_continuation()
	_test_hand_retain_choice()
	_test_temporary_choice_costs()
	_test_persistent_card_sources()
	print("RESULT: passed=%d failed=%d" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
	return true


func _setup() -> void:
	_db = root.get_node_or_null("CardDB") as CardDatabase
	_caster = _make_unit(false)
	_ally = _make_unit(false)
	_enemy = _make_unit(true)
	_enemy2 = _make_unit(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261003
	_manager = BattleManager.new()
	var units: Array[BattleUnit] = [_caster, _ally, _enemy, _enemy2]
	_manager.setup(units, rng, func(name: String) -> CardData: return _db.get_card(name))
	_manager.turn_system.action_order = [0, 1, 2, 3]
	_manager.turn_system.current_index = 0


func _make_unit(enemy: bool) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.is_enemy = enemy
	if not enemy:
		unit.character_data = CharacterData.new()
		unit.character_data.character_name = "测试者"
	unit.current_hp = 100
	return unit


func _card(card_id: String) -> CardData:
	for card in _db.cards:
		if card.card_id == card_id:
			return card
	return null


func _play(card_id: String, target: BattleUnit = null) -> bool:
	var card := _card(card_id)
	if card == null:
		_check(false, "卡牌已入库：" + card_id)
		return false
	_caster.hand.append(card)
	_caster.energy = 20
	return _manager.play_card(card, target)


func _check(value: bool, label: String) -> void:
	if value:
		_passed += 1
		print("PASS  ", label)
	else:
		_failed += 1
		print("FAIL  ", label)


func _test_card_choice_batch() -> void:
	var a := _card("A017")
	var d := _card("D027")
	var k := _card("K026")
	var a_discard := _card("A054")
	_check(a != null and d != null and k != null and a_discard != null,
		"四张随机展示牌均已入库")
	if a == null or d == null or k == null or a_discard == null:
		return
	var filler1 := _card("A001")
	var filler2 := _card("A002")
	var filler3 := _card("A003")
	var filler4 := _card("A004")
	_caster.hand.clear()
	_caster.draw_pile = [filler1, filler2, filler3, filler4]
	_caster.discard_pile.clear()
	_caster.energy = 20
	_caster.hand.append(a)
	var requested := [0]
	var callback := func(_prompt: String, options: Array) -> void: requested[0] = options.size()
	_manager.card_choice_requested.connect(callback)
	_check(_manager.play_card(a), "抽牌堆选择牌可打出")
	_check(requested[0] == 3 and _manager.has_pending_card_choice(), "随机展示三张并等待玩家")
	var shown := _manager.card_choice_options()
	_check(shown.size() == 3 and shown[0] != shown[1] and shown[1] != shown[2] and shown[0] != shown[2],
		"候选按实体无放回抽取")
	_caster.hand.append(k)
	var energy_before := _caster.energy
	_check(not _manager.play_card(k) and _caster.energy == energy_before and _caster.hand.has(k),
		"等待选择时拒绝再次出牌且不扣资源")
	_manager.end_turn()
	_check(_manager.has_pending_card_choice() and _caster.hand.has(k), "等待选择时禁止结束行动")
	_check(not _manager.choose_card_option(-1), "无效选择不改变事务")
	var selected: CardData = shown[1]
	_check(_manager.choose_card_option(1) and not _manager.has_pending_card_choice(), "合法选择提交并解锁")
	_check(_caster.draw_pile.back() == selected and _caster.draw_pile.size() == 4,
		"选中实体牌置顶且牌数守恒")
	_check(_caster.draw_pile.has(shown[0]) and _caster.draw_pile.has(shown[2]), "未选中牌仍在原牌区")
	_caster.draw_pile.clear()
	_caster.discard_pile = [filler1, filler2]
	_caster.hand.append(d)
	_caster.energy = 20
	_check(_manager.play_card(d), "弃牌堆选择牌可打出")
	shown = _manager.card_choice_options()
	_check(shown.size() == 2 and requested[0] == 2, "候选不足时全部展示")
	selected = shown[0]
	_check(_manager.choose_card_option(0) and _caster.draw_pile.back() == selected,
		"从弃牌堆选中实体牌移至抽牌堆顶")
	_check(_caster.discard_pile.has(shown[1]), "未选中弃牌保持原位")
	_caster.draw_pile.clear()
	_caster.discard_pile.clear()
	_caster.hand.append(k)
	_caster.energy = 20
	_check(_manager.play_card(k) and not _manager.has_pending_card_choice(), "空抽牌堆不弹选择框")
	_caster.discard_pile.append(filler3)
	_caster.hand.append(a_discard)
	_caster.energy = 20
	_check(_manager.play_card(a_discard), "A054 复用弃牌堆选择机制")
	if _manager.has_pending_card_choice():
		_check(_manager.choose_card_option(0), "A054 选择结果可提交")
	_manager.card_choice_requested.disconnect(callback)


func _test_filtered_card_choice_batch() -> void:
	var clinical := _card("K060")
	var pickpocket := _card("D059")
	var memory := _card("A063")
	_check(clinical != null and pickpocket != null and memory != null,
		"三张筛选选择牌已入库")
	if clinical == null or pickpocket == null or memory == null:
		return
	var drug := _card("K004")
	var surgery := _card("K008")
	var skill := _card("K002")
	var free_skill := _card("K003")
	var attack := _card("K001")
	_caster.hand.clear()
	_caster.draw_pile.clear()
	_caster.discard_pile = [drug, surgery, skill]
	_caster.played_card_ids_in_battle = {drug.card_id: true, surgery.card_id: true}
	_caster.energy = 20
	_caster.hand.append(clinical)
	_check(_manager.play_card(clinical), "K060 可打出")
	var shown := _manager.card_choice_options()
	_check(shown.size() == 2 and shown.has(drug) and shown.has(surgery),
		"K060 只展示本场已打出的 Drug 或 Surgery")
	_check(_manager.choose_card_option(0) and _caster.draw_pile.back() == shown[0],
		"K060 选择后置于抽牌堆顶")
	_caster.hand.clear()
	_caster.discard_pile = [skill, free_skill, attack]
	_caster.energy = 20
	_caster.hand.append(pickpocket)
	_check(_manager.play_card(pickpocket), "D059 可打出")
	shown = _manager.card_choice_options()
	_check(shown.size() == 1 and shown[0] == skill,
		"D059 只展示基础费用为 1 的 Skill")
	_check(_manager.choose_card_option(0) and _caster.hand.size() == 1,
		"D059 选中牌进入手牌")
	var selected: CardData = _caster.hand[0]
	_check(selected != skill and selected.exhaust_on_play and not skill.exhaust_on_play,
		"临时消耗只作用于选中的实体牌")
	_caster.energy = 20
	_check(_manager.play_card(selected) and _caster.exhaust_pile.has(selected),
		"D059 选中牌下次打出后消耗")
	var power := CardData.new()
	power.card_id = "TEST_POWER"
	power.card_type = CardData.CardType.ABILITY
	_caster.hand.clear()
	_caster.discard_pile = [attack, skill, power]
	_caster.played_cards_this_turn = [skill]
	_caster.energy = 20
	_caster.hand.append(memory)
	_check(_manager.play_card(memory), "A063 可打出")
	shown = _manager.card_choice_options()
	_check(shown.size() == 1 and shown[0] == attack,
		"A063 排除本行动已打出的牌与 Power")
	_check(_manager.choose_card_option(0) and _caster.hand.size() == 1,
		"A063 选中牌进入手牌")
	selected = _caster.hand[0]
	_caster.energy = 20
	_check(_manager.play_card(selected, _enemy) and _caster.exhaust_pile.has(selected),
		"A063 选中牌下一次打出后消耗")


func _test_card_choice_continuation() -> void:
	var card := CardData.new()
	card.card_id = "TEST_CHOICE_CONTINUE"
	card.card_name = "选择续行测试"
	card.card_type = CardData.CardType.ACTION
	card.target_type = CardData.TargetType.SELF
	var choice := ChooseFromPileEffect.new()
	choice.source = "discard"
	choice.sample_count = 1
	card.effects.append(choice)
	var gain := GainEnergyEffect.new()
	gain.value = 2
	card.effects.append(gain)
	var played := [0]
	var callback := func(_unit: BattleUnit, actual: CardData) -> void:
		if actual == card:
			played[0] += 1
	_manager.card_played.connect(callback)
	_caster.hand.clear()
	_caster.discard_pile = [_card("K003")]
	_caster.energy = 0
	_caster.hand.append(card)
	_check(_manager.play_card(card) and _manager.has_pending_card_choice(),
		"选择效果暂停当前出牌")
	_check(_caster.energy == 0 and played[0] == 0 and not _caster.discard_pile.has(card),
		"选择前后续效果、出牌事件与离场尚未发生")
	_check(_manager.choose_card_option(0) and _caster.energy == 2,
		"选择提交后从下一效果继续")
	_check(played[0] == 1 and _caster.discard_pile.has(card),
		"续行结束后只完成一次出牌并让牌离场")
	_caster.hand.append(card)
	_caster.discard_pile.clear()
	_caster.energy = 0
	_check(_manager.play_card(card) and not _manager.has_pending_card_choice()
		and _caster.energy == 2 and played[0] == 2,
		"空候选跳过选择并同步完成后续效果")
	_manager.card_played.disconnect(callback)


func _test_hand_retain_choice() -> void:
	var retain_card := _card("D034")
	_check(retain_card != null, "D034 已入库")
	if retain_card == null:
		return
	var chosen := _card("A001")
	var untouched := _card("A002")
	_caster.hand = [retain_card, chosen, untouched]
	_caster.block_value = 0
	_caster.energy = 20
	_check(_manager.play_card(retain_card) and _manager.has_pending_card_choice(),
		"D034 当前牌离手后展示其他手牌")
	var shown := _manager.card_choice_options()
	_check(shown.size() == 2 and shown[0] == chosen and shown[1] == untouched,
		"D034 按原手牌顺序展示可选实体")
	_check(_caster.block_value == 0, "D034 选择前尚未结算后续格挡")
	_check(_manager.choose_card_option(0) and _caster.block_value == 5,
		"D034 提交选择后获得 5 格挡")
	var retained: CardData = _caster.hand[0]
	_check(retained != chosen and retained.retain and _caster.hand[1] == untouched,
		"D034 只修改选中实体并保持手牌顺序")
	_manager._effect_system.discard_hand(_caster)
	_check(_caster.hand.has(retained) and not _caster.hand.has(untouched),
		"被选牌跨行动保留，未选牌正常弃置")


func _test_temporary_choice_costs() -> void:
	var reclaim := _card("A019")
	var blood := _card("B071")
	_check(reclaim != null and blood != null, "A019 与 B071 已入库")
	if reclaim == null or blood == null:
		return
	var basic_attack := _card("A001")
	var basic_skill := _card("A002")
	var common := _card("K011")
	_caster.hand.clear()
	_caster.draw_pile.clear()
	_caster.discard_pile = [basic_attack, common, basic_skill]
	_caster.energy = 20
	_caster.hand.append(reclaim)
	_check(_manager.play_card(reclaim), "A019 可打出")
	var shown := _manager.card_choice_options()
	_check(shown.size() == 2 and shown[0] == basic_attack and shown[1] == basic_skill,
		"A019 按牌区原顺序展示全部 Basic，排除其他稀有度")
	_check(_manager.choose_card_option(0) and _caster.hand.size() == 1,
		"A019 选中 Basic 进入手牌")
	var selected: CardData = _caster.hand[0]
	_check(selected != basic_attack and selected.temporary_cost_override == 0
		and _manager.effective_card_cost(_caster, selected, _enemy) == 0,
		"A019 仅选中实体本行动费用变为零")
	_check(_manager.play_card(selected, _enemy) and _caster.exhaust_pile.has(selected),
		"A019 选中实体打出后消耗")
	_caster.hand.clear()
	_caster.discard_pile = [basic_skill, common]
	_caster.current_hp = 100
	_caster.energy = 20
	_caster.hand.append(blood)
	_check(_manager.play_card(blood) and _caster.current_hp == 93,
		"B071 放血 7 后进入选择")
	shown = _manager.card_choice_options()
	_check(shown.size() == 2 and shown.has(basic_skill) and shown.has(common),
		"B071 展示弃牌堆非 Power 候选")
	var picked_index := shown.find(basic_skill)
	_check(_manager.choose_card_option(picked_index) and _caster.hand.size() == 1,
		"B071 选中牌进入手牌")
	selected = _caster.hand[0]
	_check(selected != basic_skill and _manager.effective_card_cost(_caster, selected, null) == 0
		and basic_skill.temporary_cost_reduction == 0,
		"B071 仅选中实体本行动费用减一")
	_manager.end_turn()
	_check(selected.temporary_cost_reduction == 0 and selected.temporary_cost_override == -1,
		"行动结束清除临时费用")


func _test_persistent_card_sources() -> void:
	_manager.turn_system.current_index = 0
	var deck_choice := _card("K025")
	var library_choice := _card("A033")
	var drug_a := _card("K004")
	var drug_b := _card("K005")
	var attack := _card("A001")
	var skill_card := _card("A002")
	_check(deck_choice != null and library_choice != null and drug_a != null and drug_b != null,
		"K025 和 A033 及候选牌已加载")
	if deck_choice == null or library_choice == null or drug_a == null or drug_b == null:
		return
	_caster.character_data.deck = [drug_a, drug_b, attack]
	_caster.character_data.skill_library.clear()
	for owned in [attack, skill_card]:
		var entry := SkillData.new()
		entry.skill_name = owned.card_name
		_caster.character_data.skill_library.append(entry)
	_caster.hand = [deck_choice]
	_caster.draw_pile.clear()
	_caster.discard_pile.clear()
	_caster.energy = 20
	_caster.block_value = 0
	_check(_manager.play_card(deck_choice) and _manager.has_pending_card_choice(),
		"K025 从携带卡组请求选择")
	var shown := _manager.card_choice_options()
	_check(shown.size() == 2 and shown.has(drug_a) and shown.has(drug_b),
		"卡组来源只展示携带的 Drug，不读取战斗抽牌堆")
	_check(_manager.choose_card_option(0) and _caster.character_data.deck.size() == 3
		and _caster.draw_pile.size() == 1 and _caster.draw_pile.back() != shown[0]
		and _caster.draw_pile.back().card_id == shown[0].card_id and _caster.block_value == 4,
		"K025 复制选中牌置顶，持久卡组不变并续行获得格挡")
	_caster.hand = [library_choice]
	_caster.energy = 20
	_check(_manager.play_card(library_choice) and _manager.has_pending_card_choice(),
		"A033 从已获牌库请求选择")
	shown = _manager.card_choice_options()
	_check(shown.size() == 2 and shown.has(attack) and shown.has(skill_card)
		and not shown.has(drug_a), "牌库候选来自已获卡，而非携带卡组或 CardDB 全池")
	var chosen_index := shown.find(attack)
	_check(_manager.choose_card_option(chosen_index) and _caster.hand.size() == 1,
		"A033 选择后获得一张手牌")
	var copy: CardData = _caster.hand[0]
	_check(copy != attack and copy.temporary_copy and not attack.temporary_copy
		and _caster.character_data.skill_library.size() == 2,
		"临时复制标志仅作用于战斗实体，牌库不变")
	var discard_before := _caster.discard_pile.size()
	var exhaust_before := _caster.exhaust_pile.size()
	_check(_manager.play_card(copy, _enemy) and not _caster.discard_pile.has(copy)
		and not _caster.exhaust_pile.has(copy)
		and _caster.discard_pile.size() == discard_before
		and _caster.exhaust_pile.size() == exhaust_before,
		"临时复制品结算后消失，不进弃牌堆或消耗堆")
	var library_skill := _card("A055")
	var deck_drug := _card("K058")
	_check(library_skill != null and deck_drug != null, "A055 与 K058 已按确定的牌库规则入库")
	if library_skill == null or deck_drug == null:
		return
	_caster.hand = [library_skill]
	_caster.energy = 20
	_check(_manager.play_card(library_skill) and _manager.has_pending_card_choice(),
		"A055 从已获牌库随机展示 Skill")
	shown = _manager.card_choice_options()
	_check(shown.size() == 1 and shown[0] == skill_card,
		"A055 排除已获 Attack，候选不足时只展示合格 Skill")
	_check(_manager.choose_card_option(0) and _caster.hand.size() == 1
		and _caster.hand[0] != skill_card and _caster.hand[0].card_id == skill_card.card_id
		and _caster.character_data.skill_library.size() == 2,
		"A055 生成选中牌到手牌，未选牌与永久牌库不变")
	_caster.hand = [deck_drug]
	_caster.energy = 20
	_check(_manager.play_card(deck_drug) and _manager.has_pending_card_choice(),
		"K058 从携带卡组随机展示 Drug")
	shown = _manager.card_choice_options()
	_check(shown.size() == 2 and shown.has(drug_a) and shown.has(drug_b),
		"K058 不把未携带的牌库牌混入候选")
	_check(_manager.choose_card_option(1) and _caster.hand.size() == 1
		and _caster.hand[0] != shown[1] and _caster.hand[0].card_id == shown[1].card_id
		and _caster.character_data.deck.size() == 3
		and _caster.character_data.deck.has(drug_a) and _caster.character_data.deck.has(drug_b),
		"K058 只生成选中战斗牌，未选牌仍在卡组中")


func _test_attack_then_move() -> void:
	_enemy.current_hp = 100
	_caster.remaining_move_points = 0
	var played := _play("A009", _enemy)
	_check(played and _enemy.current_hp < 100 and _caster.remaining_move_points == 1,
		"A009 攻击后获得 1 格移动力")
	_enemy.current_hp = 100
	_caster.remaining_move_points = 0
	played = _play("D006", _enemy)
	_check(played and _enemy.current_hp < 100 and _caster.remaining_move_points == 1,
		"D006 攻击后获得 1 格移动力")


func _test_ally_block_and_heal() -> void:
	_ally.block_value = 0
	_check(_play("K018", _ally) and _ally.block_value == 8 and _caster.block_value == 0,
		"K018 格挡给予所选友军")
	_ally.current_hp = maxi(1, _ally.get_max_hp_value() - 10)
	var before := _ally.current_hp
	_check(_play("K007", _ally) and _ally.current_hp == before + 4,
		"K007 治疗所选友军 4 生命")


func _test_direct_hp_loss() -> void:
	_enemy.current_hp = 100
	_enemy.block_value = 10
	var played := _play("K008", _enemy)
	_check(played and _enemy.current_hp == 98 and _enemy.block_value < 10,
		"K008 攻击被格挡后仍令目标直接失去 2 生命")
	_enemy.block_value = 0


func _test_hp_payment() -> void:
	_caster.current_hp = 4
	var card := _card("B004")
	_caster.hand.append(card)
	_caster.energy = 20
	var enemy_before := _enemy.current_hp
	_check(not _manager.play_card(card, _enemy) and _caster.current_hp == 4
		and _caster.energy == 20 and _caster.hand.has(card) and _enemy.current_hp == enemy_before,
		"B004 致死放血被拒绝且不扣资源")
	_caster.hand.erase(card)
	_caster.current_hp = 20
	_check(_play("B004", _enemy) and _caster.current_hp == 16 and _enemy.current_hp < enemy_before,
		"B004 先支付 4 生命再攻击")
	_caster.block_value = 0
	_check(_play("B007") and _caster.current_hp == 15 and _caster.block_value == 10,
		"B007 放血 1 后获得 10 格挡")


func _test_low_hp_block() -> void:
	var half := _caster.get_max_hp_value() / 2
	_caster.current_hp = half
	_caster.block_value = 0
	_check(_play("B006") and _caster.block_value == 11,
		"B006 恰好 50% 生命时获得 11 格挡")
	_caster.current_hp = half + 1
	_caster.block_value = 0
	_check(_play("B006") and _caster.block_value == 9,
		"B006 高于 50% 生命时仅获得 9 格挡")


func _test_healing_block() -> void:
	_caster.block_value = 0
	_check(_play("B010") and _caster.block_value == 4
		and not _manager._find_buff(_caster, "疗愈").is_empty(),
		"B010 同时给予疗愈和格挡")


func _test_three_dreams() -> void:
	_caster.redesign_dream_state = 0
	_caster.redesign_dream_enabled = true
	_enemy.current_hp = 100
	_enemy.block_value = 50
	var doom := _card("A008")
	_caster.hand.append(doom)
	_caster.energy = 20
	_check(not _manager.play_card(doom, _enemy) and _caster.hand.has(doom),
		"A008 沉梦时不能打出灾梦")
	_caster.hand.erase(doom)
	_check(_play("A007", _enemy) and _caster.redesign_dream_state == 1
		and _enemy.current_hp == 94 and _enemy.block_value == 50,
		"A007 结算前进入幻梦并无视格挡")
	_check(_play("A008", _enemy) and _caster.redesign_dream_state == 0
		and _enemy.current_hp == 76 and not _manager._find_buff(_enemy, "虚弱").is_empty(),
		"A008 幻梦中打出、穿透格挡并回到沉梦")
	_caster.block_value = 0
	_manager.end_turn()
	_check(_caster.block_value == 3, "沉梦结束行动获得 3 格挡")


func _test_precision_cost() -> void:
	_caster.tags_played_on_targets.clear()
	_enemy.buffs.clear()
	_enemy2.buffs.clear()
	_enemy.current_hp = 100
	_enemy2.current_hp = 100
	_enemy.block_value = 0
	_enemy2.block_value = 0
	var k009 := _card("K009")
	_caster.hand.append(k009)
	_caster.energy = 0
	_check(not _manager.play_card(k009, _enemy) and _caster.hand.has(k009) and _caster.energy == 0,
		"K009 无中毒时 0 费无法打出且不扣资源")
	_check(_play("K004", _enemy), "K004 对目标施加毒并登记 Drug")
	_caster.energy = 0
	_check(_manager.play_card(k009, _enemy) and _caster.energy == 0
		and not _manager._find_buff(_enemy, "中毒").is_empty(),
		"K009 目标中毒时 1→0 费且不消耗毒")
	var k028 := _card("K028")
	_caster.hand.append(k028)
	_caster.energy = 0
	_check(not _manager.play_card(k028, _enemy), "K028 目标未虚弱时不可 0 费打出")
	_check(_play("K005", _enemy), "K005 施加虚弱")
	_caster.energy = 0
	var hp_before := _enemy.current_hp
	_check(_manager.play_card(k028, _enemy) and _enemy.current_hp <= hp_before - 2
		and not _manager._find_buff(_enemy, "虚弱").is_empty(),
		"K028 目标虚弱时 1→0 费并直接失去生命")
	var k029 := _card("K029")
	_caster.hand.append(k029)
	_caster.energy = 1
	_check(not _manager.play_card(k029, _enemy2) and _caster.hand.has(k029),
		"K029 另一目标毒不足 5 层时仍需 2 费")
	_caster.energy = 1
	_check(_manager.play_card(k029, _enemy) and _caster.energy == 0,
		"K029 目标毒至少 5 层时 2→1 费")
	var k010 := _card("K010")
	_caster.hand.append(k010)
	_caster.energy = 1
	_check(not _manager.play_card(k010, _enemy2) and _caster.hand.has(k010),
		"K010 Drug 记录不能跨目标降费")
	_caster.energy = 1
	_check(_manager.play_card(k010, _enemy) and _caster.energy == 0,
		"K010 对同目标用过 Drug 后 2→1 费")
	var stacked := CardData.new()
	stacked.cost = 2
	stacked.cost_rules.append({"type": "target_has_buff", "buff": "中毒", "amount": 1})
	stacked.cost_rules.append({"type": "target_has_buff", "buff": "虚弱", "amount": 1})
	_check(_manager.effective_card_cost(_caster, stacked, _enemy) == 0
		and _manager.effective_card_cost(_caster, stacked, _enemy2) == 2
		and stacked.minimum_cost() == 0,
		"两项合法精密降费可叠加且不会作用于另一目标")
	_manager.end_turn()
	_check(_caster.tags_played_on_targets.is_empty(), "结束行动清空本回合目标标签")
	_manager.turn_system.current_index = 0


func _test_direct_loss_precision() -> void:
	_caster.direct_hp_loss_targets.clear()
	_caster.moved_this_turn = false
	_enemy.buffs.clear()
	_enemy2.buffs.clear()
	_enemy.current_hp = 100
	_enemy2.current_hp = 100
	_enemy.block_value = 50
	_enemy2.block_value = 0
	var k030 := _card("K030")
	_caster.hand.append(k030)
	_caster.energy = 0
	_check(not _manager.play_card(k030, _enemy) and _caster.hand.has(k030),
		"K030 目标未直接失血时 0 费不能打出")
	_check(_play("A001", _enemy2) and not _caster.direct_hp_loss_targets.has(_enemy2.get_instance_id()),
		"普通攻击造成生命损失不登记直接失血")
	_check(_play("K008", _enemy) and _enemy.current_hp == 98
		and _caster.direct_hp_loss_targets.has(_enemy.get_instance_id()),
		"K008 攻击被格挡后直接失去的 2 生命会登记目标")
	_caster.energy = 0
	_check(not _manager.play_card(k030, _enemy2) and _caster.hand.has(k030),
		"K030 不会把另一目标的直接失血记录套用到当前目标")
	_caster.energy = 0
	var before := _enemy.current_hp
	_check(_manager.play_card(k030, _enemy) and _enemy.current_hp == before - 3,
		"K030 满足条件后 0 费令同目标直接失去 3 生命")
	var k044 := _card("K044")
	_caster.hand.append(k044)
	_caster.energy = 0
	before = _enemy.current_hp
	_check(_manager.play_card(k044, _enemy) and _enemy.current_hp == before - 4,
		"K044 满足条件后 0 费令同目标直接失去 4 生命")
	var k031 := _card("K031")
	_caster.hand.append(k031)
	_caster.energy = 0
	_check(not _manager.play_card(k031, _enemy), "K031 未移动时 0 费不能打出")
	_caster.moved_this_turn = true
	_caster.energy = 0
	before = _enemy.current_hp
	_check(_manager.play_card(k031, _enemy) and _enemy.current_hp == before - 1,
		"K031 已移动时 0 费打出，格挡后仍直接失去 1 生命")
	_check(_play("K004", _enemy2), "K004 对第二目标施毒")
	_manager._resolve_end_turn_buffs(_enemy2)
	_check(not _caster.direct_hp_loss_targets.has(_enemy2.get_instance_id()),
		"毒在结束回合造成的生命损失不算出牌者本回合直接失血")
	_manager.end_turn()
	_check(_caster.direct_hp_loss_targets.is_empty(), "结束行动清空直接失血目标记录")
	_manager.turn_system.current_index = 0


func _test_bloodlet_attack() -> void:
	_caster.bled_this_turn = false
	_caster.current_hp = 30
	_enemy.current_hp = 100
	_enemy.block_value = 0
	_enemy.buffs.clear()
	var basis := _caster.character_data.get_strength_damage_basis()
	var normal_11 := BattleManager.compute_damage(11, basis, false)
	_check(_play("B005", _enemy) and _enemy.current_hp == 100 - normal_11,
		"B005 未放血时造成基础 11 面板伤害")
	_manager.lose_hp(_caster, 1)
	_check(not _caster.bled_this_turn, "普通自身失血不触发放血条件")
	_enemy.current_hp = 100
	_check(_play("B004", _enemy) and _caster.bled_this_turn,
		"B004 支付生命后标记本回合已放血")
	_enemy.current_hp = 100
	var boosted_14 := BattleManager.compute_damage(14, basis, false)
	_check(_play("B005", _enemy) and _enemy.current_hp == 100 - boosted_14,
		"B005 放血后改为 14 面板伤害")
	_enemy.current_hp = 100
	var boosted_16 := BattleManager.compute_damage(16, basis, false)
	_check(_play("B022", _enemy) and _enemy.current_hp == 100 - boosted_16,
		"B022 放血后改为 16 面板伤害")
	_manager.end_turn()
	_check(not _caster.bled_this_turn, "结束行动清空放血标记")
	_manager.turn_system.current_index = 0


func _test_multi_hit_and_dual_buffs() -> void:
	_enemy.current_hp = 100
	_enemy.block_value = 0
	_enemy.buffs.clear()
	var basis := _caster.character_data.get_strength_damage_basis()
	var four := BattleManager.compute_damage(4, basis, false)
	_enemy.block_value = four + 1
	_check(_play("A030", _enemy) and _enemy.block_value == 0
		and _enemy.current_hp == 100 - (four - 1),
		"A030 两段 4 伤分别受格挡")
	_enemy.current_hp = 100
	_enemy.block_value = 0
	_check(_play("D015", _enemy) and _enemy.current_hp == 100 - four * 2,
		"D015 两段 4 伤独立结算")
	_enemy.current_hp = 100
	var five := BattleManager.compute_damage(5, basis, false)
	_check(_play("D063", _enemy) and _enemy.current_hp == 100 - five * 5,
		"D063 五段 5 伤独立结算")
	var defeats := {"count": 0}
	_manager.unit_defeated.connect(func(_defeated: BattleUnit): defeats["count"] += 1)
	_enemy.current_hp = 1
	_enemy.block_value = 0
	_check(_play("D063", _enemy) and _enemy.current_hp == 0 and defeats["count"] == 1,
		"多段攻击在目标倒下后停止，不重复触发击败")
	_enemy2.buffs.clear()
	_check(_play("K012", _enemy2)
		and int(_manager._find_buff(_enemy2, "中毒").get("stacks", 0)) == 4
		and int(_manager._find_buff(_enemy2, "虚弱").get("stacks", 0)) == 1,
		"K012 同时施加毒 4 与虚弱 1")
	_enemy2.buffs.clear()
	_check(_play("K016", _enemy2)
		and int(_manager._find_buff(_enemy2, "中毒").get("stacks", 0)) == 2
		and int(_manager._find_buff(_enemy2, "虚弱").get("stacks", 0)) == 1,
		"K016 同时施加毒 2 与虚弱 1")
	_enemy2.buffs.clear()
	_check(_play("K037", _enemy2)
		and int(_manager._find_buff(_enemy2, "中毒").get("stacks", 0)) == 10
		and int(_manager._find_buff(_enemy2, "虚弱").get("stacks", 0)) == 1,
		"K037 同时施加毒 10 与虚弱 1")


func _test_move_block_healing() -> void:
	_caster.current_hp = 30
	_caster.block_value = 0
	_caster.remaining_move_points = 0
	_caster.buffs.clear()
	_check(_play("A021") and _caster.remaining_move_points == 1 and _caster.block_value == 6,
		"A021 同时获得 1 格移动力和 6 格挡")
	_caster.buffs.clear()
	_check(_play("B018") and int(_manager._find_buff(_caster, "疗愈").get("stacks", 0)) == 3,
		"B018 获得 3 层疗愈")
	_caster.buffs.clear()
	_caster.block_value = 0
	_check(_play("B019") and _caster.block_value == 6
		and int(_manager._find_buff(_caster, "疗愈").get("stacks", 0)) == 2,
		"B019 同时获得 6 格挡和 2 层疗愈")
	_caster.buffs.clear()
	var before := _caster.current_hp
	_check(_play("B020") and _caster.current_hp == before - 1
		and int(_manager._find_buff(_caster, "疗愈").get("stacks", 0)) == 4,
		"B020 支付 1 生命后获得 4 层疗愈")
	_caster.buffs.clear()
	_check(_play("B043") and int(_manager._find_buff(_caster, "疗愈").get("stacks", 0)) == 5,
		"B043 获得 5 层疗愈")
	_caster.buffs.clear()
	_caster.block_value = 0
	before = _caster.current_hp
	_check(_play("B044") and _caster.current_hp == before - 4 and _caster.block_value == 16
		and int(_manager._find_buff(_caster, "疗愈").get("stacks", 0)) == 1,
		"B044 支付 4 生命后获得 16 格挡和 1 层疗愈")


func _test_conditional_poison() -> void:
	_enemy.current_hp = 100
	_enemy2.current_hp = 100
	_enemy.buffs.clear()
	_enemy2.buffs.clear()
	_caster.direct_hp_loss_targets.clear()
	_check(_play("K015", _enemy) and int(_manager._find_buff(_enemy, "中毒").get("stacks", 0)) == 5,
		"K015 目标未中毒时施加 5 层")
	_check(_play("K015", _enemy) and int(_manager._find_buff(_enemy, "中毒").get("stacks", 0)) == 12,
		"K015 目标原有中毒时追加 7 层")
	_enemy.buffs.clear()
	_check(_play("K036", _enemy) and int(_manager._find_buff(_enemy, "中毒").get("stacks", 0)) == 6,
		"K036 首段新施加的毒不触发任意 Debuff 加层")
	_enemy2.buffs.append({"name": "虚弱", "stacks": 1, "duration": 1})
	_check(_play("K036", _enemy2) and int(_manager._find_buff(_enemy2, "中毒").get("stacks", 0)) == 9,
		"K036 原有其他负面状态时分两段施加 6+3 层毒")
	_enemy2.buffs.clear()
	_check(_play("K041", _enemy2) and int(_manager._find_buff(_enemy2, "中毒").get("stacks", 0)) == 5,
		"K041 未直接失血的目标只获得 5 层毒")
	_enemy2.buffs.clear()
	_enemy.buffs.clear()
	_check(_play("K008", _enemy) and _caster.direct_hp_loss_targets.has(_enemy.get_instance_id()),
		"K008 对指定目标记录本回合直接失血")
	_check(_play("K041", _enemy) and int(_manager._find_buff(_enemy, "中毒").get("stacks", 0)) == 8,
		"K041 对已直接失血目标追加 5+3 层毒")
	_enemy2.buffs.clear()
	_check(_play("K041", _enemy2) and int(_manager._find_buff(_enemy2, "中毒").get("stacks", 0)) == 5,
		"K041 不把另一目标的直接失血记录混用")


func _test_conditional_block_heal_energy() -> void:
	_caster.redesign_dream_enabled = true
	_caster.redesign_dream_state = 0
	_caster.block_value = 0
	_check(_play("A011") and _caster.block_value == 10, "A011 沉梦时改为 10 格挡")
	_caster.redesign_dream_state = 1
	_caster.block_value = 0
	_check(_play("A011") and _caster.block_value == 8, "A011 幻梦时仅获得 8 格挡")
	_enemy.current_hp = 100
	_enemy.block_value = 0
	_caster.block_value = 0
	_caster.redesign_dream_state = 0
	var eight := BattleManager.compute_damage(8, _caster.character_data.get_strength_damage_basis(), false)
	_check(_play("A013", _enemy) and _enemy.current_hp == 100 - eight and _caster.block_value == 3,
		"A013 沉梦时攻击后获得 3 格挡")
	_enemy.current_hp = 100
	_caster.block_value = 0
	_caster.redesign_dream_state = 1
	_check(_play("A013", _enemy) and _enemy.current_hp == 100 - eight and _caster.block_value == 0,
		"A013 幻梦时只攻击")
	_caster.moved_this_turn = false
	_caster.block_value = 0
	_check(_play("B017") and _caster.block_value == 12, "B017 未移动时改为 12 格挡")
	_caster.moved_this_turn = true
	_caster.block_value = 0
	_check(_play("B017") and _caster.block_value == 9, "B017 已移动时获得 9 格挡")
	_caster.buffs.clear()
	_caster.block_value = 0
	_caster.moved_this_turn = false
	_check(_play("B033") and _caster.block_value == 19
		and int(_manager._find_buff(_caster, "疗愈").get("stacks", 0)) == 2,
		"B033 未移动时获得格挡与疗愈")
	_caster.buffs.clear()
	_caster.block_value = 0
	_caster.moved_this_turn = true
	_check(_play("B033") and _caster.block_value == 19 and _manager._find_buff(_caster, "疗愈").is_empty(),
		"B033 已移动时仅获得格挡")
	_caster.current_hp = 8
	var energy_card := _card("B042")
	_caster.hand.append(energy_card)
	_caster.energy = 0
	_check(_manager.play_card(energy_card) and _caster.current_hp == 1 and _caster.energy == 1,
		"B042 先放血 7 再获得 1 费")
	_caster.current_hp = 7
	_caster.hand.append(energy_card)
	_caster.energy = 0
	_check(not _manager.play_card(energy_card) and _caster.current_hp == 7 and _caster.energy == 0,
		"B042 不能以致死生命支付换费")
	_caster.hand.erase(energy_card)
	var threshold := _caster.get_max_hp_value() * 35 / 100
	_caster.current_hp = threshold
	_caster.buffs.clear()
	_caster.block_value = 0
	_check(_play("B055") and _caster.block_value == 8
		and int(_manager._find_buff(_caster, "疗愈").get("stacks", 0)) == 5,
		"B055 生命恰好不高于 35% 时获得疗愈和格挡")
	_caster.current_hp = threshold + 1
	_caster.buffs.clear()
	_caster.block_value = 0
	_check(_play("B055") and _caster.block_value == 0 and _manager._find_buff(_caster, "疗愈").is_empty(),
		"B055 生命高于 35% 时无效果")


func _test_ally_spatial_mechanics() -> void:
	_manager.turn_system.current_index = 0
	_caster.current_hp = 100
	_ally.current_hp = 100
	_enemy.current_hp = 100
	_enemy2.current_hp = 100
	_caster.hex_coords = Vector2i(2, 2)
	_ally.hex_coords = Vector2i(3, 2)
	_enemy.hex_coords = Vector2i(2, 3)
	_enemy2.hex_coords = Vector2i(3, 3)
	_caster.block_value = 0
	_ally.block_value = 0
	_check(_play("A004", _ally) and _ally.block_value == 5 and _caster.block_value == 2,
		"A004 友军相邻时目标获得 5 格挡，自己获得 2 格挡")
	_ally.hex_coords = Vector2i(2, 4)
	_caster.block_value = 0
	_ally.block_value = 0
	_check(_play("A004", _ally) and _ally.block_value == 5 and _caster.block_value == 0,
		"A004 友军不相邻时只给目标格挡")
	_caster.remaining_move_points = 0
	_ally.block_value = 0
	_check(_play("A015", _ally) and _ally.block_value == 7 and _caster.remaining_move_points == 1,
		"A015 友军格挡后出牌者获得可用移动力")
	_caster.block_value = 0
	_ally.block_value = 0
	_check(_play("A016", _ally) and _caster.block_value == 4 and _ally.block_value == 4,
		"A016 同时给自己和所选友军各 4 格挡")
	_ally.moved_this_turn = false
	_ally.block_value = 0
	_check(_play("A027", _ally) and _ally.block_value == 6,
		"A027 友军未移动时获得 6 格挡")
	_ally.moved_this_turn = true
	_ally.block_value = 0
	_check(_play("A027", _ally) and _ally.block_value == 8,
		"A027 友军已移动时追加 2 格挡")
	_enemy2.hex_coords = Vector2i(5, 3)
	_caster.block_value = 0
	_check(_play("B054") and _caster.block_value == 18,
		"B054 仅 1 名相邻敌人时获得 18 格挡")
	_enemy2.hex_coords = Vector2i(1, 2)
	_caster.block_value = 0
	_check(_play("B054") and _caster.block_value == 23,
		"B054 2 名相邻敌人时再获得 5 格挡")


func _test_played_tag_and_target_hp_mechanics() -> void:
	_manager.turn_system.current_index = 0
	_caster.played_cards_this_turn.clear()
	_enemy.current_hp = 100
	_enemy.block_value = 0
	_caster.moved_this_turn = false
	var basis := _caster.character_data.get_strength_damage_basis()
	var seven := BattleManager.compute_damage(7, basis, false)
	var ten := BattleManager.compute_damage(10, basis, false)
	_check(_play("D016", _enemy) and _enemy.current_hp == 100 - seven,
		"D016 未移动时只造成 7 面板伤害")
	_enemy.current_hp = 100
	_caster.moved_this_turn = true
	_check(_play("D016", _enemy) and _enemy.current_hp == 100 - ten,
		"D016 已移动时只造成 10 面板伤害")
	_caster.played_cards_this_turn.clear()
	_enemy.current_hp = 100
	_check(_play("D018", _enemy) and _enemy.current_hp == 100 - seven,
		"D018 本行动未打出 Dagger Attack 时造成 7 面板伤害")
	_check(_play("D002"), "非 Dagger 攻击牌成功打出")
	_enemy.current_hp = 100
	_check(_play("D018", _enemy) and _enemy.current_hp == 100 - seven,
		"D018 防御牌不会误触发 Dagger Attack 条件")
	_check(_play("D001", _enemy), "Dagger Attack 成功打出并记入本行动历史")
	_enemy.current_hp = 100
	_check(_play("D018", _enemy) and _enemy.current_hp == 100 - ten,
		"D018 打出 Dagger Attack 后造成 10 面板伤害")
	_caster.played_cards_this_turn.clear()
	_check(_play("D001", _enemy), "D052 前只记录 Dagger Attack")
	_caster.energy = 0
	var combo := _card("D052")
	_caster.hand.append(combo)
	_check(_manager.play_card(combo) and _caster.energy == 0,
		"D052 仅打出 Dagger Attack 时不获得费用")
	var pistol := _card("D004")
	_caster.hand.append(pistol)
	var history_size := _caster.played_cards_this_turn.size()
	_check(not _manager.play_card(pistol, _enemy) and _caster.played_cards_this_turn.size() == history_size,
		"费用不足的 Pistol Attack 不记入出牌历史")
	_caster.hand.erase(pistol)
	_check(_play("D004", _enemy), "Pistol Attack 成功打出并记入本行动历史")
	_caster.hand.append(combo)
	_caster.energy = 0
	_check(_manager.play_card(combo) and _caster.energy == 1,
		"D052 分别打出 Dagger 与 Pistol Attack 后获得 1 费")
	_caster.current_hp = 100
	_caster.buffs.clear()
	_enemy.current_hp = 100
	var nineteen := BattleManager.compute_damage(19, basis, false)
	var twenty_three := BattleManager.compute_damage(23, basis, false)
	_check(_play("B045", _enemy) and _enemy.current_hp == 100 - nineteen and _caster.current_hp == 96,
		"B045 无疗愈时先放血 4 再造成 19 面板伤害")
	_check(_play("B018"), "B018 给出牌者施加疗愈")
	_enemy.current_hp = 100
	_check(_play("B045", _enemy) and _enemy.current_hp == 100 - twenty_three,
		"B045 打出前有疗愈时改为 23 面板伤害")
	var threshold := _ally.get_max_hp_value() * 40 / 100
	_ally.current_hp = threshold
	_check(_play("K050", _ally) and _ally.current_hp == threshold + 6,
		"K050 友军生命恰好 40% 时回复 6 生命")
	_ally.current_hp = threshold + 1
	_check(_play("K050", _ally) and _ally.current_hp == threshold + 1,
		"K050 友军生命高于 40% 时不治疗")
	_manager.end_turn()
	_check(_caster.played_cards_this_turn.is_empty(), "行动结束时清空已打出卡牌历史")
	_manager.turn_system.current_index = 0


func _test_poison_stack_direct_loss() -> void:
	_manager.turn_system.current_index = 0
	_enemy.current_hp = 100
	_enemy.block_value = 50
	_enemy.buffs.clear()
	_caster.direct_hp_loss_targets.clear()
	_check(_play("K063", _enemy) and _enemy.current_hp == 100 and _enemy.block_value == 50
		and _caster.exhaust_pile.has(_card("K063")),
		"K063 目标无毒时直接失血为 0，卡牌照常消耗")
	_enemy.buffs.append({"name": "中毒", "stacks": 9, "duration": 9})
	_check(_play("K063", _enemy) and _enemy.current_hp == 91 and _enemy.block_value == 50
		and int(_manager._find_buff(_enemy, "中毒").get("stacks", 0)) == 9
		and int(_manager._find_buff(_enemy, "中毒").get("duration", 0)) == 9
		and _caster.direct_hp_loss_targets.has(_enemy.get_instance_id()),
		"K063 无视格挡按当前毒层数直接失血，不触发毒衰减")
	_enemy.current_hp = 100
	_enemy.block_value = 50
	_enemy.buffs.clear()
	_enemy.buffs.append({"name": "中毒", "stacks": 4, "duration": 4})
	_check(_play("K042", _enemy) and _caster.energy == 18 and _enemy.current_hp == 95,
		"K042 毒低于 5 层时支付 2 费，攻击被挡后直接失去 5 生命")
	_enemy.current_hp = 100
	_enemy.block_value = 50
	_enemy.buffs[0]["stacks"] = 5
	_check(_play("K042", _enemy) and _caster.energy == 19 and _enemy.current_hp == 95,
		"K042 毒达到 5 层时降至 1 费，仍直接失去 5 生命")
	_enemy.current_hp = 100
	_enemy.block_value = 50
	_enemy.buffs[0]["stacks"] = 10
	_check(_play("K042", _enemy) and _caster.energy == 19 and _enemy.current_hp == 93,
		"K042 毒达到 10 层时直接失血改为 7，降费仍生效")


func _test_poison_tick_and_simple_doom() -> void:
	_manager.turn_system.current_index = 0
	_enemy.current_hp = 100
	_enemy.block_value = 30
	_enemy.buffs.clear()
	_caster.direct_hp_loss_targets.clear()
	_check(_play("K039", _enemy) and _enemy.current_hp == 100,
		"K039 目标没有毒时不造成生命损失")
	_check(_play("K004", _enemy) and int(_manager._find_buff(_enemy, "中毒").get("stacks", 0)) == 5,
		"K004 为 K039 提供 5 层毒")
	_check(_play("K039", _enemy) and _enemy.current_hp == 95 and _enemy.block_value == 30
		and int(_manager._find_buff(_enemy, "中毒").get("stacks", 0)) == 4
		and int(_manager._find_buff(_enemy, "中毒").get("duration", 0)) == 4
		and not _caster.direct_hp_loss_targets.has(_enemy.get_instance_id()),
		"K039 按毒正常结算一次并衰减，不登记为卡牌直接失血")
	_caster.redesign_dream_enabled = true
	_caster.redesign_dream_state = 0
	_enemy.current_hp = 100
	_enemy.block_value = 30
	var doom := _card("A031")
	_caster.hand.append(doom)
	_caster.energy = 20
	_check(not _manager.play_card(doom, _enemy) and _caster.hand.has(doom),
		"A031 沉梦时不能打出")
	_caster.hand.erase(doom)
	_caster.redesign_dream_state = 1
	_check(_play("A031", _enemy) and _enemy.current_hp == 85
		and _enemy.block_value == 30 and _caster.redesign_dream_state == 0,
		"A031 幻梦中造成 15 伤害并结算后回到沉梦")


func _test_ally_move_and_dream_return() -> void:
	_manager.turn_system.current_index = 0
	_ally.current_hp = 100
	_ally.block_value = 0
	_ally.remaining_move_points = 0
	_caster.remaining_move_points = 0
	_check(_play("K006", _ally) and _ally.block_value == 3
		and _ally.remaining_move_points == 1 and _caster.remaining_move_points == 0,
		"K006 给所选友军 3 格挡和 1 格可用移动力")
	_ally.block_value = 0
	_ally.remaining_move_points = 0
	_check(_play("K022", _ally) and _ally.block_value == 4 and _ally.remaining_move_points == 2,
		"K022 给所选友军 4 格挡和 2 格可用移动力")
	_caster.played_cards_this_turn.clear()
	_caster.remaining_move_points = 0
	_check(_play("K033") and _caster.remaining_move_points == 2,
		"K033 此前未使用 Drug 时可移动最多 2 格")
	_enemy.current_hp = 100
	_check(_play("K004", _enemy), "K033 条件用的 Drug 成功打出")
	_caster.remaining_move_points = 0
	_check(_play("K033") and _caster.remaining_move_points == 3,
		"K033 此前使用 Drug 后改为可移动最多 3 格")
	_caster.redesign_dream_enabled = true
	_caster.redesign_dream_state = 0
	_caster.block_value = 0
	_check(_play("A032") and _caster.redesign_dream_state == 0 and _caster.block_value == 0,
		"A032 在沉梦中打出时不切换梦态也不获得格挡")
	_caster.redesign_dream_state = 1
	_caster.block_value = 0
	_check(_play("A032") and _caster.redesign_dream_state == 0 and _caster.block_value == 5,
		"A032 从幻梦立即回沉梦，仍按切换前梦态获得 5 格挡")


func _test_push_and_surgery_cost() -> void:
	_manager.turn_system.current_index = 0
	for spec in [["A026", 5], ["D013", 7], ["B034", 10]]:
		_enemy.current_hp = 100
		_enemy.block_value = 0
		_caster.pending_knockback = 0
		var damage := BattleManager.compute_damage(int(spec[1]), _caster.character_data.get_strength_damage_basis(), false)
		_check(_play(str(spec[0]), _enemy) and _enemy.current_hp == 100 - damage
			and _caster.pending_knockback == 1,
			"%s 造成伤害并登记 1 格推动" % spec[0])
	_caster.pending_knockback = 0
	_caster.played_cards_this_turn.clear()
	var surgery := _card("K045")
	_check(surgery != null and _manager.effective_card_cost(_caster, surgery, _enemy) == 2,
		"K045 未打出 Surgery 时费用为 2")
	_enemy.current_hp = 100
	_check(_play("K008", _enemy), "K008 Surgery 标签牌成功打出")
	_check(_manager.effective_card_cost(_caster, surgery, _enemy) == 1,
		"K045 已打出 Surgery 时费用降为 1")
	_enemy.current_hp = 100
	_enemy.block_value = 0
	_caster.hand.append(surgery)
	_caster.energy = 1
	var played := _manager.play_card(surgery, _enemy)
	var attack_damage := BattleManager.compute_damage(6, _caster.character_data.get_strength_damage_basis(), false)
	_check(played and _caster.energy == 0 and _enemy.current_hp == 100 - attack_damage * 2 - 2,
		"K045 费用 1 时两次 6 伤害后直接失去 2 生命")


func _test_mechanism_composition_batch() -> void:
	_manager.turn_system.current_index = 0
	_caster.redesign_dream_enabled = true
	_caster.redesign_dream_state = 0
	_caster.hex_coords = Vector2i(3, 3)
	_enemy.hex_coords = Vector2i(3, 4)
	_caster.remaining_move_points = 0
	_caster.block_value = 0
	_check(_play("A012") and _caster.remaining_move_points == 2 and _caster.block_value == 3,
		"A012 移动前相邻敌人时获得移动力与格挡")
	_enemy.hex_coords = Vector2i(8, 8)
	_caster.remaining_move_points = 0
	_caster.block_value = 0
	_check(_play("A012") and _caster.remaining_move_points == 2 and _caster.block_value == 0,
		"A012 移动前不相邻时不获得额外格挡")
	_caster.hex_coords = Vector2i(-1, -1)
	_enemy.hex_coords = Vector2i(-1, -1)
	_enemy.current_hp = 100
	_enemy.block_value = 2
	_enemy.buffs.clear()
	_check(_play("A022", _enemy) and _manager._effect_system.has_buff(_enemy, "虚弱"),
		"A022 出牌前目标格挡至少 2 时施加虚弱")
	_enemy.current_hp = 100
	_enemy.block_value = 0
	_enemy.buffs.clear()
	_check(_play("A022", _enemy) and not _manager._effect_system.has_buff(_enemy, "虚弱"),
		"A022 出牌前目标格挡不足 2 时不施加虚弱")
	var basis := _caster.character_data.get_strength_damage_basis()
	_enemy.current_hp = 100
	_enemy.block_value = 0
	var fourteen := BattleManager.compute_damage(14, basis, false)
	_check(_play("A047", _enemy) and _enemy.current_hp == 100 - fourteen,
		"A047 出牌前 Armor 为 0 时造成 14 面板伤害")
	_enemy.current_hp = 100
	_enemy.block_value = 5
	var ten := BattleManager.compute_damage(10, basis, false)
	_check(_play("A047", _enemy) and _enemy.current_hp == 100 - maxi(ten - 5, 0),
		"A047 出牌前有 Armor 时只造成 10 面板伤害")
	_enemy.current_hp = 100
	_enemy.block_value = 3
	var four := BattleManager.compute_damage(4, basis, false)
	_check(_play("K034", _enemy) and _enemy.current_hp == 100 - maxi(four - 3, 0) - 5,
		"K034 出牌前 Armor 至少 3 时直接失去 5 生命")
	_enemy.current_hp = 100
	_enemy.block_value = 0
	_check(_play("K034", _enemy) and _enemy.current_hp == 100 - four - 3,
		"K034 出牌前无 Armor 时直接失去 3 生命")
	for spec in [["K027", 5, 1], ["K048", 6, 2]]:
		_enemy.current_hp = 100
		_enemy.block_value = 0
		_caster.remaining_move_points = 0
		var dealt := BattleManager.compute_damage(int(spec[1]), basis, false)
		_check(_play(str(spec[0]), _enemy) and _enemy.current_hp == 100 - dealt - int(spec[2])
			and _caster.remaining_move_points == 1,
			"%s 攻击、直接失血后获得移动力" % spec[0])
	_caster.remaining_move_points = 0
	_caster.block_value = 0
	_check(_play("B031") and _caster.remaining_move_points == 1 and _caster.block_value == 8,
		"B031 获得 1 格移动力和 8 格挡")
	_caster.played_cards_this_turn.clear()
	_caster.remaining_move_points = 0
	_caster.block_value = 0
	_check(_play("D056") and _caster.remaining_move_points == 0 and _caster.block_value == 6,
		"D056 未打出 Pistol 时仅获得 6 格挡")
	_enemy.current_hp = 100
	_check(_play("D004", _enemy), "D004 登记 Pistol 出牌历史")
	_caster.remaining_move_points = 0
	_caster.block_value = 0
	_check(_play("D056") and _caster.remaining_move_points == 1 and _caster.block_value == 8,
		"D056 打出 Pistol 后获得移动力和 8 格挡")
	_enemy.current_hp = 100
	_caster.remaining_move_points = 0
	_caster.pending_knockback = 0
	_check(_play("D057", _enemy) and _caster.pending_knockback == 1
		and _caster.remaining_move_points == 2,
		"D057 登记目标推动并给予自身 2 格移动力")
	_caster.pending_knockback = 0
	_caster.redesign_dream_state = 1
	_enemy.current_hp = 100
	var twenty_two := BattleManager.compute_damage(22, basis, false)
	_check(_play("A052", _enemy) and _enemy.current_hp == 100 - twenty_two
		and _caster.pending_knockback == 1 and _caster.redesign_dream_state == 0,
		"A052 幻梦中造成 22 面板伤害并推动，随后回沉梦")
	_caster.pending_knockback = 0


func _test_card_zone_and_play_condition_batch() -> void:
	_manager.turn_system.current_index = 0
	_caster.hand.clear()
	_caster.draw_pile.clear()
	_caster.discard_pile.clear()
	var eligible := CardData.new()
	eligible.card_name = "弃牌堆行动牌"
	eligible.card_type = CardData.CardType.ACTION
	var power := CardData.new()
	power.card_name = "弃牌堆能力牌"
	power.card_type = CardData.CardType.ABILITY
	var filler := CardData.new()
	filler.card_name = "原抽牌堆牌"
	_caster.discard_pile = [eligible, power]
	_caster.draw_pile = [filler]
	_check(_play("A024") and _caster.hand.size() == 1 and _caster.hand[0] == eligible
		and _caster.draw_pile.size() == 1 and _caster.draw_pile[0] == filler
		and _caster.discard_pile.has(power),
		"A024 从弃牌堆转移非 Power 实体牌到顶并立即抽到")
	_caster.hand.clear()
	_caster.draw_pile = [filler]
	_caster.discard_pile = [power]
	_check(_play("A024") and _caster.hand.size() == 1 and _caster.hand[0] == filler
		and _caster.discard_pile.has(power),
		"A024 无合法转移候选时仍执行后续抽牌")
	_caster.hand = [eligible, power]
	_caster.draw_pile = [filler]
	_caster.discard_pile.clear()
	var exhausted_before := _caster.exhaust_pile.size()
	_check(_play("D071") and _caster.hand.size() == 2 and _caster.draw_pile.size() == 1
		and _caster.exhaust_pile.size() == exhausted_before + 1
		and _caster.exhaust_pile.back().card_id == "D071",
		"D071 其余手牌洗回并重抽同数，卡牌自身消耗")
	_caster.hand.clear()
	_caster.draw_pile.clear()
	_caster.discard_pile.clear()
	_ally.current_hp = int(_ally.get_max_hp_value() * 0.25) + 1
	_ally.block_value = 0
	var low_hp_card := _card("K067")
	_caster.hand.append(low_hp_card)
	_caster.energy = 1
	_check(not _manager.play_card(low_hp_card, _ally) and _caster.energy == 1
		and _caster.hand.has(low_hp_card) and _ally.block_value == 0,
		"K067 友军生命高于 25% 时拒绝出牌且不扣资源")
	_ally.current_hp = int(_ally.get_max_hp_value() * 0.25)
	var hp_before := _ally.current_hp
	_check(_manager.play_card(low_hp_card, _ally) and _caster.energy == 0
		and _ally.current_hp == mini(hp_before + 10, _ally.get_max_hp_value())
		and _ally.block_value == 8,
		"K067 友军生命恰好不高于 25% 时治疗并获得格挡")
