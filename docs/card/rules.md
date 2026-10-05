# Card 规则

## 1. 卡牌数据字段（content/cards/*.json）

| 字段 | 说明 |
| --- | --- |
| `id` / `name` | 唯一标识 / 卡牌名 |
| `category` | 通用卡牌 / 道途专属卡牌 |
| `path` | 道途名（道途专属卡填写，通用卡留空） |
| `card_type` | 攻击 / 行动 / 能力 |
| `cost` | 费用 |
| `load` | 荷载（受意志力限制，允许为 0） |
| `target_type` | Self / Ally / Enemy / Hex / Area / None |
| `min_range` / `range` | 最小 / 最大射程（六边形距离）；未填最小射程时按旧牌规则视为 1 |
| `area` | 区域 |
| `discard_on_use` | 是否打出后消失（能力牌自动 true） |
| `keywords` | 关键词数组（消耗/保留/虚无/固有/沉梦/幻梦/灾梦/衍生/吸血） |
| `icon` / `art` / `animation` | 美术接口（相对 content/cards/ 的路径，可空） |
| `character` / `rarity` / `tags` / `description` | 新卡组的角色、稀有度、设计标签与原文说明；这些字段不得替代实际效果结算 |
| `implementation_status` | `supported` 牌进入运行时；`design_only` 牌保留设计数据但 CardDB 不加载，直到效果完整实现 |
| `source_file` / `source_line` / `source_effect` | 重制卡牌的设计文档、行号与效果原文，用于逐牌核对 |
| `effects` | 效果数组（组件化，顺序即触发顺序） |
| `mechanism_ids` | 本牌引用的机制库 ID，按首次出现顺序记录；用于查找与复用，不改变结算顺序 |
| `hp_payment` | 出牌时必须支付的生命；支付后生命须大于 0，先于效果结算，且无视格挡 |
| `cost_rules` | 条件降费数组；每条满足时费用减 `amount`，可叠加且最低为 0，目标状态不因此消耗 |

> 兼容：旧版本使用 `art_path` 字段，CardDB 仍可读取。

重制 v1.0 的 300 张设计牌由 `dev/import_card_redesign_v1.py` 从根目录四份卡组文档生成。导入器只把完全匹配现有结算能力的效果标为 `supported`；其余牌的 `effects` 留空并标记 `design_only`。本轮卡面字段为空。

`content/cards/mechanics.json` 是重制牌的机制数据库：`effects` 提供可参数化的效果模板，`conditions` 和 `play_rules` 记录条件及出牌规则的语义、读取时机和实现位置。导入器按机制 ID 实例化效果并校验每张已实现牌的引用；设计稿牌只记录已落实的机制。扩展机制时先补齐该库及规则，再接入结算和卡牌模板。`mechanism_ids` 是溯源索引，实际结算仍读取 `effects`、`cost_rules` 等字段。

## 2. 关键词

- **消耗**：打出后进入消耗堆（本场战斗移除）；能力牌默认消耗
- **保留**：回合结束时不弃掉
- **虚无**：回合结束时若在手牌则被消耗
- **固有**：战斗开始时直接在手牌
- **沉梦 / 幻梦 / 灾梦**：本场依次打出沉梦牌 → 幻梦牌后解锁灾梦牌（未解锁无法打出）
- **衍生**：由其他牌生成/衍生的牌，不进入战斗结束后的卡牌奖励池
- **吸血**：攻击造成伤害后恢复等量生命（被格挡抵消的部分不回复）

## 3. 逻辑链效果（effects）

