class_name MapScene
extends Node2D

## 地图场景控制器：挂在「用 Godot 地图编辑器手工绘制」的地图场景根节点上
## （由 maps/godot/tools/make_map.gd 生成，也可手工新建后挂本脚本）。
##
## 约定（改动前先读 docs/world/map_pipeline.md）：
## - 图块层固定六层，名字与顺序不可改：地形 / 高差 / 建筑 / 装饰 / 植被 / 碰撞；
##   其中「碰撞」层在游戏里隐藏（visible=false），只用于放“没有美术的阻挡”。
## - 标记放在名为「标记」的 Node2D 容器下，用 Marker2D 摆位，**节点名就是标记 id**
##   （spawn / gate / battle_trigger / skill_light / story_trigger …）。
## - 阻挡判定：除「地形」外的图块层中 solid=true 的图块一律阻挡；
##   「碰撞」层里放了图块即阻挡；「地形」层没铺的格子视为不可通行（没画地面=走不过去）。
## - **大型建筑**（可选）挂在「建筑对象」Node2D 下，每座是一个 `Building`（core/building/building.gd）。
##   建筑**只对它占用的格**表态：占用区内以建筑自己的掩码为准（可走/阻挡），
##   占用区外照旧走上面那套图块规则。地图里没有「建筑对象」时行为与接入前一致。
##
## 职责边界：本脚本只回答“这张地图长什么样、哪儿能走、关键点在哪”，
## 不含玩法规则，坐标一律是**地图局部像素坐标**；缩放/摆在画面哪里由上层决定（见 core/world/main.gd）。

const LAYER_TERRAIN := "地形"
const LAYER_HEIGHT := "高差"
const LAYER_BUILDING := "建筑"
const LAYER_DECOR := "装饰"
const LAYER_VEGETATION := "植被"
const LAYER_COLLISION := "碰撞"

## 图层顺序 = 绘制顺序（先地形、最后碰撞），也是 validate() 的检查清单。
const LAYERS: Array[String] = [
	LAYER_TERRAIN, LAYER_HEIGHT, LAYER_BUILDING, LAYER_DECOR, LAYER_VEGETATION, LAYER_COLLISION,
]
## 参与自动阻挡判定的美术层（不含地形与碰撞层）。
const SOLID_ART_LAYERS: Array[String] = [LAYER_HEIGHT, LAYER_BUILDING, LAYER_DECOR, LAYER_VEGETATION]

const MARKER_ROOT := "标记"
const SOLID_KEY := "solid"
const DEFAULT_TILE_SIZE := 48
## 大型建筑容器：地图里的大型建筑都挂在这个 Node2D 下（见 docs/world/building_pipeline.md）。
## 地图没有这个容器时，按普通图块地图处理。
const BUILDING_ROOT := "建筑对象"
## 大图块（2×2 道具）只在起始格存 TileData：判断某格是否被挡住时要回看这四个可能的起始格。
const MULTI_CELL_ORIGIN_OFFSETS: Array[Vector2i] = [
	Vector2i.ZERO, Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1),
]

## 玩法必需的标记：缺任何一个都算地图未完成（validate() 会报）。
const REQUIRED_MARKERS: Array[String] = ["spawn", "battle_trigger", "story_trigger", "skill_light"]
## 地标标记（可选，供剧情/任务/UI 引用）。
const LANDMARK_MARKERS: Array[String] = ["gate", "church", "bell_tower", "cloister", "kitchen_garden", "herb_garden"]

@export var map_size_cells: Vector2i = Vector2i(40, 30)
## 地图在主场景里的显示倍率：48px 素材按 1 米/格设计，所以 1:1（=1.0）显示；
## 当前 48px 素材按 1 米/格设计，默认 1:1 显示。主场景读它来摆位与缩放（见 core/world/main.gd）。
@export var display_scale: float = 1.0
@export var spawn_marker_id: String = "spawn"
@export var auto_solid_from_art_layers: bool = true


func _ready() -> void:
	var collision := get_layer(LAYER_COLLISION)
	if collision != null:
		collision.visible = false   # 碰撞层只是数据，别在游戏里画出来


## 取指定图层；不存在返回 null。
func get_layer(layer_name: String) -> TileMapLayer:
	for child in get_children():
		if child is TileMapLayer and child.name == layer_name:
			return child
	return null


func get_tile_size() -> Vector2i:
	for layer_name in LAYERS:
		var layer := get_layer(layer_name)
		if layer != null and layer.tile_set != null:
			return layer.tile_set.tile_size
	return Vector2i(DEFAULT_TILE_SIZE, DEFAULT_TILE_SIZE)


