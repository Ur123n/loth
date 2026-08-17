extends Node2D

## 战斗地图场景（独立于大世界）。
## 回合制战斗：行动次序 → buff 结算（预格挡/预抽牌/费用预支）→ 抽牌/获得费用 → 移动/出牌 → 结束回合。
## 底部手牌界面：拖拽卡牌向上打出；点击高亮格移动。
## 敌怪：骷髅（近战靠近）+ 骷髅弓箭手（远程远离），数据来自敌怪库。
## 敌怪死亡原地变尸骸（占格、无 AI、原名、血量=原上限/3 向下取整），尸骸血量清零后消失。
## 右上角队伍血量面板 + 单位头顶 HP 标签实时显示角色血量。Esc 返回大世界。
## 出生点：从锚点 BFS 向外扩展，保证每名角色占据不同图格。

@export var cols: int = 10
@export var rows: int = 10
@export var tile_size: float = 44.0
@export var fixed_seed: int = -1

var _map_data: BattleMapData
var _map_view: BattleMapView
var _battle_manager: BattleManager
var _turn_system: TurnSystem
var _units: Array[BattleUnit] = []          # 参与行动次序：4 玩家 + AI 敌怪
var _enemy_units: Array[BattleUnit] = []    # 全部敌怪（AI 敌怪 + 尸骸）
var _occupied: Dictionary = {}
var _reachable: Dictionary = {}

var _round_label: Label
var _current_label: Label
var _order_bar: TurnOrderBar
var _log_label: Label
var _hand_ui: BattleHandUI
var _party_hp_panel: PartyHpPanel
var _settlement_panel: BattleSettlementPanel
var _settlement_active: bool = false
var _card_reward_panel: CardRewardPanel
var _pending_card_rewards: Array = []
var _ai_debug_panel: AiDebugPanel
var _last_ai_decisions: Dictionary = {}   # BattleUnit -> Dictionary（最近一次 AI 决策，调试用）
var _demo_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	if GameState.demo_mode:
		# Demo：每场战斗随机地图
		fixed_seed = _demo_rng.randi_range(1, 999999)
	_map_data = BattleMapData.new()
	_map_data.cols = cols
	_map_data.rows = rows
	_map_data.tile_size = tile_size
	_map_data.generate(fixed_seed)

	_map_view = BattleMapView.new()
	_map_view.name = "MapView"
	add_child(_map_view)
	_map_view.build(_map_data)

	var viewport_size := get_viewport_rect().size
	var grid := _map_data.grid_size()
	_map_view.position = Vector2(
		(viewport_size.x - grid.x) * 0.5,
		(viewport_size.y - grid.y) * 0.5
	)

	_spawn_party()
	_spawn_ai_enemies()
	_build_ui()

	_battle_manager = BattleManager.new()
	_battle_manager.battle_log.connect(_on_battle_log)
	_battle_manager.round_started.connect(_on_round_started)
	_battle_manager.turn_started.connect(_on_turn_started)
	_battle_manager.unit_defeated.connect(_on_unit_defeated)
	_battle_manager.hp_changed.connect(_on_hp_changed)
	_battle_manager.battle_finished.connect(_on_battle_finished)
	_battle_manager.setup(_units)
	_turn_system = _battle_manager.turn_system
	_battle_manager.start_battle()
	_party_hp_panel.refresh(_player_units())


func _unhandled_input(event: InputEvent) -> void:
	if _settlement_active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _hand_ui != null and _hand_ui.is_dragging():
			return
		var local := _map_view.to_local(get_global_mouse_position())
		var cell := HexGrid.world_to_hex(local, _map_data.tile_size, _map_data.cols, _map_data.rows)
		if cell.x >= 0 and _occupied.has(cell):
			var occupant: BattleUnit = _occupied[cell]
			if occupant != null and occupant.is_enemy and _last_ai_decisions.has(occupant):
				_show_ai_debug(occupant)
				return
		if cell.x >= 0 and _reachable.has(cell):
			_move_current_unit(cell)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F4:
		_toggle_ai_debug()
	elif event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://world/map/Main.tscn")


