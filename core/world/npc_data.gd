class_name NpcData
extends Resource

## NPC 数据（数据驱动，由 编辑器/NPC创建.xlsx 同步生成）。

@export var npc_name: String = ""
@export var description: String = ""
@export var block_color: Color = Color(0.36, 0.48, 0.63)
@export var icon_path: String = ""            # 图标（NPC 列表小图），res:// 路径
@export var art_path: String = ""             # 主体贴图（res://，留空则用色块）
@export var animation_path: String = ""       # 动画/动画场景资源（res://）
@export var ai_mode: String = ""              # AI 行为（待机/巡逻 等，占位）
@export var interaction_options: Array[String] = []   # 互动选项列表
@export var dialogue: Array = []              # 对话树（节点列表，JSON 解析）
