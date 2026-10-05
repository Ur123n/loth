# 新版美术指导手册工作记录

Updated: 2026-10-04 Asia/Shanghai
Status: complete

## Objective

以用户确认的会堂样板制作新版指导手册，移除现行文档里的旧技术路线，保留非技术内容。

## Canonical source and runtime target

- 规范源：C:/美术素材制作/docs/地图与大型建筑制作指导手册.md
- 游戏入口：C:/游戏/docs/world/map_production_workflow.md
- 运行依据：C:/游戏/dev/hall_art_v1；本轮仅更新文档。
- 暂存：C:/Users/njw/art_manual_v2_20261004

## Definition of done

- 手册包含完整操作、结构/材质责任、运行验证和交付依赖。
- 世界观、风格、比例、房间设计和素材需求有保留记录。
- 旧说明退出现行入口，原文可恢复；不删除程序、模型或既有素材。
- 文档链接、操作路径及保留内容检查通过。

## Completed

- 已核对会堂代码、Shader、启动器修复和GPU报告。
- 已盘点美术README、01—11文档、修改方案和游戏文档入口。
- 图谱Transport closed，使用精确文件路径核对。
- 完成新版技术手册与四份配套非技术文档，新增迁移记录。
- 29份文档/入口更新，旧01—11、修改方案和建筑旧流程正文已撤下，仅保留跳转。
- 更新美术与游戏AGENTS、世界规则、风格引用、地图入口与变更日志。
- 修改前原文完整保存到C:/美术素材制作/backups/manual_v2_20261004，migration_manifest.json记录前后哈希。

## Validation

- 29份暂存和部署文档哈希、Markdown代码围栏、文件链接及命令依赖检查通过，errors=[]。
- 原修道院设计与世界需求清单的所有表格行逐行保留检查通过。
- 旧技术入口已无代码块，正文只保留迁移说明；旧项目报告的交付清单与非技术评审另行保留。
- 所有写入目标为明确清单内.md文件；没有修改运行程序、Shader、纹理或场景。
- 本轮为file-level verification only（文档级验证）；没有因文档变更重跑游戏测试。手册中398项及GPU结果标明为前轮样板证据。

## Pending

- 无本轮待完成事项。后续新建筑按新版手册另立任务。

## Next exact action

从美术README或游戏docs/world/map_production_workflow.md打开新版手册；按用户下一项建筑需求执行。

## Changed paths

- 精确清单：C:/美术素材制作/backups/manual_v2_20261004/migration_manifest.json。
- 规范源：C:/美术素材制作/docs/地图与大型建筑制作指导手册.md。

## Runtime state

- 此轮未启动或更换Godot实例，无运行部署。