## 地图尺寸（格）：声明值、实际铺过的范围、以及**大型建筑伸出去的范围**取最大者，
## 放一座比地图还大的建筑也不会被裁掉。
func get_map_size_cells() -> Vector2i:
	var size := map_size_cells
	for layer_name in LAYERS:
		var layer := get_layer(layer_name)
		if layer == null:
			continue
		var used := layer.get_used_rect()
		size.x = maxi(size.x, used.position.x + used.size.x)
		size.y = maxi(size.y, used.position.y + used.size.y)
	for building in get_buildings():
		var rect: Rect2i = building.call("get_map_footprint_rect")
		size.x = maxi(size.x, rect.position.x + rect.size.x)
		size.y = maxi(size.y, rect.position.y + rect.size.y)
	return size


## 地图局部像素矩形（原点为地图左上角）。
func get_map_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(get_map_size_cells()) * Vector2(get_tile_size()))


func get_marker(marker_id: String) -> Node2D:
	var root_node := get_node_or_null(NodePath(MARKER_ROOT))
	if root_node == null:
		return null
	var node := root_node.get_node_or_null(NodePath(marker_id))
	return node as Node2D


func has_marker(marker_id: String) -> bool:
	return get_marker(marker_id) != null


## 标记的地图局部像素坐标；缺失返回 Vector2.INF（调用方自行兜底）。
func get_marker_position(marker_id: String) -> Vector2:
	var marker := get_marker(marker_id)
	return marker.position if marker != null else Vector2.INF


## 出生点：spawn 标记；缺失时退回地图中心。
func get_spawn_position() -> Vector2:
	var pos := get_marker_position(spawn_marker_id)
	if pos == Vector2.INF:
		return get_map_rect().get_center()
	return pos


func get_all_marker_ids() -> PackedStringArray:
	var out := PackedStringArray()
	var root_node := get_node_or_null(NodePath(MARKER_ROOT))
	if root_node == null:
		return out
	for child in root_node.get_children():
		if child is Node2D:
			out.append(String(child.name))
	return out


func local_to_cell(local_position: Vector2) -> Vector2i:
	var tile := get_tile_size()
	return Vector2i(floori(local_position.x / tile.x), floori(local_position.y / tile.y))


