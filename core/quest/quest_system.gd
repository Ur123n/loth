extends Node

## 任务系统（Autoload：QuestSystem）。
## 无任务 UI / 无任务栏 / 无任务提示：任务状态只记录在 GameState.quest_state（随存档持久化），
## 完成条件满足后自动推进到下一任务；分支任务按完成时的前置条件不同进入不同后续任务。
## 奖励与线索由 NPC 对话与文本提供（rewards 中的 text / quest.description / NPC dialogue）。
## 触发点：
##   - GameState.flag_changed → 自动检查（剧情/对话置 flag 即推进）
##   - notify_npc_talked()：与 NPC 交谈后调用（世界脚本 / StoryTrigger）
##   - notify_battle_won()：战斗胜利后调用（BattleMap 结算）
##   - check_advance()：可被主场景按帧/定时调用（覆盖物品/时间等条件）

## 注意：脚本通过 preload 引用同模块类型，不依赖全局 class 缓存（无头测试/新文件均可用）。
const _QuestData := preload("quest_data.gd")
const _QuestCondition := preload("quest_condition.gd")

signal quest_started(quest_id: String)
signal quest_completed(quest_id: String, result: Dictionary)

const ACTIVE_KEY := "active"
const DONE_KEY := "done"
const TALKED_KEY := "talked"
const BATTLES_KEY := "battles_won"

var _db = null
var _check_cd: float = 0.0


func _ready() -> void:
	_db = get_node_or_null("/root/QuestDB")
	GameState.flag_changed.connect(_on_flag_changed)


## 供测试/特殊场景注入数据库（正常运行时由 /root/QuestDB 提供）。
func set_database(db) -> void:
	_db = db


# ---------------- 状态读取 ----------------

func get_quest_state() -> Dictionary:
	return GameState.quest_state


func get_active_quest_id() -> String:
	return str(GameState.quest_state.get(ACTIVE_KEY, ""))


func get_active_quest():
	var qid := get_active_quest_id()
	if qid.is_empty() or _db == null:
		return null
	return _db.get_quest(qid)


func is_quest_done(quest_id: String) -> bool:
	var done: Array = GameState.quest_state.get(DONE_KEY, [])
	return done.has(quest_id)


func get_talked_npcs() -> Array:
	var talked: Array = GameState.quest_state.get(TALKED_KEY, [])
	return talked


func get_battles_won() -> int:
	return int(GameState.quest_state.get(BATTLES_KEY, 0))


# ---------------- 通知接口（外部调用） ----------------

## 与某 NPC 交谈后调用；记录并检查任务推进。
func notify_npc_talked(npc_name: String) -> void:
	if npc_name.is_empty():
		return
	var talked: Array = GameState.quest_state.get(TALKED_KEY, [])
	if not talked.has(npc_name):
		talked.append(npc_name)
		GameState.quest_state[TALKED_KEY] = talked
		GameState.save_game()
	check_advance()


## 战斗胜利后调用；累计并检查任务推进。
func notify_battle_won() -> void:
	var n := get_battles_won() + 1
	GameState.quest_state[BATTLES_KEY] = n
	GameState.save_game()
	check_advance()


## 手动接取任务（对话选项/剧情指令可调用）；已接取/已完成返回 false。
func start_quest(quest_id: String) -> bool:
	if _db == null or not _db.has_quest(quest_id):
		return false
	if is_quest_done(quest_id):
		return false
	if get_active_quest_id() == quest_id:
		return false
	_activate(quest_id)
	check_advance()
	return true


# ---------------- 推进逻辑 ----------------

## 检查并推进任务（自动接取 → 完成 → 分支/下一任务）。可安全高频调用。
func check_advance() -> void:
	if _db == null:
		return
	var guard := 0
	while guard < 8:
		guard += 1
		if not _step_once():
			break


