# M07 门楼静态美术验收记录

日期：2026-09-27。规范源和运行目录均为 `C:\游戏`。

## 美术与注册

- 基于已验证灰盒和M04石桥材质参考生成整座门楼概念图，原始1066×1476透明PNG保留于建筑包 source/concept_v1.png；提示词同时归档。
- 使用固定地标分段注册为624×864；四个互斥透明层 Base/Floor/Roof/WallWalk 合成与注册图逐像素一致。
- 屋顶避开六格门洞与三格墙顶路径；墙顶192像素视觉宽度含两侧各24像素护栏，实际通行宽144像素。
- 同源48像素长纹理段延伸门楼以外的巡逻道；没有扩大上层导航或地面掩码。
- 微型徽记只是当前生成图中的装饰表达，未验收为设定中纹章的精确绘制。

## 验证证据

- `test_leyton_gatehouse_art.gd`：24项通过，包括四层重建、透明留白、通道留空、五张逻辑掩码哈希不变、运行时高度与延伸纹理。
- `test_leyton_gatehouse.gd`：69项通过，包含三态地面/墙顶通行基线、动态物理阻挡和安全切图。
- `gatehouse_art_render.json`：实际 NVIDIA GeForce RTX 4060 Ti 渲染，failed=0。相同XY地面玩家被遮、上层玩家可见，两项像素检查通过。
- 八张实际截图：`gatehouse_art_{open_ground,open_cart,curfew,sealed,wall_over_closed_gate,wall_over_water_gate,probe_ground,probe_upper}.png`。
- 已直接查看开放地面、关门上层与水门上方画面；完整回归结果记于同目录测试日志及 WORKLOG.md。

## 尚未交付

关门仍显示黄/红诊断填色，尚无真实门扇或开合动画。水门仍为独立占位对象。马车为测试矩形。没有迁移生产主场景，没有将此增量计为完整城区交付。
