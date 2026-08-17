class_name PathData
extends Resource

## 道途数据（数据驱动，由 编辑器/道途创建.xlsx 同步生成）。
## 道途 = 角色成长方向：专属初始牌（starter_cards）+ 基础被动（passive）。
## 后续扩展接口：专属装备、道途专属事件、技能树等字段在此追加。

@export var path_name: String = ""
@export var character_name: String = ""     # 归属角色（展示用）
@export var description: String = ""
@export var passive: PassiveData = null     # 基础被动
@export var starter_cards: Array[String] = []   # 专属初始牌（卡牌库中的卡名）
@export var icon_path: String = ""          # 图标（列表/面板小图），res:// 路径
@export var art_path: String = ""           # 主体贴图（res://，留空则用色块/文本）
@export var animation_path: String = ""     # 动画/特效资源（res://）


## 专属初始牌是否包含某张卡。
func has_starter_card(card_name: String) -> bool:
	return starter_cards.has(card_name)