## 单步推进；返回是否发生了状态变化（需要继续检查）。
func _step_once() -> bool:
	var active := get_active_quest_id()
	if active.is_empty():
		return _try_auto_start()
	var quest = _db.get_quest(active)
	if quest == null:
		# 引用不存在：清掉并继续
		GameState.quest_state[ACTIVE_KEY] = ""
		GameState.save_game()
		return true
	if not _QuestCondition.evaluate(quest.complete_condition, GameState):
		return false
	# 完成当前任务
	var result := _apply_rewards(quest)
	GameState.quest_state[ACTIVE_KEY] = ""
	var done: Array = GameState.quest_state.get(DONE_KEY, [])
	if not done.has(active):
		done.append(active)
	GameState.quest_state[DONE_KEY] = done
	GameState.save_game()
	quest_completed.emit(active, result)
	# 分支 → 后续任务
	var next := _pick_next(quest)
	if not next.is_empty():
		_activate(next)
		return true
	return false


## 自动接取：按加载顺序取第一个 start 条件满足且未完成的任务。
func _try_auto_start() -> bool:
	for quest in _db.all_quests():
		if is_quest_done(quest.quest_id):
			continue
		if quest.start_condition.is_empty():
			continue
		if _QuestCondition.evaluate(quest.start_condition, GameState):
			_activate(quest.quest_id)
			return true
	return false


## 激活任务（不递归 check_advance）。
func _activate(quest_id: String) -> void:
	GameState.quest_state[ACTIVE_KEY] = quest_id
	GameState.save_game()
	quest_started.emit(quest_id)


## 分支选择：branches 按顺序取首个 when 满足；否则用默认 next。
func _pick_next(quest) -> String:
	for b in quest.branches:
		if not b is Dictionary:
			continue
		if _QuestCondition.evaluate(b.get("when", {}), GameState):
			return str(b.get("next", ""))
	return quest.next_quest


func _on_flag_changed(_key: String, _value) -> void:
	check_advance()


# ---------------- 奖励 ----------------

func _apply_rewards(quest) -> Dictionary:
	var result := {"texts": []}
	for r in quest.rewards:
		if not r is Dictionary:
			continue
		var type := str(r.get("type", ""))
		match type:
			"coin":
				GameState.add_money(int(r.get("amount", 0)))
			"item":
				_give_item(str(r.get("item", "")), int(r.get("count", 1)))
			"equipment":
				_give_item(str(r.get("equipment", "")), 1)
			"xp":
				GameState.grant_battle_exp(int(r.get("amount", 0)))
			"flag":
				GameState.set_flag(str(r.get("key", "")), r.get("value", true))
			"card":
				_give_card(str(r.get("card", "")))
			"text":
				var text := str(r.get("text", ""))
				if not text.is_empty():
					result["texts"].append(text)
	GameState.save_game()
	return result


func _give_item(item_name: String, count: int) -> void:
	if item_name.is_empty() or count <= 0:
		return
	var item_db := get_node_or_null("/root/ItemDB")
	if item_db == null:
		push_warning("[QuestSystem] ItemDB 不可用，无法发放物品：%s" % item_name)
		return
	var item: ItemData = item_db.get_item(item_name)
	if item == null:
		push_warning("[QuestSystem] 奖励物品不存在：%s" % item_name)
		return
	for i in count:
		var spot := GameState.inventory.find_free_spot(item)
		if not bool(spot.get("found", false)):
			push_warning("[QuestSystem] 背包已满，奖励物品未发放：%s" % item_name)
			return
		GameState.inventory.place(item, int(spot.get("page", 0)), int(spot.get("x", 0)), int(spot.get("y", 0)))


## 卡牌奖励：加入当前首位角色的技能库（与技能光点学习逻辑一致）。
func _give_card(card_name: String) -> void:
	if card_name.is_empty():
		return
	var card_db := get_node_or_null("/root/CardDB")
	if card_db == null:
		push_warning("[QuestSystem] CardDB 不可用，无法发放卡牌：%s" % card_name)
		return
	var card: CardData = card_db.get_card(card_name)
	if card == null or card.card_name.is_empty():
		push_warning("[QuestSystem] 奖励卡牌不存在：%s" % card_name)
		return
	if GameState.party_characters.is_empty():
		return
	var character: CharacterData = GameState.party_characters[0]
	for skill in character.skill_library:
		if skill.skill_name == card_name:
			return
	var skill := SkillData.new()
	skill.skill_name = card_name
	skill.description = card_db.describe_card(card)
	character.skill_library.append(skill)
