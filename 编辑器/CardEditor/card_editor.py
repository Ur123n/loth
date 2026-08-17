# -*- coding: utf-8 -*-
"""卡牌制作编辑器（独立于 Godot 运行）。

双击 C:\\游戏\\启动卡牌编辑器.bat 启动。
生成的卡牌 JSON 保存到：C:\\游戏\\content\\cards\\
功能：
- 单张卡支持多条逻辑链，按编辑器中的顺序触发（effects 数组顺序即触发顺序）
- 卡面生成器：文字卡面（费用 / 负载 / 卡名 / 效果），含图片槽占位
- 可读取本机图片作为卡面图（自动复制到 卡牌/card_faces/，预览与 PNG 导出均使用）
- 荷载允许为 0
"""

import json
import os
import re
import time
from pathlib import Path

import tkinter as tk
from tkinter import ttk, messagebox, filedialog

try:
    from PIL import Image, ImageDraw, ImageFont, ImageTk
    HAVE_PIL = True
except Exception:
    HAVE_PIL = False

BASE_DIR = Path(__file__).resolve().parents[2]          # C:\游戏
CARDS_DIR = BASE_DIR / "content" / "cards"
FACE_DIR = BASE_DIR / "content" / "card_faces"
BUFFS_DIR = BASE_DIR / "content" / "buffs"
TRASH_DIR = CARDS_DIR / ".trash"   # 删除的卡牌移入此处（可手动恢复）

CARD_TYPES = ["攻击", "行动", "能力"]
CATEGORIES = ["通用卡牌", "道途专属卡牌"]
LOGICS = ["攻击", "移动", "防御", "给予buff", "抽牌", "弃牌", "加入手牌", "加入抽牌堆", "加入弃牌堆", "生成牌", "复制", "失去生命", "获得费用", "伺机反打", "击退"]
BUFF_TARGETS = ["自身", "友方", "敌方"]
PILE_TARGETS = ["手牌", "抽牌堆", "弃牌堆"]
DISCARD_MODES = ["随机", "全部"]
DRAW_POSITIONS = ["洗入", "置于顶部"]
HP_TARGETS = ["自身", "敌方"]
GENERATE_POOLS = ["", "攻击", "行动", "能力", "全部"]
KEYWORDS = ["消耗", "保留", "虚无", "固有", "沉梦", "幻梦", "灾梦", "衍生", "吸血"]
GDD_TARGET_TYPES = ["Self", "Ally", "Enemy", "Hex", "Area", "None"]
BUFF_TYPES = [""]   # buff 种类（运行时从 数据/buffs 加载）
CONDITIONS_FILE = BASE_DIR / "content" / "cards" / "conditions.json"
CONDITION_NONE = "无条件"
CONDITIONS = []     # 条件类型（运行时从 卡牌/conditions.json 加载）

## 关键词与卡牌 JSON 顶层布尔字段的对应关系（兼容旧格式，如 小刀 的 derived 字段）。
## 以卡牌库数据为准：keywords 数组为主，顶层字段为辅。
KEYWORD_TOP_FIELDS = {"衍生": "derived", "吸血": "lifesteal"}


## 关键词是否在卡牌上生效（keywords 数组优先，兼容顶层布尔字段）。
def keyword_active(card: dict, kw: str) -> bool:
    if kw in (card.get("keywords") or []):
        return True
    field = KEYWORD_TOP_FIELDS.get(kw)
    return bool(card.get(field, False)) if field else False

LOGIC_MAP = {"攻击": "attack", "移动": "move", "防御": "defense", "给予buff": "buff",
             "抽牌": "draw", "弃牌": "discard", "加入手牌": "add_to_hand",
             "加入抽牌堆": "add_to_draw", "加入弃牌堆": "add_to_discard",
             "生成牌": "generate", "复制": "copy", "失去生命": "lose_hp", "获得费用": "gain_energy",
             "伺机反打": "flank", "击退": "knockback"}
BUFF_TARGET_MAP = {"自身": "self", "友方": "ally", "敌方": "enemy"}
BUFF_TARGET_LABEL = {v: k for k, v in BUFF_TARGET_MAP.items()}
PILE_MAP = {"手牌": "hand", "抽牌堆": "draw", "弃牌堆": "discard"}
PILE_LABEL = {v: k for k, v in PILE_MAP.items()}
DISCARD_MODE_MAP = {"随机": "random", "全部": "all"}
DISCARD_MODE_LABEL = {v: k for k, v in DISCARD_MODE_MAP.items()}
DRAW_POSITION_MAP = {"洗入": "shuffle", "置于顶部": "top"}
DRAW_POSITION_LABEL = {v: k for k, v in DRAW_POSITION_MAP.items()}
HP_TARGET_MAP = {"自身": "self", "敌方": "enemy"}
HP_TARGET_LABEL = {v: k for k, v in HP_TARGET_MAP.items()}

## 从 content/buffs/*.json 读取可用 buff 名称，供“给予buff”逻辑选择。
def load_buff_names() -> list:
    names = []
    if BUFFS_DIR.exists():
        for f in sorted(BUFFS_DIR.glob("*.json")):
            try:
                data = json.loads(f.read_text(encoding="utf-8"))
                name = str(data.get("name", "")).strip()
                if name:
                    names.append(name)
            except Exception:
                continue
    return names


def refresh_buff_types() -> None:
    global BUFF_TYPES
    names = load_buff_names()
    BUFF_TYPES = [""] + names


## 从 卡牌/conditions.json 读取条件类型清单（供“条件”下拉与描述）。
def load_condition_types() -> list:
    if not CONDITIONS_FILE.exists():
        return []
    try:
        data = json.loads(CONDITIONS_FILE.read_text(encoding="utf-8"))
        return [c for c in data.get("conditions", []) if isinstance(c, dict)]
    except Exception:
        return []


def refresh_condition_types() -> None:
    global CONDITIONS
    CONDITIONS = load_condition_types()


## 条件的中文描述（与 Godot describe_card 保持一致）。
def condition_text(condition: dict) -> str:
    if not condition:
        return ""
    negate = bool(condition.get("negate", False))
    text = ""
    ctype = condition.get("type", "")
    if ctype == "enemies_in_range":
        text = "%d 名敌人在攻击范围内" % int(condition.get("count", 1))
    elif ctype == "moved_this_turn":
        text = "本回合已移动"
    elif ctype == "not_moved_this_turn":
        text = "本回合未移动"
    elif ctype == "hp_below_pct":
        text = "生命低于 %d%%" % int(condition.get("pct", 50))
    elif ctype == "hand_size_at_least":
        text = "手牌不少于 %d 张" % int(condition.get("count", 1))
    elif ctype == "energy_at_least":
        text = "费用不少于 %d" % int(condition.get("value", 1))
    elif ctype == "has_buff":
        text = "持有「%s」" % str(condition.get("buff_name", ""))
    elif ctype == "enemies_alive_at_least":
        text = "场上敌人不少于 %d" % int(condition.get("count", 1))
    elif ctype == "last_card_keyword":
        text = "上一张牌带「%s」" % str(condition.get("keyword", ""))
    if negate and text:
        text = "非" + text
    return text


def _describe_condition_prefix(effect) -> str:
    condition = effect.get("condition") if isinstance(effect, dict) else None
    if not condition:
        return ""
    text = condition_text(condition)
    if not text:
        return ""
    return "如果%s，则 " % text

ART_SLOT = (70, 100, 290, 218)   # 卡面图片槽（卡面坐标系）


# ---------- 数据层（可脱离 GUI 单独测试） ----------

