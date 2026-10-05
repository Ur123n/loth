# 莱顿 M07 西门楼

2026-09-27。独立 Building：`LeytonWestGatehouse.tscn`。静态建筑已替换为分层美术；动态门扇仍为状态色块，室内、NPC 和水门另待制作。

- 地基左上 (85,32)，11×16 格；176 格占用、66 格地面通道、110 格实体。中央东西门洞净宽六格。
- 北南两翼石墙、深色瓦顶；东侧三格巡逻道保持通畅，护栏各向通道外延伸24像素。
- 共用624×864透明画布：Floor z=-1、Base z=0、Roof z=2、WallWalk z=4；墙顶玩家 z=5。
- 地面与上层导航分离，开放/宵禁/封锁逻辑及原有碰撞保持不变。墙梯仅供步行角色使用。

## 规范源与重建

原始生成图 `source/concept_v1.png`；完整提示词 `source/exact_concept_prompt_v1.txt`；测量参考 `source/art_geometry_guide.png`。原图 SHA256：`df4dfc32cc8fa283247b731b0b2db2aaf6af894df3fd1a0d5000552ed4baff19`。

`maps/leyton/tools/prepare_gatehouse_art.gd` 负责按测量坐标注册、分层，并在 `source/registered_art_v1/` 输出图片、注册记录及候选规格 `building.spec.staged.json`。建筑逻辑规范仍为包内 `building.spec.json`。

1. 使用项目 Godot 4.7.1 运行 `--headless --path . --script maps/leyton/tools/prepare_gatehouse_art.gd`。
2. 比较候选规格与当前规格，确保 plan/collision/tactical 数值语义不变，再用候选规格替换当前规格。不要未经比较覆盖。
3. 运行 `maps/godot/tools/build_building.gd -- --id leyton_west_gatehouse --phase visual`，然后 `--editor --import`，再运行同一生成器的 `--phase prefab`。此次纯美术重建不需要重新生成掩码。
4. 运行 `maps/leyton/tools/validate.ps1` 和 `maps/leyton/tools/run_gatehouse_capture.ps1`，检查日志与实际截图。

旧 `prepare_gatehouse.gd` 仅保存灰盒几何历史；检测到当前美术注册记录时会拒绝覆盖。灰盒资源备份在 `maps/leyton/archive/pre_gatehouse_art/`。

入口 `maps/leyton/scenes/slice_test.tscn`，按7进入西门。完整画面见 `maps/leyton/qa/gatehouse_art_*.png`，默认建筑 preview 仅显示 Base，不能代表四层效果。
