class_name TerrainData
extends Resource

## 六边形图格数据（遵循 GDD 第 19 节）。
## 每种图格：类型、是否阻挡进入、离开该格所需移动力、站上时给予的 buff 占位。

enum TerrainType { NORMAL, OBSTACLE, SLOW, HASTE, BUFF }

@export var terrain_type: TerrainType = TerrainType.NORMAL
@export var display_name: String = "普通"
@export var blocks_movement: bool = false
@export var leave_move_cost: int = 1
@export var buff_name: String = ""
@export var color: Color = Color(0.36, 0.42, 0.34)


static func create(type: TerrainType) -> TerrainData:
	var data := TerrainData.new()
	data.terrain_type = type
	match type:
		TerrainType.NORMAL:
			data.display_name = "普通"
			data.leave_move_cost = 1
			data.color = Color(0.36, 0.42, 0.34)
		TerrainType.OBSTACLE:
			data.display_name = "障碍"
			data.blocks_movement = true
			data.leave_move_cost = 0
			data.color = Color(0.30, 0.27, 0.24)
		TerrainType.SLOW:
			data.display_name = "减速"
			data.leave_move_cost = 2
			data.color = Color(0.32, 0.48, 0.72)
		TerrainType.HASTE:
			data.display_name = "加速"
			data.leave_move_cost = 0
			data.color = Color(0.85, 0.74, 0.30)
		TerrainType.BUFF:
			data.display_name = "buff"
			data.leave_move_cost = 1
			data.buff_name = "buff_占位"
			data.color = Color(0.60, 0.38, 0.78)
	return data
