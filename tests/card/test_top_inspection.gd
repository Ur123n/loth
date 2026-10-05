extends SceneTree

var _db: CardDatabase
var _manager: BattleManager
var _unit: BattleUnit
var _rng: RandomNumberGenerator
var _passed := 0
var _failed := 0
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_db = root.get_node("CardDB") as CardDatabase
	_unit = BattleUnit.new()
	_unit.character_data = CharacterData.new()
	_rng = RandomNumberGenerator.new()
	_rng.seed = 20261006
	_manager = BattleManager.new()
	var units: Array[BattleUnit] = [_unit]
	_manager.setup(units, _rng, func(name: String) -> CardData: return _db.get_card(name))
	_manager.turn_system.action_order = [0]
	_manager.turn_system.current_index = 0
	_test_reorder_only()
	_test_pick_and_reorder()
	_test_pick_hand_discard_and_top()
	_test_block_then_pick()
	_test_empty_and_short_pile()
	_test_optional_discard()
	print("RESULT: passed=%d failed=%d" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
	return true


func _card(card_id: String) -> CardData:
	for card in _db.cards:
		if card.card_id == card_id:
			return card
	return null


func _filler(id: String) -> CardData:
	var card := CardData.new()
	card.card_id = id
	card.card_name = id
	return card


func _reset(card: CardData, pile: Array[CardData]) -> void:
	_unit.hand.clear()
	_unit.draw_pile = pile
	_unit.discard_pile.clear()
	_unit.exhaust_pile.clear()
	_unit.block_value = 0
	_unit.energy = 20
	_unit.hand.append(card)


func _test_reorder_only() -> void:
	var card := _card("A006")
	var lower := _filler("lower")
	var second := _filler("second")
	var top := _filler("top")
	_reset(card, [lower, second, top])
	var rng_before := _rng.state
	_check(_manager.play_card(card) and _manager.has_pending_card_choice(),
		"A006 打出后等待顶牌排序")
	var options := _manager.card_choice_options()
	_check(options == [top, second], "顶牌候选按牌顶到牌底展示")
	_check(not _manager.choose_card_option(-1) and _manager.has_pending_card_choice(),
		"非法排序选择不修改事务")
	_check(not _manager.choose_card_option(-2) and _manager.has_pending_card_choice(),
		"必选排序不能跳过")
	_check(_manager.choose_card_option(1) and not _manager.has_pending_card_choice(),
		"最后一张自动归位，完成排序")
	_check(_unit.draw_pile == [lower, top, second] and _rng.state == rng_before,
		"A006 将所选实体置顶且不重新洗牌")


func _test_pick_and_reorder() -> void:
	var card := _card("A029")
	var lower := _filler("lower")
	var a := _filler("a")
	var b := _filler("b")
	var c := _filler("c")
	var d := _filler("d")
	_reset(card, [lower, a, b, c, d])
	var played := [0]
	var callback := func(_actor: BattleUnit, actual: CardData) -> void:
		if actual == card:
			played[0] += 1
	_manager.card_played.connect(callback)
	_check(_manager.play_card(card) and _manager.card_choice_options() == [d, c, b, a],
		"A029 查看四张真实顶牌")
	_check(played[0] == 0 and _unit.draw_pile == [lower],
		"选择期间顶牌暂存且出牌尚未结束")
	_check(_manager.choose_card_option(1) and _unit.hand == [c],
		"A029 选择一张实体加入手牌")
	_check(_manager.card_choice_options() == [d, b, a] and _manager.choose_card_option(2),
		"剩余实体继续由玩家选择牌顶顺序")
	_check(_manager.choose_card_option(1) and not _manager.has_pending_card_choice(),
		"A029 完成剩余牌排序")
	_check(_unit.draw_pile == [lower, d, b, a] and played[0] == 1
		and _unit.discard_pile.has(card),
		"A029 按指定牌序放回并只完成一次出牌")
	_manager.card_played.disconnect(callback)


func _test_pick_hand_discard_and_top() -> void:
	var card := _card("A036")
	var a := _filler("a")
	var b := _filler("b")
	var c := _filler("c")
	_reset(card, [a, b, c])
	_check(_manager.play_card(card) and _manager.card_choice_options() == [c, b, a],
		"A036 查看三张顶牌")
	_check(_manager.choose_card_option(1) and _unit.hand == [b],
		"A036 第一张加入手牌")
	_check(_manager.choose_card_option(0) and not _manager.has_pending_card_choice(),
		"A036 第二张进入弃牌堆并完成事务")
	_check(_unit.draw_pile == [a] and _unit.discard_pile.has(c)
		and _unit.discard_pile.has(card), "A036 第三张保留为牌顶")


func _test_block_then_pick() -> void:
	var card := _card("A068")
	var a := _filler("a")
	var b := _filler("b")
	var c := _filler("c")
	_reset(card, [a, b, c])
	_check(_manager.play_card(card) and _unit.block_value == 12
		and _manager.has_pending_card_choice(), "A068 先获得格挡再等待选择")
	_check(_manager.choose_card_option(0) and _unit.hand == [c],
		"A068 选择顶牌入手")
	_check(_manager.choose_card_option(1) and _unit.draw_pile == [b, a],
		"A068 剩余两张按所选顺序置顶")


func _test_empty_and_short_pile() -> void:
	var card := _card("A029")
	_reset(card, [])
	_check(_manager.play_card(card) and not _manager.has_pending_card_choice(),
		"空抽牌堆直接完成效果")
	var only := _filler("only")
	_reset(card, [only])
	_check(_manager.play_card(card) and _manager.card_choice_options() == [only],
		"不足四张时只展示现有实体")
	_check(_manager.choose_card_option(0) and _unit.hand == [only]
		and _unit.draw_pile.is_empty(), "仅一张时入手后无需排序")


func _test_optional_discard() -> void:
	var card := _card("A042")
	var a := _filler("a")
	var b := _filler("b")
	var c := _filler("c")
	var d := _filler("d")
	var e := _filler("e")
	_reset(card, [a, b, c, d, e])
	_check(_manager.play_card(card) and _manager.card_choice_can_skip(),
		"A042 可弃置阶段提供结束入口")
	_check(_manager.choose_card_option(-2) and not _manager.card_choice_can_skip(),
		"弃置零张后进入必选排序")
	_check(_manager.choose_card_option(3) and _manager.choose_card_option(0)
		and _manager.choose_card_option(0) and _manager.choose_card_option(0),
		"A042 零弃置时可重排全部五张")
	_check(_unit.draw_pile == [a, c, d, e, b] and _unit.discard_pile == [card],
		"零弃置的实体全部按指定顺序返回")
	_reset(card, [a, b, c, d, e])
	_check(_manager.play_card(card) and _manager.choose_card_option(0)
		and _manager.card_choice_can_skip(), "弃置一张后仍可提前结束")
	_check(_manager.choose_card_option(-2) and _manager.choose_card_option(2),
		"弃置一张后进入余牌排序")
	_check(_manager.choose_card_option(0) and _manager.choose_card_option(0),
		"余下牌归位")
	_check(_unit.draw_pile == [a, c, d, b] and _unit.discard_pile.has(e),
		"提前结束时只弃所选一张")
	_reset(card, [a, b, c, d, e])
	_check(_manager.play_card(card) and _manager.choose_card_option(0)
		and _manager.choose_card_option(0) and not _manager.card_choice_can_skip(),
		"弃满两张后自动进入排序")
	_check(_manager.choose_card_option(2) and _manager.choose_card_option(1)
		and _unit.draw_pile == [c, b, a], "弃满两张后余牌牌序正确")
	_check(_unit.discard_pile.has(e) and _unit.discard_pile.has(d),
		"两张被弃实体进入弃牌堆")


func _check(okay: bool, label: String) -> void:
	if okay:
		_passed += 1
		print("PASS  ", label)
	else:
		_failed += 1
		print("FAIL  ", label)
