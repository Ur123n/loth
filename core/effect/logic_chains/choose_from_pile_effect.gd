class_name ChooseFromPileEffect
extends Resource

## 从实体牌区展示随机候选，等待玩家选择一张移到目标牌区顶部。
@export var source: String = "draw"
@export var sample_count: int = 3
@export var show_all: bool = false
@export var destination: String = "draw"
@export var position: String = "top"
@export var required_card_type: String = ""
@export var exclude_card_type: String = ""
@export var required_rarity: String = ""
@export var base_cost: int = -1
@export var required_tags: Array[String] = []
@export var played_in_battle: bool = false
@export var not_played_this_turn: bool = false
@export var exhaust_selected_on_play: bool = false
@export var selected_cost_override: int = -1
@export var selected_cost_reduction: int = 0
@export var grant_retain_selected: bool = false
@export var temporary_copy: bool = false
