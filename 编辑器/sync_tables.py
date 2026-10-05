# -*- coding: utf-8 -*-
"""表格同步工具。

读取 编辑器/*.xlsx，把数据写入游戏可读取的位置：
- 角色数据.xlsx  -> content/characters/*.tres（游戏角色资源）
- NPC创建.xlsx   -> content/npcs/*.json（游戏 NpcDB 读取）
- 装备创建.xlsx  -> content/equipment/*.json（游戏 EquipDB 读取）
- buff创建.xlsx  -> content/buffs/*.json（游戏 BuffDB 读取）
- 敌怪创建.xlsx  -> content/enemies/*.json（游戏 EnemyDB 读取）
- 物品创建.xlsx  -> content/items/*.json（游戏 ItemDB 读取）
- 道途创建.xlsx  -> content/paths/*.json（游戏 PathDB 读取）
- 卡牌创建.xlsx  -> content/cards/*.json（游戏 CardDB 读取，效果用 JSON 数组列，可含 condition）

所有数据类均含统一美术接口字段：美术图标（icon）、美术资源（art）、美术动画（animation）；角色另有立绘（portrait），角色与敌怪另有尸骸美术 A/B。留空则继续使用对应占位。
用法：修改表格后运行本脚本（或双击 同步表格.bat），再启动游戏即可生效。
"""

import json
import re
from pathlib import Path

from openpyxl import load_workbook

BASE_DIR = Path(__file__).resolve().parent              # C:\游戏\编辑器
GAME_DIR = BASE_DIR.parent                 # C:\游戏
CHARACTERS_DIR = GAME_DIR / "content" / "characters"
NPCS_DIR = GAME_DIR / "content" / "npcs"
EQUIPMENT_DIR = GAME_DIR / "content" / "equipment"
BUFFS_DIR = GAME_DIR / "content" / "buffs"
ENEMIES_DIR = GAME_DIR / "content" / "enemies"
ITEMS_DIR = GAME_DIR / "content" / "items"
PATHS_DIR = GAME_DIR / "content" / "paths"
ENEMY_PACKS_FILE = GAME_DIR / "content" / "encounters" / "enemy_packs.json"
CARDS_DIR = GAME_DIR / "content" / "cards"

# 四名固定队员在游戏资源中的文件名映射（Main.tscn 引用这些文件）
CHARACTER_FILE_ALIASES = {
    "艾莉丝": "alice",
    "鲍德温": "baldwin",
    "迪马斯": "dismas",
    "卡莎": "kasha",
}


def _sanitize(name):
    return re.sub(r'[\\/:*?"<>|\s]+', "_", str(name)).strip("_") or "未命名"


def _cell(row, index, default=""):
    if index < 0 or index >= len(row):
        return default
    value = row[index]
    if value is None:
        return default
    return str(value).strip()


def _int_cell(row, index, default=0):
    try:
        return int(float(_cell(row, index, default)))
    except Exception:
        return default


def _float_cell(row, index, default=0.0):
    try:
        return float(_cell(row, index, default))
    except Exception:
        return default


def _hex_to_color(hex_str, default=(0.42, 0.60, 0.90)):
    h = str(hex_str).strip().lstrip("#")
    if len(h) != 6:
        return default
    try:
        return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    except Exception:
        return default


def _read_sheet(path):
    if not path.exists():
        return []
    wb = load_workbook(path, data_only=True)
    ws = wb.active
    rows = []
    for row in ws.iter_rows(values_only=True):
        if row is None:
            continue
        if all(c is None or str(c).strip() == "" for c in row):
            continue
        rows.append(row)
    wb.close()
    return rows


