# Work Log

Updated: 2026-10-04 Asia/Shanghai
Status: complete_for_requested_workflow_scope

## Objective
完善地图制作闭环：数据驱动建筑转换、复用审批发布机制、12×10m 建筑灰盒及运行验证、可执行操作文档。

## Canonical source and runtime target
- Production: C:/美术素材制作/tools
- Game: C:/游戏，Godot 4.7.1 executable at C:/1
- Staging: C:/Users/njw/map_flow_20261004；部署前备份规范源，不改缓存。

## Definition of done
- [x] 配置驱动转换接入既有 build_building.gd。
- [x] 通用发布器支持建筑附属文件和哈希绑定的视觉/引擎复核。
- [x] 回归覆盖缺审批、篡改、发布/回滚与转换错误。
- [x] 灰盒导入、场景加载、门/碰撞/屋顶/排序测试及渲染检查。
- [x] 地图/建筑基线全部 failed=0，文档和变更日志同步。

## Completed
- 本轮 list_projects 返回 Transport closed；按精确路径读取生产转换器、发布器、Godot 生成器与样板代码。
- 已确认现有生成器与通用审批流程，应扩展它们而非新建并行系统。
- make_building_spec --config 支持显式图层和已有分层包映射，校验48px/m、投影、原点、画布、独立屋顶、QA及选中层哈希，写入输入溯源。
- build_map_asset 统一构建/导入/校验/可选捕获；agent_assets 支持 file 附属文件与 required_reviews，原发布和回滚机制复用。
- 灰盒生成器、平面、配置、游戏包与独立实验场已落盘；入口：启动地图制作样板.bat。
- 发现并修复原 Building 碰撞/Doors/Interaction 未减去锚点导致错位，运行时修正旧 prefab，生成器保存新偏移。
- 大图审核缩略图适配单元格，纯文件批次也能生成审核面板。
- 转换备份改存 assets/buildings/.backups，避免旧包进入活动建筑索引；实际替换失败恢复测试通过。

## Validation
- 美术全套：32 tests OK。最后备份路径小改的转换定向回归：7 tests OK。
- 灰盒：22/22；地图：85/85；建筑：296/296；第一阶段实验场：33/33。
- 脚本编译：159 failed=0；存档33/33；角色9/9；卡牌目录300 total, 112 supported, failed=0。
- 主场景3帧无头加载通过；独立 BattleMap 冒烟发现未修改的 enemy_ai.gd:174 给 Array[Vector2i] 赋无类型Array，继发104行Nil.score；不是地图闭环通过项。
- 实际OpenGL渲染outside/inside/north三状态均成功并目视检查，物理移动验收确认撞墙停止、通过门洞、屋顶显隐和22项结构行为。
- 实际捕获批次 workflow-hall-graybox-20261004-v3：21 assets, failures=0, warnings=0；源游戏文件哈希与快照逐一一致；engine复核已记录。
- 真实批次缺visual复核时approve被拒绝，未执行发布；前两次分类QA失败的批次保留供追踪。
- 工具部署逐文件SHA256验证；备份和完整日志在 C:/Users/njw/map_flow_20261004/backups 与 logs。

## Pending
- 后续内容制作：用户检查灰盒结构后开始精细美术；复杂修道院多庭院遮挡另做语义样板。
- 发布样板批次仍缺visual复核，状态captured；这是有意保留的正式美术门禁，不影响开发样板运行。

## Blockers and warnings
- MCP 图谱不可用，源码回退；项目有既有未提交改动。
- 灰盒允许技术验证，正式美术的用户视觉批准不能自动生成。
- 全项目战斗冒烟未通过，具体独立AI类型问题见Validation；本轮未改AI模块。
- 无头测试、真实渲染和静态目视已完成；没有冒充用户亲自操作验收或最终艺术品质批准。

## Next exact action
双击 C:/游戏/启动地图制作样板.bat，沿南门→大厅→北门→侧翼绕回检查结构；确认后基于同一plan制作分层美术。

## Runtime state
- Godot实际加载 C:/游戏，运行样板并保存三张review图片；捕获进程已退出。
- 未启动生成模型；正式地图入口未替换。

## Changed paths
- Art tools: make_building_spec.py, agent_assets.py, build_map_asset.py, make_workflow_graybox.py。
- Art tests: test_agent_assets.py, test_building_transfer.py；specs/templates/map_asset_task.json，README。
- Game: core/building/building.gd，maps/godot/tools/build_building.gd；assets/buildings/workflow_hall，dev/map_workflow_lab，tests/map/test_map_workflow.gd。
- Docs: world/rules.md、map_pipeline.md、map_production_workflow.md、development/changelog.md、本记录及启动入口。
