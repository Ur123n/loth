class_name BattleMapView
extends Node2D

## 战斗地图表现层：把图格数据绘制为彩色六边形（美术占位）。

## 兼容旧接口保留 tile_size 名称；实际语义是六边形边长/外接圆半径。
var tile_size: float = HexGrid.DEFAULT_SIDE_LENGTH
var _reachable_overlays: Array[Polygon2D] = []


func build(map_data: BattleMapData) -> void:
	tile_size = map_data.tile_size
	for row in map_data.rows:
		for col in map_data.cols:
			var cell := map_data.get_cell(col, row)
			var pos := HexGrid.hex_to_world(col, row, map_data.tile_size)
			_add_hex(pos, Color(0.12, 0.13, 0.15), map_data.tile_size + 1.5)
			_add_hex(pos, cell.color, map_data.tile_size)


## 格坐标 → 地图世界坐标（考虑视图整体偏移）。
func hex_to_world(cell: Vector2i) -> Vector2:
	return position + HexGrid.hex_to_world(cell.x, cell.y, tile_size)


## 高亮当前角色在剩余移动力内可达的图格。
func set_reachable(reachable: Dictionary) -> void:
	for overlay in _reachable_overlays:
		overlay.queue_free()
	_reachable_overlays.clear()
	for cell in reachable:
		var poly := Polygon2D.new()
		poly.color = Color(0.85, 0.95, 1.0, 0.35)
		poly.polygon = _hex_points(tile_size - 5.0)
		poly.position = HexGrid.hex_to_world(cell.x, cell.y, tile_size)
		add_child(poly)
		_reachable_overlays.append(poly)


func _add_hex(center: Vector2, color: Color, radius: float) -> void:
	var poly := Polygon2D.new()
	poly.color = color
	poly.polygon = _hex_points(radius)
	poly.position = center
	add_child(poly)


func _hex_points(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in 6:
		var angle := deg_to_rad(90.0 - k * 60.0)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
