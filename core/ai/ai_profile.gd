class_name AiProfile
extends Resource

## 敌怪 AI 行为档案（《敌怪ai逻辑.txt》第 4 节 AIProfile）。
##
## 统一行为倾向参数：
##   Aggression（进攻性）/ Support（支援性）/ Caution（谨慎）/ Mobility（机动性）
##   / Defensiveness（防守性）/ TargetPriority（目标优先级）/ PreferredRange（理想距离）。
## 这些参数只影响 Utility 评分，不直接规定敌怪“必须”采取某种行为；
## 狂战士与祭司即使共用同一框架，也能因参数不同产生截然不同的打法。
##
## 数据来源优先级：
##   content/enemies/*.json 的 ai_profile 覆盖（Excel「AI参数」列同步）
##   > archetype 模板（「行为模板」列）> 小队角色推导 > 旧 ai 字段 > 默认士兵。

## 目标优先级常量（第 21 节 Target Preference）。
const PRIORITY_NEAREST := "nearest"          # 最近
const PRIORITY_LOWEST_HP := "lowest_hp"      # 低生命
const PRIORITY_HIGHEST_THREAT := "highest_threat"  # 高威胁
const PRIORITY_ISOLATED := "isolated"        # 孤立
const PRIORITY_BACKLINE := "backline"        # 后排（高威胁 + 孤立）
const PRIORITY_KILLABLE := "killable"        # 可击杀
const PRIORITY_BALANCED := "balanced"        # 均衡（多因素综合）

@export var archetype_name: String = ""
@export var aggression: int = 50             # 0-100 进攻性：提升攻击/接近评分
@export var support: int = 30                # 0-100 支援性：提升治疗/保护/强化倾向
@export var caution: int = 50                # 0-100 谨慎：提升撤退/危险回避
@export var mobility: int = 50               # 0-100 机动性：提升移动/站位追求
@export var defensiveness: int = 30          # 0-100 防守性：提升自保/保护站位
@export var target_priority: String = PRIORITY_BALANCED  # 目标选择偏好
@export var preferred_range: int = 1         # 理想距离（格）；-1 = 攻击范围边缘（风筝）
@export var intelligence: int = 50           # 0-100 智力（决策深度预留）

# 角色职责 / 特殊规则（与评分参数分离，由模板或小队角色决定）
@export var protects_leader: bool = false    # 保护本队首领（护卫）
@export var protects_wounded: bool = false   # 贴近受伤友军（支援）
@export var chases: bool = true              # 追击低生命目标
@export var never_retreats: bool = false     # 永不撤退
@export var is_boss: bool = false            # Boss：允许半血狂暴等专属规则
@export var inert: bool = false              # 无 AI（木桩等）


## 内置模板表（第 4 节示例参数落地的 9 个行为模板）。
## preferred_range = -1 表示取攻击范围边缘（风筝型）。
const ARCHETYPES := {
	"士兵": {
		"aggression": 60, "support": 15, "caution": 40, "mobility": 55, "defensiveness": 30,
		"target_priority": PRIORITY_LOWEST_HP, "preferred_range": 1, "chases": true,
	},
	"狂战士": {
		"aggression": 90, "support": 0, "caution": 10, "mobility": 70, "defensiveness": 10,
		"target_priority": PRIORITY_LOWEST_HP, "preferred_range": 1,
		"chases": true, "never_retreats": true,
	},
	"鲁莽": {
		"aggression": 95, "support": 0, "caution": 5, "mobility": 85, "defensiveness": 5,
		"target_priority": PRIORITY_KILLABLE, "preferred_range": 1,
		"chases": true, "never_retreats": true,
	},
	"猎人": {
		"aggression": 55, "support": 10, "caution": 65, "mobility": 75, "defensiveness": 55,
		"target_priority": PRIORITY_LOWEST_HP, "preferred_range": -1, "chases": false,
	},
	"刺客": {
		"aggression": 80, "support": 0, "caution": 45, "mobility": 100, "defensiveness": 25,
		"target_priority": PRIORITY_BACKLINE, "preferred_range": 2, "chases": false,
	},
	"护卫": {
		"aggression": 45, "support": 40, "caution": 55, "mobility": 45, "defensiveness": 90,
		"target_priority": PRIORITY_NEAREST, "preferred_range": 1,
		"protects_leader": true, "chases": false, "never_retreats": true,
	},
	"支援": {
		"aggression": 25, "support": 100, "caution": 65, "mobility": 40, "defensiveness": 80,
		"target_priority": PRIORITY_NEAREST, "preferred_range": 1,
		"protects_wounded": true, "chases": false,
	},
	"首领": {
		"aggression": 95, "support": 20, "caution": 5, "mobility": 55, "defensiveness": 30,
		"target_priority": PRIORITY_BALANCED, "preferred_range": 1,
		"chases": true, "never_retreats": true, "is_boss": true,
	},
	"木桩": {
		"aggression": 0, "support": 0, "caution": 0, "mobility": 0, "defensiveness": 0,
		"target_priority": PRIORITY_NEAREST, "preferred_range": 1, "inert": true,
	},
}

