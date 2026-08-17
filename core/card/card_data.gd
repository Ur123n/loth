class_name CardData
extends Resource

## 卡牌数据（遵循 GDD 第 8 节 + 分类扩展）。
## 所有卡牌数据驱动；逻辑链效果见 res://core/effect/logic_chains/。

enum CardCategory { GENERIC, PATH }     # 通用卡牌 / 道途专属卡牌
enum CardType { ACTION, ATTACK, ABILITY }
enum TargetType { SELF, ALLY, ENEMY, HEX, AREA, NONE }

@export var category: CardCategory = CardCategory.GENERIC
@export var path_name: String = ""       # 道途专属卡牌所属道途（空表示未指定）
@export var card_name: String = ""
@export var card_type: CardType = CardType.ATTACK
@export var cost: int = 0
@export var load: int = 1
@export var target_type: TargetType = TargetType.NONE
@export var range: int = 1
@export var area: int = 0
@export var icon_path: String = ""     # 图标相对路径（相对 卡牌/ 目录，列表/槽位小图），未设置留空
@export var art_path: String = ""      # 卡面图相对路径（相对 卡牌/ 目录），未设置留空
@export var animation_path: String = "" # 动画/特效资源路径（相对 卡牌/ 目录），未设置留空
@export var description: String = ""   # 附加说明（兜底卡使用，正常卡由效果生成）
@export var effects: Array[Resource] = []   # 组件化效果（AttackEffect / MoveEffect / DefenseEffect / BuffEffect / ...）

## 卡牌关键词：
## - 消耗 / 保留 / 虚无 / 固有：基础四词条；
## - 沉梦 / 幻梦 / 灾梦：梦魇行者梦境链（本场战斗依次打出沉梦牌→幻梦牌后解锁灾梦牌）；
## - 衍生：由其他牌生成/衍生的牌（如 小刀），不进入战斗结束后的卡牌奖励池。
@export var exhaust_on_play: bool = false   # 消耗
@export var retain: bool = false            # 保留
@export var ethereal: bool = false          # 虚无
@export var innate: bool = false            # 固有
@export var dream: bool = false             # 沉梦
@export var phantom: bool = false           # 幻梦
@export var doom_dream: bool = false        # 灾梦
@export var derived: bool = false           # 衍生
@export var lifesteal: bool = false         # 吸血：攻击造成伤害后恢复等量生命


## 能力牌打出后自动消失，不进入弃牌堆（GDD 第 7 节）。
## 这是底层逻辑，编辑器不要求手动配置。
func is_consumed_on_play() -> bool:
	return card_type == CardType.ABILITY


## 打出后是否进入消耗堆（能力牌自动消耗，或配置了“消耗”关键词）。
func should_exhaust_on_play() -> bool:
	return is_consumed_on_play() or exhaust_on_play


## 卡牌关键词中文标签（用于描述/手牌角标），顺序固定。
func keyword_labels() -> Array[String]:
	var labels: Array[String] = []
	if exhaust_on_play:
		labels.append("消耗")
	if retain:
		labels.append("保留")
	if ethereal:
		labels.append("虚无")
	if innate:
		labels.append("固有")
	if dream:
		labels.append("沉梦")
	if phantom:
		labels.append("幻梦")
	if doom_dream:
		labels.append("灾梦")
	if derived:
		labels.append("衍生")
	if lifesteal:
		labels.append("吸血")
	return labels
