# 莱顿城地图集工作日志

Updated: 2026-09-27 Asia/Shanghai
Status: M07_static_gatehouse_art_runtime_verified

## 本轮成果

- M07西门楼由结构灰盒升级为深青石墙、深色瓦顶和高架巡逻道的四层静态美术；已接入实际地图运行。
- 当前仅完成门楼静态外观增量。完整地图交付仍为0/8；未迁移生产主场景。

## 规范源与运行目标

- 规范源/运行：C:\游戏；Godot：C:\1\Godot_v4.7.1-stable_win64_console.exe（4.7.1）。
- 入口：maps/leyton/scenes/slice_test.tscn，按7进入西门；地图通过slice.json加载独立Building。
- 原始生成图：assets/buildings/leyton_west_gatehouse/source/concept_v1.png（1066×1476，真实透明）。
- 原图SHA256：df4dfc32cc8fa283247b731b0b2db2aaf6af894df3fd1a0d5000552ed4baff19。
- 生成方式：内置image_gen，参考当前测量灰盒与M04石桥材质；完整提示词source/exact_concept_prompt_v1.txt，测量图source/art_geometry_guide.png。
- 原始工具输出：C:\Users\njw\.codex\generated_images\01a0e2df-98b2-7193-a44d-3eeb07515e36\exec-5004671d-782e-407f-b2b2-8c727d6bd144.png，已复制归档到项目。
- 注册源：maps/leyton/tools/prepare_gatehouse_art.gd；输出source/registered_art_v1/内四层、合成图、延伸纹理和注册记录。
- 当前逻辑规范：建筑包building.spec.json；重建先生成候选building.spec.staged.json，比较逻辑字段再推广，随后visual/import/prefab。完整命令见建筑README。
- 旧prepare_gatehouse.gd已加覆盖保护，不能直接将当前美术退回灰盒。
- C:\Users\njw\game_stage\leyton_gate_art只作编辑暂存，不参与运行。

## 已完成与验证

- [x] 624×864透明画布，Floor z=-1、Base z=0、Roof z=2、WallWalk z=4；四层互斥像素重建与注册图完全一致。
- [x] 北南翼楼与六格地面门洞、三格墙顶通道对齐；墙顶护栏各向通道外延伸24像素，不压缩通行净宽。
- [x] 门楼外墙顶使用同源纹理重复段，保持跨越水门的连续巡逻路径。
- [x] 五张逻辑掩码与灰盒备份哈希一致；plan/collision/tactical数值语义不变。176占用/66可走/110阻挡、两入口和两碰撞矩形保持不变。
- [x] 三种城门状态的全图地面/墙顶通行摘要与原基线相同；上下墙、动态物理阻挡、安全切图继续通过。
- [x] 实际GPU八张截图生成；直接检查开放地面、关门上层、水门上方画面；同XY地面玩家被遮、墙顶玩家可见，两项像素检查通过。
- [x] 建筑资源包校验errors=0/warnings=0。
- [x] 完整回归：LEYTON61、BRIDGE138、GATEHOUSE69、GATEHOUSE_ART24、SURFACE60、Map85、Building296、Phase one33，共766断言全部通过；139脚本编译检查通过。

## 证据与备份

- qa/GATEHOUSE_ART_QA.md、qa/gatehouse_art_render.json（failed=0，NVIDIA GeForce RTX4060Ti）。
- qa/gatehouse_art_{open_ground,open_cart,curfew,sealed,wall_over_closed_gate,wall_over_water_gate,probe_ground,probe_upper}.png。
- qa/test_*.log为当前全回归；qa/gatehouse_art_import.log、gatehouse_capture.err.log为导入/运行证据。
- archive/pre_gatehouse_art/保存旧灰盒资源包、旧prepare/capture/graybox_map/门楼测试和前一轮WORKLOG；.gdignore排除备份导入。
- archive/pre_gatehouse/另保留更早布局和脚本；不是本轮所有文件的完整快照。
- 图谱项目C-e6b8b8e6888f；先前索引generation为2026-09-14，相关freshness缺失，已用当前源文件和实际运行验证补足，不以旧图谱作为完整性证明。

## 前序成果

- M04石桥分层美术、护栏YSort、玩家/马车通行已验证，见qa/BRIDGE_ART_QA.md。
- M07独立Building结构、双层导航、三态关门、墙梯及拒绝进入关闭门洞的安全切图已完成，见qa/GATEHOUSE_QA.md。
- M01/M04/M07沿用v2地表，仍为可玩制作切片。

## 限制与下一步

- 动态门扇尚未制作；宵禁/封锁仍用黄/红诊断填色。下一步先制作与六格门洞对齐的关闭门扇草稿，再替换状态色块，保持碰撞和双层基线不变。
- 水门仍是独立占位结构；门楼室内、NPC岗位、精细纹章、门扇动画待制作。原图微型纹章没有按设定细节逐项验收。
- 马车为2×3测试矩形，转向、交通、会车未实现。
- 剩余五区、其余建筑/Prop与生产主场景接入待完成。
- 默认preview.png只显示Base，完整外观以四层运行截图为准。

## 变更路径

- assets/buildings/leyton_west_gatehouse/源图、四层资源、规格、场景和README。
- maps/leyton/tools/prepare_gatehouse_art.gd、make_gate_art_guide.gd、prepare_gatehouse.gd、capture_gatehouse.gd、validate.ps1。
- maps/leyton/graybox_map.gd、viewer.gd、slice.json；tests/map/test_leyton_gatehouse_art.gd。
- maps/leyton/GATEHOUSE_ART_PLAN.md、qa/GATEHOUSE_ART_QA.md、README.md、本日志；docs/world/rules.md及开发changelog。
