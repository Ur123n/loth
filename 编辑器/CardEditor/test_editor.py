# -*- coding: utf-8 -*-
"""卡牌编辑器数据层 + 卡面生成测试（无 GUI）。"""

import json
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import card_editor as ce

# 荷载允许为 0
zero_load = ce.make_card(
    name="测试零荷载",
    category="通用卡牌",
    path="",
    card_type="行动",
    cost=0,
    load=0,
    target_type="Self",
    range_=0,
    area=0,
    effects=[{"logic": "move", "distance": 1}],
)
assert zero_load["load"] == 0

# 单逻辑攻击牌
card = ce.make_card(
    name="测试攻击",
    category="通用卡牌",
    path="",
    card_type="攻击",
    cost=1,
    load=2,
    target_type="Enemy",
    range_=2,
    area=0,
    effects=[{"logic": "attack", "value": 7, "attack_range": 2}],
)
assert card["card_type"] == "攻击"
assert card["discard_on_use"] is False
assert card["effects"][0]["logic"] == "attack"
assert card["effects"][0]["value"] == 7
assert card["art"] == ""
assert card["icon"] == ""
assert card["animation"] == ""

# 能力牌自动消失
ability = ce.make_card(
    name="测试能力",
    category="道途专属卡牌",
    path="圣骑士",
    card_type="能力",
    cost=0,
    load=3,
    target_type="Ally",
    range_=1,
    area=0,
    effects=[{"logic": "buff", "target": "ally", "buff_type": "", "duration": 2}],
)
assert ability["discard_on_use"] is True
assert ability["effects"][0]["target"] == "ally"

# 多逻辑链：顺序必须保留（顺序即触发顺序）
multi = ce.make_card(
    name="测试多逻辑",
    category="通用卡牌",
    path="",
    card_type="行动",
    cost=2,
    load=2,
    target_type="Self",
    range_=0,
    area=0,
    effects=[
        {"logic": "move", "distance": 2},
        {"logic": "defense", "value": 3},
        {"logic": "attack", "value": 5, "attack_range": 1},
    ],
)
assert [e["logic"] for e in multi["effects"]] == ["move", "defense", "attack"]

# 卡面描述（顺序展示）
lines = ce.describe_effects(multi["effects"])
assert len(lines) == 3
assert "移动 2 格" in lines[0]
assert "防御" in lines[1] and "3" in lines[1]
assert "攻击" in lines[2] and "5" in lines[2]

# 保存 / 加载 / 删除往返
path = ce.save_card(card)
assert path.exists()
assert not path.with_suffix(".json.tmp").exists(), "原子保存不应残留 .tmp 文件"
multi_path = ce.save_card(multi)
loaded = ce.load_cards()
assert any(c["id"] == card["id"] for c in loaded)
assert any(c["id"] == multi["id"] for c in loaded)
assert ce.delete_card(card["id"])
assert ce.delete_card(multi["id"])
assert not any(c["id"] == card["id"] for c in ce.load_cards())

# 卡面 PNG 渲染与导出
if ce.HAVE_PIL:
    tmp = Path(tempfile.mkdtemp(prefix="cardface_test_"))
    img = ce.render_card_face(multi)
    assert img.size == (360, 500)
    out = ce.export_card_face(multi, tmp)
    assert out.exists() and out.stat().st_size > 0

    # 卡面图读取与渲染（含图片时应正常出图）
    from PIL import Image
    art_file = tmp / "art.png"
    Image.new("RGB", (80, 60), (200, 30, 30)).save(art_file)
    art_data = dict(multi)
    art_data["art_path"] = str(art_file)
    img_with_art = ce.render_card_face(art_data)
    assert img_with_art.size == (360, 500)
    assert ce.load_art_image(str(art_file)) is not None

    for f in tmp.iterdir():
        f.unlink()
    tmp.rmdir()
    print("PNG_RENDER_OK")

# 关键词字段（消耗/保留/虚无/固有）
kw_card = ce.make_card(
    name="测试关键词",
    category="通用卡牌",
    path="",
    card_type="攻击",
    cost=1,
    load=1,
    target_type="Self",
    range_=0,
    area=0,
    keywords=["消耗", "虚无", "固有"],
    effects=[{"logic": "draw", "value": 2}],
)
assert kw_card["keywords"] == ["消耗", "虚无", "固有"]

# 新增逻辑：抽牌/弃牌/加入牌堆/生成/复制/失去生命/获得费用
new_logic_card = ce.make_card(
    name="测试新逻辑",
    category="通用卡牌",
    path="",
    card_type="行动",
    cost=1,
    load=1,
    target_type="Self",
    range_=0,
    area=0,
    effects=[
        {"logic": "discard", "value": 2, "mode": "random"},
        {"logic": "add_to_hand", "card": "小刀", "value": 2},
        {"logic": "add_to_draw", "card": "小刀", "value": 1, "position": "top"},
        {"logic": "add_to_discard", "card": "伤口", "value": 1},
        {"logic": "generate", "pool": "攻击", "value": 1, "pile": "hand"},
        {"logic": "copy", "value": 1, "pile": "discard"},
        {"logic": "lose_hp", "value": 3, "target": "self"},
        {"logic": "gain_energy", "value": 2},
    ],
)
lines = ce.describe_effects(new_logic_card["effects"])
assert any("弃掉 2 张" in s for s in lines)
assert any("小刀" in s and "加入手牌" in s for s in lines)
assert any("抽牌堆" in s for s in lines)
assert any("弃牌堆" in s for s in lines)
assert any("生成 1 张" in s for s in lines)
assert any("复制" in s for s in lines)
assert any("失去 3 点生命" in s for s in lines)
assert any("获得 2 点费用" in s for s in lines)
assert all(e["logic"] in ("discard", "add_to_hand", "add_to_draw", "add_to_discard",
                          "generate", "copy", "lose_hp", "gain_energy")
           for e in new_logic_card["effects"])

