class_name HexGrid
extends RefCounted

## 六边形网格数学工具（尖顶朝上 + odd-r 偏移坐标系）。
## 后续寻路 / 范围计算统一使用这里提供的方法。

const SQRT3 := 1.7320508075688772


static func hex_to_world(col: int, row: int, tile_size: float) -> Vector2:
	var x := tile_size * SQRT3 * (col + 0.5 * (row & 1))
	var y := tile_size * 1.5 * row
	return Vector2(x, y)


static func world_to_hex(point: Vector2, tile_size: float, cols: int, rows: int) -> Vector2i:
	# 像素 → 轴向坐标
	var q: float = (SQRT3 / 3.0 * point.x - 1.0 / 3.0 * point.y) / tile_size
	var r: float = (2.0 / 3.0 * point.y) / tile_size
	# 立方坐标取整
	var cube := _cube_round(q, -q - r, r)
	var row := cube.z
	var col := cube.x + (row - (row & 1)) / 2
	if col < 0 or col >= cols or row < 0 or row >= rows:
		return Vector2i(-1, -1)
	return Vector2i(col, row)


static func neighbors(col: int, row: int) -> Array[Vector2i]:
	if row & 1 == 0:
		return [
			Vector2i(col - 1, row - 1),
			Vector2i(col, row - 1),
			Vector2i(col - 1, row),
			Vector2i(col + 1, row),
			Vector2i(col - 1, row + 1),
			Vector2i(col, row + 1),
		]
	return [
		Vector2i(col, row - 1),
		Vector2i(col + 1, row - 1),
		Vector2i(col - 1, row),
		Vector2i(col + 1, row),
		Vector2i(col, row + 1),
		Vector2i(col + 1, row + 1),
	]


## 两格之间的六边形距离（格数）。
static func hex_distance(a: Vector2i, b: Vector2i) -> int:
	var a_cube := _offset_to_cube(a.x, a.y)
	var b_cube := _offset_to_cube(b.x, b.y)
	return (abs(a_cube.x - b_cube.x) + abs(a_cube.y - b_cube.y) + abs(a_cube.z - b_cube.z)) / 2


static func _offset_to_cube(col: int, row: int) -> Vector3i:
	var q := col - (row - (row & 1)) / 2
	var z := row
	return Vector3i(q, -q - z, z)


static func _cube_round(x: float, y: float, z: float) -> Vector3i:
	var rx := roundi(x)
	var ry := roundi(y)
	var rz := roundi(z)
	var x_diff := absf(rx - x)
	var y_diff := absf(ry - y)
	var z_diff := absf(rz - z)
	if x_diff > y_diff and x_diff > z_diff:
		rx = -ry - rz
	elif y_diff > z_diff:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector3i(rx, ry, rz)
