class_name CharacterData
extends Resource

## 角色基础数据（数据驱动）。
## 未来每个角色可由一个 .tres 资源定义，不再修改代码。

@export var character_name: String = "艾莉丝"
@export var path_name: String = ""              # 道途（空字符串表示未选择）
@export var level: int = 0
@export var exp: int = 0                        # 当前经验（战斗结算时获得）
@export var attribute_points: int = 0           # 升级获得的自由属性点（可在角色面板分配）

# 经验曲线：升到下一级所需经验 = EXP_BASE + (当前等级 - 1) * EXP_GROWTH
const EXP_BASE := 100
const EXP_GROWTH := 50

# 基础属性（见 GDD 第 6 节）
@export var strength: int = 10
@export var agility: int = 10
@export var endurance: int = 10
@export var willpower: int = 10

# 力量伤害补正：角色攻击伤害 = 攻击卡面板 * (1 + 力量伤害补正 * (力量 - 10))
@export var strength_damage_bonus: float = 0.0

# 生命值派生：基础生命值 + 耐力 * 耐力收益补正
@export var base_hp: int = 100
@export var endurance_hp_bonus: int = 5

# 美术资源接口（统一约定，均为 res:// 路径，留空则继续用色块/文本占位）：
# icon_path    头像/小图标（列表、队伍条等 UI 槽位）
# portrait_path 立绘（角色面板/详情大图）
# art_path     场景/战斗主体贴图
# animation_path 动画或动画场景资源（AnimatedSprite2D、AnimationPlayer 等）
# corpse_art_a_path / corpse_art_b_path 两种战斗尸骸主体贴图
@export var block_color: Color = Color(0.42, 0.60, 0.90)
@export var icon_path: String = ""
@export var portrait_path: String = ""
@export var art_path: String = ""
@export var animation_path: String = ""
@export var corpse_art_a_path: String = ""
@export var corpse_art_b_path: String = ""

# 技能库 / 装备 / 卡组（当前留空，预留接口）
@export var skill_library: Array[SkillData] = []
@export var equipment: Array[EquipmentData] = []
@export var deck: Array[CardData] = []


func get_corpse_art_paths() -> Array[String]:
	var paths: Array[String] = []
	if not corpse_art_a_path.is_empty():
		paths.append(corpse_art_a_path)
	if not corpse_art_b_path.is_empty():
		paths.append(corpse_art_b_path)
	return paths


func get_max_hp() -> int:
	return base_hp + get_effective_endurance() * endurance_hp_bonus + get_equipment_mod_total("max_hp")


func get_path_display() -> String:
	if path_name.is_empty():
		return "未选择"
	return path_name


## 道途数据（接口）：按 path_name 从 PathDB 查找，未设置道途返回 null。
## 注意：不能命名为 get_path()（与 Resource 原生方法冲突）。
func get_path_data() -> PathData:
	if path_name.is_empty():
		return null
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		var db := (tree as SceneTree).root.get_node_or_null("PathDB")
		if db != null:
			return db.get_path_data(path_name)
	return null


## 基础被动（接口）：未设置道途或无被动时返回 null。
func get_passive() -> PassiveData:
	var path_data := get_path_data()
	return path_data.passive if path_data != null else null


## 道途专属初始牌卡名列表（接口）。
func get_starter_card_names() -> Array[String]:
	var path_data := get_path_data()
	return path_data.starter_cards if path_data != null else []


## 升到下一级所需经验（按当前等级计算）。
func exp_to_next_level() -> int:
	return EXP_BASE + (level - 1) * EXP_GROWTH


## 获得经验；经验满自动升级：等级 +1，并获得 1 点可自由分配的属性点。
## 返回本次升级次数（经验溢出继续累计）。
func gain_exp(amount: int) -> int:
	var levels := 0
	exp += maxi(amount, 0)
	while exp >= exp_to_next_level():
		exp -= exp_to_next_level()
		level += 1
		attribute_points += 1
		levels += 1
	return levels


## 消耗 1 点自由属性点分配属性；成功返回 true。
func allocate_attribute(stat: String) -> bool:
	if attribute_points <= 0:
		return false
	match stat:
		"力量":
			strength += 1
		"敏捷":
			agility += 1
		"耐力":
			endurance += 1
		"意志力":
			willpower += 1
		_:
			return false
	attribute_points -= 1
	return true


## 力量对攻击伤害的倍率（浮点，用于展示/参考）。
func get_strength_damage_multiplier() -> float:
	var basis := float(get_strength_damage_basis())
	return basis / 100.0


## 力量伤害基数（整数百分比）：100 表示 ×1.0。
## 伤害计算全程使用整数：面板 * 基数 / 100，再按攻防方向取整。
## 装备「攻击伤害 ±%」修正在此乘算（GDD：装备改变卡牌效果）。
func get_strength_damage_basis() -> int:
	var basis := 100 + int(round(strength_damage_bonus * 100.0)) * (get_effective_strength() - 10)
	var pct := get_equipment_mod_total("attack_damage_pct")
	if pct != 0:
		basis = maxi(1, int(round(basis * (100 + pct) / 100.0)))
	return basis


# ============================================================
# 装备（有舍有得）
# ============================================================

## 合并后属性：基础值 + 装备修正（得与舍叠加）。
func get_effective_strength() -> int:
	return strength + get_equipment_mod_total("stat", "力量")


func get_effective_agility() -> int:
	return agility + get_equipment_mod_total("stat", "敏捷")


func get_effective_endurance() -> int:
	return endurance + get_equipment_mod_total("stat", "耐力")


func get_effective_willpower() -> int:
	return willpower + get_equipment_mod_total("stat", "意志力")


## 卡牌荷载容量：GDD「意志力 = 卡牌荷载容量」，再叠加装备修正。
func get_effective_load_capacity() -> int:
	return get_effective_willpower() + get_equipment_mod_total("load_capacity")


## 当前已穿装备中某类型修正总和。
func get_equipment_mod_total(mod_type: String, stat_name := "") -> int:
	var total := 0
	for equip in equipment:
		if equip is EquipmentData:
			total += equip.get_mod_total(mod_type, stat_name)
	return total


## 某槽位已穿装备（无则 null）。
func get_equipped_in_slot(slot_name: String) -> EquipmentData:
	for equip in equipment:
		if equip is EquipmentData and equip.slot == slot_name:
			return equip
	return null


## 穿装备：槽位非法或已被占用时返回 false。
func equip_equipment(equip: EquipmentData) -> bool:
	if equip == null or not EquipmentData.SLOT_NAMES.has(equip.slot):
		return false
	if get_equipped_in_slot(equip.slot) != null:
		return false
	equipment.append(equip)
	return true


## 按名称穿装备（从 EquipDB 查）；成功返回 true。
func equip_by_name(equip_name: String) -> bool:
	var db := _get_equip_db()
	if db == null:
		return false
	var equip: EquipmentData = db.get_equipment(equip_name)
	return equip_equipment(equip)


## 卸下某槽位装备；返回被卸下的装备（该槽为空则 null）。
func unequip_slot(slot_name: String) -> EquipmentData:
	for i in equipment.size():
		if equipment[i] is EquipmentData and equipment[i].slot == slot_name:
			return equipment.pop_at(i)
	return null


## EquipDB 自动加载（无头脚本模式可能缺失，返回 null 由调用方兜底）。
func _get_equip_db() -> Node:
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		return (tree as SceneTree).root.get_node_or_null("EquipDB")
	return null
