class_name BuildingMask
extends RefCounted

## 大型建筑「逻辑掩码」规范与几何工具（正方形网格，1 像素 = 1 格）。
##
## 掩码是**视觉与逻辑分离**的落点：主视觉 PNG 随便怎么改都不影响逻辑，
## 逻辑只认这里定义的 5 张掩码。全部是 PNG，宽高 = 建筑 footprint 的格数，
## 一个像素对应一格，**不透明 = 该格属于这张掩码**。
##
## | 文件 | 含义 | 约束 |
## | --- | --- | --- |
## | `masks/occupancy.png` | 建筑占用哪些格（含墙、含院内） | 其它掩码都必须 ⊆ 它 |
## | `masks/walkable.png` | 占用区里哪些格可以走（室内地板 / 院子） | ⊆ occupancy，与 collision 不相交 |
## | `masks/collision.png` | 占用区里哪些格是实体（墙、柱子、水面） | ⊆ occupancy，与 walkable 不相交 |
## | `masks/occlusion.png` | 哪些格会被建筑**遮挡**（屋顶挑檐压住的可通行格） | ⊆ occupancy；用于进出建筑时收屋顶 |
## | `masks/doors.png` | 门 / 入口所在格 | ⊆ walkable ∩ occupancy |
##
## `doors.png` 是唯一带颜色语义的掩码：颜色 = 门朝外的方向（见 `DOOR_SIDE_COLORS`）。
## 坐标系统一为**建筑局部格坐标**：左上角为 (0,0)，x 向东、y 向南，单位是格；
## 换算见 `BuildingData.cell_to_local_px()` / `local_px_to_cell()`。

const MASK_OCCUPANCY := "occupancy"
const MASK_WALKABLE := "walkable"
const MASK_COLLISION := "collision"
const MASK_OCCLUSION := "occlusion"
const MASK_DOORS := "doors"
## 顺序 = 生成顺序 = 校验清单顺序。
const MASK_NAMES: Array[String] = [
	MASK_OCCUPANCY, MASK_WALKABLE, MASK_COLLISION, MASK_OCCLUSION, MASK_DOORS,
]
## 走「有/无」语义的掩码（doors 另有颜色语义）。
const BINARY_MASKS: Array[String] = [
	MASK_OCCUPANCY, MASK_WALKABLE, MASK_COLLISION, MASK_OCCLUSION,
]

const ON := Color(1, 1, 1, 1)
const OFF := Color(0, 0, 0, 0)
## 门掩码的颜色 = 门朝外的方向。n = 北（y-1），s = 南（y+1），e = 东（x+1），w = 西（x-1）。
const DOOR_SIDE_COLORS := {
	"n": Color8(90, 160, 255),
	"s": Color8(255, 140, 60),
	"e": Color8(120, 220, 120),
	"w": Color8(220, 120, 255),
}
const DOOR_SIDES: Array[String] = ["n", "s", "e", "w"]


## 门掩码颜色 → 朝向名；不匹配返回空串。
static func side_from_color(color: Color) -> String:
	for side in DOOR_SIDES:
		var expected: Color = DOOR_SIDE_COLORS[side]
		if absf(color.r - expected.r) < 0.02 and absf(color.g - expected.g) < 0.02 \
				and absf(color.b - expected.b) < 0.02:
			return side
	return ""


## 一张全空掩码底图。
static func new_image(size: Vector2i) -> Image:
	var image := Image.create(maxi(1, size.x), maxi(1, size.y), false, Image.FORMAT_RGBA8)
	image.fill(OFF)
	return image


## 把格集合写进掩码图：binary 掩码一律写白色；doors 按 side 取色（side 缺失用白色）。
static func write_cells(image: Image, cells: Dictionary, mask_name: String = MASK_OCCUPANCY,
		sides: Dictionary = {}) -> void:
	for cell in cells:
		var color := ON
		if mask_name == MASK_DOORS:
			var side := String(sides.get(cell, ""))
			color = DOOR_SIDE_COLORS.get(side, ON)
		image.set_pixel(cell.x, cell.y, color)


## 读出掩码图里所有"不透明"的格（阈值取 alpha > 0.5）。
static func read_cells(image: Image) -> Dictionary:
	var cells := {}
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.5:
				cells[Vector2i(x, y)] = true
	return cells