def _column_map(headers):
    """把表头按关键词映射为列下标（找不到返回 -1），支持不同布局。"""
    keys = {
        "name": ["名称"],
        "alignment": ["阵营"],
        "type": ["类型"],
        "value": ["数值", "价值"],
        "shape": ["形状"],
        "base_duration": ["基础持续"],
        "duration_per_stack": ["每层持续"],
        "decay": ["每回合是否衰减", "衰减"],
        "consumed": ["触发后是否消失", "消失"],
        "timing": ["触发时机", "时机"],
        "condition": ["触发条件", "条件"],
        "description": ["描述"],
        "hp_min": ["最小血量"],
        "hp_max": ["最大血量"],
        "attack_min": ["最小攻击"],
        "attack_max": ["最大攻击"],
        "attack_range": ["攻击距离"],
        "move_points": ["移动力"],
        "agility": ["敏捷"],
        "ai": ["AI"],
        "archetype": ["行为模板", "archetype"],
        "ai_profile": ["AI参数", "ai_profile"],
        "skills": ["技能集", "skills"],
        "coin_min": ["钱币下限"],
        "coin_max": ["钱币上限"],
        "exp": ["经验"],
        "loot": ["战利品表"],
        "tier": ["难度"],
        "slot": ["部位"],
        "character": ["归属角色"],
        "passive_name": ["被动名称"],
        "passive_description": ["被动描述"],
        "passive_timing": ["被动触发时机"],
        "passive_value": ["被动数值"],
        "starter": ["专属初始牌"],
        "color": ["色块颜色"],
        # 美术资源接口：icon（图标）/ art（主体）/ animation（动画），角色另有 portrait（立绘）
        "art": ["美术资源"],
        "icon": ["美术图标", "图标"],
        "animation": ["美术动画", "动画资源", "动画"],
        "corpse_art_a": ["尸骸美术A", "尸骸资源A", "尸骸A"],
        "corpse_art_b": ["尸骸美术B", "尸骸资源B", "尸骸B"],
        "mods": ["修正", "mods"],
        "portrait": ["立绘", "头像"],
        "interaction": ["互动选项"],
        "dialogue": ["对话树"],
        "pack_name": ["小队名称"],
        "pack_tier": ["强度"],
        "pack_description": ["描述"],
        "pack_members": ["成员列表"],
        "category": ["分类"],
        "path": ["道途名", "道途（"],
        "card_type": ["卡牌类型"],
        "cost": ["费用"],
        "load": ["荷载"],
        "target_type": ["目标类型"],
        "range": ["范围"],
        "area": ["区域"],
        "keywords": ["关键词"],
        "effects": ["效果列表"],
        "discard_on_use": ["打出后消失"],
    }
    result = {}
    for key, keywords in keys.items():
        found = -1
        for i, header in enumerate(headers):
            for kw in keywords:
                if kw in header:
                    found = i
                    break
            if found >= 0:
                break
        result[key] = found
    return result


def sync_characters():
    rows = _read_sheet(BASE_DIR / "角色数据.xlsx")
    if not rows:
        print("角色数据.xlsx 缺失或为空")
        return 0
    headers = [str(h) if h is not None else "" for h in rows[0]]
    col = _column_map(headers)
    count = 0
    for row in rows[1:]:
        name = _cell(row, 0)
        if not name:
            continue
        file_stem = CHARACTER_FILE_ALIASES.get(name, _sanitize(name))
        character_path = CHARACTERS_DIR / ("%s.tres" % file_stem)
        corpse_art_a = _cell(row, col["corpse_art_a"])
        corpse_art_b = _cell(row, col["corpse_art_b"])
        if character_path.exists():
            existing_text = character_path.read_text(encoding="utf-8")
            if col["corpse_art_a"] < 0:
                match = re.search(r'^corpse_art_a_path = "([^"]*)"', existing_text, re.MULTILINE)
                corpse_art_a = match.group(1) if match else ""
            if col["corpse_art_b"] < 0:
                match = re.search(r'^corpse_art_b_path = "([^"]*)"', existing_text, re.MULTILINE)
                corpse_art_b = match.group(1) if match else ""
        r, g, b = _hex_to_color(_cell(row, 9))
        lines = [
            '[gd_resource type="Resource" script_class="CharacterData" load_steps=2 format=3]',
            '',
            '[ext_resource type="Script" path="res://core/character/character_data.gd" id="1"]',
            '',
            '[resource]',
            'script = ExtResource("1")',
            'character_name = "%s"' % name,
            'path_name = "%s"' % _cell(row, 1),
            'level = %d' % _int_cell(row, 2),
            'strength = %d' % _int_cell(row, 3, 10),
            'agility = %d' % _int_cell(row, 4, 10),
            'endurance = %d' % _int_cell(row, 5, 10),
            'willpower = %d' % _int_cell(row, 6, 10),
            'strength_damage_bonus = %.3f' % _float_cell(row, 10, 0.0),
            'base_hp = %d' % _int_cell(row, 7, 100),
            'endurance_hp_bonus = %d' % _int_cell(row, 8, 5),
            'block_color = Color(%.3f, %.3f, %.3f, 1)' % (r, g, b),
            'icon_path = "%s"' % _cell(row, col["icon"]),
            'portrait_path = "%s"' % _cell(row, col["portrait"]),
            'art_path = "%s"' % _cell(row, col["art"]),
            'animation_path = "%s"' % _cell(row, col["animation"]),
            'corpse_art_a_path = "%s"' % corpse_art_a,
            'corpse_art_b_path = "%s"' % corpse_art_b,
        ]
        content = "\n".join(lines) + "\n"
        CHARACTERS_DIR.mkdir(parents=True, exist_ok=True)
        (CHARACTERS_DIR / ("%s.tres" % file_stem)).write_text(content, encoding="utf-8")
        count += 1
    print("角色同步：%d 名" % count)
    return count


