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
| `range` | 范围（六边形距离） |
| `area` | 区域 |
| `discard_on_use` | 是否打出后消失（能力牌自动 true） |
| `keywords` | 关键词数组（消耗/保留/虚无/固有/沉梦/幻梦/灾梦/衍生/吸血） |
| `icon` / `art` / `animation` | 美术接口（相对 content/cards/ 的路径，可空） |
| `effects` | 效果数组（组件化，顺序即触发顺序） |

> 兼容：旧版本使用 `art_path` 字段，CardDB 仍可读取。

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
| 移动 `move` | distance |
| 防御 `defense` | value（可带 alt_value） |
| 给予buff `buff` | target（self/ally/enemy）、buff_type、duration（可带 stacks 初始层数） |
| 抽牌 `draw` | value |
| 弃牌 `discard` | value、mode（random/all） |
| 加入手牌 `add_to_hand` | card、value |
| 加入抽牌堆 `add_to_draw` | card、value、position（shuffle/top） |
| 加入弃牌堆 `add_to_discard` | card、value |
| 生成牌 `generate` | card 或 pool（攻击/行动/能力/全部）、value、pile（hand/draw/discard） |
| 复制 `copy` | value、pile（默认 discard） |
| 失去生命 `lose_hp` | value、target（self/enemy），无视格挡 |
| 获得费用 `gain_energy` | value |
| 伺机反打 `flank` | value：离开攻击范围时造成伤害 |
| 击退 `knockback` | value：下一次攻击推开目标格数 |

一张卡可以有多个效果，effects 数组顺序即结算顺序。

## 4. 条件判断（condition）

任意效果可挂条件：满足才结算，不满足跳过（不影响后续效果）。
JSON：`{"logic":"attack", ..., "condition":{"type":"敌人数量在攻击范围内","count":2,"negate":false}}`。
条件类型记录在 content/cards/conditions.json，支持：敌人数量在攻击范围内 / 本回合已移动 / 本回合未移动 / 生命低于百分比 / 手牌不少于 / 费用不少于 / 自身持有buff / 场上敌人不少于 / 上一张牌带词条（可取反）。

## 5. 卡组规则

- 初始卡组补齐：每名角色至少 5 打击 + 5 防御，随后用基础牌补齐到 20 张（DECK_CAPACITY=20）。
- 卡牌加入技能库（SkillData）与卡组由 GameState / 道途系统负责；同一张牌不重复添加（幂等）。
- 费用、荷载由 CardSystem 校验；抽牌堆为空时洗回弃牌堆（防无限循环限制由测试覆盖）。