| 逻辑 | 参数 |
| --- | --- |
| 攻击 `attack` | value、attack_range（可带 pierce 无视格挡、alt_value 本回合移动过则替换） |
| 攻击替换条件 | `alt_condition` 默认 `moved_this_turn`；可设 `bloodlet_this_turn`，成功支付放血牌的生命后本行动内为真 |
| 移动 `move` | distance、target（self/ally，默认 self）；给予对象本行动可使用的额外移动距离 |
| 防御 `defense` | value（可带 alt_value） |
| 防御目标 | `defense` 可带 target=`self` / `ally`，友军格挡结算到所选目标 |
| 直接治疗 `heal` | value、target=`self` / `ally`，不超过目标生命上限 |
| 给予buff `buff` | target（self/ally/enemy）、buff_type、duration（可带 stacks 初始层数） |
| 立即正常结算状态 `trigger_buff` | target（self/enemy）、buff_type；按该状态既有触发与衰减规则结算一次，仅作用于指定状态 |
| 切换梦态 `set_dream_state` | state（0 沉梦 / 1 幻梦）；立即更改重制三梦状态 |
| 抽牌 `draw` | value |
| 弃牌 `discard` | value、mode（random/all） |
| 加入手牌 `add_to_hand` | card、value |
| 加入抽牌堆 `add_to_draw` | card、value、position（shuffle/top） |
| 加入弃牌堆 `add_to_discard` | card、value |
| 生成牌 `generate` | card 或 pool（攻击/行动/能力/全部）、value、pile（hand/draw/discard） |
| 复制 `copy` | value、pile（默认 discard） |
| 失去生命 `lose_hp` | value、target（self/enemy），无视格挡；可用 `value_from_target_buff_stacks` 指定状态名，结算时以目标当前层数替代 value，不触发该状态正常结算或衰减 |
| 获得费用 `gain_energy` | value |
| 伺机反打 `flank` | value：离开攻击范围时造成伤害 |
| 击退 `knockback` | value：下一次攻击推开目标格数 |

一张卡可以有多个效果，effects 数组顺序即结算顺序。

“造成 N 伤害 M 次”由 M 个顺序执行的 `attack` 效果表示。每段单独经过伤害和格挡结算；目标在某段后倒下或变为尸骸时不再执行后续段。复合状态按文字顺序分别施加，各自使用对应的 BuffData。

## 4. 条件判断（condition）

任意效果可挂条件：满足才结算，不满足跳过（不影响后续效果）。
JSON：`{"logic":"attack", ..., "condition":{"type":"敌人数量在攻击范围内","count":2,"negate":false}}`。
条件类型记录在 content/cards/conditions.json，支持：敌人数量在攻击范围内 / 本回合已移动 / 本回合未移动 / 生命低于百分比 / 手牌不少于 / 费用不少于 / 自身持有buff / 场上敌人不少于 / 上一张牌带词条（可取反）。

重制数据另使用 `hp_at_most_pct`：当前生命小于或等于指定百分比时生效，边界值包含 50%。

重制三梦牌可用 `redesign_dream_state_is` 效果条件（`state=0` 为沉梦，`state=1` 为幻梦）。它读取效果结算时的当前梦态；牌面写“若处于沉梦”时由此决定分支。

`redesign_dream_state_at_play_is` 读取本牌开始结算时的梦态，适用于同牌先切换梦态、后续效果仍需按切换前状态判断的情况。

目标状态条件可使用 `target_has_buff_at_play`（指定 `buff_name`）与 `target_has_any_debuff_at_play`。两者读取本张牌开始结算时的目标状态快照，牌内前序效果新施加的状态不计入；目标未指定时条件不满足。`target_lost_direct_hp_this_turn` 也可用于效果条件，按出牌者本回合对当前目标的直接失血记录判断。

友军条件支持 `target_moved_this_turn`，仅检查当前所选友军；`caster_target_adjacent` 在效果结算时检查出牌者与所选目标的六边形距离恰好为 1。`adjacent_enemies_at_least` 统计与出牌者距离恰好为 1 且仍存活的敌人。条件的参数和实现位置记录于机制数据库。

`played_card_tags_this_turn` 判断出牌者本行动此前已成功打出的卡牌：`tag` 为必需标签，`other_tag` 可指定第二标签，`card_type` 可限定为 `Attack`；`distinct=1` 要求两个标签来自不同次出牌。当前牌在效果结算完成后才记入历史，失败出牌不计入；结束行动和战斗重置时清空。`target_hp_at_most_pct` 用所选目标当前生命与其生命上限比较，包含边界值；无有效目标时不满足。

`target_buff_stacks_at_least` 除精密降费外也可用于效果条件，按目标当前状态层数与 `stacks` 阈值比较。条件分支分别挂到效果上，取反时走低于阈值分支；目标无状态视为 0 层。

