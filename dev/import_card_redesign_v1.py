"""Import the four v1.0 card design tables into content/cards.

Only effects that match a complete, lossless template are activated. The
remaining designs stay in the catalog with implementation_status=design_only.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROOT = Path(sys.argv[1]).resolve()
CARD_DIR = ROOT / "content" / "cards"
MECHANICS = json.loads((CARD_DIR / "mechanics.json").read_text(encoding="utf-8"))
assert MECHANICS["schema_version"] == 1
SOURCES = {
    "A": ("艾莉丝", "梦魇行者", "艾莉丝_完整卡组_重制v1.0.md"),
    "D": ("迪马斯", "侠盗", "迪马斯_完整卡组_重制v1.0.md"),
    "K": ("卡莎", "解剖学者", "卡莎_完整卡组_重制v1.0.md"),
    "B": ("鲍德温", "孢子卫士", "鲍德温_完整卡组_重制v1.0.md"),
}
ROW = re.compile(r"^\| ([ADKB]\d{3}) \| \*\*(.*?)\*\* \| (\d+) \| (\d+) \| (Attack|Skill|Power) \| (.*?) \| (.*?) \| (是|否) \| (.*?) \|$")
RANGE = re.compile(r"距(\d+)(?:[–—-](\d+))?")


def effect_from_mechanic(mechanism: str, **params: object) -> dict:
    """Instantiate a reusable effect template from the mechanism database."""
    template = MECHANICS["effects"][mechanism]["template"]
    required = {value[1:] for value in template.values() if isinstance(value, str) and value.startswith("$")}
    assert required == params.keys(), (mechanism, required, params.keys())
    return {key: params[value[1:]] if isinstance(value, str) and value.startswith("$") else value
            for key, value in template.items()}


def mechanism_ids(effects: list[dict], cost_rules: list[dict], play_conditions: list[dict], hp_payment: int, dream_mode: str) -> list[str]:
    """Index the implemented building blocks used by one playable card."""
    ids: list[str] = []
    def record(group: str, name: str) -> None:
        assert name in MECHANICS[group], (group, name)
        identifier = f"{group}.{name}"
        if identifier not in ids:
            ids.append(identifier)
    for effect in effects:
        record("effects", effect["logic"])
        if "condition" in effect:
            record("conditions", effect["condition"]["type"])
        if effect.get("alt_condition"):
            record("modifiers", effect["alt_condition"])
        if effect.get("value_from_target_buff_stacks"):
            record("modifiers", "value_from_target_buff_stacks")
    for rule in cost_rules:
        record("conditions", rule["type"])
    for condition in play_conditions:
        record("conditions", condition["type"])
    if play_conditions:
        record("play_rules", "play_conditions")
    if hp_payment:
        record("play_rules", "hp_payment")
    if dream_mode:
        record("play_rules", dream_mode)
    return ids


def target_of(label: str) -> tuple[str, int, int, int]:
    if label.startswith("自身+友军"):
        kind = "Ally"
    elif label.startswith("自身"):
        kind = "Self"
    elif label.startswith(("友军", "全体友军", "至多2友军", "至多3友军")):
        kind = "Ally"
    elif label.startswith(("敌群", "至多2敌", "直线")):
        kind = "Area"
    elif label.startswith(("敌", "相邻敌人")):
        kind = "Enemy"
    elif label.startswith("区域"):
        kind = "Area"
    else:
        kind = "None"
    match = RANGE.search(label)
    minimum = int(match.group(1)) if match else 0
    maximum = int(match.group(2) or match.group(1)) if match else 0
    if label == "相邻敌人" or label.endswith("当前相邻"):
        minimum = maximum = 1
    area_match = re.search(r"半径(\d+)", label)
    return kind, minimum, maximum, int(area_match.group(1)) if area_match else 0


def exact_effects(description: str, kind: str, maximum: int) -> list[dict]:
    # Complete templates only. A partial clause must never become a live card.
    def top_inspect_effect(count: int, pick_to_hand: bool = False,
                           pick_to_discard: int = 0, discard_up_to: int = 0,
                           reorder_remaining: bool = True) -> dict:
        return effect_from_mechanic("inspect_top_cards", count=count,
                                    pick_to_hand=pick_to_hand,
                                    pick_to_discard=pick_to_discard,
                                    discard_up_to=discard_up_to,
                                    reorder_remaining=reorder_remaining)
    if kind == "Self":
        top_reorder = re.fullmatch(r"查看抽牌堆顶(\d+)张并任意排序。", description)
        if top_reorder:
            return [top_inspect_effect(int(top_reorder.group(1)))]
        top_optional_discard = re.fullmatch(r"查看抽牌堆顶(\d+)张；可将其中至多(\d+)张置入弃牌堆，其余任意排序。", description)
        if top_optional_discard:
            return [top_inspect_effect(int(top_optional_discard.group(1)),
                                       discard_up_to=int(top_optional_discard.group(2)))]
        top_pick = re.fullmatch(r"查看抽牌堆顶(\d+)张；选择1张加入手牌，其余按任意顺序放回顶部。", description)
        if top_pick:
            return [top_inspect_effect(int(top_pick.group(1)), pick_to_hand=True)]
        top_split = re.fullmatch(r"查看抽牌堆顶(\d+)张：1张加入手牌，1张置入弃牌堆，1张留在牌堆顶。", description)
        if top_split:
            return [top_inspect_effect(int(top_split.group(1)), pick_to_hand=True,
                                       pick_to_discard=1, reorder_remaining=False)]
        block_top_pick = re.fullmatch(r"获得(\d+)格挡；查看抽牌堆顶(\d+)张，选择1张加入手牌，其余任意排序。", description)
        if block_top_pick:
            return [effect_from_mechanic("defense", target="self", value=int(block_top_pick.group(1))),
                    top_inspect_effect(int(block_top_pick.group(2)), pick_to_hand=True)]
    def pile_choice_effect(source: str, destination: str = "draw", **filters: object) -> dict:
        params = dict(source=source, sample_count=3, show_all=False,
                      distinct_by_card_id=False,
                      destination=destination, position="top", selection_destinations=[],
                      required_card_type="",
                      exclude_card_type="Power" if filters.get("non_power") else "",
                      required_rarity="", base_cost=-1, required_tags=[], played_in_battle=False,
                      not_played_this_turn=False, exhaust_selected_on_play=False,
                      selected_cost_override=-1, selected_cost_reduction=0,
                      grant_retain_selected=False, temporary_copy=False)
        params.update({key: value for key, value in filters.items() if key != "non_power"})
        return effect_from_mechanic("choose_from_pile", **params)
    if kind == "Self":
        deck_drug = re.fullmatch(r"从当前牌组随机展示(\d+)张Drug；选择1张置于牌堆顶，并获得(\d+)格挡。", description)
        if deck_drug:
            return [pile_choice_effect("deck", required_tags=["Drug"], sample_count=int(deck_drug.group(1))),
                    effect_from_mechanic("defense", target="self", value=int(deck_drug.group(2)))]
        if description == "从你的牌库中随机展示3张非Power牌；选择1张生成临时复制品加入手牌，复制品打出后消失。":
            return [pile_choice_effect("library", "hand", non_power=True, temporary_copy=True)]
        if description == "从牌库随机展示3张Skill；选择1张置于手牌，另外2张洗回牌库。":
            return [pile_choice_effect("library", "hand", required_card_type="Skill")]
        if description == "从当前牌组随机展示5张Drug；选择1张加入手牌，另外4张洗回牌库。":
            return [pile_choice_effect("deck", "hand", required_tags=["Drug"], sample_count=5)]
        if description == "从当前牌组随机展示3张Pistol Attack；选择1张生成临时复制品加入手牌，其本回合费用-1。":
            return [pile_choice_effect("deck", "hand", required_card_type="Attack",
                                       required_tags=["Pistol"], selected_cost_reduction=1)]
        if description == "从当前牌组随机展示4张不同Attack；选择1张生成临时复制品加入手牌，其本回合费用变为0，打出后消失。":
            return [pile_choice_effect("deck", "hand", required_card_type="Attack",
                                       distinct_by_card_id=True, sample_count=4,
                                       selected_cost_override=0, temporary_copy=True)]
        if description == "从当前牌组随机展示5张不同非Power牌；选择2张生成临时复制品置入弃牌堆。":
            return [pile_choice_effect("deck", non_power=True, distinct_by_card_id=True,
                                       sample_count=5, selection_destinations=["discard", "discard"])]
        if description == "从牌库随机展示3张Drug；选择1张加入手牌，另1张置于牌堆顶，剩余1张置于牌堆底。":
            return [pile_choice_effect("library", required_tags=["Drug"],
                                       selection_destinations=["hand", "draw_top", "draw_bottom"])]
        if description == "选择1张其他手牌获得保留；获得5格挡。":
            return [pile_choice_effect("hand", "hand", show_all=True, grant_retain_selected=True),
                    effect_from_mechanic("defense", target="self", value=5)]
        if description == "从弃牌堆选择1张Basic牌置于手牌；其本回合费用变为0，打出后消耗。":
            return [pile_choice_effect("discard", "hand", show_all=True, required_rarity="Basic",
                                       selected_cost_override=0, exhaust_selected_on_play=True)]
        if description == "将弃牌堆随机展示3张非Power牌，选择1张置于手牌，其本回合费用-1。":
            return [pile_choice_effect("discard", "hand", non_power=True,
                                       selected_cost_reduction=1)]
        if description == "从弃牌堆随机展示3张本场战斗已打出过的Drug或Surgery；选择1张置于牌堆顶。":
            return [pile_choice_effect("discard", required_tags=["Drug", "Surgery"], played_in_battle=True)]
        if description == "从弃牌堆随机展示3张基础费用为1的Skill；选择1张加入手牌，该牌打出后消耗。":
            return [pile_choice_effect("discard", "hand", required_card_type="Skill", base_cost=1,
                                       exhaust_selected_on_play=True)]
        if description == "从弃牌堆随机展示3张本回合尚未打出过的非Power牌；选择1张加入手牌，其下一次打出后消耗。":
            return [pile_choice_effect("discard", "hand", non_power=True, not_played_this_turn=True,
                                       exhaust_selected_on_play=True)]
    pile_choice = re.fullmatch(r"从(抽牌堆中|抽牌堆|弃牌堆)随机展示(\d+)张牌；选择1张置于牌堆顶(?:，其余保持不变)?。", description)
    if pile_choice and kind == "Self":
        source = "discard" if pile_choice.group(1) == "弃牌堆" else "draw"
        choice = pile_choice_effect(source)
        choice["sample_count"] = int(pile_choice.group(2))
        return [choice]
    random_discard_top_draw = re.fullmatch(r"从弃牌堆随机将(\d+)张非Power牌置于牌堆顶；然后抽(\d+)张。", description)
    if random_discard_top_draw and kind == "Self":
        return [
            effect_from_mechanic("transfer_random_card", source="discard", destination="draw",
                                  exclude_card_type="Power", position="top", count=int(random_discard_top_draw.group(1))),
            effect_from_mechanic("draw", value=int(random_discard_top_draw.group(2))),
        ]
    mulligan = re.fullmatch(r"将当前手牌除本牌外全部洗入抽牌堆；随机抽取同等数量的牌。", description)
    if mulligan and kind == "Self":
        return [effect_from_mechanic("mulligan_hand")]
    low_hp_ally_heal_block = re.fullmatch(r"回复(\d+)生命并获得(\d+)格挡。", description)
    if low_hp_ally_heal_block and kind == "Ally":
        return [
            effect_from_mechanic("heal", target="ally", value=int(low_hp_ally_heal_block.group(1))),
            effect_from_mechanic("defense", target="ally", value=int(low_hp_ally_heal_block.group(2))),
        ]
    armor_weak = re.fullmatch(r"造成(\d+)伤害；若目标Armor≥(\d+)，施加(\d+)层虚弱。", description)
    if armor_weak and kind == "Enemy":
        return [
            effect_from_mechanic("attack", value=int(armor_weak.group(1)), attack_range=maximum),
            {**effect_from_mechanic("buff", target="enemy", buff_type="虚弱", stacks=int(armor_weak.group(3))),
             "condition": {"type": "target_block_at_play_at_least", "threshold": int(armor_weak.group(2))}},
        ]
    armor_attack = re.fullmatch(r"造成(\d+)伤害；若目标Armor=0，改为(\d+)伤害。", description)
    if armor_attack and kind == "Enemy":
        condition = {"type": "target_block_at_play_at_most", "threshold": 0}
        return [
            {**effect_from_mechanic("attack", value=int(armor_attack.group(1)), attack_range=maximum),
             "condition": {**condition, "negate": True}},
            {**effect_from_mechanic("attack", value=int(armor_attack.group(2)), attack_range=maximum),
             "condition": condition},
        ]
    armor_direct_loss = re.fullmatch(r"造成(\d+)伤害并使目标直接失去(\d+)生命；若目标Armor≥(\d+)，直接生命损失改为(\d+)。", description)
    if armor_direct_loss and kind == "Enemy":
        condition = {"type": "target_block_at_play_at_least", "threshold": int(armor_direct_loss.group(3))}
        return [
            effect_from_mechanic("attack", value=int(armor_direct_loss.group(1)), attack_range=maximum),
            {**effect_from_mechanic("lose_hp", target="enemy", value=int(armor_direct_loss.group(2))),
             "condition": {**condition, "negate": True}},
            {**effect_from_mechanic("lose_hp", target="enemy", value=int(armor_direct_loss.group(4))),
             "condition": condition},
        ]
    before_move_adjacent = re.fullmatch(r"移动最多(\d+)格；若移动前与敌人相邻，获得(\d+)格挡。", description)
    if before_move_adjacent and kind == "Self":
        return [
            effect_from_mechanic("move", target="self", distance=int(before_move_adjacent.group(1))),
            {**effect_from_mechanic("defense", target="self", value=int(before_move_adjacent.group(2))),
             "condition": {"type": "adjacent_enemies_at_least", "count": 1}},
        ]
    attack_loss_move = re.fullmatch(r"造成(\d+)伤害并使目标直接失去(\d+)生命；之后移动(\d+)格。", description)
    if attack_loss_move and kind == "Enemy":
        return [
            effect_from_mechanic("attack", value=int(attack_loss_move.group(1)), attack_range=maximum),
            effect_from_mechanic("lose_hp", target="enemy", value=int(attack_loss_move.group(2))),
            effect_from_mechanic("move", target="self", distance=int(attack_loss_move.group(3))),
        ]
    self_move_block = re.fullmatch(r"移动(\d+)格并获得(\d+)格挡。", description)
    if self_move_block and kind == "Self":
        return [
            effect_from_mechanic("move", target="self", distance=int(self_move_block.group(1))),
            effect_from_mechanic("defense", target="self", value=int(self_move_block.group(2))),
        ]
    pistol_move_block = re.fullmatch(r"若本回合打出过Pistol，移动(\d+)格并获得(\d+)格挡；否则获得(\d+)格挡。", description)
    if pistol_move_block and kind == "Self":
        condition = {"type": "played_card_tags_this_turn", "tag": "Pistol"}
        return [
            {**effect_from_mechanic("move", target="self", distance=int(pistol_move_block.group(1))),
             "condition": condition},
            {**effect_from_mechanic("defense", target="self", value=int(pistol_move_block.group(2))),
             "condition": condition},
            {**effect_from_mechanic("defense", target="self", value=int(pistol_move_block.group(3))),
             "condition": {**condition, "negate": True}},
        ]
    push_then_move = re.fullmatch(r"推动目标(\d+)格；然后你移动最多(\d+)格。", description)
    if push_then_move and kind == "Enemy":
        return [
            effect_from_mechanic("knockback", value=int(push_then_move.group(1))),
            effect_from_mechanic("move", target="self", distance=int(push_then_move.group(2))),
        ]
    doom_push = re.fullmatch(r"【灾梦】造成(\d+)伤害并推动目标(\d+)格；结算后进入沉梦。", description)
    if doom_push and kind == "Enemy":
        return [
            effect_from_mechanic("attack", value=int(doom_push.group(1)), attack_range=maximum),
            effect_from_mechanic("knockback", value=int(doom_push.group(2))),
        ]
    push_attack = re.fullmatch(r"造成(\d+)伤害并推动目标(\d+)格。", description)
    if push_attack and kind == "Enemy":
        return [
            effect_from_mechanic("attack", value=int(push_attack.group(1)), attack_range=maximum),
            effect_from_mechanic("knockback", value=int(push_attack.group(2))),
        ]
    surgery_multi = re.fullmatch(r"造成(\d+)伤害([2-9])次，并使目标直接失去(\d+)生命。", description)
    if surgery_multi and kind == "Enemy":
        attacks = [effect_from_mechanic("attack", value=int(surgery_multi.group(1)), attack_range=maximum)
                   for _ in range(int(surgery_multi.group(2)))]
        return attacks + [effect_from_mechanic("lose_hp", target="enemy", value=int(surgery_multi.group(3)))]
    ally_block_move_bonus = re.fullmatch(r"目标获得(\d+)格挡，且本回合移动距离\+(\d+)。", description)
    if ally_block_move_bonus and kind == "Ally":
        return [
            effect_from_mechanic("defense", target="ally", value=int(ally_block_move_bonus.group(1))),
            effect_from_mechanic("move", target="ally", distance=int(ally_block_move_bonus.group(2))),
        ]
    drug_move = re.fullmatch(r"移动最多(\d+)格；若本回合使用过Drug，改为(\d+)格。", description)
    if drug_move and kind == "Self":
        condition = {"type": "played_card_tags_this_turn", "tag": "Drug"}
        return [
            {**effect_from_mechanic("move", target="self", distance=int(drug_move.group(1))),
             "condition": {**condition, "negate": True}},
            {**effect_from_mechanic("move", target="self", distance=int(drug_move.group(2))),
             "condition": condition},
        ]
    return_from_phantom = re.fullmatch(r"若处于幻梦，立即进入沉梦并获得(\d+)格挡。", description)
    if return_from_phantom and kind == "Self":
        return [
            {**effect_from_mechanic("set_dream_state", state=0),
             "condition": {"type": "redesign_dream_state_is", "state": 1}},
            {**effect_from_mechanic("defense", target="self", value=int(return_from_phantom.group(1))),
             "condition": {"type": "redesign_dream_state_at_play_is", "state": 1}},
        ]
    if description == "立即令目标的毒正常结算一次。" and kind == "Enemy":
        return [effect_from_mechanic("trigger_buff", target="enemy", buff_type="中毒")]
    simple_doom_attack = re.fullmatch(r"【灾梦】造成(\d+)伤害；结算后进入沉梦。", description)
    if simple_doom_attack and kind == "Enemy":
        return [effect_from_mechanic("attack", value=int(simple_doom_attack.group(1)), attack_range=maximum)]
    if description == "目标直接失去等于当前毒层数的生命，不减少毒层数；不视为毒正常结算。" and kind == "Enemy":
        return [{**effect_from_mechanic("lose_hp", target="enemy", value=0),
                 "value_from_target_buff_stacks": "中毒"}]
    poison_threshold_loss = re.fullmatch(r"造成(\d+)伤害并使目标直接失去(\d+)生命；毒≥(\d+)时改为(\d+)生命。", description)
    if poison_threshold_loss and kind == "Enemy":
        condition = {"type": "target_buff_stacks_at_least", "buff": "中毒",
                     "stacks": int(poison_threshold_loss.group(3))}
        return [
            effect_from_mechanic("attack", value=int(poison_threshold_loss.group(1)), attack_range=maximum),
            {**effect_from_mechanic("lose_hp", target="enemy", value=int(poison_threshold_loss.group(2))),
             "condition": {**condition, "negate": True}},
            {**effect_from_mechanic("lose_hp", target="enemy", value=int(poison_threshold_loss.group(4))),
             "condition": condition},
        ]
    moved_attack = re.fullmatch(r"若本回合已移动，造成(\d+)伤害；否则造成(\d+)伤害。", description)
    if moved_attack and kind == "Enemy":
        return [
            {**effect_from_mechanic("attack", value=int(moved_attack.group(1)), attack_range=maximum),
             "condition": {"type": "moved_this_turn"}},
            {**effect_from_mechanic("attack", value=int(moved_attack.group(2)), attack_range=maximum),
             "condition": {"type": "not_moved_this_turn"}},
        ]
    played_dagger_attack = re.fullmatch(r"若本回合打出过Dagger Attack，造成(\d+)伤害；否则造成(\d+)伤害。", description)
    if played_dagger_attack and kind == "Enemy":
        condition = {"type": "played_card_tags_this_turn", "tag": "Dagger", "card_type": "Attack"}
        return [
            {**effect_from_mechanic("attack", value=int(played_dagger_attack.group(1)), attack_range=maximum),
             "condition": condition},
            {**effect_from_mechanic("attack", value=int(played_dagger_attack.group(2)), attack_range=maximum),
             "condition": {**condition, "negate": True}},
        ]
    dagger_pistol_energy = re.fullmatch(r"若本回合已分别打出Dagger和Pistol Attack，获得(\d+)费。", description)
    if dagger_pistol_energy and kind == "Self":
        return [{**effect_from_mechanic("gain_energy", value=int(dagger_pistol_energy.group(1))),
                 "condition": {"type": "played_card_tags_this_turn", "tag": "Dagger",
                               "other_tag": "Pistol", "card_type": "Attack", "distinct": 1}}]
    healing_attack = re.fullmatch(r"造成(\d+)伤害；若打出前拥有疗愈，改为(\d+)伤害。", description)
    if healing_attack and kind == "Enemy":
        condition = {"type": "has_buff", "buff_name": "疗愈"}
        return [
            {**effect_from_mechanic("attack", value=int(healing_attack.group(1)), attack_range=maximum),
             "condition": {**condition, "negate": True}},
            {**effect_from_mechanic("attack", value=int(healing_attack.group(2)), attack_range=maximum),
             "condition": condition},
        ]
    low_target_hp_heal = re.fullmatch(r"若目标生命≤(\d+)%，回复(\d+)生命。", description)
    if low_target_hp_heal and kind == "Ally":
        return [{**effect_from_mechanic("heal", target="ally", value=int(low_target_hp_heal.group(2))),
                 "condition": {"type": "target_hp_at_most_pct", "pct": int(low_target_hp_heal.group(1))}}]
    adjacent_ally_block = re.fullmatch(r"目标获得(\d+)格挡；若结算后仍与你相邻，你获得(\d+)格挡。", description)
    if adjacent_ally_block and kind == "Ally":
        return [
            effect_from_mechanic("defense", target="ally", value=int(adjacent_ally_block.group(1))),
            {**effect_from_mechanic("defense", target="self", value=int(adjacent_ally_block.group(2))),
             "condition": {"type": "caster_target_adjacent"}},
        ]
    ally_block_move = re.fullmatch(r"目标获得(\d+)格挡；你可移动最多(\d+)格。", description)
    if ally_block_move and kind == "Ally":
        return [
            effect_from_mechanic("defense", target="ally", value=int(ally_block_move.group(1))),
            effect_from_mechanic("move", target="self", distance=int(ally_block_move.group(2))),
        ]
    self_ally_block = re.fullmatch(r"你获得(\d+)格挡；目标友军获得(\d+)格挡。", description)
    if self_ally_block and kind == "Ally":
        return [
            effect_from_mechanic("defense", target="self", value=int(self_ally_block.group(1))),
            effect_from_mechanic("defense", target="ally", value=int(self_ally_block.group(2))),
        ]
    moved_ally_block = re.fullmatch(r"目标获得(\d+)格挡；若其本回合已移动，再获得(\d+)格挡。", description)
    if moved_ally_block and kind == "Ally":
        return [
            effect_from_mechanic("defense", target="ally", value=int(moved_ally_block.group(1))),
            {**effect_from_mechanic("defense", target="ally", value=int(moved_ally_block.group(2))),
             "condition": {"type": "target_moved_this_turn"}},
        ]
    adjacent_enemies_block = re.fullmatch(r"获得(\d+)格挡；若相邻敌人≥(\d+)，再获得(\d+)格挡。", description)
    if adjacent_enemies_block and kind == "Self":
        return [
            effect_from_mechanic("defense", target="self", value=int(adjacent_enemies_block.group(1))),
            {**effect_from_mechanic("defense", target="self", value=int(adjacent_enemies_block.group(3))),
             "condition": {"type": "adjacent_enemies_at_least", "count": int(adjacent_enemies_block.group(2))}},
        ]
    dream_block = re.fullmatch(r"获得(\d+)格挡；若处于沉梦，改为(\d+)格挡。", description)
    if dream_block and kind == "Self":
        condition = {"type": "redesign_dream_state_is", "state": 0}
        return [
            {"logic": "defense", "value": int(dream_block.group(1)), "condition": {**condition, "negate": True}},
            {"logic": "defense", "value": int(dream_block.group(2)), "condition": condition},
        ]
    dream_attack_block = re.fullmatch(r"造成(\d+)伤害；若处于沉梦，获得(\d+)格挡。", description)
    if dream_attack_block and kind == "Enemy":
        return [
            {"logic": "attack", "value": int(dream_attack_block.group(1)), "attack_range": maximum},
            {"logic": "defense", "value": int(dream_attack_block.group(2)),
             "condition": {"type": "redesign_dream_state_is", "state": 0}},
        ]
    stationary_block = re.fullmatch(r"获得(\d+)格挡；若本回合尚未移动，改为(\d+)格挡。", description)
    if stationary_block and kind == "Self":
        return [
            {"logic": "defense", "value": int(stationary_block.group(1)),
             "condition": {"type": "moved_this_turn"}},
            {"logic": "defense", "value": int(stationary_block.group(2)),
             "condition": {"type": "not_moved_this_turn"}},
        ]
    stationary_healing = re.fullmatch(r"获得(\d+)格挡；若本回合尚未移动，再获得(\d+)层疗愈。", description)
    if stationary_healing and kind == "Self":
        return [
            {"logic": "defense", "value": int(stationary_healing.group(1))},
            {"logic": "buff", "target": "self", "buff_type": "疗愈", "stacks": int(stationary_healing.group(2)),
             "condition": {"type": "not_moved_this_turn"}},
        ]
    low_hp_healing_block = re.fullmatch(r"若生命≤(\d+)%，获得(\d+)层疗愈和(\d+)格挡。", description)
    if low_hp_healing_block and kind == "Self":
        condition = {"type": "hp_at_most_pct", "pct": int(low_hp_healing_block.group(1))}
        return [
            {"logic": "buff", "target": "self", "buff_type": "疗愈", "stacks": int(low_hp_healing_block.group(2)),
             "condition": condition},
            {"logic": "defense", "value": int(low_hp_healing_block.group(3)), "condition": condition},
        ]
    poison_replace = re.fullmatch(r"施加(\d+)层毒；若目标已经中毒，改为(\d+)层。", description)
    if poison_replace and kind == "Enemy":
        condition = {"type": "target_has_buff_at_play", "buff_name": "中毒"}
        return [
            {"logic": "buff", "target": "enemy", "buff_type": "中毒",
             "stacks": int(poison_replace.group(1)), "condition": {**condition, "negate": True}},
            {"logic": "buff", "target": "enemy", "buff_type": "中毒",
             "stacks": int(poison_replace.group(2)), "condition": condition},
        ]
    poison_extra_debuff = re.fullmatch(r"施加(\d+)层毒；若目标已有任意Debuff，再施加(\d+)层毒。", description)
    if poison_extra_debuff and kind == "Enemy":
        return [
            {"logic": "buff", "target": "enemy", "buff_type": "中毒", "stacks": int(poison_extra_debuff.group(1))},
            {"logic": "buff", "target": "enemy", "buff_type": "中毒", "stacks": int(poison_extra_debuff.group(2)),
             "condition": {"type": "target_has_any_debuff_at_play"}},
        ]
    poison_extra_hp = re.fullmatch(r"施加(\d+)层毒；若目标本回合直接失去过生命，再施加(\d+)层。", description)
    if poison_extra_hp and kind == "Enemy":
        return [
            {"logic": "buff", "target": "enemy", "buff_type": "中毒", "stacks": int(poison_extra_hp.group(1))},
            {"logic": "buff", "target": "enemy", "buff_type": "中毒", "stacks": int(poison_extra_hp.group(2)),
             "condition": {"type": "target_lost_direct_hp_this_turn"}},
        ]
    move_block = re.fullmatch(r"移动最多(\d+)格并获得(\d+)格挡。", description)
    if move_block and kind == "Self":
        return [
            {"logic": "move", "distance": int(move_block.group(1))},
            {"logic": "defense", "value": int(move_block.group(2))},
        ]
    healing_only = re.fullmatch(r"获得(\d+)层疗愈。", description)
    if healing_only and kind == "Self":
        return [{"logic": "buff", "target": "self", "buff_type": "疗愈",
                 "stacks": int(healing_only.group(1))}]
    block_healing = re.fullmatch(r"获得(\d+)格挡和(\d+)层疗愈。", description)
    if block_healing and kind == "Self":
        return [
            {"logic": "defense", "value": int(block_healing.group(1))},
            {"logic": "buff", "target": "self", "buff_type": "疗愈",
             "stacks": int(block_healing.group(2))},
        ]
    bloodlet_attack = re.fullmatch(r"造成(\d+)伤害；若本回合已经放血，改为(\d+)伤害。", description)
    if bloodlet_attack and kind == "Enemy":
        return [{"logic": "attack", "value": int(bloodlet_attack.group(1)),
                 "alt_value": int(bloodlet_attack.group(2)),
                 "alt_condition": "bloodlet_this_turn", "attack_range": maximum}]
    phantom_entry = re.fullmatch(r"【幻梦】造成(\d+)伤害。若从沉梦打出，结算前进入幻梦。", description)
    if phantom_entry and kind == "Enemy":
        return [{"logic": "attack", "value": int(phantom_entry.group(1)), "attack_range": maximum}]
    doom_return = re.fullmatch(r"【灾梦】造成(\d+)伤害并施加(\d+)层虚弱；结算后进入沉梦。", description)
    if doom_return and kind == "Enemy":
        return [
            {"logic": "attack", "value": int(doom_return.group(1)), "attack_range": maximum},
            {"logic": "buff", "target": "enemy", "buff_type": "虚弱", "stacks": int(doom_return.group(2))},
        ]
    low_hp_block = re.fullmatch(r"获得(\d+)格挡；若当前生命≤50%，再获得(\d+)格挡。", description)
    if low_hp_block and kind == "Self":
        return [
            {"logic": "defense", "value": int(low_hp_block.group(1))},
            {"logic": "defense", "value": int(low_hp_block.group(2)),
             "condition": {"type": "hp_at_most_pct", "pct": 50}},
        ]
    healing_block = re.fullmatch(r"获得(\d+)层疗愈和(\d+)格挡。", description)
    if healing_block and kind == "Self":
        return [
            {"logic": "buff", "target": "self", "buff_type": "疗愈", "stacks": int(healing_block.group(1))},
            {"logic": "defense", "value": int(healing_block.group(2))},
        ]
    clauses = [part.strip() for part in re.split(r"[；。]", description) if part.strip()]
    effects: list[dict] = []
    for clause in clauses:
        match = re.fullmatch(r"造成(\d+)伤害([2-9])次", clause)
        if match and kind == "Enemy":
            effects.extend({"logic": "attack", "value": int(match.group(1)),
                            "attack_range": maximum} for _ in range(int(match.group(2))))
            continue
        match = re.fullmatch(r"造成(\d+)伤害并使目标直接失去(\d+)生命", clause)
        if match and kind == "Enemy":
            effects.append({"logic": "attack", "value": int(match.group(1)), "attack_range": maximum})
            effects.append({"logic": "lose_hp", "target": "enemy", "value": int(match.group(2))})
            continue
        match = re.fullmatch(r"造成(\d+)伤害(?:并施加(\d+)层(虚弱|中毒))?", clause)
        if match and kind == "Enemy":
            effects.append({"logic": "attack", "value": int(match.group(1)), "attack_range": maximum})
            if match.group(2):
                effects.append({"logic": "buff", "target": "enemy", "buff_type": match.group(3), "stacks": int(match.group(2)), "duration": int(match.group(2))})
            continue
        match = re.fullmatch(r"(?:你)?获得(\d+)格挡", clause)
        if match and kind == "Self":
            effects.append({"logic": "defense", "value": int(match.group(1))})
            continue
        match = re.fullmatch(r"目标获得(\d+)格挡", clause)
        if match and kind == "Ally":
            effects.append({"logic": "defense", "target": "ally", "value": int(match.group(1))})
            continue
        match = re.fullmatch(r"回复(\d+)生命", clause)
        if match and kind == "Ally":
            effects.append({"logic": "heal", "target": "ally", "value": int(match.group(1))})
            continue
        match = re.fullmatch(r"移动最多(\d+)格", clause)
        if match and kind == "Self":
            effects.append({"logic": "move", "distance": int(match.group(1))})
            continue
        match = re.fullmatch(r"之后移动最多(\d+)格", clause)
        if match and kind == "Enemy":
            effects.append({"logic": "move", "distance": int(match.group(1))})
            continue
        match = re.fullmatch(r"目标直接失去(\d+)生命", clause)
        if match and kind == "Enemy":
            effects.append({"logic": "lose_hp", "target": "enemy", "value": int(match.group(1))})
            continue
        match = re.fullmatch(r"使其直接失去(\d+)生命", clause)
        if match and kind == "Enemy":
            effects.append({"logic": "lose_hp", "target": "enemy", "value": int(match.group(1))})
            continue
        match = re.fullmatch(r"抽(\d+)张(?:牌)?", clause)
        if match and kind == "Self":
            effects.append({"logic": "draw", "value": int(match.group(1))})
            continue
        match = re.fullmatch(r"获得(\d+)费", clause)
        if match and kind == "Self":
            effects.append({"logic": "gain_energy", "value": int(match.group(1))})
            continue
        match = re.fullmatch(r"施加(\d+)层(毒|中毒|虚弱)", clause)
        if match and kind == "Enemy":
            buff = "中毒" if match.group(2) == "毒" else match.group(2)
            effects.append({"logic": "buff", "target": "enemy", "buff_type": buff, "stacks": int(match.group(1)), "duration": int(match.group(1))})
            continue
        match = re.fullmatch(r"施加(\d+)层毒和(\d+)层虚弱", clause)
        if match and kind == "Enemy":
            effects.append({"logic": "buff", "target": "enemy", "buff_type": "中毒",
                            "stacks": int(match.group(1)), "duration": int(match.group(1))})
            effects.append({"logic": "buff", "target": "enemy", "buff_type": "虚弱",
                            "stacks": int(match.group(2)), "duration": int(match.group(2))})
            continue
        return []
    return effects


def main() -> None:
    cards: list[dict] = []
    for prefix, (character, path, source) in SOURCES.items():
        rarity = ""
        for line_number, line in enumerate((ROOT / source).read_text(encoding="utf-8-sig").splitlines(), 1):
            heading = re.match(r"^## (Basic|Common|Uncommon|Rare)\b", line)
            if heading:
                rarity = heading.group(1)
            match = ROW.fullmatch(line.strip())
            if not match:
                continue
            card_id, name, cost, load, card_type, target_label, description, exhaust, tags = match.groups()
            assert card_id.startswith(prefix) and rarity, (source, line_number)
            target, minimum, maximum, area = target_of(target_label)
            payment_match = re.match(r"^放血([147])；", description)
            hp_payment = int(payment_match.group(1)) if payment_match else 0
            effect_text = description[payment_match.end():] if payment_match else description
            play_conditions: list[dict] = []
            low_hp_ally_only = re.match(r"^仅可对生命≤(\d+)%的友军使用；", effect_text)
            if low_hp_ally_only and target == "Ally":
                play_conditions.append({"type": "target_hp_at_most_pct", "pct": int(low_hp_ally_only.group(1))})
                effect_text = effect_text[low_hp_ally_only.end():]
            precision_match = re.match(r"^若(.+?)，本牌费用-1；", effect_text)
            cost_rules: list[dict] = []
            precision_conditions = {
                "目标中毒": {"type": "target_has_buff", "buff": "中毒"},
                "目标有虚弱": {"type": "target_has_buff", "buff": "虚弱"},
                "目标毒≥5": {"type": "target_buff_stacks_at_least", "buff": "中毒", "stacks": 5},
                "本回合对目标使用过Drug": {"type": "used_tag_on_target_this_turn", "tag": "Drug"},
                "目标本回合已直接失去过生命": {"type": "target_lost_direct_hp_this_turn"},
                "你本回合移动过": {"type": "caster_moved_this_turn"},
                "本回合已打出Surgery": {"type": "played_card_tags_this_turn", "tag": "Surgery"},
            }
            if precision_match and precision_match.group(1) in precision_conditions:
                cost_rules.append({**precision_conditions[precision_match.group(1)], "amount": 1})
                effect_text = effect_text[precision_match.end():]
            effects = exact_effects(effect_text, target, maximum)
            keywords = [tag for tag in ("沉梦", "幻梦", "灾梦") if tag in tags.split(", ")]
            if exhaust == "是":
                keywords.append("消耗")
            card = {
                "id": card_id, "name": name, "character": character, "rarity": rarity,
                "category": "道途专属卡牌", "path": path,
                "card_type": {"Attack": "攻击", "Skill": "行动", "Power": "能力"}[card_type],
                "cost": int(cost), "load": int(load), "target_type": target,
                "hp_payment": hp_payment,
                "cost_rules": cost_rules,
                "play_conditions": play_conditions,
                "dream_mode": "three_dreams" if prefix == "A" else "",
                "min_range": minimum, "range": maximum, "target_spec": target_label,
                "area": area, "keywords": keywords,
                "tags": [tag.strip() for tag in tags.split(",")],
                "description": description, "source_effect": description,
                "source_file": source, "source_line": line_number,
                "icon": "", "art": "", "animation": "", "effects": effects,
                "mechanism_ids": mechanism_ids(effects, cost_rules, play_conditions, hp_payment, "three_dreams" if prefix == "A" else "") if effects else [],
                "implementation_status": "supported" if effects else "design_only",
            }
            cards.append(card)
    ids = [card["id"] for card in cards]
    assert len(cards) == 300 and len(set(ids)) == 300, (len(cards), len(set(ids)))
    for prefix in SOURCES:
        assert {f"{prefix}{number:03d}" for number in range(1, 76)} == {card_id for card_id in ids if card_id.startswith(prefix)}
    CARD_DIR.mkdir(parents=True, exist_ok=True)
    for card in cards:
        (CARD_DIR / f"{card['id']}.json").write_text(json.dumps(card, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    counts = {prefix: sum(card["id"].startswith(prefix) and card["implementation_status"] == "supported" for card in cards) for prefix in SOURCES}
    print(json.dumps({"total": len(cards), "supported_by_character": counts}, ensure_ascii=False))


if __name__ == "__main__":
    main()
