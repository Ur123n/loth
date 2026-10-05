"""Versioned terrain preprocessing and derived tile packaging for Leyton."""
from pathlib import Path
import hashlib
import json
import shutil
import sys
import numpy as np
from PIL import Image

ROOT = Path(r'C:\游戏')
ART = Path(r'C:\美术素材制作')
sys.path.insert(0, str(ART / 'tools'))
import pixelize

OUT = ROOT / 'assets/maps/leyton/surface_v2'
GEN = Path(r'C:\Users\njw\.codex\generated_images\01a0e1c4-62b4-70f1-ba5c-a93e83203d57')
SOURCES = [
    ('grass', 'exec-b20c8c34-95f4-49b0-af97-d2bec0b6c0f4.png', [3, 5, 7, 8, 10, 13, 16], 47),
    ('dirt', 'exec-6dd89c6d-37b8-442b-80ea-75abff15222e.png', [6, 8, 12, 13, 14, 18], 77),
    ('road_stone', 'exec-5b76378e-7071-4988-894b-3b67c811c462.png', [11, 15, 19, 24, 26], 108),
]
SIDES = 'nesw'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def save(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(data.astype(np.uint8), 'RGBA').save(path)

def luma(rgb):
    return rgb[:, :, :3] @ np.asarray([.299, .587, .114])

def extent(side, depth, variant):
    yy, xx = np.mgrid[:48, :48]
    t = np.arange(48)
    taper = np.minimum(np.minimum(t, 47-t) / 7.0, 1)
    profile = 1 + taper * (depth - 1 + 1.3 * np.sin((t + variant * 9) * np.pi / 17))
    if side == 'n': return yy < profile[None, :]
    if side == 's': return 47-yy < profile[None, :]
    if side == 'w': return xx < profile[:, None]
    return 47-xx < profile[:, None]

def force_edges(result, base, by_side):
    result[0, 1:-1] = by_side.get('n', base)[0, 1:-1]
    result[-1, 1:-1] = by_side.get('s', base)[-1, 1:-1]
    result[1:-1, 0] = by_side.get('w', base)[1:-1, 0]
    result[1:-1, -1] = by_side.get('e', base)[1:-1, -1]
    return result

def verify_edges(result, base, by_side):
    for side, edge in [('n', (0, slice(1, -1))), ('s', (-1, slice(1, -1))), ('w', (slice(1, -1), 0)), ('e', (slice(1, -1), -1))]:
        assert np.array_equal(result[edge], by_side.get(side, base)[edge]), side

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    palette_path = ROOT / 'assets/dark48/色板/map_env.json'
    colors = json.loads(palette_path.read_text(encoding='utf-8-sig'))['palette']
    shutil.copy2(palette_path, OUT / 'palette.json')
    arrays = {}
    manifest = []
    items = []
    for name, filename, indices, target in SOURCES:
        raw = OUT / 'raw' / (name + '.png')
        raw.parent.mkdir(exist_ok=True)
        shutil.copy2(GEN / filename, raw)
        subset = np.asarray([colors[i] for i in indices], dtype=np.uint8)
        image = pixelize.pixelize(str(raw), subset, (48, 48), tileable=True, fit=False,
                                 dither=False, cutout=False, outline=False, despeckle_passes=0,
                                 accent_cap=0.0, luma_target=target)
        data = np.asarray(image).copy()
        assert data.shape == (48, 48, 4) and np.all(data[:, :, 3] == 255)
        assert np.array_equal(data[0], data[-1]) and np.array_equal(data[:, 0], data[:, -1])
        allowed = {tuple(c) for c in subset.tolist()}
        assert {tuple(c) for c in data[:, :, :3].reshape(-1, 3).tolist()} <= allowed
        path = OUT / 'tiles' / (name + '.png')
        save(path, data)
        arrays[name] = data
        old_path = ROOT / 'assets/dark48/地形' / ('tile_' + name + '.png')
        old = np.asarray(Image.open(old_path).convert('RGBA'))
        manifest.append(dict(name=name, raw_sha256=sha(raw), output_sha256=sha(path),
                             mean_luma=float(luma(data).mean()), std_luma=float(luma(data).std()),
                             previous_std_luma=float(luma(old).std()), colors=len(np.unique(data.reshape(-1, 4), axis=0))))
        items.append(dict(tag=name, name=name, solid=False, file='res://' + str(path.relative_to(ROOT)).replace('\\', '/')))
        if name in ['grass', 'road_stone']:
            yy, xx = np.mgrid[:48, :48]
            weight = np.clip((np.minimum.reduce([yy, xx, 47-yy, 47-xx]) - 3) / 6, 0, 1)[:, :, None]
            for index, (dy, dx) in enumerate([(11, 17), (25, 7), (19, 31)], 1):
                shifted = np.roll(data, (dy, dx), (0, 1))
                blend = data[:, :, :3] * (1-weight) + shifted[:, :, :3] * weight
                rgb = pixelize.quantize(blend.astype(np.uint8), subset)
                variant = np.dstack([rgb, data[:, :, 3]])
                assert np.array_equal(variant[:3], data[:3]) and np.array_equal(variant[-3:], data[-3:])
                assert np.array_equal(variant[:, :3], data[:, :3]) and np.array_equal(variant[:, -3:], data[:, -3:])
                name_v = f'{name}_variant_{index}'
                path_v = OUT / 'tiles' / (name_v + '.png')
                save(path_v, variant)
                items.append(dict(tag=name_v, name=name_v, solid=False, file='res://' + str(path_v.relative_to(ROOT)).replace('\\', '/')))
    for name in ['water_deep', 'wall_top']:
        path = ROOT / f'assets/maps/leyton/surface_v1/tiles/{name}.png'
        arrays[name] = np.asarray(Image.open(path).convert('RGBA')).copy()
        items.append(dict(tag=name, name=name, solid=True, file='res://' + str(path.relative_to(ROOT)).replace('\\', '/')))
    spec = dict(tileset_name='leyton_surface_v2', display_name='莱顿城低重复地表与水岸', tile_size=[48, 48],
                custom_data=[dict(name='solid', type='bool'), dict(name='tag', type='string')],
                sources=[dict(name='materials', columns=8, tile_size=[48, 48], items=items)])
    edge_checks = 0
    for base_name, patch_name, pair in [('grass', 'dirt', 'dirt_over_grass'), ('dirt', 'road_stone', 'road_over_dirt')]:
        base, patch = arrays[base_name], arrays[patch_name]
        directory = OUT / 'autotile' / pair
        for bits in range(16):
            sides = {side for i, side in enumerate(SIDES) if bits & (1 << i)}
            key = ''.join(side for side in SIDES if side in sides) or 'none'
            for variant in [1, 2]:
                mask = np.zeros((48, 48), dtype=bool)
                for side in sides:
                    mask |= extent(side, 10 if pair == 'dirt_over_grass' else 7, variant)
                result = np.where(mask[:, :, None], patch, base)
                side_data = {side: patch for side in sides}
                force_edges(result, base, side_data)
                verify_edges(result, base, side_data)
                edge_checks += 4
                save(directory / f'auto_{pair}_{key}_v{variant}.png', result)
        spec['sources'].append(dict(name='auto_' + pair, columns=8, tile_size=[48, 48],
            autotile=dict(pair=pair, base_tag=base_name, patch_tag=patch_name, dir='res://' + str(directory.relative_to(ROOT)).replace('\\', '/'), prefix='auto_' + pair, variants=2),
            terrain=dict(set=pair, base={'grass': '草地', 'dirt': '泥土'}[base_name], patch={'dirt': '泥土', 'road_stone': '石砖路'}[patch_name])))
    shore_items = []
    for code in range(81):
        result = arrays['water_deep'].copy()
        remaining = code
        side_data = {}
        for side in SIDES:
            kind = remaining % 3
            remaining //= 3
            if kind == 0:
                continue
            land = arrays['grass' if kind == 1 else 'dirt']
            outer = extent(side, 7, 1)
            inner = extent(side, 3, 1)
            result[outer] = arrays['dirt'][outer]
            result[inner] = land[inner]
            side_data[side] = land
        force_edges(result, arrays['water_deep'], side_data)
        verify_edges(result, arrays['water_deep'], side_data)
        edge_checks += 4
        path = OUT / 'shore' / f'shore_{code}.png'
        save(path, result)
        shore_items.append(dict(tag=f'shore_{code}', name=f'三材质水岸 {code}', solid=True, file='res://' + str(path.relative_to(ROOT)).replace('\\', '/')))
    spec['sources'].append(dict(name='shore', columns=9, tile_size=[48, 48], items=shore_items))
    for path in OUT.rglob('*.png'):
        if 'raw' in path.parts:
            continue
        data = np.asarray(Image.open(path).convert('RGBA'))
        assert data.shape == (48, 48, 4) and np.all(data[:, :, 3] == 255)
    report = dict(materials=manifest, shared_variant_border_px=3, edge_checks=edge_checks,
                  shore_combinations=81, transition_tiles=64, generator='built-in image_gen',
                  pixelize_sha256=sha(ART / 'tools/pixelize.py'))
    (OUT / 'manifest.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    (ROOT / 'maps/godot/tilesets/leyton_surface_v2.spec.json').write_text(json.dumps(spec, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()