## 小队角色 → 行为模板（敌怪未显式配置 archetype 时按角色推导）。
const ROLE_TO_ARCHETYPE := {
	"前排": "士兵",
	"近战": "狂战士",
	"远程": "猎人",
	"护卫": "护卫",
	"侧翼": "刺客",
	"炮灰": "鲁莽",
	"首领": "首领",
}


## 解析敌怪的行为档案：显式 archetype > 小队角色 > 旧 ai 字段 > 默认士兵，
## 最后叠加敌怪数据中的 ai_profile 覆盖参数。
static func resolve(enemy_data, pack_role: String) -> AiProfile:
	var key := _resolve_key(enemy_data, pack_role)
	var profile := from_key(key)
	if enemy_data != null and "ai_profile" in enemy_data:
		var overrides = enemy_data.ai_profile
		if overrides is Dictionary and not overrides.is_empty():
			profile.apply_overrides(overrides)
	return profile


static func _resolve_key(enemy_data, pack_role: String) -> String:
	var key := ""
	if enemy_data != null and not str(enemy_data.archetype).is_empty():
		key = str(enemy_data.archetype)
	elif ROLE_TO_ARCHETYPE.has(pack_role):
		key = ROLE_TO_ARCHETYPE[pack_role]
	elif enemy_data != null:
		var ai_mode := str(enemy_data.ai_mode)
		if ai_mode == "远离":
			key = "猎人"
		elif ai_mode == "靠近":
			key = "士兵"
		elif ai_mode == "无":
			key = "木桩"
	if not ARCHETYPES.has(key):
		key = "士兵"
	return key


## 从模板键创建实例。
static func from_key(key: String) -> AiProfile:
	var profile := AiProfile.new()
	profile.archetype_name = key
	profile.apply_data(ARCHETYPES.get(key, ARCHETYPES["士兵"]))
	return profile


## 应用模板字典（模板字段均存在时生效）。
func apply_data(data: Dictionary) -> void:
	if data.has("aggression"):
		aggression = int(data["aggression"])
	if data.has("support"):
		support = int(data["support"])
	if data.has("caution"):
		caution = int(data["caution"])
	if data.has("mobility"):
		mobility = int(data["mobility"])
	if data.has("defensiveness"):
		defensiveness = int(data["defensiveness"])
	if data.has("target_priority"):
		target_priority = str(data["target_priority"])
	if data.has("preferred_range"):
		preferred_range = int(data["preferred_range"])
	if data.has("intelligence"):
		intelligence = int(data["intelligence"])
	if data.has("protects_leader"):
		protects_leader = bool(data["protects_leader"])
	if data.has("protects_wounded"):
		protects_wounded = bool(data["protects_wounded"])
	if data.has("chases"):
		chases = bool(data["chases"])
	if data.has("never_retreats"):
		never_retreats = bool(data["never_retreats"])
	if data.has("is_boss"):
		is_boss = bool(data["is_boss"])
	if data.has("inert"):
		inert = bool(data["inert"])


## 应用敌怪数据中的 ai_profile 覆盖（只覆盖显式给出的参数）。
func apply_overrides(overrides: Dictionary) -> void:
	apply_data(overrides)


## 期望站位距离；preferred_range < 0（风筝）取攻击范围边缘。
func desired_distance_for(attack_range: int) -> int:
	if preferred_range < 0:
		return maxi(attack_range, 1)
	return preferred_range


## 兼容访问器：kites（风筝）由 preferred_range < 0 推导。
var kites: bool:
	get:
		return preferred_range < 0


## 兼容访问器：偏好低生命目标（第 21 节组合规则）。
var prefers_low_hp: bool:
	get:
		return target_priority in [PRIORITY_LOWEST_HP, PRIORITY_KILLABLE]


## 兼容访问器：偏好高威胁目标（后排猎杀）。
var prefers_high_threat: bool:
	get:
		return target_priority in [PRIORITY_HIGHEST_THREAT, PRIORITY_BACKLINE]


## 兼容访问器：偏好孤立目标。
var targets_isolated: bool:
	get:
		return target_priority in [PRIORITY_ISOLATED, PRIORITY_BACKLINE]


## 兼容访问器：保护欲 ≈ 支援性。
var protectiveness: int:
	get:
		return support


## 一行性格说明（调试面板用）。
func describe() -> String:
	if inert:
		return "无 AI（%s）" % archetype_name
	var traits: Array[String] = []
	if aggression >= 80:
		traits.append("进攻性强")
	if support >= 70:
		traits.append("支援倾向")
	if caution >= 60:
		traits.append("谨慎")
	if mobility >= 75:
		traits.append("机动")
	if defensiveness >= 75:
		traits.append("防守")
	if protects_leader:
		traits.append("守护首领")
	if protects_wounded:
		traits.append("支援友军")
	if kites:
		traits.append("保持距离")
	if targets_isolated:
		traits.append("猎杀孤立目标")
	if never_retreats:
		traits.append("不撤退")
	if is_boss:
		traits.append("Boss 规则")
	return "；".join(traits) if not traits.is_empty() else "均衡"