# 保存/读取往返（含关键词）
kw_path = ce.save_card(kw_card)
loaded_kw = json.loads(kw_path.read_text(encoding="utf-8"))
assert loaded_kw["keywords"] == ["消耗", "虚无", "固有"]
assert ce.delete_card(kw_card["id"])

# 新逻辑/新关键词：伺机、击退、无视护甲、buff 层数、梦境链关键词
new_logic2 = ce.make_card(
    name="测试新逻辑2",
    category="通用卡牌",
    path="",
    card_type="攻击",
    cost=1,
    load=1,
    target_type="Enemy",
    range_=1,
    area=0,
    keywords=["沉梦", "幻梦", "灾梦", "衍生"],
    effects=[
        {"logic": "attack", "value": 10, "attack_range": 1, "pierce": True},
        {"logic": "buff", "target": "self", "buff_type": "疗愈", "duration": 0, "stacks": 3},
        {"logic": "flank", "value": 7},
        {"logic": "knockback", "value": 1},
    ],
)
assert new_logic2["keywords"] == ["沉梦", "幻梦", "灾梦", "衍生"]
lines2 = ce.describe_effects(new_logic2["effects"])
assert any("无视护甲" in s for s in lines2)
assert any("3 层" in s for s in lines2)
assert any("伺机" in s and "7" in s for s in lines2)
assert any("击退 1 格" in s for s in lines2)

# 条件效果：攻击/防御“移动后数值”
cond_card = ce.make_card(
    name="测试条件",
    category="通用卡牌",
    path="",
    card_type="攻击",
    cost=1,
    load=1,
    target_type="Enemy",
    range_=1,
    area=0,
    effects=[
        {"logic": "attack", "value": 8, "attack_range": 1, "alt_value": 13},
        {"logic": "defense", "value": 10, "alt_value": 7},
    ],
)
lines3 = ce.describe_effects(cond_card["effects"])
assert any("移动后 13" in s for s in lines3)
assert any("移动后 7" in s for s in lines3)
assert cond_card["effects"][0]["alt_value"] == 13
assert cond_card["effects"][1]["alt_value"] == 7

# ---------- 卡牌库同步校验（以 卡牌/cards/*.json 为准） ----------
def _library_sync_check():
    cards = ce.load_cards()
    assert len(cards) >= 40, "卡牌库应包含全部卡牌（%d）" % len(cards)
    known_logics = set(ce.LOGIC_MAP.values())
    for c in cards:
        assert c.get("card_type") in ce.CARD_TYPES, c.get("name")
        assert c.get("category") in ce.CATEGORIES, c.get("name")
        assert c.get("target_type") in ce.GDD_TARGET_TYPES, c.get("name")
        for eff in c.get("effects", []):
            assert eff.get("logic") in known_logics, "%s: 未知逻辑 %s" % (c.get("name"), eff.get("logic"))
            assert ce.describe_effects([eff]), "%s: 效果无描述 %s" % (c.get("name"), eff.get("logic"))
        # 关键词识别：keywords 数组与顶层布尔字段两种格式均以卡牌库数据为准
        for kw in ce.KEYWORDS:
            expect = (kw in (c.get("keywords") or [])) or bool(
                c.get(ce.KEYWORD_TOP_FIELDS.get(kw, ""), False))
            assert ce.keyword_active(c, kw) == expect, "%s: 关键词 %s 识别不一致" % (c.get("name"), kw)
    xiao_dao = next((c for c in cards if c.get("name") == "小刀"), None)
    assert xiao_dao is not None and ce.keyword_active(xiao_dao, "衍生"), "小刀：衍生应可识别（顶层字段）"
    print("LIB_SYNC_OK cards=%d" % len(cards))


_library_sync_check()

# ---------- 条件判断（condition） ----------
ce.refresh_condition_types()
assert ce.CONDITIONS and any(c["type"] == "enemies_in_range" for c in ce.CONDITIONS), "条件库应可加载"
assert ce.condition_text({"type": "moved_this_turn"}) == "本回合已移动"
assert "非" in ce.condition_text({"type": "moved_this_turn", "negate": True})
cond_card = ce.make_card(
    name="测试条件卡",
    category="通用卡牌",
    path="",
    card_type="攻击",
    cost=1,
    load=1,
    target_type="Enemy",
    range_=1,
    area=0,
    effects=[{"logic": "attack", "value": 8, "attack_range": 1,
             "condition": {"type": "enemies_in_range", "count": 2, "negate": True}}],
)
assert cond_card["effects"][0]["condition"]["type"] == "enemies_in_range"
assert cond_card["effects"][0]["condition"]["count"] == 2
assert cond_card["effects"][0]["condition"]["negate"] is True
clines = ce.describe_effects(cond_card["effects"])
assert any("如果" in s and "2 名敌人在攻击范围内" in s and "攻击" in s for s in clines), clines

print("EDITOR_TEST_OK")
