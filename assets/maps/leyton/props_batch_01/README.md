# 莱顿共享物件01 · 验收候选

本批交付六件FreeProp，面向市场、煤粮物流、城门检查和公共告示。生成方式：**内置image_gen**，逐件独立生成；完整精确提示词见[prompts.json](prompts.json)。没有覆盖现有美术或改动八图摆放。

先看[验收图](qa/review_sheet.png)：上部为2倍像素与1.8米人体标尺，下部为原尺寸在草地、泥地和石路上的效果。人体标尺是测量示意，不是角色美术。棋盘格只在验收背景中，PNG素材有真实透明度。

| 编号 | 素材 | 实际轮廓 | PNG | 候选场景 |
|---|---|---|---|---|
| 01 | 木箱 | 44×47px | sprites/prop_crate.png | scenes/crate.tscn |
| 02 | 木桶 | 34×47px | sprites/prop_barrel.png | scenes/barrel.tscn |
| 03 | 粮袋堆 | 72×57px | sprites/prop_grain_sacks.png | scenes/grain_sacks.tscn |
| 04 | 煤筐 | 64×37px | sprites/prop_coal_basket.png | scenes/coal_basket.tscn |
| 05 | 公告栏 | 68×55px | sprites/prop_notice_board.png | scenes/notice_board.tscn |
| 06 | 手推车 | 58×102px | sprites/prop_handcart.png | scenes/handcart.tscn |

## 技术验收

- 66项像素/文件检查、32项实际GPU/物理检查、33项既有地图一期回归均通过。
- 透明画布边缘、非空轮廓、源图SHA、原有环境色板、稀少亮点、接地点、独立碰撞及YSort层级通过；qa/pixel_checks.json记录各项统计。
- GPU对每件素材实测前后遮挡：同一世界采样点，后方探针被挡、前方探针可见。六件均通过；qa/runtime.json记录结果。
- PNG四周保留透明留白。只在测量裁切框时忽略alpha低于5%的零散残留，框内alpha保留；原始生成图在source/完整保存。
- 缩放使用最近邻；RGB映射至map_env环境色板及规范描边色，没有重画或手工拼装物体。
- 尺寸与锚点在manifest.json中；建议碰撞是独立矩形，不能从视觉透明度推导。场景以底部接地点参与现有FreeProp排序，不额外添加第二层阴影。

## 视觉验收结论

六件已完成候选制作，材质和用途可辨，正交轴线与统一光向基本一致。**煤筐和木桶在深草地上对比偏弱**，建议优先摆放在清理过的泥地/石铺区域；正式密集摆放时还需检查相邻物体遮挡和地表噪声。公告文字为不可读的装饰笔画，未制作真实告示内容或纹章。

候选状态不表示用户已经批准最终风格。本批已完成技术验收和对照图制作；正式八图部署、交互、手推车移动与动画另做，不将六件物件计作城区完成。

## 文件与复现

- source/：六张原始透明PNG；sprites/：六张按48px/m注册的游戏PNG。
- scenes/：六个现有FreeProp契约的独立候选场景；review.tscn：可直接在Godot打开的验收场景。
- prompts.json：六个实际发送提示词；manifest.json：SHA、裁切框、尺寸、锚点、建议碰撞、明度。
- qa/：验收图、像素和GPU报告、导入/运行/回归日志。
- tools/build_batch.gd → 编辑器导入 → tools/package_scenes.gd → tools/validate_batch.gd → tools/run_review.ps1。全部从C:\游戏运行，Godot为C:\1\Godot_v4.7.1-stable_win64_console.exe。
- run_review.ps1后台启动隐藏GPU实例并返回PID；qa/runtime.log中PROPS_RUNTIME为完成标记。验收场景分辨率1280×960。

原始生成记录均属于本批内置工具输出；最终文件已归档在项目目录，不依赖.codex临时输出位置。