## 稀疏格集合 → 紧凑游程编码 `[[y, x起, 长度], …]`（按行、x 升序，行内合并连续格）。
## metadata 里存的就是这个：69×73 的建筑只有几百条，Agent 读起来毫无压力。
static func runs_from_cells(cells: Dictionary) -> Array:
	var by_row := {}
	for cell in cells:
		if not by_row.has(cell.y):
			by_row[cell.y] = []
		by_row[cell.y].append(cell.x)
	var runs: Array = []
	var rows: Array = by_row.keys()
	rows.sort()
	for y_key in rows:
		var y: int = int(y_key)
		var xs: Array = by_row[y]
		xs.sort()
		var start: int = xs[0]
		var previous: int = xs[0]
		for i in range(1, xs.size()):
			var x: int = xs[i]
			if x == previous + 1:
				previous = x
				continue
			runs.append([y, start, previous - start + 1])
			start = x
			previous = x
		runs.append([y, start, previous - start + 1])
	return runs


## 游程编码 → 稀疏格集合。
static func cells_from_runs(runs: Array) -> Dictionary:
	var cells := {}
	for entry in runs:
		if typeof(entry) != TYPE_ARRAY or entry.size() < 3:
			continue
		var y := int(entry[0])
		var x0 := int(entry[1])
		var length := int(entry[2])
		for i in length:
			cells[Vector2i(x0 + i, y)] = true
	return cells


## 贪心矩形分解：把格集合拆成尽量少的轴对齐矩形（碰撞体用）。
## 返回 `[Rect2i, …]`；同一集合的分解结果确定（可复现）。
static func greedy_rects(cells: Dictionary) -> Array:
	var remaining := cells.duplicate()
	var rows: Array = []
	var by_row := {}
	for cell in remaining:
		if not by_row.has(cell.y):
			by_row[cell.y] = []
		by_row[cell.y].append(cell.x)
	for y_key in by_row:
		var xs: Array = by_row[y_key]
		xs.sort()
		rows.append(int(y_key))
	rows.sort()

	var rects: Array = []
	for y_key in rows:
		var y: int = int(y_key)
		var xs: Array = by_row[y]
		xs.sort()
		var i := 0
		while i < xs.size():
			var x: int = xs[i]
			var origin := Vector2i(x, y)
			if not remaining.has(origin):
				i += 1
				continue
			# 向右扩
			var width := 1
			while remaining.has(Vector2i(x + width, y)):
				width += 1
			# 向下扩：整行都得还在
			var height := 1
			while true:
				var next_y: int = y + height
				var full := true
				for dx in width:
					if not remaining.has(Vector2i(x + dx, next_y)):
						full = false
						break
				if not full:
					break
				height += 1
			for dy in height:
				for dx in width:
					remaining.erase(Vector2i(x + dx, y + dy))
			rects.append(Rect2i(origin, Vector2i(width, height)))
			i += 1
	return rects


## 把所有格向外扩 `ring` 圈（8 邻域切比雪夫距离）。
static func grow(cells: Dictionary, ring: int) -> Dictionary:
	if ring <= 0:
		return cells.duplicate()
	var out := {}
	for cell in cells:
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				out[Vector2i(cell.x + dx, cell.y + dy)] = true
	return out


## 格集合的包围盒；空集合返回 `Rect2i()`。
static func bounds(cells: Dictionary) -> Rect2i:
	if cells.is_empty():
		return Rect2i()
	var min_x := 1 << 30
	var min_y := 1 << 30
	var max_x := -(1 << 30)
	var max_y := -(1 << 30)
	for cell in cells:
		min_x = mini(min_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_x = maxi(max_x, cell.x)
		max_y = maxi(max_y, cell.y)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


## 把格集合整体平移。
static func offset_cells(cells: Dictionary, delta: Vector2i) -> Dictionary:
	var out := {}
	for cell in cells:
		out[cell + delta] = true
	return out


## 集合差 a - b。
static func subtract(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := {}
	for cell in a:
		if not b.has(cell):
			out[cell] = true
	return out


## 集合交 a ∩ b。
static func intersect(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := {}
	for cell in a:
		if b.has(cell):
			out[cell] = true
	return out


## 集合并 a ∪ b。
static func union(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	for cell in b:
		out[cell] = true
	return out
