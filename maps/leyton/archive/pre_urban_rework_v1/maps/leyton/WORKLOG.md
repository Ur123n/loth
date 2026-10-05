# 莱顿城地图集工作日志

Updated: 2026-09-28 Asia/Shanghai
Status: movement_demo_and_basic_materials_v1_complete

## 当前任务与成果

用户要求“先批量制作美术素材，验收”。优先级已从继续地图结构转为共享物件批量生产。本轮完成6件：木箱、木桶、粮袋堆、煤筐、公告栏、空手推车。交付原图、游戏尺寸透明PNG、独立FreeProp场景、统一验收图、提示词和技术报告。

美术风格最终确认仍为候选状态；未声称用户已经批准。未改动八区摆放、导航或城门。整个地图集仍为8/8基础可玩灰盒，0/8完整交付。

## 规范源与运行

- 项目/运行：C:\游戏；Godot C:\1\Godot_v4.7.1-stable_win64_console.exe，4.7.1。
- 本批规范包：assets/maps/leyton/props_batch_01/；说明README.md，制作范围BATCH_PLAN.md。
- 生成：内置image_gen，每件单独调用；六个原始提示词prompts.json，源图source/，不覆盖旧资产。
- 原图SHA及注册信息：manifest.json。游戏图sprites/prop_*.png；候选场景scenes/*.tscn；验收场景review.tscn。
- build_batch.gd进行机械裁切测量、最近邻缩放和环境色板映射；未用代码替代生成物体美术。使用alpha>=5%测量裁切边界，框内原alpha保留。
- 接地点为底部中心，碰撞建议独立于PNG；复用core/world/free_prop.gd，不新建平行玩法系统。
- C:\Users\njw\game_stage\leyton_props_batch仅为补丁暂存，不参与运行。

## 实际产物

| 素材 | 注册轮廓 | 画布 |
|---|---|---|
| crate 木箱 | 44×47 | 96×96 |
| barrel 木桶 | 34×47 | 96×96 |
| grain_sacks 粮袋堆 | 72×57 | 144×96 |
| coal_basket 煤筐 | 64×37 | 144×96 |
| notice_board 公告栏 | 68×55 | 144×144 |
| handcart 手推车 | 58×102 | 144×192 |

## 验收证据

- 6件PNG解码、源图哈希、尺寸、透明边缘、色板、亮点比例、碰撞建议及锚点共66检查通过，qa/pixel_checks.json。
- 实际NVIDIA RTX4060Ti GPU检查32项通过，qa/runtime.json。包含每件前后YSort遮挡像素检查、独立碰撞体及物理点查询。
- 现有FreeProp所在地图一期回归33项通过，qa/phase_one.log；本轮共131项相关检查通过。
- qa/review_sheet.png为实际Godot截图，已直接查看最终版本：2倍细节、1.8m人体测量线稿、原尺寸三种地表对照。
- 最终GPU stderr为空、导入日志无ERROR/WARNING。验收截图工具不会向八区场景写入物件。
- 木箱均值亮度62.8、木桶59.9、粮袋80.4、煤筐38.4、公告栏67.9、手推车57.4；亮点占比均低于0.34%，不是逐件强行满足画面级75/20/5。
- 图谱generation仍为2026-09-14；FreeProp与角色参照路径freshness缺失，已回读源文件。没有依赖图谱作完备性断言。

## 发现与处理

- 手推车源图有近乎透明的边缘残留，直接非零alpha包围框错误触边；改用5%阈值仅测量裁切框，原始源图完整保留。
- 验收场景最初短生命周期背景纹理显示成白块；改为持有纹理引用后重跑GPU，三种背景均正确。
- 旧48×96角色图片实际人体只有约48px且带深底，不能作为严格比例尺；最终改用准确1.8m中性人体测量线稿，未修改旧角色资源。
- 煤筐/木桶在深草地上对比偏弱，建议泥地/石路或先清理地表噪声。该限制写入README，不把技术通过等同于任何场景都适用。

## 备份、剩余工作与下一步

- 前一轮八区完整日志保存于maps/leyton/archive/pre_props_batch_01/WORKLOG.md；该目录有.gdignore。
- 批次01为新增版本目录；M04石桥、M07门楼、八区布局均保持前轮状态。
- 下一步按本批验收意见调整候选并决定正式入库；随后继续共享市场/农业素材批次，大型太阳神像/门楼仍按完整建筑需求与概念流程单独制作。
- 手推车目前是静态道具，不具有转向、移动或载货动画；公告栏无真实文本、纹章或交互。大范围布置还需地图级通行与密集遮挡检查。

## 视觉模型审验01

- 用户要求用视觉识别模型审验已完成部分。本轮使用当前会话多模态模型，通过view_image直接读取11张归档渲染图；没有调用另一个独立外部模型，也没有重跑运行场景。
- 结论：有条件通过，3项P1先修：地表高频噪声、门洞覆盖区角色追踪缺失、煤筐/木桶暗草地低对比。另有桥跨层次、门楼高差2项P2优化，以及公告栏用途/高度1项待确认。
- 已知灰盒、诊断色块、未做门扇/水门和城区建筑单独列为交付缺口；没有把它们当作本轮新发现的主体资源损坏。
- 报告qa/visual_audit_01/report.md；可切换定位框的图文页index.html；结构化问题findings.json；11张原样证据副本及SHA/修改时间evidence_manifest.json。
- 本轮未修改美术、碰撞、导航或地图摆放。源图与副本哈希一致，报告范围为静态视觉意见；已有技术检查结果保留，不宣称重新跑过。
- 下一步先将地表降噪与煤筐/木桶背景适配做同场景对照，然后补门洞受控角色可见反馈并连续移动复验。

## Active movement demo increment
Status: complete. Monastery spawn, southbound travel, all 16 directed connections, regressions and GPU review completed on 2026-09-28. See dev/leyton_world_demo/WORKLOG.md and README.md.

## 2026-09-28 基础材质与移动Demo交付

用户追加要求调用image模型补基础灰盒贴图，细节日后补。内置image_gen完成暗瓦/耕土/旧木板/踩实泥地四张原图，basic_materials_v1保存提示词、源图SHA、48px图块和铺图预览，覆盖16,734格。八区三态全格碰撞对比51项通过；完整回归、实际GPU总览与Demo截图通过。

新增材质不等于完整建筑美术：无Prefab的结构仍保留占地轮廓，太阳神像、屋顶轮廓、作物和区域边缘细节后续补。既有视觉审验问题继续有效。验收与限制详见dev/leyton_world_demo/WORKLOG.md。
