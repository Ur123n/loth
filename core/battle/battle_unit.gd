class_name BattleUnit
extends Node2D

## 战斗地图上的单位。
## 玩家单位持有 CharacterData；敌怪单位持有 EnemyData（血量/伤害/攻击距离/移动力/AI）。
## 战斗中维护手牌 / 抽牌堆 / 弃牌堆 / 费用 / 生命 / 格挡 / buff。
## 格挡（block_value）：护盾与格挡已统一为单一数值；防御卡/「预格挡」等来源获得，
## 轮次开始时自动清空，先于生命抵消“受到伤害”。
## 任意单位死亡后原地变为尸骸（无行动、原名、血量=原上限/3 向下取整），尸骸血量清零后消失。
## 美术接口：数据类统一提供 icon_path / art_path / animation_path / corpse_art_a_path / corpse_art_b_path；
## 主体贴图 art_path 非空且存在时经 ArtLoader 加载，替代色块占位。

@export var character_data: CharacterData
@export var enemy_data: EnemyData = null

const MAX_MOVE_POINTS := 3

var hex_coords: Vector2i = Vector2i(-1, -1)
var remaining_move_points: int = MAX_MOVE_POINTS
var is_enemy: bool = false
var is_corpse: bool = false
var is_removed: bool = false
var corpse_max_hp: int = 0

# 战斗状态
var hand: Array[CardData] = []
var draw_pile: Array[CardData] = []
var discard_pile: Array[CardData] = []
var exhaust_pile: Array[CardData] = []   # 消耗堆：打出即消耗/虚无/能力牌进入，本场战斗不移回
var moved_this_turn: bool = false        # 本回合是否移动过（条件效果：夹击/坚守）
var flank_trigger_damage: int = 0        # 伺机：本回合离开攻击范围时造成伤害
var pending_knockback: int = 0           # 击退：本回合下一次攻击命中后推开敌人格数
var dream_progress: int = 0              # 梦境链进度：0 未开始 / 1 已出沉梦 / 2 已出幻梦（解锁灾梦）
var redesign_dream_enabled: bool = false
var redesign_dream_state: int = 0         # 重制三梦：0 沉梦 / 1 幻梦
var last_played_card: CardData = null    # 上一张打出的牌（幻梦联动判断）
var tags_played_on_targets: Dictionary = {}  # 本回合成功打出的目标牌标签：instance_id -> Array[String]
var played_cards_this_turn: Array[CardData] = []  # 本行动已成功结算的牌；供标签/类型条件复用
var played_card_ids_in_battle: Dictionary = {}  # 本场已打出的卡牌 ID；用于检索候选
var direct_hp_loss_targets: Dictionary = {}  # 本回合由自己的牌令其直接失去生命的目标 instance_id -> true
var bled_this_turn: bool = false
var pack_id: String = ""                 # 所属敌怪小队（空=散兵，无协同）
var pack_role: String = ""               # 小队角色：前排/近战/远程/护卫/侧翼/炮灰/首领
var pack_leader: BattleUnit = null       # 护卫对象（本队首领单位，同一小队共享）
var energy: int = 0
var current_hp: int = 100
var block_value: int = 0      # 格挡（护盾/格挡已统一，轮次开始清空）
var buffs: Array = []   # 占位：{"name": String, "duration": int, "value": int, "data": BuffData}

var _visual: CharacterVisual
var _name_label: Label
var _hp_label: Label
var _block_label: Label


## 配置为敌怪：血量在范围内随机生成。
func configure_enemy(data: EnemyData) -> void:
	enemy_data = data
	is_enemy = true
	current_hp = data.get_random_hp()
	block_value = 0


## 原地变为尸骸：退出行动与存活判定，保留原名，血量 = 原上限 / 3（向下取整，至少 1）。
func become_corpse() -> void:
	if is_corpse or is_removed:
		return
	var original_max := get_max_hp_value()
	is_corpse = true
	corpse_max_hp = maxi(1, original_max / 3)
	current_hp = corpse_max_hp
	block_value = 0
	buffs.clear()
	if _visual != null:
		_apply_corpse_visual()
	refresh_hp_display()
	refresh_block_display()


## 尸骸血量清零后从场上移除（视觉隐藏）。
func remove_corpse() -> void:
	is_removed = true
	visible = false


func get_display_name() -> String:
	if is_enemy:
		return enemy_data.enemy_name if enemy_data != null else "敌怪"
	return character_data.character_name if character_data != null else "角色"


func get_max_hp_value() -> int:
	if is_corpse:
		return corpse_max_hp
	if is_enemy:
		return enemy_data.hp_max if enemy_data != null else 100
	return character_data.get_max_hp() if character_data != null else 100