## 格中心的地图局部像素坐标。
func cell_to_local(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * Vector2(get_tile_size())


func is_cell_inside(cell: Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO, get_map_size_cells()).has_point(cell)


# ---------------------------------------------------------------- 大型建筑接口

## 「建筑对象」容器；没有就返回 null。
func get_building_root() -> Node2D:
	return get_node_or_null(NodePath(BUILDING_ROOT)) as Node2D


## 地图里的全部大型建筑。判定标准：节点挂了 Building 脚本（有 get_building_data 方法）。
func get_buildings() -> Array:
	var out: Array = []
	var root_node := get_building_root()
	if root_node == null:
		return out
	for child in root_node.get_children():
		if child.has_method("get_building_data"):
			out.append(child)
	return out


## 某格属于哪座建筑（没有返回 null）。
func get_building_at(cell: Vector2i) -> Node:
	for building in get_buildings():
		if bool(building.call("covers_map_cell", cell)):
			return building
	return null


## 某格上的门（没有返回空字典）。
func get_door_at(cell: Vector2i) -> Dictionary:
	for building in get_buildings():
		if not bool(building.call("covers_map_cell", cell)):
			continue
		for door in building.call("get_door_map_cells"):
			var d: Dictionary = door
			var map_cell: Vector2i = d["map_cell"]
			if map_cell == cell:
				return d
	return {}


## 大型建筑自检（不并入 validate()，避免影响既有地图的通过标准）。
func validate_buildings() -> PackedStringArray:
	var issues := PackedStringArray()
	for building in get_buildings():
		var name_text := String(building.name)
		var data: Variant = building.call("get_building_data")
		if data == null:
			issues.append("建筑「%s」读不到 metadata" % name_text)
			continue
		var rect: Rect2i = building.call("get_map_footprint_rect")
		if rect.size.x <= 0 or rect.size.y <= 0:
			issues.append("建筑「%s」的地基尺寸非法：%s" % [name_text, str(rect)])
			continue
		# 门口外侧必须真的能走出去
		for door in building.call("get_door_map_cells"):
			var d: Dictionary = door
			var side := String(d.get("outward_side", "n"))
			var offset: Vector2i = {"n": Vector2i(0, -1), "s": Vector2i(0, 1), "e": Vector2i(1, 0), "w": Vector2i(-1, 0)}.get(side, Vector2i.ZERO)
			var door_cell: Vector2i = d["map_cell"]
			var outward: Vector2i = door_cell + offset
			if get_building_at(outward) != null:
				continue   # 通向另一座建筑（内门），不算问题
			if not is_cell_walkable(outward):
				issues.append("建筑「%s」的门「%s」外侧 %s 不可通行" % [
					name_text, String(d.get("id", "")), str(outward)])
	return issues


# ---------------------------------------------------------------- 通行判定

## 单格是否可通行。
## 顺序：地图边界 → **建筑占用区（建筑说了算）** → 地形层必须铺过 → 没有阻挡图块。
func is_cell_walkable(cell: Vector2i) -> bool:
	if not is_cell_inside(cell):
		return false
	var building := get_building_at(cell)
	if building != null:
		# 建筑占用区内由建筑自己裁定：可走 → 通过（不管地形铺没铺）；墙/实体 → 挡住
		return bool(building.call("judge_map_cell", cell))
	var terrain := get_layer(LAYER_TERRAIN)
	if terrain == null or terrain.get_cell_tile_data(cell) == null:
		return false   # 没画地面 = 走不过去
	var collision := get_layer(LAYER_COLLISION)
	if collision != null and _blocked_by_layer(collision, cell, false):
		return false
	if auto_solid_from_art_layers and _cell_has_solid_art(cell):
		return false
	return true


## 该格是否被某个图块挡住。`only_solid` = 只看 solid 图块（美术层）；false = 有图块就算挡（碰撞层）。
## 2×2 这类大图块只在"起始格"存 TileData，所以要看四个可能的起始格是否覆盖到本格。
func _blocked_by_layer(layer: TileMapLayer, cell: Vector2i, only_solid: bool) -> bool:
	for offset in MULTI_CELL_ORIGIN_OFFSETS:
		var origin := cell + offset
		var data := layer.get_cell_tile_data(origin)
		if data == null:
			continue
		if only_solid and not (data.has_custom_data(SOLID_KEY) and bool(data.get_custom_data(SOLID_KEY))):
			continue
		if not _tile_covers(layer, origin, cell):
			continue
		return true
	return false


## 起始格 origin 上的图块是否覆盖目标格（1×1 图块只覆盖自己；2×2 覆盖右下 2×2 区域）。
func _tile_covers(layer: TileMapLayer, origin: Vector2i, cell: Vector2i) -> bool:
	var source := layer.tile_set.get_source(layer.get_cell_source_id(origin)) as TileSetAtlasSource
	if source == null:
		return origin == cell
	var size := source.get_tile_size_in_atlas(layer.get_cell_atlas_coords(origin))
	return Rect2i(origin, size).has_point(cell)


func is_walkable(local_position: Vector2) -> bool:
	return is_cell_walkable(local_to_cell(local_position))


func _cell_has_solid_art(cell: Vector2i) -> bool:
	for layer_name in SOLID_ART_LAYERS:
		var layer := get_layer(layer_name)
		if layer == null or layer.tile_set == null:
			continue
		if _blocked_by_layer(layer, cell, true):
			return true
	return false


## 结构自检（编辑器/CI 用，不检查画得好不好）：
## 返回问题列表，空 = 通过。典型问题：缺图层、图层图块集不一致、缺必需标记、spawn 越界。
func validate() -> PackedStringArray:
	var issues := PackedStringArray()
	var tile_set: TileSet = null
	var tile_set_owner := ""
	for layer_name in LAYERS:
		var layer := get_layer(layer_name)
		if layer == null:
			issues.append("缺少图块层「%s」" % layer_name)
			continue
		if layer.tile_set == null:
			issues.append("图块层「%s」没有绑定 TileSet" % layer_name)
			continue
		if tile_set == null:
			tile_set = layer.tile_set
			tile_set_owner = layer_name
		elif layer.tile_set != tile_set:
			issues.append("图块层「%s」的 TileSet 与「%s」不一致（应共用同一个）" % [layer_name, tile_set_owner])
	var marker_root := get_node_or_null(NodePath(MARKER_ROOT))
	if marker_root == null:
		issues.append("缺少标记容器「%s」（Node2D）" % MARKER_ROOT)
	else:
		for marker_id in REQUIRED_MARKERS:
			if not has_marker(marker_id):
				issues.append("缺少必需标记「%s/%s」" % [MARKER_ROOT, marker_id])
	var spawn := get_spawn_position()
	if not get_map_rect().has_point(spawn):
		issues.append("spawn 标记 %s 落在地图外（地图 %s px）" % [str(spawn), str(get_map_rect().size)])
	return issues


## 玩法自检（在 validate() 之上）：出生点必须真的能站人。
func validate_spawn_walkable() -> PackedStringArray:
	var issues := PackedStringArray()
	if not is_walkable(get_spawn_position()):
		issues.append("spawn 标记 %s 不可通行（地形层没铺 / 被 solid 图块压住）" % str(get_spawn_position()))
	return issues
