# 修道院与莱顿 M02 地图重制工作记录

Updated: 2026-10-05 Asia/Shanghai
Status: released

## Objective

按现行《地图与大型建筑制作指导手册》和两份版本更迭指南，发布并验证伊瑟拉修道院与莱顿城 M02 的视觉重制版本。

## Canonical source and runtime target

- 游戏规范源：`C:/游戏/docs/world/version_guides/`。
- 美术规范源：`C:/美术素材制作/docs/地图与大型建筑制作指导手册.md`。
- 当前运行源：`C:/游戏`；Godot：`C:/1/Godot_v4.7.1-stable_win64_console.exe`。
- 暂存源：`C:/Users/njw/map_rework_20261005_r01`。
- 活动接入：`assets/buildings/iserra_monastery_highland/IserraMonasteryHighland.tscn` 与 `maps/leyton/scenes/m02.tscn`；正式材质在 `assets/map_versions/`。
- 候选、QA 和发布回退：`dev/map_versions/map_rework_20261005_r01/`。

## Scope and invariants

- 任务类型为 `surface` / `building appearance`；不改变占地、出生、出口、道路、水体、门禁、碰撞、12 个修道院标记或故事功能。
- 修道院贴图更换已有明确授权；本轮不开放室内，不新增自动屋顶。
- 莱顿先完成 M02 的可审阅区段，不将一次视觉更新扩展到全部八区。
- 用户已批准发布；只切换两个活动场景的材质绑定，不修改布局、逻辑掩码或共享地图生成器。

## Definition of done

- [x] 当前源、加载链、Git 状态、进程与工具完成新鲜快照。
- [x] 两份 revision 任务单、原文件备份和回退依据齐全。
- [x] 修道院候选在独立世界审验入口中加载并可切换新旧材质。
- [x] M02 候选在同一入口加载，保留布局和通行，34 座宅邸轮换三套材质。
- [x] 资源可导入，针对性检查和 GPU 色板/alpha 检查通过。
- [x] 本轮完整地图回归 13/13 与脚本编译 160/160 通过。
- [x] 真实 GPU 固定机位截图已生成并检查；新旧图像哈希不同。
- [x] 用户确认发布后，活动入口加载正式版本；发布前备份与哈希清单齐全。
- [x] 发布后默认主场景、九图 Demo 和 M02 实际入口验证通过。

## Current evidence

- codebase-memory 项目 `C-e6b8b8e6888f` 已于 2026-10-05 重新 fast-index：29152 nodes / 45216 edges。
- 发布前 Git HEAD：`b28ca40d979b3d777820ac02abb9b236de26c711`；工作区有大量既有修改和未跟踪文件，提交只收录本次发布文件。
- 当前没有 Godot 进程；Godot 可执行文件存在。
- 当前默认入口仍读取修道院 highlands；九图 Demo 读取活动 M02 场景，两个入口现在都加载正式版本材质。

## Completed and validation

- 2026-10-05 基线：13 项现行地图回归 `failed=0`，NVIDIA GPU 旧版截图已保存。
- 候选入口：`review.tscn` / `launch_candidate.bat`，九图移动审验；V 切新旧材质。
- 修道院：2400×2880 Base 材质；修复五个运行时 YSort 遮挡带的材质绑定与切换。Shadow/WarmLight、占地、门、碰撞和地图功能保持原版。
- M02：88×80 的 `slice.candidate.json` 与活动版逐字一致；34 个住宅按 12/11/11 使用三套候选材质。
- 针对性 Godot 检查 `22/22 failed=0`，包含 M02 全部 7040 格通行一致、修道院 12 标记和五个遮挡带绑定。
- GPU 检查四层 alpha 偏差均为 0，不透明色板越界均为 0；半透明边缘单独计数。报告：`qa/gpu_qa.json`。
- 固定机位 GPU 截图 7 张，`qa/render.json failed=0`；修道院和 M02 候选/活动总览图哈希不同。修道院候选较暗，M02 候选降低同款重复感，保留原布局。
- `tools/verify_active_hashes.ps1`：25 个活动源哈希与重制前一致，`failed=0`。
- 四张生成原图及提示词：`assets/map_versions/iserra_surface_20261005_r01/` 和 `leyton_m02_surface_20261005_r01/`；两份 `task.json` 含材质 SHA256。
- 本轮完整地图回归：`maps/leyton/tools/validate.ps1` 的 13 项均 `failed=0`，脚本编译 `scripts=160 failed=0`；日志位于 `maps/leyton/qa/`。
- 用户明确答复“可以发布，记得帮我git”；已将两版材质接入正式资源，发布前精确备份位于 `publish_before/`，`.gdignore` 防止 Godot 扫描副本。
- 发布后 `tools/check_release.gd` 17/17 通过；默认主场景和九图 Demo 修道院均有五个正确绑定的遮挡带，活动 M02 34 座住宅材质均已加载。
- 发布后 NVIDIA GPU 捕获三张：`qa/released_iserra_overview.png`、`qa/released_m02_overview.png`、`qa/released_m02_north_street.png`；`qa/release_render.json failed=0`，实际画面已检查。
- 发布后完整地图回归再次 13/13 `failed=0`，脚本编译 `scripts=160 failed=0`。
- `release_manifest.json` 记录全部发布哈希和回退映射；`tools/verify_release_hashes.ps1` 核对 23 个基线源未变、2 个活动场景已切换、8 个正式资源哈希一致，`failed=0`。

## Blockers and warnings

- 既有工作区很脏，不能依赖 Git 回退；本轮使用独立版本目录、精确哈希和文件清单。
- 生成美术必须由灰盒 alpha/逻辑数据约束；生成图片不作为碰撞来源。

## Next exact action

如需下一版，先确定 M02 街坊布局调整范围；本版只更新材质。回退时按 `release_manifest.json` 精确恢复两个场景，并重新导入与复验。