func get_agility() -> int:
	if is_enemy:
		return enemy_data.agility if enemy_data != null else 5
	# 合并后敏捷（基础 + 装备修正）
	return character_data.get_effective_agility() if character_data != null else 10


## 装备「行动值」修正（独立于敏捷，直接叠加到行动值）。
func get_initiative_bonus() -> int:
	if is_enemy or character_data == null:
		return 0
	return character_data.get_equipment_mod_total("initiative")


func get_max_move_points() -> int:
	if is_enemy:
		return enemy_data.move_points if enemy_data != null else 1
	var passive := character_data.get_passive() if character_data != null else null
	var base := MAX_MOVE_POINTS
	if passive != null and passive.passive_name == "孢子怪力":
		base = 2
	var equip_bonus := character_data.get_equipment_mod_total("move_points") if character_data != null else 0
	return maxi(base + equip_bonus, 1)


func get_attack_range() -> int:
	if is_enemy:
		return enemy_data.attack_range if enemy_data != null else 1
	# 玩家基础攻击范围 1 + 装备修正（长枪等）
	return maxi(1 + get_attack_range_bonus(), 1)


## 装备「攻击范围」修正（卡牌目标射程 max(card.range, 效果范围) 之上叠加）。
func get_attack_range_bonus() -> int:
	if is_enemy or character_data == null:
		return 0
	return character_data.get_equipment_mod_total("attack_range")


func get_attack_damage() -> int:
	if is_enemy and enemy_data != null:
		return enemy_data.get_random_attack_damage()
	return 0


func refresh_hp_display() -> void:
	if _hp_label != null:
		_hp_label.text = "HP %d/%d" % [current_hp, get_max_hp_value()]


func refresh_block_display() -> void:
	if _block_label == null:
		return
	if block_value > 0:
		_block_label.text = "格挡 %d" % block_value
		_block_label.visible = true
	else:
		_block_label.visible = false


## 美术接口：art_path 非空且存在时用贴图替代色块。
## 应用主体贴图：经 ArtLoader 统一加载；返回是否成功。
func _apply_art_texture(art_path: String) -> bool:
	var texture := ArtLoader.load_texture(art_path)
	if texture != null:
		_visual.set_texture(texture)
		return true
	return false


func _corpse_art_paths() -> Array[String]:
	if is_enemy and enemy_data != null:
		return enemy_data.get_corpse_art_paths()
	if not is_enemy and character_data != null:
		return character_data.get_corpse_art_paths()
	return []


## 同一个单位在同一格始终选中同一版本；首选资源失效时按稳定顺序尝试其余版本。
func _apply_corpse_visual() -> void:
	var paths := _corpse_art_paths()
	if not paths.is_empty():
		var signature := "%s:%d:%d" % [get_display_name(), hex_coords.x, hex_coords.y]
		var first_index := absi(signature.hash()) % paths.size()
		for offset in paths.size():
			if _apply_art_texture(paths[(first_index + offset) % paths.size()]):
				return
	_visual.show_corpse_placeholder()


func _ready() -> void:
	_visual = CharacterVisual.new()
	_visual.block_size = Vector2(28, 28)
	if is_enemy:
		_visual.placeholder_color = enemy_data.block_color if enemy_data != null else Color(0.72, 0.53, 0.33)
	else:
		_visual.placeholder_color = character_data.block_color if character_data != null else Color(0.9, 0.9, 0.9)
	add_child(_visual)
	if is_enemy:
		_apply_art_texture(enemy_data.art_path if enemy_data != null else "")
	else:
		_apply_art_texture(character_data.art_path if character_data != null else "")

	_name_label = Label.new()
	_name_label.position = Vector2(-40, -44)
	_name_label.size = Vector2(80, 18)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 12)
	_name_label.add_theme_color_override("font_color", Color(0.90, 0.92, 0.96))
	_name_label.text = get_display_name()
	add_child(_name_label)

	_block_label = Label.new()
	_block_label.name = "BlockLabel"
	_block_label.position = Vector2(-40, -26)
	_block_label.size = Vector2(80, 16)
	_block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_block_label.add_theme_font_size_override("font_size", 11)
	_block_label.add_theme_color_override("font_color", Color(0.62, 0.85, 1.0))
	_block_label.visible = false
	add_child(_block_label)

	_hp_label = Label.new()
	_hp_label.name = "HPLabel"
	_hp_label.position = Vector2(-40, 12)
	_hp_label.size = Vector2(80, 16)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.add_theme_font_size_override("font_size", 11)
	if is_enemy:
		_hp_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	else:
		_hp_label.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	add_child(_hp_label)
	refresh_hp_display()