def sync_npcs():
    rows = _read_sheet(BASE_DIR / "NPC创建.xlsx")
    if not rows:
        print("NPC创建.xlsx 缺失或为空")
        return 0
    headers = [str(h) if h is not None else "" for h in rows[0]]
    col = _column_map(headers)
    count = 0
    for row in rows[1:]:
        name = _cell(row, col["name"])
        if not name:
            continue
        r, g, b = _hex_to_color(_cell(row, col["color"]), (0.36, 0.48, 0.63))
        interaction_text = _cell(row, col["interaction"])
        interactions = [s.strip() for s in re.split(r"[；;]", interaction_text) if s.strip()]
        dialogue_raw = _cell(row, col["dialogue"])
        dialogue = []
        if dialogue_raw:
            try:
                parsed = json.loads(dialogue_raw)
                if isinstance(parsed, list):
                    dialogue = parsed
            except Exception:
                dialogue = [{"text": dialogue_raw}]
        data = {
            "id": _sanitize(name),
            "name": name,
            "description": _cell(row, col["description"]),
            "color": "#%02x%02x%02x" % (int(r * 255), int(g * 255), int(b * 255)),
            "icon": _cell(row, col["icon"]),
            "art": _cell(row, col["art"]),
            "animation": _cell(row, col["animation"]),
            "ai": _cell(row, col["ai"]),
            "interaction": interactions,
            "dialogue": dialogue,
        }
        # 表格无“行动轨迹”列时，保留 JSON 中已有的 schedule（时间轴），避免同步覆盖丢失
        existing = NPCS_DIR / ("%s.json" % _sanitize(name))
        if existing.exists():
            try:
                old = json.loads(existing.read_text(encoding="utf-8"))
                if isinstance(old, dict) and old.get("schedule"):
                    data["schedule"] = old["schedule"]
            except Exception:
                pass
        NPCS_DIR.mkdir(parents=True, exist_ok=True)
        (NPCS_DIR / ("%s.json" % _sanitize(name))).write_text(
            json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        count += 1
    print("NPC 同步：%d 个" % count)
    return count


def sync_equipment():
    rows = _read_sheet(BASE_DIR / "装备创建.xlsx")
    if not rows:
        print("装备创建.xlsx 缺失或为空")
        return 0
    headers = [str(h) if h is not None else "" for h in rows[0]]
    col = _column_map(headers)
    count = 0
    for row in rows[1:]:
        name = _cell(row, col["name"])
        if not name:
            continue
        # 有舍有得修正：优先读表格「修正」JSON 列；表格无该列时保留现有 JSON 的 mods
        json_path = EQUIPMENT_DIR / ("%s.json" % _sanitize(name))
        mods = []
        if json_path.exists():
            try:
                existing = json.loads(json_path.read_text(encoding="utf-8"))
                if isinstance(existing, dict) and isinstance(existing.get("mods"), list):
                    mods = existing["mods"]
            except Exception:
                mods = []
        mods_raw = _cell(row, col["mods"]) if col.get("mods", -1) >= 0 else ""
        if mods_raw:
            try:
                parsed = json.loads(mods_raw)
                if isinstance(parsed, list):
                    mods = parsed
            except Exception:
                pass
        data = {
            "id": _sanitize(name),
            "name": name,
            "slot": _cell(row, col["slot"]),
            "description": _cell(row, col["description"]),
            "icon": _cell(row, col["icon"]),
            "art": _cell(row, col["art"]),
            "animation": _cell(row, col["animation"]),
            "mods": mods,
        }
        EQUIPMENT_DIR.mkdir(parents=True, exist_ok=True)
        json_path.write_text(
            json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        count += 1
    print("装备同步：%d 件" % count)
    return count


def sync_buffs():
    rows = _read_sheet(BASE_DIR / "buff创建.xlsx")
    if not rows:
        print("buff创建.xlsx 缺失或为空")
        return 0
    headers = [str(h) if h is not None else "" for h in rows[0]]
    col = _column_map(headers)
    names = []
    for row in rows[1:]:
        name = _cell(row, col["name"])
        if not name:
            continue
        names.append(name)
        decay_text = _cell(row, col["decay"], "否")
        decay_amount = 1
        match = re.search(r"衰减\s*(\d+)", decay_text)
        if match:
            decay_amount = int(match.group(1))
        data = {
            "id": _sanitize(name),
            "name": name,
            "alignment": _cell(row, col["alignment"], "中立"),
            "type": _cell(row, col["type"], "持续"),
            "value": _int_cell(row, col["value"], 0),
            "base_duration": _int_cell(row, col["base_duration"], 1),
            "duration_per_stack": _int_cell(row, col["duration_per_stack"], 0),
            "decay_per_turn": decay_text == "是" or "衰减" in decay_text,
            "decay_amount": decay_amount,
            "consumed_on_trigger": _cell(row, col["consumed"], "否") == "是",
            "trigger_timing": _cell(row, col["timing"]),
            "trigger_condition": _cell(row, col["condition"]),
            "description": _cell(row, col["description"]),
            "icon": _cell(row, col["icon"]),
            "art": _cell(row, col["art"]),
            "animation": _cell(row, col["animation"]),
        }
        BUFFS_DIR.mkdir(parents=True, exist_ok=True)
        (BUFFS_DIR / ("%s.json" % _sanitize(name))).write_text(
            json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    for f in BUFFS_DIR.glob("*.json"):
        try:
            d = json.loads(f.read_text(encoding="utf-8"))
            if isinstance(d, dict) and "name" in d and d.get("name") not in names:
                f.unlink()
        except Exception:
            continue
    print("buff 同步：%d 个" % len(names))
    return len(names)


def sync_enemies():
    rows = _read_sheet(BASE_DIR / "敌怪创建.xlsx")
    if not rows:
        print("敌怪创建.xlsx 缺失或为空")
        return 0
    headers = [str(h) if h is not None else "" for h in rows[0]]
    col = _column_map(headers)
    names = []
    for row in rows[1:]:
        name = _cell(row, col["name"])
        if not name:
            continue
        names.append(name)
        r, g, b = _hex_to_color(_cell(row, col["color"]), (0.6, 0.6, 0.6))
        json_path = ENEMIES_DIR / ("%s.json" % _sanitize(name))
        existing = {}
        if json_path.exists():
            try:
                parsed = json.loads(json_path.read_text(encoding="utf-8"))
                existing = parsed if isinstance(parsed, dict) else {}
            except Exception:
                existing = {}
        corpse_art_a = (_cell(row, col["corpse_art_a"])
                        if col["corpse_art_a"] >= 0 else str(existing.get("corpse_art_a", "")))
        corpse_art_b = (_cell(row, col["corpse_art_b"])
                        if col["corpse_art_b"] >= 0 else str(existing.get("corpse_art_b", "")))
        data = {
            "id": _sanitize(name),
            "name": name,
            "hp_min": _int_cell(row, col["hp_min"], 100),
            "hp_max": _int_cell(row, col["hp_max"], 100),
            "attack_min": _int_cell(row, col["attack_min"], 0),
            "attack_max": _int_cell(row, col["attack_max"], 0),
            "attack_range": _int_cell(row, col["attack_range"], 1),
            "move_points": _int_cell(row, col["move_points"], 0),
            "agility": _int_cell(row, col["agility"], 5),
            "ai": _cell(row, col["ai"], "无"),
            "archetype": _cell(row, col["archetype"], ""),
            "ai_profile": _cell(row, col["ai_profile"], ""),
            "skills": _cell(row, col["skills"], ""),
            "coin_min": _int_cell(row, col["coin_min"], 0),
            "coin_max": _int_cell(row, col["coin_max"], 0),
            "exp": _int_cell(row, col["exp"], 0),
            "loot_table": _parse_loot_table(_cell(row, col["loot"])),
            "tier": _cell(row, col["tier"], "普通"),
            "color": "#%02x%02x%02x" % (int(r * 255), int(g * 255), int(b * 255)),
            "description": _cell(row, col["description"]),
            "icon": _cell(row, col["icon"]),
            "art": _cell(row, col["art"]),
            "animation": _cell(row, col["animation"]),
            "corpse_art_a": corpse_art_a,
            "corpse_art_b": corpse_art_b,
        }
        ENEMIES_DIR.mkdir(parents=True, exist_ok=True)
        json_path.write_text(
            json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    for f in ENEMIES_DIR.glob("*.json"):
        try:
            d = json.loads(f.read_text(encoding="utf-8"))
            if isinstance(d, dict) and "name" in d and d.get("name") not in names:
                f.unlink()
        except Exception:
            continue
    print("敌怪同步：%d 个" % len(names))
    return len(names)


def _parse_keywords(raw):
    """解析关键词：支持 JSON 数组或 中文逗号/顿号 分隔。"""
    raw = str(raw).strip()
    if not raw:
        return []
    if raw.startswith("["):
        try:
            parsed = json.loads(raw)
            if isinstance(parsed, list):
                return [str(x).strip() for x in parsed if str(x).strip()]
        except Exception:
            pass
    return [s.strip() for s in re.split(r"[，,；;、]", raw) if s.strip()]


def _parse_loot_table(raw):
    """解析战利品表：优先 JSON 数组，失败则返回空表。"""
    if not raw:
        return []
    try:
        parsed = json.loads(raw)
        if isinstance(parsed, list):
            return parsed
    except Exception:
        pass
    return []


def sync_items():
    rows = _read_sheet(BASE_DIR / "物品创建.xlsx")
    if not rows:
        print("物品创建.xlsx 缺失或为空")
        return 0
    headers = [str(h) if h is not None else "" for h in rows[0]]
    col = _column_map(headers)
    names = []
    for row in rows[1:]:
        name = _cell(row, col["name"])
        if not name:
            continue
        names.append(name)
        data = {
            "id": _sanitize(name),
            "name": name,
            "description": _cell(row, col["description"]),
            "shape": _cell(row, col["shape"], "1x1"),
            "value": _int_cell(row, col["value"], 0),
            "icon": _cell(row, col["icon"]),
            "art": _cell(row, col["art"]),
            "animation": _cell(row, col["animation"]),
        }
        ITEMS_DIR.mkdir(parents=True, exist_ok=True)
        (ITEMS_DIR / ("%s.json" % _sanitize(name))).write_text(
            json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    for f in ITEMS_DIR.glob("*.json"):
        try:
            d = json.loads(f.read_text(encoding="utf-8"))
            if isinstance(d, dict) and "name" in d and d.get("name") not in names:
                f.unlink()
        except Exception:
            continue
    print("物品同步：%d 件" % len(names))
    return len(names)


def sync_paths():
    rows = _read_sheet(BASE_DIR / "道途创建.xlsx")
    if not rows:
        print("道途创建.xlsx 缺失或为空")
        return 0
    headers = [str(h) if h is not None else "" for h in rows[0]]
    col = _column_map(headers)
    names = []
    for row in rows[1:]:
        name = _cell(row, col["name"])
        if not name:
            continue
        names.append(name)
        data = {
            "id": _sanitize(name),
            "name": name,
            "character": _cell(row, col["character"]),
            "description": _cell(row, col["description"]),
            "passive": {
                "name": _cell(row, col["passive_name"]),
                "description": _cell(row, col["passive_description"]),
                "trigger_timing": _cell(row, col["passive_timing"]),
                "value": _int_cell(row, col["passive_value"], 0),
            },
            "starter_cards": _parse_loot_table(_cell(row, col["starter"])),
            "icon": _cell(row, col["icon"]),
            "art": _cell(row, col["art"]),
            "animation": _cell(row, col["animation"]),
        }
        PATHS_DIR.mkdir(parents=True, exist_ok=True)
        (PATHS_DIR / ("%s.json" % _sanitize(name))).write_text(
            json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    for f in PATHS_DIR.glob("*.json"):
        try:
            d = json.loads(f.read_text(encoding="utf-8"))
            if isinstance(d, dict) and "name" in d and d.get("name") not in names:
                f.unlink()
        except Exception:
            continue
    print("道途同步：%d 个" % len(names))
    return len(names)


def sync_enemy_packs():
    """敌怪小队表：读取 敌怪小队创建.xlsx，生成 数据/enemy_packs.json。
    每支小队 3~4 只相互配合的敌怪，按强度（普通/精英/Boss）分类，
    战斗时从符合强度的若干小队中随机抽取一支。"""
    rows = _read_sheet(BASE_DIR / "敌怪小队创建.xlsx")
    if not rows:
        print("敌怪小队创建.xlsx 缺失或为空")
        return 0
    headers = [str(h) if h is not None else "" for h in rows[0]]
    col = _column_map(headers)
    packs = []
    for row in rows[1:]:
        name = _cell(row, col["pack_name"])
        if not name:
            continue
        packs.append({
            "id": _sanitize(name),
            "name": name,
            "tier": _cell(row, col["pack_tier"], "普通"),
            "description": _cell(row, col["pack_description"]),
            "members": _parse_loot_table(_cell(row, col["pack_members"])),
        })
    ENEMY_PACKS_FILE.parent.mkdir(parents=True, exist_ok=True)
    ENEMY_PACKS_FILE.write_text(
        json.dumps({"version": 1, "packs": packs}, ensure_ascii=False, indent=2),
        encoding="utf-8")
    print("敌怪小队同步：%d 支" % len(packs))
    return len(packs)


def sync_cards():
    """卡牌同步：读取 卡牌创建.xlsx，生成 content/cards/*.json。
    一行一张卡；效果列表用 JSON 数组列（可含 condition）；关键词支持数组或分隔文本。
    Excel 中不存在的卡会被清理（回收站 .trash 不受影响）。"""
    rows = _read_sheet(BASE_DIR / "卡牌创建.xlsx")
    if not rows:
        print("卡牌创建.xlsx 缺失或为空")
        return 0
    headers = [str(h) if h is not None else "" for h in rows[0]]
    col = _column_map(headers)
    names = []
    for row in rows[1:]:
        name = _cell(row, col["name"])
        if not name:
            continue
        names.append(name)
        data = {
            "id": _sanitize(name),
            "name": name,
            "category": _cell(row, col["category"], "通用卡牌"),
            "path": _cell(row, col["path"]),
            "card_type": _cell(row, col["card_type"], "攻击"),
            "cost": _int_cell(row, col["cost"], 0),
            "load": _int_cell(row, col["load"], 1),
            "target_type": _cell(row, col["target_type"], "Self"),
            "range": _int_cell(row, col["range"], 0),
            "area": _int_cell(row, col["area"], 0),
            "discard_on_use": _cell(row, col["discard_on_use"], "否") == "是",
            "keywords": _parse_keywords(_cell(row, col["keywords"])),
            "icon": _cell(row, col["icon"]),
            "art": _cell(row, col["art"]),
            "animation": _cell(row, col["animation"]),
            "description": _cell(row, col["description"]),
            "effects": _parse_loot_table(_cell(row, col["effects"])),
        }
        CARDS_DIR.mkdir(parents=True, exist_ok=True)
        (CARDS_DIR / ("%s.json" % _sanitize(name))).write_text(
            json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    for f in CARDS_DIR.glob("*.json"):
        try:
            d = json.loads(f.read_text(encoding="utf-8"))
            if isinstance(d, dict) and "name" in d and d.get("name") not in names:
                f.unlink()
        except Exception:
            continue
    print("卡牌同步：%d 张" % len(names))
    return len(names)


def main():
    sync_characters()
    sync_npcs()
    sync_equipment()
    sync_buffs()
    sync_enemies()
    sync_items()
    sync_paths()
    sync_enemy_packs()
    sync_cards()
    print("SYNC_DONE")


if __name__ == "__main__":
    main()
