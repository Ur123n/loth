# 莱顿城 M04 货运石桥

状态：v2注册图层已接入独立Building，通行与实际GPU遮挡已验收（2026-09-27）。

- 唯一规范源 `building.spec.json`；场景 `LeytonCargoBridge.tscn`；12×11格、48px/格，四周1格透明边。
- v1/v2为内置image_gen原始源稿；提示词分别存于 `source/exact_bridge_prompt.txt`、`source/exact_bridge_prompt_v2.txt`。原稿不直接参与运行。
- `source/registered_v2/registration.json`记录v2源图SHA256和尺寸配准控制线；`registered.png`是完整配准图，`deck.png`与`rails.png`互补且能逐像素重组。
- `Visual/Deck`读取`visual/deck.png`，z=-1；`Visual/Base`读取`visual/base.png`护栏图，进入YSort时由语义带接管并隐藏原Sprite。
- 五条语义带覆盖完整画布，仅东西护栏带含非透明像素，脚点为地图y=69格；三条透明带服务既有完整覆盖校验，不产生可见覆盖。
- 露天桥不需要屋顶；碰撞始终来自规范和掩码，与图片alpha独立。
- 生成器默认`preview/preview.png`仅显示Base护栏层；查看整桥请用`source/registered_v2/registered.png`或运行截图。
- 灰盒源图保留；完整旧版本备份在`maps/leyton/archive/pre_bridge_layers/`，可恢复。

## 重建

以下命令在工程根执行，`godot`代表`C:\1\Godot_v4.7.1-stable_win64_console.exe`。

1. `godot --headless --path . --script maps/leyton/tools/prepare_bridge_art.gd`
2. `godot --headless --path . --script maps/godot/tools/build_building.gd -- --id leyton_cargo_bridge --phase visual`
3. `godot --headless --path . --editor --import`
4. `godot --headless --path . --script maps/godot/tools/build_building.gd -- --id leyton_cargo_bridge --phase prefab`
5. `godot --headless --path . --script tests/map/test_leyton_bridge.gd`
6. `godot --path . --rendering-method gl_compatibility --script maps/leyton/tools/capture_bridge_art.gd`

源图SHA发生变化时注册脚本会拒绝执行，需重新人工核对边界，不可盲目跳过。
完整结果：`maps/leyton/qa/BRIDGE_ART_QA.md`；进度：`maps/leyton/WORKLOG.md`。
