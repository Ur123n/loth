class_name ItemData
extends Resource

## 物品数据（数据驱动，由 编辑器/物品创建.xlsx 同步生成）。
## 战利品/背包物品：拥有名称、描述、体积（形状）、价值与美术接口。

@export var item_name: String = ""
@export var description: String = ""
## 体积形状：1x1 / 2x1 / 1x2 / 3x1 / 2x2 / L
@export var shape: String = "1x1"
@export var value: int = 0        # 价值（出售价/参考价）
@export var icon_path: String = ""          # 图标（背包/战利品小图），res:// 路径
@export var art_path: String = ""           # 主体贴图（res://，留空则用色块/文本）
@export var animation_path: String = ""     # 动画/特效资源（res://）


## 形状对应的格子偏移（左上角为原点，每格一个 Vector2i）。
func shape_cells() -> Array[Vector2i]:
	match shape:
		"2x1":
			return [Vector2i(0, 0), Vector2i(1, 0)]
		"1x2":
			return [Vector2i(0, 0), Vector2i(0, 1)]
		"3x1":
			return [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
		"2x2":
			return [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
		"L":
			return [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]
	return [Vector2i(0, 0)]


## 形状说明（悬停提示用）。
func shape_label() -> String:
	match shape:
		"2x1":
			return "2x1 横条"
		"1x2":
			return "1x2 竖条"
		"3x1":
			return "3x1 长条"
		"2x2":
			return "2x2 方块"
		"L":
			return "L 形"
	return "1x1 单格"
