class_name AiArchetype
extends Resource

## 敌怪行为模板（AI 性格）。
## 对应《敌人 AI 重构方案》的 Archetype 层：每类敌人一套性格参数，
## 由 EnemyAI 决策引擎消费（目标选择 / 行动评分 / 位置评价）。
## 数据来源优先级：content/enemies/*.json 的 archetype 字段（Excel 同步）
## > 小队角色推导（前排/近战/远程/护卫/侧翼/炮灰/首领）> 旧 ai 字段 > 默认士兵。

@export var archetype_name: String = ""
@export var desired_distance: int = 1     # 期望站位距离（格）；-1 = 攻击范围边缘（风筝）
@export var aggression: int = 50          # 0-100 进攻性：影响攻击/接近评分
@export var caution: int = 50             # 0-100 谨慎：影响撤退/危险回避
@export var protectiveness: int = 30      # 0-100 保护欲：护卫/支援行为强度
@export var intelligence: int = 50        # 0-100 智力（暂用于说明，可扩展决策深度）
@export var prefers_low_hp: bool = false  # 偏好集火低生命目标
@export var prefers_high_threat: bool = false  # 偏好高威胁目标（后排）
@export var targets_isolated: bool = false     # 偏好孤立目标
@export var protects_leader: bool = false      # 保护本队首领
@export var protects_wounded: bool = false     # 贴近受伤友军（支援）
@export var kites: bool = false                # 风筝：贴脸先拉开、保持射程边缘
@export var chases: bool = true                # 追击低生命目标
@export var never_retreats: bool = false       # 永不撤退
@export var is_boss: bool = false              # Boss：拥有专属规则（半血狂暴等）
@export var inert: bool = false                # 无 AI（木桩等）


## 内置模板表。desired_distance = -1 表示取攻击范围边缘。
const ARCHETYPES := {
	"士兵": {
		"desired_distance": 1, "aggression": 60, "caution": 40, "protectiveness": 25,
		"intelligence": 50, "prefers_low_hp": true, "chases": true,
	},
	"狂战士": {
		"desired_distance": 1, "aggression": 90, "caution": 10, "protectiveness": 10,
		"intelligence": 30, "prefers_low_hp": true, "chases": true, "never_retreats": true,
	},
	"鲁莽": {
		"desired_distance": 1, "aggression": 95, "caution": 5, "protectiveness": 5,
		"intelligence": 20, "prefers_low_hp": true, "chases": true, "never_retreats": true,
	},
	"猎人": {
		"desired_distance": -1, "aggression": 55, "caution": 65, "protectiveness": 20,
		"intelligence": 70, "prefers_low_hp": true, "kites": true, "chases": false,
	},
	"刺客": {
		"desired_distance": 2, "aggression": 75, "caution": 45, "protectiveness": 15,
		"intelligence": 75, "prefers_high_threat": true, "targets_isolated": true,
		"kites": false, "chases": false,
	},
	"护卫": {
		"desired_distance": 1, "aggression": 50, "caution": 55, "protectiveness": 90,
		"intelligence": 60, "protects_leader": true, "chases": false, "never_retreats": true,
	},
	"支援": {
		"desired_distance": 1, "aggression": 25, "caution": 60, "protectiveness": 90,
		"intelligence": 80, "protects_wounded": true, "chases": false,
	},
	"首领": {
		"desired_distance": 1, "aggression": 95, "caution": 5, "protectiveness": 40,
		"intelligence": 90, "prefers_low_hp": true, "prefers_high_threat": true,
		"chases": true, "never_retreats": true, "is_boss": true,
	},
	"木桩": {
		"desired_distance": 0, "aggression": 0, "caution": 0, "protectiveness": 0,
		"intelligence": 0, "inert": true,
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


## 解析敌怪的行为模板：显式 archetype > 小队角色 > 旧 ai 字段 > 默认士兵。
static func resolve(enemy_data, pack_role: String) -> AiArchetype:
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
	return from_key(key)


## 从模板键创建实例。
static func from_key(key: String) -> AiArchetype:
	var arch := AiArchetype.new()
	arch.archetype_name = key
	var data: Dictionary = ARCHETYPES.get(key, ARCHETYPES["士兵"])
	arch.desired_distance = int(data.get("desired_distance", 1))
	arch.aggression = int(data.get("aggression", 50))
	arch.caution = int(data.get("caution", 50))
	arch.protectiveness = int(data.get("protectiveness", 30))
	arch.intelligence = int(data.get("intelligence", 50))
	arch.prefers_low_hp = bool(data.get("prefers_low_hp", false))
	arch.prefers_high_threat = bool(data.get("prefers_high_threat", false))
	arch.targets_isolated = bool(data.get("targets_isolated", false))
	arch.protects_leader = bool(data.get("protects_leader", false))
	arch.protects_wounded = bool(data.get("protects_wounded", false))
	arch.kites = bool(data.get("kites", false))
	arch.chases = bool(data.get("chases", true))
	arch.never_retreats = bool(data.get("never_retreats", false))
	arch.is_boss = bool(data.get("is_boss", false))
	arch.inert = bool(data.get("inert", false))
	return arch


## 期望站位距离；-1（风筝）取攻击范围边缘。
func desired_distance_for(attack_range: int) -> int:
	if desired_distance < 0:
		return maxi(attack_range, 1)
	return desired_distance


## 一行性格说明（调试面板用）。
func describe() -> String:
	if inert:
		return "无 AI（%s）" % archetype_name
	var traits: Array[String] = []
	if aggression >= 80:
		traits.append("进攻性强")
	if caution >= 60:
		traits.append("谨慎")
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
