class_name EquipmentData
extends Resource

## 装备数据。根据 GDD 第 14 节：装备不能只是数值提升，应改变卡牌效果/战斗机制/道途方向。
## 本项目落地为“有舍有得”的机制修正：每件装备携带 mods 修正列表，
## 既有收益（正修正）也有代价（负修正），穿戴后叠加到角色合并属性与战斗计算。

@export var equipment_name: String = ""
@export var slot: String = ""       # 部位：头部/身体/腿部/足部/首饰1/首饰2/左手武器/右手武器
@export var description: String = ""
@export var icon_path: String = ""          # 图标（背包/装备栏槽位小图），res:// 路径
@export var art_path: String = ""           # 主体贴图（res://，留空则用文本/占位）
@export var animation_path: String = ""     # 动画/特效资源（res://）

## 修正列表：[{"type": String, "value": int, "stat": String(可选)}]
## 正 value = 收益（得），负 value = 代价（舍）。
## type 支持：
## - stat                属性修正（stat 取 力量/敏捷/耐力/意志力）
## - max_hp              生命上限（HP 派生）
## - initiative          行动值（行动顺序）
## - load_capacity       卡牌荷载容量（意志力派生）
## - move_points         每回合移动力
## - attack_range        攻击范围（卡牌目标射程）
## - attack_damage_pct   攻击伤害 ±%（卡牌效果）
## - defend_bonus        防御卡获得格挡 ±N（卡牌效果）
## - draw_modifier       每回合抽牌 ±N（战斗机制）
## - energy_modifier     每回合费用 ±N（战斗机制）
## - block_on_turn_start 回合开始获得 N 格挡（战斗机制）
@export var mods: Array[Dictionary] = []

const SLOT_NAMES := ["头部", "身体", "腿部", "足部", "首饰1", "首饰2", "左手武器", "右手武器"]
const STAT_NAMES := ["力量", "敏捷", "耐力", "意志力"]


## 某类型修正总和；stat 类型需传属性名，其余类型忽略。
func get_mod_total(mod_type: String, stat_name := "") -> int:
	var total := 0
	for mod in mods:
		if str(mod.get("type", "")) != mod_type:
			continue
		if mod_type == "stat" and str(mod.get("stat", "")) != stat_name:
			continue
		total += int(mod.get("value", 0))
	return total


## 是否有收益（至少一条正修正）。
func has_benefit() -> bool:
	for mod in mods:
		if int(mod.get("value", 0)) > 0:
			return true
	return false


## 是否有代价（至少一条负修正）。
func has_cost() -> bool:
	for mod in mods:
		if int(mod.get("value", 0)) < 0:
			return true
	return false


## 收益说明（得）。
func benefit_lines() -> Array[String]:
	var lines: Array[String] = []
	for mod in mods:
		if int(mod.get("value", 0)) > 0:
			lines.append(_mod_label(mod))
	return lines


## 代价说明（舍）。
func cost_lines() -> Array[String]:
	var lines: Array[String] = []
	for mod in mods:
		if int(mod.get("value", 0)) < 0:
			lines.append(_mod_label(mod))
	return lines


## 修正的人话描述（面板/悬停提示用）。
func _mod_label(mod: Dictionary) -> String:
	var value := int(mod.get("value", 0))
	var sign := "+" if value > 0 else ""
	match str(mod.get("type", "")):
		"stat":
			return "%s %s%d" % [str(mod.get("stat", "")), sign, value]
		"max_hp":
			return "生命上限 %s%d" % [sign, value]
		"initiative":
			return "行动值 %s%d" % [sign, value]
		"load_capacity":
			return "荷载容量 %s%d" % [sign, value]
		"move_points":
			return "移动力 %s%d" % [sign, value]
		"attack_range":
			return "攻击范围 %s%d" % [sign, value]
		"attack_damage_pct":
			return "攻击伤害 %s%d%%" % [sign, value]
		"defend_bonus":
			return "防御卡格挡 %s%d" % [sign, value]
		"draw_modifier":
			return "每回合抽牌 %s%d" % [sign, value]
		"energy_modifier":
			return "每回合费用 %s%d" % [sign, value]
		"block_on_turn_start":
			return "回合开始获得 %d 格挡" % value
	return "%s %s%d" % [str(mod.get("type", "未知")), sign, value]
