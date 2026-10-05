"""Use the established pixelize pipeline to package Leyton's first surface batch."""
from pathlib import Path
import hashlib
import json
import shutil
import sys

import numpy as np

ROOT = Path(r'C:\游戏')
ART = Path(r'C:\美术素材制作')
sys.path.insert(0, str(ART / 'tools'))
import pixelize

OUT = ROOT / 'assets/maps/leyton/surface_v1'
GENERATED = Path(r'C:\Users\njw\.codex\generated_images\01a0e1c4-62b4-70f1-ba5c-a93e83203d57')
SOURCES = [
    ('water_deep', 'exec-7e0488a3-ef42-4a1e-9490-e38234768fd0.png', 'cold_water', None),
    ('wall_top', 'exec-78c8f474-5f9a-434a-88c8-a4e6c7dc337c.png', 'deep_teal_stone', None),
]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    (OUT / 'raw').mkdir(parents=True, exist_ok=True)
    (OUT / 'tiles').mkdir(exist_ok=True)
    palette_path = ART / 'assets/palettes/layton_env.json'
    palette = json.loads(palette_path.read_text(encoding='utf-8-sig'))
    shutil.copy2(palette_path, OUT / 'palette.json')
    records = []
    for name, filename, family, luma in SOURCES:
        raw = OUT / 'raw' / f'{name}.png'
        shutil.copy2(GENERATED / filename, raw)
        colors = np.asarray([palette['palette'][i] for i in palette['families'][family]], dtype=np.uint8)
        image = pixelize.pixelize(str(raw), colors, (48, 48), tileable=True, fit=False,
                                 cutout=False, outline=False, dither=False, despeckle_passes=0,
                                 accent_cap=0.0, luma_target=luma)
        arr = np.asarray(image)
        rgb = arr[:, :, :3]
        allowed = {tuple(c) for c in colors.tolist()}
        used = {tuple(c) for c in rgb.reshape(-1, 3).tolist()}
        luminance = rgb @ np.array([0.299, 0.587, 0.114])
        qa = dict(size=list(image.size), opaque=bool(np.all(arr[:, :, 3] == 255)),
                  edges_x=bool(np.array_equal(arr[:, 0], arr[:, -1])),
                  edges_y=bool(np.array_equal(arr[0], arr[-1])),
                  palette_ok=used <= allowed, colors=len(used),
                  mean_luma=float(luminance.mean()), accent_ratio=float((luminance >= 185).mean()))
        assert qa['size'] == [48, 48] and all(qa[k] for k in ['opaque', 'edges_x', 'edges_y', 'palette_ok']), qa
        assert qa['colors'] >= 3 and qa['accent_ratio'] == 0, qa
        output = OUT / 'tiles' / f'{name}.png'
        image.save(output)
        records.append(dict(name=name, raw_sha256=sha(raw), output_sha256=sha(output), qa=qa,
                            generator='built-in image_gen', family=family,
                            pipeline=str(ART / 'tools/pixelize.py'), pipeline_sha256=sha(ART / 'tools/pixelize.py')))
    (OUT / 'manifest.json').write_text(json.dumps(records, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    spec = json.loads((ROOT / 'maps/godot/tilesets/dark48.spec.json').read_text(encoding='utf-8-sig'))
    spec['tileset_name'] = 'leyton_surface_v1'
    spec['display_name'] = '莱顿城首批地表 48px'
    spec['sources'] = spec['sources'][:5]
    spec['sources'].append(dict(name='leyton_water_wall', columns=2, tile_size=[48, 48], items=[
        dict(tag='water_deep', name='不可通航深水', solid=True, file='res://assets/maps/leyton/surface_v1/tiles/water_deep.png'),
        dict(tag='wall_top', name='深青石墙顶', solid=True, file='res://assets/maps/leyton/surface_v1/tiles/wall_top.png')]))
    (ROOT / 'maps/godot/tilesets/leyton_surface_v1.spec.json').write_text(json.dumps(spec, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(records, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()