精密降费支持 `target_has_buff`、`target_buff_stacks_at_least` 和 `used_tag_on_target_this_turn`。最后一项只记录本回合对同一单位成功打出的牌的标签；在该角色下次行动开始前清空。本回合每次出牌按实际目标计算费用，出牌前完成目标、费用与生命支付校验，失败时不改变手牌或资源。

新增 `target_lost_direct_hp_this_turn` 与 `caster_moved_this_turn` 两类降费条件。前者仅在出牌者的卡牌效果令该目标实际直接失去至少 1 生命时记录；普通攻击伤害、被格挡的攻击和出牌者自身的生命支付不计入。记录在出牌者行动结束时清空，按目标分别保存。

鲍德温放血牌的生命支付成功后记录 `bloodlet_this_turn`，用于条件攻击数值；其他失去生命来源不触发，行动结束清空。

`played_card_tags_this_turn` 也可用于条件降费，读取此前成功打出的标签卡牌；出牌前完成费用校验，当前牌不为自己触发降费。攻击后推动目标使用已有 `knockback` 组件：伤害结算完毕后，战斗地图尝试沿远离攻击者的方向移动目标；若目标已倒下，不推动并清除该次待结算推动。

## 5. 卡组规则

**卡组**是角色携带进入战斗的卡牌实体清单，存于 `CharacterData.deck`；开战时复制这些牌，洗成有序的战斗抽牌堆。卡组、抽牌堆、弃牌堆、手牌是四个不同概念。**牌库**是角色在战斗之外已获得的全部卡牌，存于 `CharacterData.skill_library`，按卡名从 CardDB 还原牌的完整效果；牌库不等于 CardDB 的全局可获得卡池。角色初始持有的基础牌也属于牌库。战斗中从卡组或牌库展示候选时，只读取持久数据，选中后另建战斗牌实体，战斗结算不会移走或改变角色持久数据。

重制三梦卡使用 `dream_mode=three_dreams`：开战处于沉梦；幻梦牌结算前进入幻梦；灾梦牌仅在幻梦中可打出，结算后回到沉梦。处于幻梦时，直接攻击伤害无视格挡；若在沉梦结束行动，获得 3 格挡。旧版梦境链没有此标记，继续走原规则。

重制牌文本里的 Armor 使用当前战斗系统的格挡值。`target_block_at_play_at_least` 与 `target_block_at_play_at_most` 在本牌任一效果结算前记录目标格挡，并用同一快照判断后续效果；本牌前段攻击消耗的格挡不改变该条件。没有有效单位目标时条件为假。`threshold` 为整数，边界值计入满足条件。

卡牌的“移动最多 N 格”通过增加本行动可用移动力执行，玩家随后在地图上选择合法路径；同张牌的“移动前与敌人相邻”在授予移动力时按当前站位判定。攻击或施术后的“之后移动”同样授予可用移动力；推动目标在该牌效果结算后由战斗地图执行，不会替玩家自动选择移动路径。

`play_conditions` 是出牌前的硬性条件：先验证目标与条件，再计算费用和支付生命；失败时手牌、费用、生命与效果均不变化。条件使用机制数据库的同一求值器，可用 `negate` 反转。目标生命百分比按当前生命和最大生命比较，恰好达到阈值时允许出牌。

`transfer_random_card` 从指定牌区的合法实体牌中等概率抽取，移到目标牌区；合法候选为空时保持牌区不变。抽牌堆以数组末尾为牌顶，`position=top` 会把选中牌放到末尾；排除 Power 时按基础卡牌类型过滤。`mulligan_hand` 在本牌已离开手牌后，把其余全部手牌洗入抽牌堆，再抽取相同张数；被抽到的可以是刚洗入的原手牌，仍受手牌上限约束。

