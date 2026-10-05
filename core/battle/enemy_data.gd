class_name EnemyData
extends Resource

## 敌怪数据（数据驱动，由 编辑器/敌怪创建.xlsx 同步生成）。

@export var enemy_name: String = ""
@export var hp_min: int = 100
@export var hp_max: int = 100
@export var attack_min: int = 0
@export var attack_max: int = 0
@export var attack_range: int = 1
@export var move_points: int = 0
@export var agility: int = 5
@export var ai_mode: String = "无"     # 无 / 靠近 / 远离
@export var archetype: String = ""     # 行为模板：士兵/狂战士/猎人/护卫/刺客/鲁莽/首领/支援/木桩（空=按小队角色推导）
## AIProfile 覆盖参数（content/enemies/*.json 的 ai_profile 列，JSON 对象字符串）。
## 空字典 = 完全按行为模板 / 小队角色推导；非空时只覆盖给出的参数。
@export var ai_profile: Dictionary = {}
## 技能集（ActionSet 预留，第 3/25 节）：敌怪通过数据定义可用 Action，而非独立 AI 脚本。
@export var skills: Array = []
@export var tier: String = "普通"      # 难度：普通 / 精英 / Boss
@export var coin_min: int = 0          # 战利品：钱币掉落下限
@export var coin_max: int = 0          # 战利品：钱币掉落上限
@export var exp: int = 0               # 战利品：战斗经验（全队共享）
## 战利品表：[{"item": String, "chance": int(1-100), "count": int}]
@export var loot_table: Array = []
@export var block_color: Color = Color(0.72, 0.53, 0.33)
@export var description: String = ""
@export var icon_path: String = ""          # 图标（敌怪列表/图鉴小图），res:// 路径
@export var art_path: String = ""           # 主体贴图（战斗表现），res:// 路径，留空则用色块
@export var animation_path: String = ""     # 动画/动画场景资源（res://）
@export var corpse_art_a_path: String = ""  # 尸骸 A 主体贴图（res://）
@export var corpse_art_b_path: String = ""  # 尸骸 B 主体贴图（res://）


func get_corpse_art_paths() -> Array[String]:
	var paths: Array[String] = []
	if not corpse_art_a_path.is_empty():
		paths.append(corpse_art_a_path)
	if not corpse_art_b_path.is_empty():
		paths.append(corpse_art_b_path)
	return paths


func get_random_hp() -> int:
	if hp_max <= hp_min:
		return hp_min
	return randi_range(hp_min, hp_max)


func get_random_attack_damage() -> int:
	if attack_max <= attack_min:
		return attack_min
	return randi_range(attack_min, attack_max)


## 战利品：随机钱币（coin_min..coin_max 闭区间）。
func roll_coins() -> int:
	if coin_max <= coin_min:
		return coin_min
	return randi_range(coin_min, coin_max)
