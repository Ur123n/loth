# 城北连续街坊样段 v3
Updated: 2026-09-28 Asia/Shanghai
Status: playable_sample_complete_visual_review_pending

## Objective / scope
用户授权按根目录参考图开始制作。完成32×32米局部可玩样段，再按视觉反馈扩展正式M02；此状态不代表全城任务完成。

## Canonical / runtime
C:/游戏；maps/leyton/street_sample_v3/layout.json为样段布局源；review.tscn为运行入口；根目录preview_street_v3.bat可直接启动。Godot C:/1/Godot_v4.7.1-stable_win64_console.exe。
正式slice.json与修道院本轮未改。共享graybox_map.gd仅新增可选layout_document，默认仍原路径；原件backup/graybox_map.gd。

## Completed
- 九处手工街坊/院墙占地、围合私院、步行巷、井台节点和曲折车路，六件既有生活道具。
- 四件image_gen新素材：共墙街屋、转角住宅、纵深附属翼、井台；原图、初稿、提示词、裁切信息和SHA在assets/maps/leyton/street_sample_v3。使用内置工具，5次调用含街屋视角修正。
- 完整Pattern/FreeProp场景、独立地面碰撞和YSort，样段屋顶淡化与恢复，V素材/灰盒对照。两处院门构件保留灰盒。
- 试玩入口、README、世界规则/架构与开发变更日志已更新。

## Verification
- 灰盒阶段12项逻辑检查通过；最终21项逻辑检查通过；GPU含5张截图共26项通过，renderer=NVIDIA GeForce RTX4060Ti，capture.err.log为空。
- 已直接查看灰盒、贴图总览、街面、私院与东侧街道实际截图，输出在qa/。图片来自--path C:/游戏的真实Godot运行。
- 完整validate.ps1退出0：LEYTON67、ATLAS451、WORLD_DEMO211、BRIDGE138、GATEHOUSE69、GATEHOUSE_ART24、SURFACE60、BASIC_MATERIALS51、URBAN_REWORK277、MAP_PIPELINE85、BUILDING296、PHASE_ONE33；既有编译检查145脚本失败0。新增脚本另由样段运行/资源导入实际解析。
- 四件源图/游戏图8个SHA重新核对一致；布局与manifest JSON解析通过。生成注册脚本读取原图时的Image离线警告不来自运行场景。
- 图谱generation=2026-09-14，相关路径freshness missing，使用直接源文件检查；未依赖图谱做完备性断言。

## Limitations / remaining
两处院门体块未补正式素材；建筑仍复用与按宽度等比缩放，逐栋尺寸、朝向和转角接合需下一轮细化；门未接室内；角色仍为原审验占位。屋顶横向分层是当前可追踪方案，复杂山墙尚无精细语义掩码。样段用户视觉反馈未获得，不宣称已被认可。

## Next exact action
依据本轮实际截图/试玩反馈细化街坊门楼、建筑比例与朝向，再将连续街坊组织方式扩展到M02；不要重新启用矩形独栋填空脚本。全城与修道院的总体任务持续记录在maps/leyton/WORKLOG.md。