## 生成队伍：从出生点 BFS 向外收集互不重复的可通行格，确保四人不同格。
func _spawn_party() -> void:
	var party: Array = GameState.party_characters
	if party.is_empty():
		party = _load_fallback_party()

	var anchor: Vector2i = _map_data.find_spawn_anchor()
	var cells := _collect_spawn_cells(anchor, party.size())

	for i in party.size():
		var data := party[i] as CharacterData
		if data == null:
			continue
		var unit := BattleUnit.new()
		unit.name = "Unit%d" % i
		unit.character_data = data
		var cell: Vector2i = cells[mini(i, cells.size() - 1)]
		unit.hex_coords = cell
		unit.position = _map_view.hex_to_world(cell)
		if i >= cells.size():
			# 极端兜底：地图可通行格不足时同格叠加做小偏移
			var offset_index := i - cells.size()
			unit.position += Vector2((offset_index % 3 - 1) * 14.0, (offset_index / 3 - 1) * 14.0)
		_occupied[cell] = unit
		add_child(unit)
		_units.append(unit)


## 从锚点 BFS 向外扩展，收集 count 个互不重复的可通行格。
func _collect_spawn_cells(anchor: Vector2i, count: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [anchor]
	var frontier: Array[Vector2i] = [anchor]
	var seen := { anchor: true }
	while cells.size() < count and not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		for neighbor in HexGrid.neighbors(current.x, current.y):
			if cells.size() >= count:
				break
			if seen.has(neighbor):
				continue
			seen[neighbor] = true
			if _map_data.is_passable(neighbor.x, neighbor.y):
				cells.append(neighbor)
				frontier.append(neighbor)
	return cells


## 生成 AI 敌怪：骷髅（靠近）+ 骷髅弓箭手（远离），参与行动次序。
func _spawn_ai_enemies() -> void:
	if GameState.demo_mode:
		_spawn_demo_enemies()
		return
	# 正式战斗：从敌怪小队表按“普通”强度随机抽取一支 3~4 人小队
	var pack_db := get_node_or_null("/root/EnemyPackDB") as EnemyPackDatabase
	if pack_db != null:
		var pack := pack_db.random_pack("普通", _demo_rng)
		if not pack.is_empty():
			_spawn_pack(pack, true)
			return
	# 兜底：无小队表时沿用原固定组合
	var spawns := [
		["骷髅", Vector2i(cols - 4, 5), true],
		["骷髅弓箭手", Vector2i(cols - 2, 2), true],
	]
	for spawn in spawns:
		var data: EnemyData = EnemyDB.get_enemy(spawn[0])
		var cell: Vector2i = spawn[1]
		if data == null:
			continue
		if not _map_data.is_passable(cell.x, cell.y) or _occupied.has(cell):
			cell = _find_free_cell()
			if cell == Vector2i(-1, -1):
				continue
		_spawn_enemy_unit(data, cell, true)


## Demo：按已通关战斗数随机生成敌怪（普通/精英/Boss），随机散落在地图可通行格上。
func _spawn_demo_enemies() -> void:
	# 优先：从敌怪小队表按当前场次强度随机抽取一支 3~4 人小队（含角色协同）
	var pack_db := get_node_or_null("/root/EnemyPackDB") as EnemyPackDatabase
	if pack_db != null:
		var tier := DemoComposer.battle_tier(GameState.demo_battle_number)
		var pack := pack_db.random_pack(tier, _demo_rng)
		if not pack.is_empty():
			_spawn_pack(pack, true)
			return
	# 兜底：无小队表时沿用旧的随机拼怪（散兵，无协同）
	var enemies := DemoComposer.compose_battle(GameState.demo_battle_number, _demo_rng)
	for enemy_data in enemies:
		var cell := _find_random_free_cell()
		if cell == Vector2i(-1, -1):
			break
		_spawn_enemy_unit(enemy_data, cell, true)


func _find_random_free_cell() -> Vector2i:
	for attempt in 80:
		var col := _demo_rng.randi_range(0, cols - 1)
		var row := _demo_rng.randi_range(0, rows - 1)
		var cell := Vector2i(col, row)
		if _map_data.is_passable(col, row) and not _occupied.has(cell):
			return cell
	return _find_free_cell()


func _spawn_enemy_unit(data: EnemyData, cell: Vector2i, join_turn_order: bool,
		pack_id := "", pack_role := "", is_leader := false) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.name = "Enemy%d" % _enemy_units.size()
	unit.configure_enemy(data)
	unit.hex_coords = cell
	unit.position = _map_view.hex_to_world(cell)
	unit.pack_id = pack_id
	unit.pack_role = pack_role
	add_child(unit)
	_occupied[cell] = unit
	_enemy_units.append(unit)
	if join_turn_order:
		_units.append(unit)
	return unit


## 生成一支小队（含角色/首领标记），并建立护卫 → 首领的绑定关系。
func _spawn_pack(pack: Dictionary, join_turn_order: bool) -> Array[BattleUnit]:
	var pack_db := get_node_or_null("/root/EnemyPackDB") as EnemyPackDatabase
	if pack_db == null:
		return []
	var entries := pack_db.pack_member_entries(pack)
	var spawned: Array[BattleUnit] = []
	var leader_unit: BattleUnit = null
	for entry in entries:
		var enemy: EnemyData = entry.get("enemy")
		if enemy == null:
			continue
		var cell := _find_random_free_cell()
		if cell == Vector2i(-1, -1):
			break
		var unit := _spawn_enemy_unit(enemy, cell, join_turn_order,
			str(pack.get("name", "")), str(entry.get("role", "")), bool(entry.get("leader", false)))
		spawned.append(unit)
		if bool(entry.get("leader", false)):
			leader_unit = unit
	# 护卫绑定本队首领（协同：保护首领）
	if leader_unit != null:
		for unit in spawned:
			if unit.pack_role == "护卫":
				unit.pack_leader = leader_unit
	return spawned


func _find_free_cell() -> Vector2i:
	for row in rows:
		for col in cols:
			var cell := Vector2i(col, row)
			if _map_data.is_passable(col, row) and not _occupied.has(cell):
				return cell
	return Vector2i(-1, -1)


func _load_fallback_party() -> Array:
	var party: Array = []
	for name in ["alice", "baldwin", "dismas", "kasha"]:
		var data: CharacterData = load("res://content/characters/%s.tres" % name)
		if data != null:
			party.append(data)
	return party


func _move_current_unit(target: Vector2i) -> void:
	var unit := _turn_system.current_unit()
	if unit == null:
		return
	var result := _map_data.find_movement_path(
		unit.hex_coords, target, unit.remaining_move_points, _occupied, unit)
	var path: Array = result.get("path", [])
	if path.is_empty():
		return
	var before_enemies := _enemies_in_range_of(unit)
	_occupied.erase(unit.hex_coords)
	unit.hex_coords = target
	_occupied[target] = unit
	unit.position = _map_view.hex_to_world(target)
	unit.remaining_move_points -= int(result.get("cost", 0))
	unit.moved_this_turn = true
	_check_flank_trigger(unit, before_enemies)
	_refresh_current_label()
	_update_reachable()


func _on_round_started(round_number: int) -> void:
	_round_label.text = "第 %d 回合" % round_number
	var ordered_units: Array[BattleUnit] = []
	for index in _turn_system.action_order:
		ordered_units.append(_units[index])
	_order_bar.update_order(ordered_units, _turn_system.action_values)
	_order_bar.set_current(_turn_system.current_index)
	for unit in _units:
		unit.refresh_block_display()
	_party_hp_panel.refresh(_player_units())


func _on_turn_started(unit: BattleUnit) -> void:
	if _settlement_active:
		return
	if unit.is_enemy:
		_hand_ui.visible = false
		_map_view.set_reachable({})
		_refresh_current_label()
		if unit.is_corpse or unit.is_removed:
			_battle_manager.end_enemy_turn(unit)
			return
		_run_enemy_turn(unit)
		_battle_manager.end_enemy_turn(unit)
		return
	_hand_ui.set_unit(unit)
	_refresh_current_label()
	_update_reachable()


## 战斗结束：发放钱币/经验，弹出结算界面（战利品页 → 经验页）。
func _on_battle_finished(coins: int, exp: int, loot: Array, defeated: bool = false) -> void:
	_settlement_active = true
	if _hand_ui != null:
		_hand_ui.visible = false
	var party := GameState.party_characters
	if party.is_empty():
		for unit in _units:
			if not unit.is_enemy and unit.character_data != null:
				party.append(unit.character_data)
		if not party.is_empty():
			GameState.party_characters = party
	var before_levels: Array[int] = []
	for character in party:
		if character is CharacterData:
			before_levels.append(character.level)
	GameState.add_money(coins)
	for character in party:
		if character is CharacterData:
			character.gain_exp(exp)
	GameState.save_game()
	if GameState.demo_mode and not defeated:
		_pending_card_rewards = _build_card_rewards()

	_settlement_panel = BattleSettlementPanel.new()
	add_child(_settlement_panel)
	_settlement_panel.setup(coins, loot, before_levels)
	_settlement_panel.settled.connect(_on_settlement_finished)


## 结算界面“结束战斗”：demo 先展示卡牌奖励（三选一），再回营地；正式战斗直接返回大世界。
func _on_settlement_finished() -> void:
	if _settlement_panel != null:
		_settlement_panel.queue_free()
		_settlement_panel = null
	GameState.save_game()
	if GameState.demo_mode:
		if not _pending_card_rewards.is_empty():
			_card_reward_panel = CardRewardPanel.new()
			add_child(_card_reward_panel)
			_card_reward_panel.setup(_pending_card_rewards)
			_card_reward_panel.finished.connect(_on_card_rewards_finished)
			return
		get_tree().change_scene_to_file("res://demo/DemoHub.tscn")
	else:
		get_tree().change_scene_to_file("res://world/map/Main.tscn")


## 卡牌奖励选择完毕：保存并返回修整营地。
func _on_card_rewards_finished() -> void:
	if _card_reward_panel != null:
		_card_reward_panel.queue_free()
		_card_reward_panel = null
	GameState.save_game()
	get_tree().change_scene_to_file("res://demo/DemoHub.tscn")


## Demo 卡牌奖励：按当前场次难度查掉落表，每名角色独立掷骰判定，
## 命中则生成 count 次“三选一”候选（通用库 + 该角色道途卡）。
func _build_card_rewards() -> Array:
	var rewards: Array = []
	if not GameState.demo_mode:
		return rewards
	var drop: Dictionary = CardDropDB.get_drop(DemoComposer.battle_tier(GameState.demo_battle_number))
	if drop.is_empty() or int(drop.get("chance", 0)) <= 0:
		return rewards
	var rolls := maxi(int(drop.get("count", 1)), 1)
	for character in GameState.party_characters:
		if not character is CharacterData:
			continue
		if _demo_rng.randi_range(1, 100) > int(drop.get("chance", 0)):
			continue
		for i in rolls:
			var offers := _roll_card_offers(character)
			if offers.is_empty():
				continue
			rewards.append({"character": character, "offers": offers})
	return rewards


## 随机 3 张候选：通用库（排除基础 打击/防御）+ 该角色道途专属卡。
func _roll_card_offers(character: CharacterData) -> Array:
	var db := get_node_or_null("/root/CardDB") as CardDatabase
	if db == null:
		return []
	var pool: Array[CardData] = []
	for card in db.cards:
		if card.category == CardData.CardCategory.GENERIC:
			if card.card_name == "打击" or card.card_name == "防御" or card.derived:
				continue
			pool.append(card)
		elif card.category == CardData.CardCategory.PATH and card.path_name == character.path_name:
			pool.append(card)
	if pool.is_empty():
		return []
	var shuffled := pool.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j := _demo_rng.randi_range(0, i)
		var tmp = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp
	return shuffled.slice(0, mini(3, shuffled.size()))


## 单位生命归零：敌怪变尸骸，尸骸血量清零则消散。
func _on_unit_defeated(unit: BattleUnit) -> void:
	if unit.is_removed:
		return
	if unit.is_corpse:
		_occupied.erase(unit.hex_coords)
		unit.remove_corpse()
		if _log_label != null:
			_log_label.text = "尸骸 %s 消散" % unit.get_display_name()
	elif unit.is_enemy:
		unit.become_corpse()
		if _log_label != null:
			_log_label.text = "%s 倒下，化为尸骸（生命 %d）" % [unit.get_display_name(), unit.corpse_max_hp]
	elif _log_label != null:
		_log_label.text = "%s 倒地" % unit.get_display_name()


## 敌怪 AI（《敌人 AI 重构方案》）：行为模板 + 目标选择 + 行动评分 + 位置评价。
## 决策引擎在 EnemyAI（core/ai/enemy_ai.gd），此处只负责执行决策与记录调试信息。
func _run_enemy_turn(unit: BattleUnit) -> void:
	if unit.is_corpse or unit.is_removed:
		return
	var decision := EnemyAI.decide(unit, _living_players(), _enemy_units, _map_data, _occupied)
	_last_ai_decisions[unit] = decision
	_execute_ai_decision(unit, decision)


## 执行 AI 决策：沿路径移动（进入攻击范围即停），随后按行动类型攻击。
func _execute_ai_decision(unit: BattleUnit, decision: Dictionary) -> void:
	var action := str(decision.get("action", "等待"))
	var target: BattleUnit = decision.get("target")
	var path: Array = decision.get("path", [])
	var budget := unit.get_max_move_points()
	var moved := 0
	for cell in path:
		if moved >= budget:
			break
		if _occupied.has(cell) and _occupied[cell] != unit:
			break
		_move_enemy(unit, cell)
		moved += 1
		if target != null and target.current_hp > 0 \
				and HexGrid.hex_distance(unit.hex_coords, target.hex_coords) <= unit.get_attack_range():
			break
	if _log_label != null:
		_log_label.text = "%s（%s）→ %s　| %s" % [
			unit.get_display_name(), decision.get("archetype", ""), action, decision.get("explain", "")]
	if target != null and target.current_hp > 0:
		var in_range := HexGrid.hex_distance(unit.hex_coords, target.hex_coords) <= unit.get_attack_range()
		if action == "攻击" or (in_range and action in ["接近", "追击", "保护"]):
			_battle_manager.enemy_attack(unit, target)


func _living_players() -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for unit in _units:
		if not unit.is_enemy and unit.current_hp > 0:
			result.append(unit)
	return result


## AI 调试：展示指定敌怪的最近一次决策。
func _show_ai_debug(unit: BattleUnit) -> void:
	var decision: Dictionary = _last_ai_decisions.get(unit, {})
	if decision.is_empty():
		return
	_ai_debug_panel.show_decision(unit, decision)


## F4：切换 AI 调试面板（未显示时展示最近行动过的敌怪决策）。
func _toggle_ai_debug() -> void:
	if _ai_debug_panel == null:
		return
	if _ai_debug_panel.visible:
		_ai_debug_panel.clear_panel()
		return
	var latest: BattleUnit = null
	for unit in _enemy_units:
		if _last_ai_decisions.has(unit):
			latest = unit
	if latest != null:
		_show_ai_debug(latest)
	else:
		_ai_debug_panel.clear_panel()


func _move_enemy(unit: BattleUnit, cell: Vector2i) -> void:
	_occupied.erase(unit.hex_coords)
	unit.hex_coords = cell
	_occupied[cell] = unit
	unit.position = _map_view.hex_to_world(cell)


## 当前单位攻击范围内的存活敌人。
func _enemies_in_range_of(unit: BattleUnit) -> Array:
	var result: Array = []
	var attack_range := unit.get_attack_range()
	for other in _units:
		if not other.is_enemy or other.is_corpse or other.is_removed:
			continue
		if HexGrid.hex_distance(unit.hex_coords, other.hex_coords) <= attack_range:
			result.append(other)
	return result


## 伺机触发：移动前后对比，离开攻击范围的敌人受到伤害。
func _check_flank_trigger(unit: BattleUnit, before_enemies: Array) -> void:
	if unit.flank_trigger_damage <= 0:
		return
	var after_enemies := _enemies_in_range_of(unit)
	for enemy in before_enemies:
		if after_enemies.has(enemy):
			continue
		_battle_manager.take_damage(enemy, unit.flank_trigger_damage)
		if _log_label != null:
			_log_label.text = "「伺机」：%s 离开攻击范围，%s 受到 %d 点伤害" % [
				unit.get_display_name(), enemy.get_display_name(), unit.flank_trigger_damage]


## 击退：把目标沿远离攻击者的方向推开 distance 格（被阻挡则原地）。
func _try_knockback(attacker: BattleUnit, target: BattleUnit, distance: int) -> void:
	var from := attacker.hex_coords
	var to := target.hex_coords
	var moved := false
	for step in distance:
		var best := Vector2i(-1, -1)
		var best_dist := HexGrid.hex_distance(from, to)
		for neighbor in HexGrid.neighbors(to.x, to.y):
			if not _map_data.is_passable(neighbor.x, neighbor.y) or _occupied.has(neighbor):
				continue
			var d := HexGrid.hex_distance(from, neighbor)
			if d > best_dist:
				best_dist = d
				best = neighbor
		if best == Vector2i(-1, -1):
			if _log_label != null:
				_log_label.text = "击退失败：%s 被地形/单位阻挡" % target.get_display_name()
			break
		_occupied.erase(to)
		to = best
		_occupied[to] = target
		target.hex_coords = to
		target.position = _map_view.hex_to_world(to)
		moved = true
	if moved and _log_label != null:
		_log_label.text = "%s 被击退至 %s" % [target.get_display_name(), str(target.hex_coords)]


func _on_battle_log(message: String) -> void:
	if _log_label != null:
		_log_label.text = message


func _on_hp_changed(_unit: BattleUnit) -> void:
	if _party_hp_panel != null:
		_party_hp_panel.refresh(_player_units())


func _player_units() -> Array:
	var players: Array = []
	for unit in _units:
		if not unit.is_enemy:
			players.append(unit)
	return players


func _on_card_play_requested(card: CardData, screen_position: Vector2) -> void:
	var target: BattleUnit = null
	if card.target_type == CardData.TargetType.ALLY or card.target_type == CardData.TargetType.ENEMY:
		var local := _map_view.to_local(screen_position)
		var cell := HexGrid.world_to_hex(local, _map_data.tile_size, _map_data.cols, _map_data.rows)
		if _occupied.has(cell):
			var occupant: BattleUnit = _occupied[cell]
			var valid := occupant.current_hp > 0 and not occupant.is_removed
			if card.target_type == CardData.TargetType.ENEMY:
				valid = valid and occupant.is_enemy and not occupant.is_corpse
			else:
				valid = valid and not occupant.is_enemy
			if valid and _target_in_range(_battle_manager.current_unit(), occupant, card):
				target = occupant
	if _battle_manager.play_card(card, target):
		_hand_ui.refresh()
		_refresh_current_label()
		_update_reachable()
		var unit := _battle_manager.current_unit()
		if unit != null and unit.pending_knockback > 0 and target is BattleUnit and target.is_enemy:
			_try_knockback(unit, target, unit.pending_knockback)
			unit.pending_knockback = 0


## 目标距离校验：有效范围 = max(card.range, 效果攻击范围)；超出范围不可指定。
func _target_in_range(unit: BattleUnit, target: BattleUnit, card: CardData) -> bool:
	if unit == null or target == null or card == null:
		return false
	var effective_range := maxi(card.range, 0)
	for effect in card.effects:
		if effect is AttackEffect:
			effective_range = maxi(effective_range, (effect as AttackEffect).attack_range)
	if effective_range <= 0:
		return true
	return HexGrid.hex_distance(unit.hex_coords, target.hex_coords) <= effective_range


func _refresh_current_label() -> void:
	var unit := _turn_system.current_unit()
	if unit == null:
		return
	_current_label.text = "当前行动：%s（行动值 %d）　移动力：%d/%d　费用：%d/%d　格挡：%d" % [
		unit.get_display_name(),
		_turn_system.current_action_value(),
		unit.remaining_move_points,
		unit.get_max_move_points(),
		unit.energy,
		BattleManager.ENERGY_PER_TURN,
		unit.block_value,
	]


func _update_reachable() -> void:
	var unit := _turn_system.current_unit()
	if unit == null:
		return
	_reachable = _map_data.compute_reachable(
		unit.hex_coords, unit.remaining_move_points, _occupied, unit)
	_map_view.set_reachable(_reachable)


func _build_ui() -> void:
	_round_label = Label.new()
	_round_label.name = "RoundLabel"
	_round_label.position = Vector2(12, 12)
	_round_label.add_theme_font_size_override("font_size", 16)
	_round_label.add_theme_color_override("font_color", Color(0.90, 0.92, 0.96))
	add_child(_round_label)

	_current_label = Label.new()
	_current_label.name = "CurrentLabel"
	_current_label.position = Vector2(12, 40)
	_current_label.add_theme_font_size_override("font_size", 15)
	_current_label.add_theme_color_override("font_color", Color(0.95, 0.86, 0.58))
	add_child(_current_label)

	_order_bar = TurnOrderBar.new()
	_order_bar.name = "TurnOrderBar"
	add_child(_order_bar)

	var legend := Label.new()
	legend.name = "Legend"
	legend.text = "图例：绿=普通　深灰=障碍(不可进入)　蓝=减速(离开耗2)　黄=加速(离开耗0)　紫=buff"
	legend.position = Vector2(12, 64)
	legend.add_theme_font_size_override("font_size", 13)
	legend.add_theme_color_override("font_color", Color(0.78, 0.80, 0.85))
	add_child(legend)

	_log_label = Label.new()
	_log_label.name = "BattleLog"
	_log_label.position = Vector2(12, 92)
	_log_label.add_theme_font_size_override("font_size", 13)
	_log_label.add_theme_color_override("font_color", Color(0.62, 0.82, 1.0))
	add_child(_log_label)

	var end_button := Button.new()
	end_button.name = "EndTurnButton"
	end_button.text = "结束回合"
	end_button.position = Vector2(1140, 480)
	end_button.custom_minimum_size = Vector2(110, 44)
	end_button.pressed.connect(_on_end_turn_pressed)
	add_child(end_button)

	_hand_ui = BattleHandUI.new()
	_hand_ui.name = "BattleHandUI"
	add_child(_hand_ui)
	_hand_ui.card_play_requested.connect(_on_card_play_requested)

	_party_hp_panel = PartyHpPanel.new()
	add_child(_party_hp_panel)

	_ai_debug_panel = AiDebugPanel.new()
	_ai_debug_panel.name = "AiDebugPanel"
	add_child(_ai_debug_panel)


func _on_end_turn_pressed() -> void:
	_battle_manager.end_turn()