def _sanitize_name(name: str) -> str:
    return re.sub(r'[\\/:*?"<>|\s]+', "_", name).strip("_") or "卡牌"


def make_card(name, category, path, card_type, cost, load, target_type,
              range_, area, effects, keywords=None) -> dict:
    """根据编辑器输入构造一张卡的 JSON 数据。
    effects 列表顺序即触发顺序（底层逻辑链依次结算）。
    keywords 为卡牌关键词列表（消耗 / 保留 / 虚无 / 固有）。
    """
    return {
        "id": "%s_%d" % (_sanitize_name(name), int(time.time() * 1000)),
        "name": name,
        "category": category,
        "path": path,
        "card_type": card_type,
        "cost": int(cost),
        "load": int(load),          # 荷载允许为 0
        "target_type": target_type,
        "range": int(range_),
        "area": int(area),
        "discard_on_use": card_type == "能力",   # 能力牌打出后自动消失（底层逻辑）
        "keywords": list(keywords or []),        # 消耗/保留/虚无/固有
        "icon": "",                 # 美术接口：图标（相对 卡牌/ 目录，未设置留空）
        "art": "",                  # 美术接口：卡面图（相对 卡牌/ 目录，未设置留空）
        "animation": "",            # 美术接口：动画/特效资源（相对 卡牌/ 目录，未设置留空）
        "effects": list(effects),
    }


def save_card(data: dict) -> Path:
    CARDS_DIR.mkdir(parents=True, exist_ok=True)
    path = CARDS_DIR / ("%s.json" % data["id"])
    # 原子写入：先写临时文件再替换，避免中途关闭/写入失败导致卡牌库损坏
    tmp = CARDS_DIR / ("%s.json.tmp" % data["id"])
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    os.replace(tmp, path)
    return path


def load_cards() -> list:
    if not CARDS_DIR.exists():
        return []
    cards = []
    for f in sorted(CARDS_DIR.glob("*.json")):
        try:
            data = json.loads(f.read_text(encoding="utf-8"))
            # 只加载真正的卡牌（含 name 字段）；conditions.json 等配置文件跳过
            if isinstance(data, dict) and data.get("name"):
                cards.append(data)
        except Exception:
            continue
    return cards


def delete_card(card_id: str) -> bool:
    """把卡牌移入回收目录（卡牌/cards/.trash/），可从那里手动恢复。"""
    path = CARDS_DIR / ("%s.json" % card_id)
    if not path.exists():
        return False
    TRASH_DIR.mkdir(parents=True, exist_ok=True)
    dest = TRASH_DIR / path.name
    if dest.exists():
        dest = TRASH_DIR / ("%s_%d.json" % (path.stem, int(time.time() * 1000)))
    path.replace(dest)
    return True


# ---------- 卡面图片 ----------

def resolve_art_path(art_path: str) -> Path:
    """把卡牌 JSON 中的 art_path 解析为绝对路径；相对路径以 卡牌/ 目录为基准。"""
    if not art_path:
        return None
    p = Path(art_path)
    if not p.is_absolute():
        p = CARDS_DIR.parent / art_path
    return p if p.exists() else None


def load_art_image(art_path: str):
    """读取卡面图（PIL Image 或 None）。"""
    if not HAVE_PIL:
        return None
    p = resolve_art_path(art_path)
    if p is None:
        return None
    try:
        return Image.open(p).convert("RGBA")
    except Exception:
        return None


def contain_image(img, max_w: int, max_h: int):
    """等比缩放图片到不超过 max_w x max_h。"""
    scale = min(max_w / img.width, max_h / img.height)
    nw = max(1, int(img.width * scale))
    nh = max(1, int(img.height * scale))
    return img.resize((nw, nh), Image.LANCZOS)


def _paste_contain(base_img, art, box):
    bx0, by0, bx1, by1 = box
    bw, bh = bx1 - bx0, by1 - by0
    fit = contain_image(art, bw, bh)
    x = bx0 + (bw - fit.width) // 2
    y = by0 + (bh - fit.height) // 2
    base_img.paste(fit, (x, y), fit)


# ---------- 卡面生成（文字卡面，可脱离 GUI 测试） ----------

