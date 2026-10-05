class_name AiPositionEvaluator
extends RefCounted

## 位置评价（《敌怪ai逻辑.txt》第 13-14 节 Position Evaluation / Preferred Range）。
##
## 回答“应该站在哪里”：在移动力内对每个可达格评分——与锚点距离（符合 PreferredRange）、
## 危险回避（谨慎型避免进入玩家相邻格）、护卫阻挡（靠近最近玩家）等，选择评分最高的格。
## 返回 {move_cell, path, position_score, improved}；position_score 为相对原地站位的改进值（0-60）。

## 生成行动的最优站位：anchor=锚点（目标/首领/受伤友军），desired=期望距离。
static func plan(unit: BattleUnit, action_key: String, anchor: Vector2i, desired: int,
		profile: AiProfile, players: Array, map_data: BattleMapData,
		occupied: Dictionary, reachable: Dictionary) -> Dictionary:
	var start := unit.hex_coords
	if reachable.is_empty():
		return {"move_cell": start, "path": [], "position_score": 0, "improved": false}
	var current_dist := HexGrid.hex_distance(start, anchor)
	var best_cell := start
	var start_cost := _cell_cost(start, action_key, anchor, desired, unit, players, profile)
	var best_cost := start_cost
	for cell in reachable:
		var d := HexGrid.hex_distance(cell, anchor)
		if action_key == "retreat" and d <= current_dist:
			continue
		var cost := _cell_cost(cell, action_key, anchor, desired, unit, players, profile)
		if cost < best_cost:
			best_cost = cost
			best_cell = cell
	if best_cell == start:
		return {"move_cell": start, "path": [], "position_score": 0, "improved": false}
	var path_data: Dictionary = map_data.find_movement_path(
		start, best_cell, unit.get_max_move_points(), occupied, unit)
	return {
		"move_cell": best_cell,
		"path": path_data.get("path", []),
		"position_score": mini(maxi(start_cost - best_cost, 0), 60),
		"improved": true,
	}


## 单元格代价（越低越好）：偏离期望距离越远扣分越多，其次越近越好。
static func _cell_cost(cell: Vector2i, action_key: String, anchor: Vector2i, desired: int,
		unit: BattleUnit, players: Array, profile: AiProfile) -> int:
	var d := HexGrid.hex_distance(cell, anchor)
	var cost := absi(d - desired) * 1000 + d
	if action_key != "retreat":
		# 危险惩罚：谨慎型避免进入玩家相邻格
		var danger := _adjacent_player_count_at(cell, players)
		cost += int(danger * 70 * (profile.caution / 100.0))
	if action_key == "protect":
		# 护卫站位：围绕首领的同时靠近最近的玩家（阻挡）
		var nearest := AiTargetSelector.nearest_player_to(players, cell)
		if nearest != null:
			cost += HexGrid.hex_distance(cell, nearest.hex_coords) * 20
	return cost


## 某格相邻的存活玩家数（位置评价的危险惩罚）。
static func _adjacent_player_count_at(cell: Vector2i, players: Array) -> int:
	var count := 0
	for player in players:
		if player.current_hp <= 0:
			continue
		if HexGrid.hex_distance(cell, player.hex_coords) <= 1:
			count += 1
	return count


## 单位相邻的存活玩家数（撤退/危险评估）。
static func adjacent_player_count(unit: BattleUnit, players: Array) -> int:
	var count := 0
	for player in players:
		if player.current_hp <= 0:
			continue
		if HexGrid.hex_distance(unit.hex_coords, player.hex_coords) <= 1:
			count += 1
	return count


## 站位评分（兼容旧接口）：距离越接近期望站位越好（先满足期望距离，其次越近越好）。
static func position_cost(d: int, desired: int) -> int:
	return absi(d - desired) * 1000 + d
