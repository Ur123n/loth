# 会堂美术样板工作记录

Updated: 2026-10-04 Asia/Shanghai
Status: candidate_runtime_verified

## 目标与源路径

12×10m会堂推进为可运行分层美术候选；保持南北门、碰撞、遮挡与48px/m比例。

- 美术源：C:/美术素材制作/working/hall_art_v1_20261004
- 几何源：C:/美术素材制作/greybox/buildings/workflow_hall_v1
- 运行候选：C:/游戏/dev/hall_art_v1
- 入口：C:/游戏/启动会堂美术审验.bat
- 实施脚本、日志、备份：C:/Users/njw/hall_art_v1_20261004

## 完成内容

- 内置imagegen生成石墙、旧石地面、暗石板屋顶；墙体进行一次边缘清理迭代。
- 保存原图、四份完整提示词与receipt.json来源哈希。
- 原图未达到请求的672×576：墙体/屋顶1355×1161，地面1355×1160。目前作为表面材质候选，尚未进入标准分层PNG发布流程。
- 独立Godot场景使用灰盒alpha限制轮廓，按672×576逻辑画布采样并映射map_env色板；缺色处使用材质基色。
- 继承大厅几何、门洞、屋顶自动隐藏与语义排序；C键切换美术/灰盒，B键显示碰撞。
- 未填写用户visual批准或执行正式发布。

## 验证

- Godot 4.7.1资源导入通过。
- 样板17项、地图85项、建筑296项检查通过，共398项。
- 实际OpenGL运行捕获室外、室内和北门；室外、室内画面已查看。
- GPU检测：Ground/Base/Roof与灰盒alpha不同的像素均为0。
- 三层超出map_env色板的颜色数量均为0（每通道容差1）；分别使用25/29/32种颜色。详见gpu_qa.json。
- 首次GPU测试使用不存在的own_world_2d属性失败，修为world_2d = World2D.new()后重跑成功；失败进程已停止。
- 图谱list_projects返回Transport closed，本轮使用已知路径和精确源码核对。

## 限制及下一步

- 交付为已验证运行的美术候选，最终风格待用户审阅；不宣称生成原图像素精确对齐。
- 下一步运行启动器，以C键比较灰盒并检查南北门；按反馈迭代，然后决定标准PNG打包与正式地图接入。
- 本轮未修改战斗；前阶段独立战斗AI问题见docs/art/map_workflow_20261004/WORKLOG.md。

## 原图与完整提示词

- base_surface_v1.png：墙体；base_draft_v1.png、base_draft_v2.png：迭代留档。
- ground_surface_v1.png：地面；roof_surface_v1.png：屋顶。
- base_prompt.txt、base_fix_prompt.txt、ground_prompt.txt、roof_prompt.txt：实际提交的完整提示词。
- review_outside.png、review_inside.png、review_north.png：运行截图。
- receipt.json：来源哈希；validation.json：运行代码及截图哈希；gpu_qa.json：GPU检测。

## 2026-10-04 启动器修复

- 复现原BAT错误：Invalid project path specified；带引号的%~dp0以反斜杠结尾，场景参数被并入项目路径。
- 会堂美术与地图灰盒两个入口改用%~dp0.，保留错误退出码，失败时暂停显示报错，支持透传诊断参数。
- 从C:/Users/njw通过cmd实际执行两个BAT并传入--quit-after 90，均初始化OpenGL且退出码0；会堂额外在沙箱外运行复验。
- 沙箱内测试有系统证书存储读取提示；不影响场景启动。此前仅直接验证Godot场景，遗漏了BAT入口，本轮补齐入口验证。
- 仅修改启动脚本，未修改场景、材质或游戏逻辑。原BAT保存在本次任务backups/launchers_*目录。
