# 修道院与莱顿版本更迭指南

Updated: 2026-10-05 Asia/Shanghai
Status: complete

## Objective

为Codex编写现有伊瑟拉修道院和莱顿城的版本更迭操作指南，沿用用户认可的新美术技术路线。

## Canonical source and runtime target

- 游戏：C:/游戏；美术规范：C:/美术素材制作/docs/地图与大型建筑制作指导手册.md。
- 指南目标：C:/游戏/docs/world/version_guides/。
- 暂存：C:/Users/njw/map_version_guides_20261005。
- 本轮编写指南，不执行地图改版或重新生成资产。

## Definition of done

- 当前加载链、候选与活动版本、真源与生成副本均有依据。
- 两份专用步骤包含修改范围、验证、替换、回退、询问条件。
- 非技术设计约束保留，技术路线使用灰盒与分层材质。
- 文档、模板、路径及基线检查通过，工作记录可续接。

## Completed

- 用户明确受众为Codex。
- codebase-memory技能已读取，Verify层级；list_projects和check_index_coverage均Transport closed，回读精确源码。
- 已确认生产MainHighlandMap加载highlands；移动Demo继承同一修道院；莱顿运行读取slice.json；街坊v3独立。
- 用户补充“修道院的贴图可以更换”，已记录为明确授权，无需重复询问；逻辑/功能改动按任务范围确认。
- 完成通用流程、修道院专用指南、莱顿专用指南、JSON任务模板和2026-10-05基线快照。
- 修道院当前48×58地基、2400×2880画布、Shadow/Base/WarmLight三层、无独立Roof；3组美术源/运行源副本哈希一致。
- 核对环境生成器覆盖行为、Pattern路径与缩放、共享依赖、13项全套验证及异步GPU捕获入口。
- 更新游戏world/README、Demo README、美术README/手册及变更日志。

## Validation

- 10份文件部署成功；12个新增链接、11个命令依赖路径检查通过，errors=[]。
- 43个当前运行源文件哈希在部署前后保持不变，未修改地图、脚本、图像或布局。
- Markdown代码块闭合、JSON解析、部署内容哈希均通过。
- 首次部署在写入前发现相对路径校验未归一化，修复验证器后重新检查通过。
- file-level verification only：这是文档任务，未重新运行游戏/渲染，不把历史样板验收当成本轮运行结果。
- 详细部署/验证记录：暂存目录deployment.json、validation.json；已有文档备份在before/。

## Pending

- 无本轮待完成项。地图改版在用户下达实施任务后按指南执行。

## Next exact action

读取C:/游戏/docs/world/version_guides/README.md，再按目标选择专用指南并创建revision任务文件。
