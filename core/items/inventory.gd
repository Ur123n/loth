class_name Inventory
extends RefCounted

## 背包逻辑层：固定宽高网格 + 多页（滚轮翻页）。
## 物品按“体积”占格（1x1 / 2x1 / 1x2 / 3x1 / 2x2 / L），
## 放置时校验是否越界/重叠，提供首个空位查找（first-fit）。

const GRID_COLS := 8
const GRID_ROWS := 6
const PAGE_COUNT := 4

## 已放置物品：{"item": ItemData, "page": int, "x": int, "y": int}
var items: Array[Dictionary] = []


func clear() -> void:
	items.clear()


func cols() -> int:
	return GRID_COLS


func rows() -> int:
	return GRID_ROWS


func page_count() -> int:
	return PAGE_COUNT


## 指定位置（页面内左上角）能否放置该物品。
func can_place(item: ItemData, page: int, x: int, y: int) -> bool:
	if item == null:
		return false
	for cell in item.shape_cells():
		var gx := x + cell.x
		var gy := y + cell.y
		if gx < 0 or gy < 0 or gx >= GRID_COLS or gy >= GRID_ROWS:
			return false
		if _occupied(page, gx, gy):
			return false
	return true


## 放置物品；成功返回 true。
func place(item: ItemData, page: int, x: int, y: int) -> bool:
	if not can_place(item, page, x, y):
		return false
	items.append({"item": item, "page": page, "x": x, "y": y})
	return true


## 从第一页开始寻找能容纳该物品的首个空位。
## 返回 {"found": bool, "page": int, "x": int, "y": int}。
func find_free_spot(item: ItemData) -> Dictionary:
	if item == null:
		return {"found": false}
	for page in PAGE_COUNT:
		for y in GRID_ROWS:
			for x in GRID_COLS:
				if can_place(item, page, x, y):
					return {"found": true, "page": page, "x": x, "y": y}
	return {"found": false}


## 移除某页某格（左上角）上的物品；返回被移除的物品或 null。
func remove_at(page: int, x: int, y: int) -> ItemData:
	for i in items.size():
		var entry := items[i]
		if int(entry.get("page", -1)) == page and int(entry.get("x", -1)) == x \
				and int(entry.get("y", -1)) == y:
			items.remove_at(i)
			return entry.get("item")
	return null


## 某页某格是否被物品占用（返回占用该格的物品，无则 null）。
func item_at(page: int, x: int, y: int) -> ItemData:
	for entry in items:
		if int(entry.get("page", -1)) != page:
			continue
		var item: ItemData = entry.get("item")
		for cell in item.shape_cells():
			if int(entry.get("x", 0)) + cell.x == x and int(entry.get("y", 0)) + cell.y == y:
				return item
	return null


## 占用的格子总数（含多格物品的全部格子）。
func used_cell_count() -> int:
	var count := 0
	for entry in items:
		var item: ItemData = entry.get("item")
		count += item.shape_cells().size()
	return count


func total_cell_count() -> int:
	return GRID_COLS * GRID_ROWS * PAGE_COUNT


## 存档序列化。
func serialize() -> Array:
	var result: Array = []
	for entry in items:
		result.append({
			"name": entry.get("item").item_name,
			"page": int(entry.get("page", 0)),
			"x": int(entry.get("x", 0)),
			"y": int(entry.get("y", 0)),
		})
	return result


## 读档还原。
func deserialize(saved: Array) -> void:
	items.clear()
	if not saved is Array:
		return
	for entry in saved:
		if not entry is Dictionary:
			continue
		var item := _lookup_item(str(entry.get("name", "")))
		if item == null:
			continue
		items.append({
			"item": item,
			"page": int(entry.get("page", 0)),
			"x": int(entry.get("x", 0)),
			"y": int(entry.get("y", 0)),
		})


## 读档时按名称查物品库（无头脚本模式自动加载可能缺失，返回 null 则跳过该条）。
func _lookup_item(item_name: String) -> ItemData:
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		var db := (tree as SceneTree).root.get_node_or_null("ItemDB")
		if db != null:
			return db.get_item(item_name)
	return null


func _occupied(page: int, gx: int, gy: int) -> bool:
	return item_at(page, gx, gy) != null