def _font(size: int):
    candidates = [
        "C:/Windows/Fonts/msyh.ttc",
        "C:/Windows/Fonts/msyh.ttf",
        "C:/Windows/Fonts/simhei.ttf",
        "C:/Windows/Fonts/simsun.ttc",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            continue
    return ImageFont.load_default()


def describe_effects(effects) -> list:
    """把逻辑链数组转换为卡面展示用的中文描述（顺序即触发顺序，含条件前缀）。"""
    lines = []
    for i, eff in enumerate(effects, 1):
        cond_prefix = _describe_condition_prefix(eff)
        logic = eff.get("logic")
        if logic == "attack":
            pierce = "，无视护甲" if eff.get("pierce") else ""
            alt = "，移动后 %d" % int(eff.get("alt_value", 0)) if int(eff.get("alt_value", 0)) > 0 else ""
            lines.append("%d. %s攻击：造成 %d 点伤害，攻击范围 %d%s%s"
                         % (i, cond_prefix, int(eff.get("value", 0)), int(eff.get("attack_range", 0)), pierce, alt))
        elif logic == "move":
            lines.append("%d. %s移动：移动 %d 格" % (i, cond_prefix, int(eff.get("distance", 0))))
        elif logic == "defense":
            alt = "，移动后 %d" % int(eff.get("alt_value", 0)) if int(eff.get("alt_value", 0)) > 0 else ""
            lines.append("%d. %s防御：获得 %d 点防御%s" % (i, cond_prefix, int(eff.get("value", 0)), alt))
        elif logic == "buff":
            target = BUFF_TARGET_LABEL.get(eff.get("target", ""), str(eff.get("target", "")))
            buff = eff.get("buff_type", "") or "（待定）"
            stacks = int(eff.get("stacks", 1))
            stacks_text = "" if stacks == 1 else "%d 层" % stacks
            duration_value = int(eff.get("duration", 0))
            duration_text = "%d 回合" % duration_value if duration_value > 0 else "按 buff 数据自动"
            lines.append("%d. %sbuff：对 %s 施加 %s%s，持续 %s"
                         % (i, cond_prefix, target, buff, stacks_text, duration_text))
        elif logic == "draw":
            lines.append("%d. %s抽牌：抽 %d 张牌" % (i, cond_prefix, int(eff.get("value", 1))))
        elif logic == "discard":
            if eff.get("mode") == "all":
                lines.append("%d. %s弃牌：弃掉全部手牌" % (i, cond_prefix))
            else:
                lines.append("%d. %s弃牌：随机弃掉 %d 张手牌" % (i, cond_prefix, int(eff.get("value", 1))))
        elif logic == "add_to_hand":
            lines.append("%d. %s加入手牌：将 %d 张「%s」加入手牌"
                         % (i, cond_prefix, int(eff.get("value", 1)), eff.get("card", "")))
        elif logic == "add_to_draw":
            pos = DRAW_POSITION_LABEL.get(eff.get("position", "shuffle"), "洗入")
            lines.append("%d. %s加入抽牌堆：将 %d 张「%s」%s抽牌堆"
                         % (i, cond_prefix, int(eff.get("value", 1)), eff.get("card", ""), pos))
        elif logic == "add_to_discard":
            lines.append("%d. %s加入弃牌堆：将 %d 张「%s」加入弃牌堆"
                         % (i, cond_prefix, int(eff.get("value", 1)), eff.get("card", "")))
        elif logic == "generate":
            source = eff.get("card", "") or ("随机" + str(eff.get("pool", "")) if eff.get("pool") else "随机牌")
            pile = PILE_LABEL.get(eff.get("pile", "hand"), "手牌")
            lines.append("%d. %s生成牌：生成 %d 张「%s」到%s"
                         % (i, cond_prefix, int(eff.get("value", 1)), source, pile))
        elif logic == "copy":
            pile = PILE_LABEL.get(eff.get("pile", "discard"), "弃牌堆")
            lines.append("%d. %s复制：将本牌的 %d 张复制品加入%s" % (i, cond_prefix, int(eff.get("value", 1)), pile))
        elif logic == "lose_hp":
            who = HP_TARGET_LABEL.get(eff.get("target", "self"), "自身")
            lines.append("%d. %s失去生命：%s失去 %d 点生命（无视格挡）" % (i, cond_prefix, who, int(eff.get("value", 1))))
        elif logic == "gain_energy":
            lines.append("%d. %s获得费用：获得 %d 点费用" % (i, cond_prefix, int(eff.get("value", 1))))
        elif logic == "flank":
            lines.append("%d. %s伺机：本回合内离开攻击范围时，造成 %d 点伤害" % (i, cond_prefix, int(eff.get("value", 7))))
        elif logic == "knockback":
            lines.append("%d. %s击退：将命中的敌人击退 %d 格" % (i, cond_prefix, int(eff.get("value", 1))))
    return lines


def _wrap_text(draw, text, font, max_width):
    lines = []
    current = ""
    for ch in text:
        if draw.textlength(current + ch, font=font) <= max_width:
            current += ch
        else:
            lines.append(current)
            current = ch
    if current:
        lines.append(current)
    return lines


def render_card_face(data: dict, size=(360, 500)):
    """绘制卡面：卡名、费用、负载、效果列表；有卡面图则显示图片，否则显示占位槽。"""
    img = Image.new("RGB", size, "#1a1f27")
    draw = ImageDraw.Draw(img)
    w, h = size

    font_name = _font(20)
    font_sub = _font(13)
    font_info = _font(15)
    font_body = _font(14)
    font_small = _font(11)

    draw.rectangle([8, 8, w - 8, h - 8], outline="#c9a35c", width=3)
    name = data.get("name") or "未命名"
    draw.text((w / 2, 40), name, font=font_name, fill="#f2e6c9", anchor="mm")
    draw.text((w / 2, 68), "%s · %s" % (data.get("card_type", ""), data.get("category", "")),
              font=font_sub, fill="#9aa3b2", anchor="mm")
    keywords = data.get("keywords") or []
    if keywords:
        draw.text((w / 2, 86), "　".join(keywords), font=font_sub, fill="#e8b64c", anchor="mm")
    draw.text((26, 30), "费用 %d" % int(data.get("cost", 0)), font=font_info, fill="#e0b64c", anchor="lt")
    draw.text((w - 26, 30), "负载 %d" % int(data.get("load", 0)), font=font_info, fill="#e0b64c", anchor="rt")

    # 图片槽：有卡面图则贴图，否则画占位
    art = load_art_image(data.get("art_path", ""))
    if art is not None:
        draw.rectangle(ART_SLOT, outline="#5a6a80", width=2)
        _paste_contain(img, art, ART_SLOT)
    else:
        draw.rectangle(ART_SLOT, outline="#5a6a80", fill="#181d25")
        draw.text(((ART_SLOT[0] + ART_SLOT[2]) / 2, (ART_SLOT[1] + ART_SLOT[3]) / 2),
                  "图片槽位\n（待美术资源）", font=font_body, fill="#6f7a8c", anchor="mm", align="center")

    draw.text((26, 242), "效果", font=font_body, fill="#f2e6c9", anchor="lt")
    y = 272
    for line in describe_effects(data.get("effects", [])):
        for sub in _wrap_text(draw, line, font_body, w - 52):
            draw.text((26, y), sub, font=font_body, fill="#cbd3de", anchor="lt")
            y += 24
    path = data.get("path", "")
    if path:
        draw.text((w / 2, h - 18), "道途：%s" % path, font=font_small, fill="#9aa3b2", anchor="mm")
    return img


def export_card_face(data: dict, out_dir: Path) -> Path:
    if not HAVE_PIL:
        raise RuntimeError("未安装 Pillow，无法导出 PNG")
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / ("%s.png" % data["id"])
    img = render_card_face(data)
    img.save(path)
    return path


# ---------- GUI ----------

class CardEditorApp:
    def __init__(self, root: tk.Tk):
        self.root = root
        root.title("卡牌制作编辑器")
        root.geometry("1080x720")
        root.minsize(960, 660)

        self.current_id = None
        self._cards = []
        self.effect_entries = []
        self._keyword_vars = {}
        self._art_path = ""
        self._art_image = None
        self._face_photo = None

        self.var_name = tk.StringVar()
        self.var_category = tk.StringVar(value=CATEGORIES[0])
        self.var_path = tk.StringVar()
        self.var_card_type = tk.StringVar(value=CARD_TYPES[0])
        self.var_cost = tk.IntVar(value=0)
        self.var_load = tk.IntVar(value=1)
        self.var_target = tk.StringVar(value=GDD_TARGET_TYPES[0])
        self.var_range = tk.IntVar(value=1)
        self.var_area = tk.IntVar(value=0)
        # 美术接口：图标与动画路径（相对 卡牌/ 目录，可空）
        self.var_icon = tk.StringVar()
        self.var_animation = tk.StringVar()

        self._loading_card = False       # 加载/新建时避免误触发“未确认修改”标记
        self._modified = False           # 是否有未确认的修改（点“确认修改”写入卡牌库）
        # 修改任意字段 → 标记“未确认修改”，由“确认修改”按钮写入卡牌库
        for var in (self.var_name, self.var_category, self.var_path, self.var_card_type,
                    self.var_cost, self.var_load, self.var_target, self.var_range,
                    self.var_area, self.var_icon, self.var_animation):
            var.trace_add("write", lambda *a: self._mark_modified())

        self._build_ui()
        self._bind_face_update()
        self.refresh_list()
        self.new_card()
        root.protocol("WM_DELETE_WINDOW", self._on_close)

    # ----- 界面搭建 -----
    def _build_ui(self):
        main = ttk.Frame(self.root, padding=10)
        main.pack(fill=tk.BOTH, expand=True)

        left = ttk.Frame(main)
        left.pack(side=tk.LEFT, fill=tk.Y)
        right = ttk.Frame(main)
        right.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=(14, 0))

        # 左：已有卡牌列表
        ttk.Label(left, text="已有卡牌").pack(anchor=tk.W)
        list_frame = ttk.Frame(left)
        list_frame.pack(fill=tk.BOTH, expand=True)
        self.card_list = tk.Listbox(list_frame, width=28, height=28, font=("Microsoft YaHei UI", 10))
        scroll = ttk.Scrollbar(list_frame, orient=tk.VERTICAL, command=self.card_list.yview)
        self.card_list.config(yscrollcommand=scroll.set)
        self.card_list.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scroll.pack(side=tk.RIGHT, fill=tk.Y)
        self.card_list.bind("<<ListboxSelect>>", self.on_select)

        btn_row = ttk.Frame(left)
        btn_row.pack(fill=tk.X, pady=(8, 0))
        ttk.Button(btn_row, text="新建", command=self.new_card).pack(side=tk.LEFT, expand=True, fill=tk.X)
        ttk.Button(btn_row, text="删除", command=self.delete_current).pack(side=tk.LEFT, expand=True, fill=tk.X, padx=(6, 0))

        # 右：Notebook（编辑 / 卡面）
        self.notebook = ttk.Notebook(right)
        self.notebook.pack(fill=tk.BOTH, expand=True)
        edit_tab = ttk.Frame(self.notebook, padding=8)
        face_tab = ttk.Frame(self.notebook, padding=8)
        self.notebook.add(edit_tab, text="卡牌编辑")
        self.notebook.add(face_tab, text="卡面生成")

        self._build_edit_tab(edit_tab)
        self._build_face_tab(face_tab)

        # 底部按钮
        bottom = ttk.Frame(right)
        bottom.pack(fill=tk.X, pady=(10, 0))
        ttk.Button(bottom, text="确认修改", command=self._confirm_changes).pack(side=tk.LEFT, expand=True, fill=tk.X)
        ttk.Button(bottom, text="新建", command=self.new_card).pack(side=tk.LEFT, expand=True, fill=tk.X, padx=(8, 0))

        self.status = ttk.Label(right, text="就绪", foreground="#666666")
        self.status.pack(anchor=tk.W, pady=(6, 0))

    def _build_edit_tab(self, tab):
        info = ttk.LabelFrame(tab, text="基本信息", padding=10)
        info.pack(fill=tk.X)
        info.columnconfigure(1, weight=1)

        self._add_entry(info, 0, "卡牌名", self.var_name)
        ttk.Label(info, text="分类").grid(row=1, column=0, sticky=tk.W, pady=4)
        category_combo = ttk.Combobox(info, textvariable=self.var_category, values=CATEGORIES, state="readonly", width=22)
        category_combo.grid(row=1, column=1, sticky=tk.W, pady=4)
        category_combo.bind("<<ComboboxSelected>>", lambda e: self._on_category_changed())

        ttk.Label(info, text="道途名（专属卡）").grid(row=2, column=0, sticky=tk.W, pady=4)
        self.path_entry = ttk.Entry(info, textvariable=self.var_path, width=24)
        self.path_entry.grid(row=2, column=1, sticky=tk.W, pady=4)
        self.path_entry.config(state="disabled")

        ttk.Label(info, text="卡牌类型").grid(row=3, column=0, sticky=tk.W, pady=4)
        type_combo = ttk.Combobox(info, textvariable=self.var_card_type, values=CARD_TYPES, state="readonly", width=22)
        type_combo.grid(row=3, column=1, sticky=tk.W, pady=4)
        type_combo.bind("<<ComboboxSelected>>", lambda e: self._on_type_changed())

        self.ability_note = ttk.Label(info, text="", foreground="#b58900")
        self.ability_note.grid(row=4, column=0, columnspan=2, sticky=tk.W, pady=(0, 2))

        self._add_spin(info, 5, "费用", self.var_cost, 0, 99)
        self._add_spin(info, 6, "荷载", self.var_load, 0, 99)   # 荷载允许为 0
        ttk.Label(info, text="目标类型").grid(row=7, column=0, sticky=tk.W, pady=4)
        ttk.Combobox(info, textvariable=self.var_target, values=GDD_TARGET_TYPES, state="readonly", width=22).grid(row=7, column=1, sticky=tk.W, pady=4)
        self._add_spin(info, 8, "范围", self.var_range, 0, 20)
        self._add_spin(info, 9, "区域", self.var_area, 0, 20)

        # 关键词（消耗/保留/虚无/固有，可多选）
        ttk.Label(info, text="关键词").grid(row=10, column=0, sticky=tk.W, pady=4)
        kw_frame = ttk.Frame(info)
        kw_frame.grid(row=10, column=1, sticky=tk.W, pady=4)
        for kw in KEYWORDS:
            var = tk.BooleanVar(value=False)
            self._keyword_vars[kw] = var
            var.trace_add("write", lambda *a: (self._redraw_face(), self._mark_modified()))
            ttk.Checkbutton(kw_frame, text=kw, variable=var).pack(side=tk.LEFT, padx=(0, 8))

        self._add_entry(info, 11, "图标路径（卡牌/ 内）", self.var_icon)
        self._add_entry(info, 12, "动画路径（卡牌/ 内）", self.var_animation)

        # 逻辑链（可多条，按顺序触发）
        effects_area = ttk.LabelFrame(tab, text="逻辑链（多条按从上到下顺序触发）", padding=8)
        effects_area.pack(fill=tk.BOTH, expand=True, pady=(8, 0))

        self._effects_canvas = tk.Canvas(effects_area, height=250, highlightthickness=0)
        self._effects_scroll = ttk.Scrollbar(effects_area, orient=tk.VERTICAL, command=self._effects_canvas.yview)
        self._effects_inner = ttk.Frame(self._effects_canvas)
        self._effects_inner.bind("<Configure>", lambda e: self._effects_canvas.configure(scrollregion=self._effects_canvas.bbox("all")))
        self._effects_canvas.create_window((0, 0), window=self._effects_inner, anchor="nw")
        self._effects_canvas.configure(yscrollcommand=self._effects_scroll.set)
        self._effects_canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        self._effects_scroll.pack(side=tk.RIGHT, fill=tk.Y)
        self._effects_canvas.bind("<MouseWheel>", lambda e: self._effects_canvas.yview_scroll(int(-e.delta / 120), "units"))
        self._effects_inner.bind("<MouseWheel>", lambda e: self._effects_canvas.yview_scroll(int(-e.delta / 120), "units"))

        add_btn = ttk.Button(effects_area, text="＋ 新增逻辑", command=self._add_effect_entry)
        add_btn.pack(side=tk.BOTTOM, pady=(6, 0))
        refresh_btn = ttk.Button(effects_area, text="刷新buff列表", command=self._on_refresh_buffs)
        refresh_btn.pack(side=tk.BOTTOM, pady=(6, 0))

    def _build_face_tab(self, tab):
        ttk.Label(tab, text="卡面预览（随编辑自动更新；图片槽位可读取本机图片）",
                  foreground="#666666").pack(anchor=tk.W)
        self.face_canvas = tk.Canvas(tab, width=360, height=500, bg="#1a1f27", highlightthickness=0)
        self.face_canvas.pack(side=tk.LEFT, padx=(0, 16))

        side = ttk.Frame(tab)
        side.pack(side=tk.LEFT, fill=tk.Y)

        ttk.Label(side, text="卡面图片", font=("Microsoft YaHei UI", 12)).pack(anchor=tk.W, pady=(0, 6))
        ttk.Button(side, text="选择卡面图片…", command=self._on_art_picked).pack(fill=tk.X, pady=4)
        ttk.Button(side, text="清除图片", command=self._clear_art).pack(fill=tk.X, pady=4)
        self.art_status_label = ttk.Label(side, text="未设置（显示占位槽）", foreground="#888888")
        self.art_status_label.pack(anchor=tk.W, pady=(6, 12))

        ttk.Label(side, text="导出卡面为 PNG", font=("Microsoft YaHei UI", 12)).pack(anchor=tk.W, pady=(0, 6))
        export_btn = ttk.Button(side, text="导出卡面 PNG", command=self.export_face)
        export_btn.pack(fill=tk.X, pady=4)
        if not HAVE_PIL:
            export_btn.config(state="disabled")
        ttk.Label(side, text="图片与导出目录：\n卡牌/card_faces/", justify=tk.LEFT,
                  foreground="#888888", wraplength=200).pack(anchor=tk.W, pady=6)

    # ----- 表单辅助 -----
    def _add_entry(self, parent, row, label, variable):
        ttk.Label(parent, text=label).grid(row=row, column=0, sticky=tk.W, pady=4)
        ttk.Entry(parent, textvariable=variable, width=24).grid(row=row, column=1, sticky=tk.W, pady=4)

    def _add_spin(self, parent, row, label, variable, from_, to):
        ttk.Label(parent, text=label).grid(row=row, column=0, sticky=tk.W, pady=4)
        ttk.Spinbox(parent, from_=from_, to=to, textvariable=variable, width=8).grid(row=row, column=1, sticky=tk.W, pady=4)

    @staticmethod
    def _int(var, default=0):
        try:
            return int(var.get())
        except Exception:
            return default

    def _bind_face_update(self):
        for var in [self.var_name, self.var_category, self.var_path, self.var_card_type,
                    self.var_cost, self.var_load, self.var_target, self.var_range, self.var_area]:
            var.trace_add("write", lambda *a: (self._redraw_face(), self._mark_modified()))

    # ----- 卡面图片 -----
    def _on_art_picked(self):
        if not HAVE_PIL:
            messagebox.showwarning("提示", "未安装 Pillow，无法读取图片")
            return
        file = filedialog.askopenfilename(
            title="选择卡面图片",
            filetypes=[("图片文件", "*.png *.jpg *.jpeg *.webp *.bmp *.gif"), ("所有文件", "*.*")],
        )
        if not file:
            return
        try:
            img = Image.open(file).convert("RGBA")
        except Exception as exc:
            messagebox.showerror("读取失败", str(exc))
            return
        if not self.current_id:
            name = self.var_name.get().strip() or "未命名"
            self.current_id = "%s_%d" % (_sanitize_name(name), int(time.time() * 1000))
        FACE_DIR.mkdir(parents=True, exist_ok=True)
        out = FACE_DIR / ("%s.png" % self.current_id)
        img.save(out)
        self._art_path = "card_faces/%s.png" % self.current_id
        self._art_image = img
        self.status.config(text="已选择卡面图片：%s" % out)
        self._redraw_face()

    def _clear_art(self):
        self._art_path = ""
        self._art_image = None
        self.status.config(text="已清除卡面图片")
        self._redraw_face()

    # ----- 逻辑链列表 -----
    def _add_effect_entry(self, effect=None):
        entry = {"frame": None, "logic_var": None, "fields_frame": None,
                 "field_vars": {}, "last_values": {}, "current_logic": "",
                 "cond_var": None, "cond_param_box": None, "cond_param_vars": {},
                 "cond_param_widgets": [], "cond_negate_var": None}
        frame = ttk.Frame(self._effects_inner)
        frame.pack(fill=tk.X, pady=3)
        frame.bind("<MouseWheel>", lambda e: self._effects_canvas.yview_scroll(int(-e.delta / 120), "units"))
        entry["frame"] = frame

        # 逻辑行（逻辑类型 + 参数 + 上移/下移/删除）
        row1 = ttk.Frame(frame)
        row1.pack(fill=tk.X)
        logic_var = tk.StringVar(value=LOGICS[0])
        entry["logic_var"] = logic_var
        logic_label = ttk.Label(row1, text="逻辑1", width=5)
        logic_label.pack(side=tk.LEFT)
        entry["logic_label"] = logic_label
        combo = ttk.Combobox(row1, textvariable=logic_var, values=LOGICS, state="readonly", width=9)
        combo.pack(side=tk.LEFT, padx=(0, 6))
        combo.bind("<<ComboboxSelected>>", lambda e, en=entry: self._rebuild_effect_fields(en))

        fields_frame = ttk.Frame(row1)
        fields_frame.pack(side=tk.LEFT, fill=tk.X, expand=True)
        entry["fields_frame"] = fields_frame

        ttk.Button(row1, text="↑", width=2, command=lambda en=entry: self._move_effect(en, -1)).pack(side=tk.LEFT)
        ttk.Button(row1, text="↓", width=2, command=lambda en=entry: self._move_effect(en, 1)).pack(side=tk.LEFT)
        ttk.Button(row1, text="删除", width=4, command=lambda en=entry: self._remove_effect(en)).pack(side=tk.LEFT, padx=(2, 0))

        # 条件行：下拉（来自 卡牌/conditions.json）+ 参数输入 + 取反
        row2 = ttk.Frame(frame)
        row2.pack(fill=tk.X, pady=(2, 0))
        ttk.Label(row2, text="条件：", width=5).pack(side=tk.LEFT)
        cond_var = tk.StringVar(value=CONDITION_NONE)
        entry["cond_var"] = cond_var
        cond_combo = ttk.Combobox(row2, textvariable=cond_var,
                                  values=[CONDITION_NONE] + [c["name"] for c in CONDITIONS],
                                  state="readonly", width=24)
        cond_combo.pack(side=tk.LEFT, padx=(0, 6))
        cond_combo.bind("<<ComboboxSelected>>", lambda e, en=entry: self._rebuild_condition_params(en))
        param_box = ttk.Frame(row2)
        param_box.pack(side=tk.LEFT, fill=tk.X, expand=True)
        entry["cond_param_box"] = param_box
        entry["cond_negate_var"] = tk.BooleanVar(value=False)
        ttk.Checkbutton(row2, text="取反", variable=entry["cond_negate_var"]).pack(side=tk.LEFT, padx=(0, 6))
        self._rebuild_condition_params(entry)

        self.effect_entries.append(entry)
        if effect is not None:
            self._apply_effect_to_entry(entry, effect)
        self._rebuild_effect_fields(entry)
        self._renumber_effects()
        self._redraw_face()

    def _rebuild_condition_params(self, entry):
        """按所选条件类型动态生成参数输入框。"""
        for w in entry.get("cond_param_widgets", []):
            w.destroy()
        entry["cond_param_widgets"] = []
        entry["cond_param_vars"] = {}
        name = entry["cond_var"].get()
        cdef = next((c for c in CONDITIONS if c["name"] == name), None)
        if cdef is None:
            return
        box = entry["cond_param_box"]
        for p in cdef.get("params", []):
            key = p["key"]
            ttk.Label(box, text=p.get("name", key)).pack(side=tk.LEFT, padx=(4, 2))
            if p.get("kind") == "int":
                var = tk.IntVar(value=int(p.get("default", 0)))
                widget = ttk.Spinbox(box, from_=p.get("min", 0), to=p.get("max", 99),
                                     textvariable=var, width=4)
            else:
                var = tk.StringVar(value=str(p.get("default", "")))
                widget = ttk.Entry(box, textvariable=var, width=10)
            widget.pack(side=tk.LEFT, padx=(0, 4))
            var.trace_add("write", lambda *a: (self._redraw_face(), self._mark_modified()))
            entry["cond_param_vars"][key] = var
            entry["cond_param_widgets"].append(widget)

    def _rebuild_effect_fields(self, entry):
        # 保存当前值（切换逻辑时保留各逻辑已输入的值）
        if entry["field_vars"]:
            entry["last_values"][entry["current_logic"]] = {
                k: self._int(var) if isinstance(var, tk.IntVar) else var.get()
                for k, var in entry["field_vars"].items()
            }
        for child in entry["fields_frame"].winfo_children():
            child.destroy()
        entry["field_vars"] = {}

        logic = entry["logic_var"].get()
        entry["current_logic"] = logic
        seeds = entry["last_values"].get(logic, {})

        def spin(key, label, default, from_, to):
            var = tk.IntVar(value=int(seeds.get(key, default)))
            entry["field_vars"][key] = var
            var.trace_add("write", lambda *a: (self._redraw_face(), self._mark_modified()))
            ttk.Label(entry["fields_frame"], text=label).pack(side=tk.LEFT)
            ttk.Spinbox(entry["fields_frame"], from_=from_, to=to, textvariable=var, width=5).pack(side=tk.LEFT, padx=(0, 6))

        def combo(key, label, values, default):
            var = tk.StringVar(value=seeds.get(key, default))
            entry["field_vars"][key] = var
            var.trace_add("write", lambda *a: (self._redraw_face(), self._mark_modified()))
            ttk.Label(entry["fields_frame"], text=label).pack(side=tk.LEFT)
            ttk.Combobox(entry["fields_frame"], textvariable=var, values=values,
                         state="readonly", width=8).pack(side=tk.LEFT, padx=(0, 6))

        def text(key, label, default):
            var = tk.StringVar(value=str(seeds.get(key, default)))
            entry["field_vars"][key] = var
            var.trace_add("write", lambda *a: (self._redraw_face(), self._mark_modified()))
            ttk.Label(entry["fields_frame"], text=label).pack(side=tk.LEFT)
            ttk.Entry(entry["fields_frame"], textvariable=var, width=10).pack(side=tk.LEFT, padx=(0, 6))

        def check(key, label, default=False):
            var = tk.BooleanVar(value=bool(seeds.get(key, default)))
            entry["field_vars"][key] = var
            var.trace_add("write", lambda *a: (self._redraw_face(), self._mark_modified()))
            ttk.Checkbutton(entry["fields_frame"], text=label, variable=var).pack(side=tk.LEFT, padx=(0, 6))

        if logic == "攻击":
            spin("value", "攻击数值", 1, 1, 999)
            spin("attack_range", "攻击范围", 1, 1, 20)
            spin("alt_value", "移动后数值", 0, 0, 999)
            check("pierce", "无视护甲")
        elif logic == "移动":
            spin("distance", "移动距离", 1, 1, 20)
        elif logic == "防御":
            spin("defense_value", "防御数值", 1, 1, 999)
            spin("alt_value", "移动后数值", 0, 0, 999)
        elif logic == "给予buff":
            combo("target", "对象", BUFF_TARGETS, BUFF_TARGETS[0])
            combo("buff_type", "buff种类", BUFF_TYPES, BUFF_TYPES[0])
            spin("duration", "持续时间(0=自动)", 0, 0, 99)
            spin("stacks", "层数", 1, -99, 99)
        elif logic == "抽牌":
            spin("value", "抽牌数量", 1, 1, 99)
        elif logic == "弃牌":
            spin("value", "弃牌数量", 1, 1, 99)
            combo("mode", "方式", DISCARD_MODES, DISCARD_MODES[0])
        elif logic == "加入手牌":
            text("card", "卡牌名", "")
            spin("value", "数量", 1, 1, 99)
        elif logic == "加入抽牌堆":
            text("card", "卡牌名", "")
            spin("value", "数量", 1, 1, 99)
            combo("position", "位置", DRAW_POSITIONS, DRAW_POSITIONS[0])
        elif logic == "加入弃牌堆":
            text("card", "卡牌名", "")
            spin("value", "数量", 1, 1, 99)
        elif logic == "生成牌":
            combo("pool", "随机池", GENERATE_POOLS, GENERATE_POOLS[0])
            text("card", "指定牌名", "")
            spin("value", "数量", 1, 1, 99)
            combo("pile", "目标牌堆", PILE_TARGETS, PILE_TARGETS[0])
        elif logic == "复制":
            spin("value", "数量", 1, 1, 99)
            combo("pile", "目标牌堆", PILE_TARGETS, PILE_TARGETS[1])
        elif logic == "失去生命":
            spin("value", "数值", 1, 1, 999)
            combo("target", "对象", HP_TARGETS, HP_TARGETS[0])
        elif logic == "获得费用":
            spin("value", "费用", 1, 1, 99)
        elif logic == "伺机反打":
            spin("value", "触发伤害", 7, 1, 999)
        elif logic == "击退":
            spin("value", "击退格数", 1, 1, 5)
        self._redraw_face()

    def _apply_effect_to_entry(self, entry, effect):
        logic_label = {v: k for k, v in LOGIC_MAP.items()}.get(effect.get("logic", ""), LOGICS[0])
        entry["logic_var"].set(logic_label)
        target_label = BUFF_TARGET_LABEL.get(effect.get("target", ""), BUFF_TARGETS[0])
        entry["last_values"] = {
            logic_label: {
                "value": int(effect.get("value", 1)),
                "attack_range": int(effect.get("attack_range", 1)),
                "distance": int(effect.get("distance", 1)),
                "defense_value": int(effect.get("value", 1)),
                "target": target_label,
                "buff_type": effect.get("buff_type", ""),
                "duration": int(effect.get("duration", 0)),
                "mode": DISCARD_MODE_LABEL.get(effect.get("mode", "random"), "随机"),
                "card": effect.get("card", ""),
                "position": DRAW_POSITION_LABEL.get(effect.get("position", "shuffle"), "洗入"),
                "pool": effect.get("pool", ""),
                "pile": PILE_LABEL.get(effect.get("pile", "hand"), "手牌"),
                "pierce": bool(effect.get("pierce", False)),
                "stacks": int(effect.get("stacks", 1)),
                "alt_value": int(effect.get("alt_value", 0)),
            }
        }
        # 条件回填（来自 卡牌/conditions.json 的类型 + 参数 + 取反）
        self._apply_condition_to_entry(entry, effect.get("condition"))

    def _apply_condition_to_entry(self, entry, condition):
        if not condition:
            entry["cond_var"].set(CONDITION_NONE)
            entry["cond_negate_var"].set(False)
        else:
            ctype = condition.get("type", "")
            name = next((c["name"] for c in CONDITIONS if c["type"] == ctype), CONDITION_NONE)
            entry["cond_var"].set(name)
            entry["cond_negate_var"].set(bool(condition.get("negate", False)))
        self._rebuild_condition_params(entry)
        if condition:
            ctype = condition.get("type", "")
            cdef = next((c for c in CONDITIONS if c["type"] == ctype), {})
            for p in cdef.get("params", []):
                var = entry["cond_param_vars"].get(p["key"])
                if var is not None:
                    if p.get("kind") == "int":
                        var.set(int(condition.get(p["key"], p.get("default", 0))))
                    else:
                        var.set(str(condition.get(p["key"], p.get("default", ""))))

    def _on_refresh_buffs(self):
        refresh_buff_types()
        for entry in self.effect_entries:
            self._rebuild_effect_fields(entry)
        self.status.config(text="buff 列表已刷新（%d 个）" % max(len(BUFF_TYPES) - 1, 0))

    def _collect_effects(self):
        result = []
        for entry in self.effect_entries:
            logic = entry["logic_var"].get()
            v = entry["field_vars"]
            item = None
            if logic == "攻击":
                item = {"logic": "attack", "value": self._int(v["value"]),
                        "attack_range": self._int(v["attack_range"]),
                        "pierce": v["pierce"].get(),
                        "alt_value": self._int(v["alt_value"])}
            elif logic == "移动":
                item = {"logic": "move", "distance": self._int(v["distance"])}
            elif logic == "防御":
                item = {"logic": "defense", "value": self._int(v["defense_value"]),
                        "alt_value": self._int(v["alt_value"])}
            elif logic == "给予buff":
                item = {"logic": "buff", "target": BUFF_TARGET_MAP.get(v["target"].get(), "self"),
                        "buff_type": v["buff_type"].get(), "duration": self._int(v["duration"]),
                        "stacks": self._int(v["stacks"])}
            elif logic == "抽牌":
                item = {"logic": "draw", "value": self._int(v["value"])}
            elif logic == "弃牌":
                item = {"logic": "discard", "value": self._int(v["value"]),
                        "mode": DISCARD_MODE_MAP.get(v["mode"].get(), "random")}
            elif logic == "加入手牌":
                item = {"logic": "add_to_hand", "card": v["card"].get().strip(),
                        "value": self._int(v["value"])}
            elif logic == "加入抽牌堆":
                item = {"logic": "add_to_draw", "card": v["card"].get().strip(),
                        "value": self._int(v["value"]),
                        "position": DRAW_POSITION_MAP.get(v["position"].get(), "shuffle")}
            elif logic == "加入弃牌堆":
                item = {"logic": "add_to_discard", "card": v["card"].get().strip(),
                        "value": self._int(v["value"])}
            elif logic == "生成牌":
                item = {"logic": "generate", "pool": v["pool"].get().strip(),
                        "card": v["card"].get().strip(),
                        "value": self._int(v["value"]),
                        "pile": PILE_MAP.get(v["pile"].get(), "hand")}
            elif logic == "复制":
                item = {"logic": "copy", "value": self._int(v["value"]),
                        "pile": PILE_MAP.get(v["pile"].get(), "discard")}
            elif logic == "失去生命":
                item = {"logic": "lose_hp", "value": self._int(v["value"]),
                        "target": HP_TARGET_MAP.get(v["target"].get(), "self")}
            elif logic == "获得费用":
                item = {"logic": "gain_energy", "value": self._int(v["value"])}
            elif logic == "伺机反打":
                item = {"logic": "flank", "value": self._int(v["value"])}
            elif logic == "击退":
                item = {"logic": "knockback", "value": self._int(v["value"])}
            if item is not None:
                condition = self._collect_condition(entry)
                if condition:
                    item["condition"] = condition
                result.append(item)
        return result

    def _collect_condition(self, entry):
        """收集条件行输入；无条件返回 None。"""
        name = entry["cond_var"].get()
        if name == CONDITION_NONE:
            return None
        cdef = next((c for c in CONDITIONS if c["name"] == name), None)
        if cdef is None:
            return None
        condition = {"type": cdef["type"]}
        if entry["cond_negate_var"].get():
            condition["negate"] = True
        for p in cdef.get("params", []):
            var = entry["cond_param_vars"].get(p["key"])
            if var is not None:
                condition[p["key"]] = self._int(var) if p.get("kind") == "int" else var.get().strip()
        return condition

    def _clear_effect_entries(self):
        for entry in self.effect_entries:
            entry["frame"].destroy()
        self.effect_entries.clear()

    def _load_effects(self, effects):
        self._clear_effect_entries()
        if not effects:
            effects = [{"logic": "attack"}]
        for eff in effects:
            self._add_effect_entry(eff)

    def _remove_effect(self, entry):
        if len(self.effect_entries) <= 1:
            messagebox.showinfo("提示", "至少保留一条逻辑")
            return
        idx = self.effect_entries.index(entry)
        entry["frame"].destroy()
        self.effect_entries.pop(idx)
        self._renumber_effects()
        self._redraw_face()

    def _move_effect(self, entry, offset):
        idx = self.effect_entries.index(entry)
        new_idx = idx + offset
        if new_idx < 0 or new_idx >= len(self.effect_entries):
            return
        self.effect_entries[idx], self.effect_entries[new_idx] = self.effect_entries[new_idx], self.effect_entries[idx]
        for e in self.effect_entries:
            e["frame"].pack_forget()
        for e in self.effect_entries:
            e["frame"].pack(fill=tk.X, pady=3)
        self._renumber_effects()
        self._redraw_face()

    def _renumber_effects(self):
        for i, entry in enumerate(self.effect_entries, 1):
            label = entry.get("logic_label")
            if label is not None:
                label.config(text="逻辑%d" % i)

    # ----- 交互逻辑 -----
    def _on_category_changed(self):
        if self.var_category.get() == CATEGORIES[1]:
            self.path_entry.config(state="normal")
        else:
            self.path_entry.config(state="disabled")
            self.var_path.set("")

    def _on_type_changed(self):
        if self.var_card_type.get() == "能力":
            self.ability_note.config(text="能力牌：打出后自动消失（底层逻辑，无需配置）")
        else:
            self.ability_note.config(text="")

    def _current_data(self) -> dict:
        return {
            "id": self.current_id or "",
            "name": self.var_name.get(),
            "category": self.var_category.get(),
            "path": self.var_path.get().strip(),
            "card_type": self.var_card_type.get(),
            "cost": self._int(self.var_cost),
            "load": self._int(self.var_load),
            "target_type": self.var_target.get(),
            "range": self._int(self.var_range),
            "area": self._int(self.var_area),
            "icon": self.var_icon.get().strip(),
            "art": self._art_path,
            "animation": self.var_animation.get().strip(),
            "keywords": [kw for kw in KEYWORDS if self._keyword_vars.get(kw, tk.BooleanVar(value=False)).get()],
            "effects": self._collect_effects(),
        }

    def refresh_list(self):
        self._cards = load_cards()
        self.card_list.delete(0, tk.END)
        for card in self._cards:
            tag = "（道途）" if card.get("category") == CATEGORIES[1] else ""
            self.card_list.insert(tk.END, "%s　%s%s" % (card.get("card_type", ""), card.get("name", "?"), tag))

    def on_select(self, _event):
        index = self.card_list.curselection()
        if not index:
            return
        # 切换卡牌前先落盘当前卡的未确认修改
        self._flush_pending()
        card = self._cards[index[0]]
        self._loading_card = True
        self.current_id = card["id"]
        self.var_name.set(card.get("name", ""))
        self.var_category.set(card.get("category", CATEGORIES[0]))
        self.var_path.set(card.get("path", ""))
        self.var_card_type.set(card.get("card_type", CARD_TYPES[0]))
        self.var_cost.set(int(card.get("cost", 0)))
        self.var_load.set(int(card.get("load", 0)))
        self.var_target.set(card.get("target_type", GDD_TARGET_TYPES[0]))
        self.var_range.set(int(card.get("range", 0)))
        self.var_area.set(int(card.get("area", 0)))
        self._art_path = card.get("art", card.get("art_path", "")) or ""
        self.var_icon.set(card.get("icon", "") or "")
        self.var_animation.set(card.get("animation", "") or "")
        for kw in KEYWORDS:
            self._keyword_vars[kw].set(keyword_active(card, kw))
        self._art_image = load_art_image(self._art_path)
        self._on_category_changed()
        self._on_type_changed()
        self._load_effects(card.get("effects", []))
        self.status.config(text="已载入：%s" % card.get("name", ""))
        self._redraw_face()
        self._loading_card = False
        self._modified = False

    def new_card(self):
        # 新建前先落盘当前卡的未确认修改
        self._flush_pending()
        self._loading_card = True
        self.current_id = None
        self._modified = False
        self.var_name.set("")
        self.var_category.set(CATEGORIES[0])
        self.var_path.set("")
        self.var_card_type.set(CARD_TYPES[0])
        self.var_cost.set(0)
        self.var_load.set(1)
        self.var_target.set(GDD_TARGET_TYPES[0])
        self.var_range.set(1)
        self.var_area.set(0)
        self.var_icon.set("")
        self.var_animation.set("")
        for kw in KEYWORDS:
            self._keyword_vars[kw].set(False)
        self._art_path = ""
        self._art_image = None
        self._on_category_changed()
        self._on_type_changed()
        self._load_effects([])
        self.card_list.selection_clear(0, tk.END)
        self.status.config(text="新建卡牌")
        self._redraw_face()
        self._loading_card = False

    def _mark_modified(self):
        """字段被修改：标记未确认，提示点击「确认修改」写入卡牌库。"""
        if getattr(self, "_loading_card", False):
            return
        self._modified = True
        self.status.config(text="⚠ 有未确认的修改（点击「确认修改」写入卡牌库）")

    def _flush_pending(self) -> bool:
        """切换/新建/关闭前：已有卡有未确认修改时立即落盘。返回是否保存。"""
        if not self._modified:
            return False
        if not self.current_id or not self.var_name.get().strip():
            return False
        data = self._persist_current()
        self._modified = False
        self.status.config(text="已保存：%s" % data["name"])
        return True

    def _confirm_changes(self):
        """确认修改：把当前卡（含新建卡）写入卡牌库并给出明确反馈。"""
        name = self.var_name.get().strip()
        if not name:
            messagebox.showwarning("提示", "请先输入卡牌名")
            return
        category = self.var_category.get()
        path = self.var_path.get().strip()
        if category == CATEGORIES[1] and not path:
            if not messagebox.askyesno("确认", "道途专属卡牌尚未填写道途名，仍要保存吗？（可稍后在 JSON 中补充）"):
                return
        data = self._persist_current()
        self.current_id = data["id"]
        self._modified = False
        self.refresh_list()
        for i, card in enumerate(self._cards):
            if card["id"] == data["id"]:
                self.card_list.selection_clear(0, tk.END)
                self.card_list.selection_set(i)
                self.card_list.see(i)
                break
        self.status.config(text="✔ 已确认修改并写入卡牌库：%s" % data["name"])
        messagebox.showinfo("确认修改", "已确认修改并写入卡牌库：\n%s" % data["name"])
        self._redraw_face()

    def _on_close(self):
        """关闭编辑器前落盘未确认修改（已有卡），避免关闭后修改丢失。"""
        try:
            self._flush_pending()
        except Exception as exc:
            messagebox.showerror("保存失败", str(exc))
        self.root.destroy()

    def _persist_current(self) -> dict:
        """把当前编辑器内容写入卡牌库（原子写）。返回保存的数据。"""
        data = make_card(
            name=self.var_name.get().strip(),
            category=self.var_category.get(),
            path=self.var_path.get().strip(),
            card_type=self.var_card_type.get(),
            cost=self._int(self.var_cost),
            load=self._int(self.var_load),
            target_type=self.var_target.get(),
            range_=self._int(self.var_range),
            area=self._int(self.var_area),
            effects=self._collect_effects(),
            keywords=[kw for kw in KEYWORDS if self._keyword_vars.get(kw, tk.BooleanVar(value=False)).get()],
        )
        if self.current_id:
            data["id"] = self.current_id
        data["icon"] = self.var_icon.get().strip()
        data["art"] = self._art_path
        data["animation"] = self.var_animation.get().strip()
        # 顶层关键词字段与勾选状态同步（兼容 小刀 等旧格式，保证卡牌库信息不丢）
        data["derived"] = "衍生" in data["keywords"]
        data["lifesteal"] = "吸血" in data["keywords"]
        save_card(data)
        return data

    def save_current(self):
        """兼容旧入口：等价于「确认修改」。"""
        self._confirm_changes()

    def delete_current(self):
        index = self.card_list.curselection()
        if not index:
            messagebox.showinfo("提示", "请先在左侧选择要删除的卡牌")
            return
        card = self._cards[index[0]]
        if not messagebox.askyesno("确认删除", "确定删除卡牌“%s”吗？\n（删除后移入回收站 卡牌/cards/.trash/，可手动恢复）" % card.get("name", "")):
            return
        delete_card(card["id"])
        self.new_card()
        self.refresh_list()
        self.status.config(text="已删除：%s" % card.get("name", ""))

    def export_face(self):
        if not HAVE_PIL:
            messagebox.showwarning("提示", "未安装 Pillow，无法导出 PNG")
            return
        name = self.var_name.get().strip() or "未命名"
        card_id = self.current_id or ("%s_%d" % (_sanitize_name(name), int(time.time() * 1000)))
        data = self._current_data()
        data["id"] = card_id
        try:
            path = export_card_face(data, FACE_DIR)
        except Exception as exc:
            messagebox.showerror("导出失败", str(exc))
            return
        self.status.config(text="已导出卡面：%s" % path)

    # ----- 卡面预览 -----
    def _redraw_face(self):
        if not hasattr(self, "face_canvas"):
            return
        c = self.face_canvas
        c.delete("all")
        self._face_photo = None
        data = self._current_data()
        w, h = 360, 500
        name = data["name"] or "未命名"

        c.create_rectangle(8, 8, w - 8, h - 8, outline="#c9a35c", width=3, fill="#232936")
        c.create_text(w / 2, 40, text=name, font=("Microsoft YaHei UI", 18, "bold"), fill="#f2e6c9")
        c.create_text(w / 2, 68, text="%s · %s" % (data["card_type"], data["category"]),
                      font=("Microsoft YaHei UI", 11), fill="#9aa3b2")
        keywords = [kw for kw in KEYWORDS if self._keyword_vars.get(kw, tk.BooleanVar(value=False)).get()]
        if keywords:
            c.create_text(w / 2, 86, text="　".join(keywords),
                          font=("Microsoft YaHei UI", 11), fill="#e8b64c")
        c.create_text(26, 30, text="费用 %d" % data["cost"], font=("Microsoft YaHei UI", 13, "bold"),
                      fill="#e0b64c", anchor="nw")
        c.create_text(w - 26, 30, text="负载 %d" % data["load"], font=("Microsoft YaHei UI", 13, "bold"),
                      fill="#e0b64c", anchor="ne")

        # 图片槽：有卡面图则贴图，否则画占位
        if self._art_image is not None and HAVE_PIL:
            c.create_rectangle(ART_SLOT[0], ART_SLOT[1], ART_SLOT[2], ART_SLOT[3],
                               outline="#5a6a80", width=2)
            fit = contain_image(self._art_image, ART_SLOT[2] - ART_SLOT[0], ART_SLOT[3] - ART_SLOT[1])
            self._face_photo = ImageTk.PhotoImage(fit)
            c.create_image((ART_SLOT[0] + ART_SLOT[2]) / 2, (ART_SLOT[1] + ART_SLOT[3]) / 2,
                           image=self._face_photo)
            if hasattr(self, "art_status_label"):
                self.art_status_label.config(text="已设置：%s" % self._art_path, foreground="#4caf50")
        else:
            c.create_rectangle(ART_SLOT[0], ART_SLOT[1], ART_SLOT[2], ART_SLOT[3],
                               outline="#5a6a80", dash=(4, 3), fill="#181d25")
            c.create_text((ART_SLOT[0] + ART_SLOT[2]) / 2, (ART_SLOT[1] + ART_SLOT[3]) / 2,
                          text="图片槽位\n（待美术资源）", font=("Microsoft YaHei UI", 12),
                          fill="#6f7a8c", justify=tk.CENTER)
            if hasattr(self, "art_status_label"):
                self.art_status_label.config(text="未设置（显示占位槽）", foreground="#888888")

        c.create_text(26, 242, text="效果", font=("Microsoft YaHei UI", 13, "bold"), fill="#f2e6c9", anchor="nw")
        y = 272
        for line in describe_effects(data["effects"]):
            c.create_text(26, y, text=line, font=("Microsoft YaHei UI", 12), fill="#cbd3de",
                          anchor="nw", width=w - 60, justify=tk.LEFT)
            y += 24
        if data["path"]:
            c.create_text(w / 2, h - 18, text="道途：%s" % data["path"],
                          font=("Microsoft YaHei UI", 10), fill="#9aa3b2")


def main():
    refresh_buff_types()      # 加载 buff 库
    refresh_condition_types() # 加载条件类型库（卡牌/conditions.json）
    root = tk.Tk()
    CardEditorApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
