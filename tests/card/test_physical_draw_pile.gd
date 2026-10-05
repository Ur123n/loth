extends SceneTree

var _failed := 0
var _passed := 0
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var prototype := CardData.new()
	prototype.card_id = "PHYSICAL_TEST"
	prototype.card_name = "实体测试牌"
	var other := CardData.new()
	other.card_id = "PHYSICAL_OTHER"
	other.card_name = "另一张牌"
	var unit := BattleUnit.new()
	unit.character_data = CharacterData.new()
	unit.character_data.deck = [prototype, prototype, other]
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261005
	var manager := BattleManager.new()
	var units: Array[BattleUnit] = [unit]
	manager.setup(units, rng, func(_name: String) -> CardData: return prototype)
	_check(unit.draw_pile.size() == 3 and unit.draw_pile[0] != unit.draw_pile[1]
		and not unit.draw_pile.has(prototype), "开战时同名多张牌拥有独立实体")
	var first: CardData = unit.draw_pile.back()
	var second: CardData = unit.draw_pile[unit.draw_pile.size() - 2]
	manager._effect_system.draw_cards(unit, 2)
	_check(unit.hand.size() == 2 and unit.hand[0] == first and unit.hand[1] == second,
		"普通抽牌依次从固定牌顶取出原实体")
	var top := unit.hand[0]
	var bottom := unit.hand[1]
	unit.hand.clear()
	unit.draw_pile.clear()
	unit.discard_pile = [top, bottom]
	manager._effect_system.draw_cards(unit, 2)
	_check(unit.discard_pile.is_empty() and unit.draw_pile.is_empty()
		and unit.hand.has(top) and unit.hand.has(bottom),
		"抽空后弃牌实体洗回并且牌数守恒")
	unit.hand.clear()
	manager._effect_system.add_cards_to_pile(unit, "draw", prototype.card_name, 3, "top")
	_check(unit.draw_pile.size() == 3 and unit.draw_pile[0] != unit.draw_pile[1]
		and unit.draw_pile[1] != unit.draw_pile[2] and not unit.draw_pile.has(prototype),
		"生成的同名多张牌也有独立实体")
	unit.draw_pile.clear()
	unit.discard_pile = [top]
	var move := TransferRandomCardEffect.new()
	move.source = "discard"
	move.destination = "draw"
	move.position = "top"
	move.count = 1
	manager._effect_system.transfer_random_cards(unit, move)
	manager._effect_system.draw_cards(unit, 1)
	_check(unit.hand.back() == top, "置顶实体是下一张抽到的牌")
	unit.hand.clear()
	unit.draw_pile = [top]
	unit.discard_pile = [bottom]
	move.position = "bottom"
	manager._effect_system.transfer_random_cards(unit, move)
	manager._effect_system.draw_cards(unit, 2)
	_check(unit.hand.size() == 2 and unit.hand[0] == top and unit.hand[1] == bottom,
		"置底实体排在已有牌之后抽到")
	print("RESULT: passed=%d failed=%d" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
	return true


func _check(okay: bool, label: String) -> void:
	if okay:
		_passed += 1
		print("PASS  ", label)
	else:
		_failed += 1
		print("FAIL  ", label)
