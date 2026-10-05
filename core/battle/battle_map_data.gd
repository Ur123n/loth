class_name BattleMapData
extends Resource

## 战斗地图数据（逻辑层）。
## 按比例生成图格：普通:障碍:加减速:buff = 6:2:1:1
## （加减速合计 1 份，加速 / 减速各占一半；10x10 地图即 60/20/5/5/10）。

const TERRAIN_WEIGHTS := {
	TerrainData.TerrainType.NORMAL: 6.0,
	TerrainData.TerrainType.OBSTACLE: 2.0,
	TerrainData.TerrainType.SLOW: 0.5,
	TerrainData.TerrainType.HASTE: 0.5,
	TerrainData.TerrainType.BUFF: 1.0,
}

@export var cols: int = 10
@export var rows: int = 10
## 兼容旧场景保留 tile_size 名称；实际语义是六边形边长/外接圆半径。
@export var tile_size: float = HexGrid.DEFAULT_SIDE_LENGTH

var cells: Array[TerrainData] = []
var _rng: RandomNumberGenerator


func generate(seed_value: int = -1) -> void:
	_rng = RandomNumberGenerator.new()
	if seed_value >= 0:
		_rng.seed = seed_value
	cells.clear()

	var counts := _compute_counts(cols * rows)
	var types: Array = []
	for type in counts:
		for i in counts[type]:
			types.append(type)
	_shuffle(types)

	for type in types:
		cells.append(TerrainData.create(type))


func get_cell(col: int, row: int) -> TerrainData:
	return cells[row * cols + col]


func is_in_bounds(col: int, row: int) -> bool:
	return col >= 0 and col < cols and row >= 0 and row < rows


func is_passable(col: int, row: int) -> bool:
	if not is_in_bounds(col, row):
		return false
	return not get_cell(col, row).blocks_movement


## 随机找一个普通格作为队伍出生点（保证可通行且无特殊效果）。
func find_spawn_anchor() -> Vector2i:
	var candidates: Array[Vector2i] = []
	for row in rows:
		for col in cols:
			if get_cell(col, row).terrain_type == TerrainData.TerrainType.NORMAL:
				candidates.append(Vector2i(col, row))
	if candidates.is_empty():
		for row in rows:
			for col in cols:
				if is_passable(col, row):
					candidates.append(Vector2i(col, row))
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func grid_size() -> Vector2:
	var width := HexGrid.SQRT3 * tile_size * (cols + 0.5)
	var height := 1.5 * tile_size * (rows - 1) + 2.0 * tile_size
	return Vector2(width, height)


## —— 移动系统（逻辑层） ——
## 代价模型：从 A 走到 B 消耗 A 格（正在离开的格）的 leave_move_cost。

## 返回 { 可达格: 最小移动代价 }；障碍格与已被其他单位占据的格不可进入。
func compute_reachable(start: Vector2i, max_cost: int, occupied: Dictionary, moving_unit) -> Dictionary:
	var result := {}
	if not is_in_bounds(start.x, start.y):
		return result
	var dist := { start: 0 }
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		var current_cost: int = dist[current]
		for neighbor in HexGrid.neighbors(current.x, current.y):
			var step_cost := _step_cost_to(current, neighbor, occupied, moving_unit)
			if step_cost < 0:
				continue
			var new_cost := current_cost + step_cost
			if new_cost > max_cost:
				continue
			if not dist.has(neighbor) or new_cost < dist[neighbor]:
				dist[neighbor] = new_cost
				frontier.append(neighbor)
	for cell in dist:
		if cell != start:
			result[cell] = dist[cell]
	return result


## 在移动力预算内找起点到目标的路径。
## 返回 { "path": Array[Vector2i]（不含起点、含终点）, "cost": int }；不可达时 path 为空。
func find_movement_path(start: Vector2i, target: Vector2i, max_cost: int, occupied: Dictionary, moving_unit) -> Dictionary:
	var parent := {}
	var dist := { start: 0 }
	var frontier: Array[Vector2i] = [start]
	var found := false
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if current == target:
			found = true
			break
		var current_cost: int = dist[current]
		for neighbor in HexGrid.neighbors(current.x, current.y):
			var step_cost := _step_cost_to(current, neighbor, occupied, moving_unit)
			if step_cost < 0:
				continue
			var new_cost := current_cost + step_cost
			if new_cost > max_cost:
				continue
			if not dist.has(neighbor) or new_cost < dist[neighbor]:
				dist[neighbor] = new_cost
				parent[neighbor] = current
				frontier.append(neighbor)
	if not found:
		return { "path": [], "cost": 0 }
	var path: Array[Vector2i] = []
	var cursor := target
	while cursor != start:
		path.push_front(cursor)
		cursor = parent[cursor]
	return { "path": path, "cost": dist[target] }


## 计算从 current 进入 neighbor 的移动代价；不可通行返回 -1。
func _step_cost_to(current: Vector2i, neighbor: Vector2i, occupied: Dictionary, moving_unit) -> int:
	if not is_in_bounds(neighbor.x, neighbor.y):
		return -1
	if occupied.has(neighbor) and occupied[neighbor] != moving_unit:
		return -1
	if get_cell(neighbor.x, neighbor.y).blocks_movement:
		return -1
	return get_cell(current.x, current.y).leave_move_cost


func _compute_counts(total: int) -> Dictionary:
	var total_weight := 0.0
	for weight in TERRAIN_WEIGHTS.values():
		total_weight += weight

	var counts := {}
	var remainders := {}
	var assigned := 0
	for type in TERRAIN_WEIGHTS:
		var exact: float = total * TERRAIN_WEIGHTS[type] / total_weight
		var count := int(floor(exact))
		counts[type] = count
		remainders[type] = exact - count
		assigned += count

	# 最大余数法补齐总数
	var keys := remainders.keys()
	keys.sort_custom(func(a, b): return remainders[a] > remainders[b])
	for type in keys:
		if assigned >= total:
			break
		counts[type] += 1
		assigned += 1
	return counts


func _shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp
