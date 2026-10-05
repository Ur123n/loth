"""Recover Leyton sources; never overwrite divergent archive files."""
import hashlib
import json
from pathlib import Path
import shutil

SOURCE = Path(r'C:\Users\njw\codex-remote-workspace\游戏\美术素材制作')
TARGET = Path(r'C:\游戏\maps\leyton')

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    records = []
    for folder, target in [('规划', 'planning'), ('topology', 'topology'), ('graybox', 'graybox')]:
        for src in sorted((SOURCE / folder).iterdir()):
            if not src.is_file():
                continue
            dst = TARGET / 'archive' / target / src.name
            dst.parent.mkdir(parents=True, exist_ok=True)
            if dst.exists() and digest(dst) != digest(src):
                raise RuntimeError(f'Divergent archive: {dst}')
            if not dst.exists():
                shutil.copy2(src, dst)
            assert digest(src) == digest(dst)
            records.append({'source': str(src), 'archive': str(dst.relative_to(TARGET)), 'sha256': digest(dst)})
    (TARGET / 'source_manifest.json').write_text(json.dumps(records, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    planning = TARGET / 'planning'
    planning.mkdir(exist_ok=True)
    for src in (TARGET / 'archive' / 'planning').glob('*.md'):
        dst = planning / src.name
        text = src.read_text(encoding='utf-8-sig')
        text = text.replace('河流与水运', '河流与灌溉').replace('交通、水运和城防', '交通、灌溉和城防')
        text = text.replace('小型卸货埠', '河岸检修台').replace('卸货埠', '河岸检修台')
        text += '\n\n## 2026-09-27 恢复修订\n\n河流不通航；货运石桥承载陆路马车。原文保留在 ../archive/planning/，本目录为后续规划规范源。首轮三图灰盒见 ../README.md。\n'
        if not dst.exists():
            dst.write_text(text, encoding='utf-8')
    data = json.loads((TARGET / 'archive/graybox/leyton_graybox_layouts_v01.json').read_text(encoding='utf-8-sig'))
    selected = [x for x in data['layouts'] if x['id'] in ['M01S', 'M04', 'M07']]
    for layout in selected:
        layout.update(status='playable_graybox_candidate', spawn=[40, 40], bridges=[], gate=[], wall_walk=[], stairs_ground=[], stairs_wall=[], exit_depth=2)
        for water in layout.get('water', []):
            water['navigable'] = False
            water['label'] = water['label'].replace('货运河道', '不可通航灌溉河道').replace('南绕候选河道', '南绕河道')
        if layout['map_id'] == 'M01':
            layout['structures'][2]['rect'] = [5, 47, 20, 12]
            layout['structures'][3]['rect'] = [72, 47, 18, 10]
            layout['bridges'] = [[45, 66, 6, 8]]
        elif layout['map_id'] == 'M04':
            layout['bridges'] = [[42, 59, 12, 11]]
        else:
            layout['spawn'] = [80, 40]
            layout['zones'][0]['rect'] = [4, 4, 52, 29]
            layout['structures'][2]['rect'] = [68, 26, 16, 9]
            layout['structures'][1]['rect'] = [88, 59, 8, 9]
            layout['structures'][3]['rect'] = [65, 44, 17, 6]
            layout['bridges'] = [[40, 35, 16, 10]]
            layout['gate'] = [85, 37, 11, 6]
            layout['wall_walk'] = [92, 0, 3, 80]
            layout['stairs_ground'] = [87, 49]
            layout['stairs_wall'] = [93, 49]
        for ex in layout['exits']:
            ex['enabled'] = ex['to'].split(':')[0] in ['M01', 'M04', 'M07']
            ex['to'] = ex['to'].replace('east_gate', 'east')
    result = {'version': '0.2-graybox', 'tile_size_px': 48, 'projection': 'strict_orthographic_top_down', 'cart_footprint_cells': [2, 3], 'maps': selected}
    dst = TARGET / 'slice.json'
    if not dst.exists():
        dst.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Archived and hash-verified {len(records)} files; prepared 3 graybox layouts.')

if __name__ == '__main__':
    main()
