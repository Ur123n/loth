extends SceneTree

## 卡牌逻辑链无头测试：
## 消耗 / 保留 / 虚无 / 固有 / 弃牌 / 抽牌 / 加入手牌·抽牌堆·弃牌堆 / 生成牌 / 复制 / 失去生命 / 获得费用。
## 运行：godot --headless --path C:\游戏 --script tests\card\test_card_logics.gd

var _card_db: CardDatabase
var _cards_by_name: Dictionary = {}
var _passed := 0
var _failed := 0
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_run_all()
	print("RESULT: passed=%d failed=%d" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
	return true


func _run_all() -> void:
	_setup_card_db()
	_test_keywords_parse()
	_test_innate()
	_test_play_exhaust()
	_test_draw()
	_test_discard()
	_test_add_to_piles()
	_test_generate()
	_test_copy()
	_test_lose_hp()
	_test_gain_energy()
	_test_end_turn_ethereal_retain()
	_test_hand_limit()


func _setup_card_db() -> void:
	var db_node: Node = root.get_node_or_null("CardDB")
	if db_node == null:
		var db := CardDatabase.new()
		db.name = "CardDB"
		root.add_child(db)
		db_node = db
	_card_db = db_node as CardDatabase
	for card in _card_db.cards:
		_cards_by_name[card.card_name] = card


func _make_unit(deck: Array) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.is_enemy = false
	var char_data := CharacterData.new()
	char_data.character_name = "测试者"
	char_data.deck.clear()
	for c in deck:
		char_data.deck.append(c)
	unit.character_data = char_data
	unit.current_hp = 100
	return unit


func _make_manager(unit: BattleUnit) -> BattleManager:
	var manager := BattleManager.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260812
	var units: Array[BattleUnit] = [unit]
	manager.setup(units, rng, func(name: String) -> CardData:
		return _cards_by_name.get(name))
	# 手动指定行动顺序，跳过完整回合流程
	manager.turn_system.action_order = [0]
	manager.turn_system.current_index = 0
	return manager


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("PASS  ", label)
	else:
		_failed += 1
		print("FAIL  ", label)


func _test_keywords_parse() -> void:
	var xiao_dao: CardData = _cards_by_name.get("小刀")
	_check(xiao_dao != null and xiao_dao.exhaust_on_play, "小刀：解析出「消耗」")
	var jian_bi: CardData = _cards_by_name.get("坚壁")
	_check(jian_bi != null and jian_bi.innate and jian_bi.retain, "坚壁：解析出「固有+保留」")
	var zhan_shu: CardData = _cards_by_name.get("战术预演")
	_check(zhan_shu != null and zhan_shu.effects.size() == 2 \
			and zhan_shu.effects[0] is DrawEffect \
			and (zhan_shu.effects[0] as DrawEffect).value == 3 \
			and zhan_shu.effects[1] is DiscardEffect, "战术预演：抽3弃1")
	var xue_ji: CardData = _cards_by_name.get("血祭")
	_check(xue_ji != null and xue_ji.effects[0] is LoseHpEffect \
			and xue_ji.effects[1] is GainEnergyEffect, "血祭：失去生命+获得费用")


func _test_innate() -> void:
	var jian_bi: CardData = _cards_by_name.get("坚壁")
	var strike: CardData = _cards_by_name.get("打击")
	var defend: CardData = _cards_by_name.get("防御")
	var unit := _make_unit([jian_bi, strike, strike, strike, strike, strike, defend, defend])
	var manager := _make_manager(unit)
	_check(unit.hand.has(jian_bi), "固有牌：开局直接在手牌")
	_check(manager != null, "管理器可用")


func _test_play_exhaust() -> void:
	var strike: CardData = _cards_by_name.get("打击")
	var xiao_dao: CardData = _cards_by_name.get("小刀")
	var unit := _make_unit([strike, xiao_dao])
	var manager := _make_manager(unit)
	unit.energy = 10
	unit.hand.append(xiao_dao)
	unit.hand.append(strike)
	manager.play_card(xiao_dao, null)
	_check(unit.exhaust_pile.has(xiao_dao), "消耗牌：打出后进入消耗堆")
	_check(not unit.discard_pile.has(xiao_dao), "消耗牌：不进入弃牌堆")
	manager.play_card(strike, null)
	_check(unit.discard_pile.has(strike), "普通牌：打出后进入弃牌堆")


func _test_draw() -> void:
	var defend: CardData = _cards_by_name.get("防御")
	var unit := _make_unit([])
	var manager := _make_manager(unit)
	unit.hand.clear()
	for i in 8:
		unit.draw_pile.append(defend)
	manager._draw_cards(unit, 3)
	_check(unit.hand.size() == 3, "抽牌：抽 3 张")
	manager._draw_cards(unit, 3)
	_check(unit.hand.size() == 6, "抽牌：抽牌堆用尽后从弃牌堆洗回（弃牌堆为空则停止）")


func _test_discard() -> void:
	var strike: CardData = _cards_by_name.get("打击")
	var defend: CardData = _cards_by_name.get("防御")
	var xiao_dao: CardData = _cards_by_name.get("小刀")
	var jian_bi: CardData = _cards_by_name.get("坚壁")
	var unit := _make_unit([])
	var manager := _make_manager(unit)
	unit.hand.clear()
	for c in [strike, defend, xiao_dao, jian_bi]:
		unit.hand.append(c)
	unit.discard_pile.clear()
	var de := DiscardEffect.new()
	de.value = 2
	de.mode = "random"
	manager._resolve_discard_effect(unit, de)
	_check(unit.hand.size() == 2 and unit.discard_pile.size() == 2, "弃牌：随机弃 2 张")
	de.mode = "all"
	manager._resolve_discard_effect(unit, de)
	_check(unit.hand.is_empty() and unit.discard_pile.size() == 4, "弃牌：弃掉全部手牌")


func _test_add_to_piles() -> void:
	var unit := _make_unit([])
	var manager := _make_manager(unit)
	unit.hand.clear()
	unit.draw_pile.clear()
	unit.discard_pile.clear()
	manager._add_cards_to_pile(unit, "hand", "小刀", 2, "shuffle")
	_check(unit.hand.size() == 2 and unit.hand[0].card_name == "小刀", "加入手牌：2 张小刀")
	manager._add_cards_to_pile(unit, "draw", "小刀", 1, "shuffle")
	_check(unit.draw_pile.size() == 1, "加入抽牌堆：洗入 1 张小刀")
	manager._add_cards_to_pile(unit, "draw", "防御", 1, "top")
	_check(unit.draw_pile.size() == 2 and unit.draw_pile[-1].card_name == "防御", "加入抽牌堆：置于顶部")
	manager._add_cards_to_pile(unit, "discard", "防御", 1, "shuffle")
	_check(unit.discard_pile.size() == 1, "加入弃牌堆：1 张防御")


func _test_generate() -> void:
	var unit := _make_unit([])
	var manager := _make_manager(unit)
	unit.hand.clear()
	var ge := GenerateEffect.new()
	ge.card_name = "小刀"
	ge.value = 1
	ge.pile = "hand"
	manager._resolve_generate_effect(unit, ge)
	_check(unit.hand.size() == 1 and unit.hand[0].card_name == "小刀", "生成牌：指定牌生成到手牌")
	unit.hand.clear()
	var ge2 := GenerateEffect.new()
	ge2.pool = "攻击"
	ge2.value = 1
	ge2.pile = "hand"
	manager._resolve_generate_effect(unit, ge2)
	_check(unit.hand.size() == 1 and unit.hand[0].card_type == CardData.CardType.ATTACK, "生成牌：随机攻击牌生成到手牌")


func _test_copy() -> void:
	var unit := _make_unit([])
	var manager := _make_manager(unit)
	unit.discard_pile.clear()
	var lie_nu: CardData = _cards_by_name.get("烈怒")
	manager._resolve_effects(unit, lie_nu, null)
	_check(unit.discard_pile.size() == 1 and unit.discard_pile[0].card_name == "烈怒", "复制：本牌复制品进入弃牌堆")


func _test_lose_hp() -> void:
	var unit := _make_unit([])
	var manager := _make_manager(unit)
	unit.current_hp = 50
	unit.block_value = 10
	var lh := LoseHpEffect.new()
	lh.value = 5
	lh.target = "self"
	manager._resolve_lose_hp_effect(unit, lh, null)
	_check(unit.current_hp == 45 and unit.block_value == 10, "失去生命：自身自损，无视格挡")
	var enemy := _make_unit([])
	enemy.current_hp = 30
	enemy.block_value = 8
	var lh2 := LoseHpEffect.new()
	lh2.value = 6
	lh2.target = "enemy"
	manager._resolve_lose_hp_effect(unit, lh2, enemy)
	_check(enemy.current_hp == 24 and enemy.block_value == 8, "失去生命：敌方目标，无视格挡")


func _test_gain_energy() -> void:
	var unit := _make_unit([])
	var manager := _make_manager(unit)
	unit.energy = 1
	var gain := GainEnergyEffect.new()
	gain.value = 2
	var card := CardData.new()
	card.card_name = "费用测试"
	card.effects = [gain]
	manager._resolve_effects(unit, card, null)
	_check(unit.energy == 3, "获得费用：+2")


func _test_end_turn_ethereal_retain() -> void:
	var strike: CardData = _cards_by_name.get("打击")
	var jian_bi: CardData = _cards_by_name.get("坚壁")
	var ethereal_card := CardData.new()
	ethereal_card.card_name = "虚无测试"
	ethereal_card.ethereal = true
	var unit := _make_unit([])
	var manager := _make_manager(unit)
	unit.hand.clear()
	for c in [ethereal_card, jian_bi, strike]:
		unit.hand.append(c)
	unit.discard_pile.clear()
	unit.exhaust_pile.clear()
	manager._discard_hand(unit)
	_check(unit.exhaust_pile.has(ethereal_card), "虚无牌：回合结束被消耗")
	_check(unit.hand.size() == 1 and unit.hand[0].card_name == "坚壁", "保留牌：回合结束留在手牌")
	_check(unit.discard_pile.size() == 1 and unit.discard_pile[0].card_name == "打击", "普通牌：回合结束进入弃牌堆")


func _test_hand_limit() -> void:
	var strike: CardData = _cards_by_name.get("打击")
	var defend: CardData = _cards_by_name.get("防御")
	var unit := _make_unit([])
	var manager := _make_manager(unit)
	unit.hand.clear()
	for i in 10:
		unit.hand.append(strike)
	unit.draw_pile.append(defend)
	manager._draw_cards(unit, 3)
	_check(unit.hand.size() == 10, "手牌上限 10：达到上限后停止抽牌")