`choose_from_pile` 先按基础类型、基础费用、标签及出牌记录过滤指定抽牌堆或弃牌堆的实体牌，再从合格实体中无放回随机展示至多 `sample_count` 张。`required_tags` 任一命中即可；`played_in_battle` 要求本场曾打出同 ID 的牌；`not_played_this_turn` 排除本行动已打出同 ID 的牌。玩家选中的实体牌移至抽牌堆顶或加入手牌；未选牌保持原位置和顺序。抽牌堆顶部是数组末尾，候选不足时全部展示，空候选时效果直接结束。`exhaust_selected_on_play` 使选中牌下一次打出后消耗，不改动数据库原型或其他同名实体。选择期间暂停出牌、移动与结束行动；玩家提交选择后从下一项效果继续，全部效果结束后才记录本次出牌、让当前牌离场并广播 `card_played`。空候选立即跳过选择并续行。

选择来源还可设为 `deck`（角色本次携带的卡组）或 `library`（角色战斗外已获得的牌库）。两者从持久清单取候选，选中时复制一张新的战斗牌放入指定牌区，原清单与未选候选保持不变；`library` 通过已获卡名查 CardDB，不会展示未获得的全局卡牌。`temporary_copy=true` 只作用于该复制品，打出并结算后直接消失，不进入弃牌堆或消耗堆。

`required_card_type=Attack` 只接受攻击牌，和 `required_tags` 可组合使用。`distinct_by_card_id=true` 先按卡牌 ID 去重，再等概率抽样不同牌种；同名卡组槽位不会重复占用展示位。文本仅说“临时复制品”时，该战斗生成牌不写回持久卡组或牌库，离场遵循自身普通关键词；只有文本明确“打出后消失”时才设 `temporary_copy=true`。

设计文字写“未选中的牌洗回牌库”时，按已确认规则只展示候选并生成选中牌；未选牌本来就在角色的永久牌库或卡组中，保持原样，不执行持久数据的移出与洗牌。

`show_all` 不随机抽样，按原牌区顺序展示全部合格牌；`required_rarity=Basic` 按牌的基础稀有度过滤。`selected_cost_override` 或 `selected_cost_reduction` 只作用于选中实体，持续到本次行动结束；降费与已有条件降费相加且最低为 0，费用覆盖优先生效。行动结束时清除仍在各牌区的临时费用，不影响“下次打出后消耗”。

从手牌选择时，当前打出的牌已离开手牌；`destination=hand` 保持被选实体原有手牌位置。`grant_retain_selected` 让选中实体获得保留关键词，按普通保留规则跨行动留在手牌，不改动卡牌数据库原型。无可选手牌时跳过选择，继续结算该牌后续效果。

- 初始卡组补齐：每名角色至少 5 打击 + 5 防御，随后用基础牌补齐到 20 张（DECK_CAPACITY=20）。
- 卡牌加入技能库（SkillData）与卡组由 GameState / 道途系统负责；同一张牌不重复添加（幂等）。
- 费用、荷载由 CardSystem 校验；抽牌堆为空时洗回弃牌堆（防无限循环限制由测试覆盖）。

战斗抽牌堆是有序的实体牌数组，每个槽位在进入战斗时拥有独立 `CardData` 实例；数组末尾是牌顶。开战和弃牌堆洗回时对现有实体做洗牌，普通抽牌只 `pop_back`，不会按卡名重新随机抽取或临时生成牌。加入牌区的每一张生成牌也各自实例化；牌区转移按选中槽位移动，不能仅按对象相等值删除第一张同名牌。这样置顶、置底、看顶牌、弃牌和临时改牌的顺序与身份才可组合。

`inspect_top_cards` 按牌顶向下取至多 `count` 张实体牌，选择事务期间暂存这些实体并锁定其他行动。可配置先选 1 张加入手牌、再选 1 张加入弃牌堆，最后按牌顶到牌底逐张指定剩余顺序；最后一张无需再点选。未要求排序时，剩余牌保持查看前的相对顺序。抽牌堆不足时只处理现有牌，空堆直接续行；需要入手但手牌已满时跳过本次查看。整段选择完成后才续行该卡后续效果及出牌离场。

`discard_up_to` 允许玩家从查看的顶牌中弃置最多指定张数，也可选择“结束弃牌”并保留剩余实体进入排序阶段。这个跳过入口只在可选弃置阶段出现；必选入手和必选弃置阶段没有跳过操作。玩家选零张或提前结束时，尚未弃置的牌仍按后续排序结果返回抽牌堆。
