class_name EquipmentData
extends Resource

## 装备数据（预留）。根据 GDD，装备应改变卡牌效果/战斗机制/道途方向，
## 不仅仅是数值提升，后续在此扩展字段。

@export var equipment_name: String = ""
@export var slot: String = ""       # 部位：武器 / 防具 / 饰品 等
@export var description: String = ""
@export var icon_path: String = ""          # 图标（背包/装备栏槽位小图），res:// 路径
@export var art_path: String = ""           # 主体贴图（res://，留空则用文本/占位）
@export var animation_path: String = ""     # 动画/特效资源（res://）
