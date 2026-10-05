# 修道院—莱顿移动审验与基础材质

Updated: 2026-09-28 Asia/Shanghai
Status: complete

## Objective

恢复上次未收尾的大世界移动 Demo，并按用户追加要求调用 image 模型补基础灰盒贴图；详细建筑美术留待后续。

## Canonical source and runtime target

- 规范源与运行项目：`C:\游戏`；Godot 4.7.1.stable.official.a13da4feb，`C:\1\Godot_v4.7.1-stable_win64_console.exe`。
- 入口：`dev/leyton_world_demo/world_demo.tscn`；用户入口：根目录 `启动莱顿大世界审验.bat`。
- 文档/安装脚本暂存：`C:\Users\njw\game_stage\leyton_world_resume`，不参与运行。
- 基础材质原图、提示词、48px图块、重建脚本：`assets/maps/leyton/basic_materials_v1/`。
- 备份：`maps/leyton/archive/pre_world_demo/` 和 `pre_basic_materials_v1/`；后者保存改动前地图脚本、上级日志与 Demo QA。

## Definition of done

- [x] 当前版本九图、16条有向连接、实际输入南下、返回保护、门禁/墙梯验收。
- [x] 四种内置 image_gen 材质落盘并实际接入，48px色板转换和4×4铺图目检。
- [x] 八区三态逐格通行掩码与灰盒一致，共享 TileSet 未污染。
- [x] 完整相关回归与所有脚本编译通过，详见 `maps/leyton/qa/`。
- [x] 规范项目 GPU 实际运行，Demo七张截图、八区总览与门禁截图成功；stderr为空。
- [x] 启动说明、素材说明、工作日志、架构和变更记录同步。

## Completed

- Demo沿用已有实现，补齐上次停止的验收交付。出生修道院南侧，S南下进入M05城外，开放门禁时继续到M02/M01。
- 北、西、南、东路线与原拓扑一致；M01→M08保留普通住宅区抽象路程提示，生产地图和存档入口不变。
- 内置image_gen分别生成暗瓦、耕土、旧木板、踩实泥地。源图SHA及处理流程见manifest.json，完整提示词见prompts.json。
- 新材质覆盖16,734格；果园/牧草地等基础色块复用既有草地。T保留诊断灰盒；碰撞与完整Building Prefab不变。
- Windows PowerShell首次误读无BOM UTF-8路径，改为UTF-8 BOM后成功；误建空目录及唯一.gdignore已验证内容后清理。

## Validation

- 材质专测：51 passed / 0 failed；八区每格×三态比较，T切换与共享资源保护。
- 完整回归：`maps/leyton/tools/validate.ps1`，1,385项检查全部通过，142个脚本编译failed=0；包含移动Demo 213项和16条有向连接。各项结果保存在 `maps/leyton/qa/`。
- GPU：NVIDIA RTX 4060 Ti；`dev/leyton_world_demo/qa/render.json` 和 `maps/leyton/qa/atlas_render.json`，均failed=0。
- 直接目检：修道院出生/总览、M05到达/关门、路线图、中心广场、东门到达和八区拼图。耕沟/建筑基础材质已可见，无贴图缺失；角色与路线提示可见。
- 旧图谱generation=2026-09-14T16:04:19Z，相关新文件freshness=missing。Verify层级查询后回读实际源文件，没有用旧图谱作完备性断言。

## Limitations / Pending

- 本轮完成基础材质与移动Demo，不等于八区完整建筑美术交付。无Prefab的建筑仍是矩形占地加基础材质，太阳神像等专属造型尚未制作。
- 暗瓦重复接缝仍可见，未承诺像素级无缝；完整屋顶/转角/地块边缘过渡、作物与树木以后补。
- 旧地表高频噪声、门洞遮挡反馈、暗草地道具对比问题仍见原visual_audit_01；本轮不宣称已修复。
- 玩家、关闭屏障、出口和墙梯标记仍为审验图形；地图边缘外显示灰色背景。

## Next exact action

双击根目录 `启动莱顿大世界审验.bat`，WASD行走、M看路线、Tab看当前图、T对比灰盒；后续按用户指示补完整建筑和细节。

## Changed paths

- `maps/leyton/graybox_map.gd`：source1001注册基础材质，深拷贝pipeline metadata。
- `assets/maps/leyton/basic_materials_v1/`：四张模型原图、提示词、图块、atlas、重建脚本、manifest和QA。
- `tests/map/test_basic_materials.gd`、`maps/leyton/tools/validate.ps1`：全格通行对比纳入回归。
- `dev/leyton_world_demo/{README,WORKLOG}.md`、上级日志及world架构/变更记录：交付说明。

## Runtime state

- 验收实例运行后退出；不保留后台游戏。启动器供用户交互审验。
- `.godot`由引擎正常导入更新，未手改缓存。磁盘与实际GPU截图均来自规范项目。
