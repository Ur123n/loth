# 城北连续街坊样段 v3

这是按用户根目录参考图与调研制作的32×32米可玩样段，尚未替换全城M02。运行规范源为C:/游戏；布局layout.json，入口review.tscn。

## 试玩

双击项目根目录的 preview_street_v3.bat，或在Godot打开本目录review.tscn按F6。
WASD移动，C切换人物/2×3车体，Tab总览，V素材/灰盒，R复位。

## 已完成

- 手工组织九处连续建筑/院墙占地，围合私院、两段步行巷、井台节点及绕过街坊的通车路；取消均匀独栋填空。
- image_gen直接使用用户参考，制作共墙街屋、转角宅邸、纵深附属翼和井台；共墙街屋额外修正一次视角。四件最终素材、一个初稿、全部提示词和SHA保存在assets/maps/leyton/street_sample_v3。
- 复用原MapScene、Viewer、独立Pattern/FreeProp与碰撞；共享加载器仅增加可选layout_document，默认仍是slice.json。
- 建筑前后排序共享角色YSort。走到楼后时只淡化屋顶，立面保留；离开即恢复。该样段用规则矩形触发范围，不声称已有逐像素遮挡掩码。
- 灰盒阶段12项逻辑检查通过；最终21项逻辑检查、含5张GPU截图的26项检查通过。真实渲染器RTX4060Ti，qa/capture.err.log为空。全项目回归结果见WORKLOG。

## 边界与下一步

两处院门/墙垛仍是灰盒；建筑素材会复用且部分按宽度等比缩放，目前用于体量与街坊方向验收，不是逐栋最终比例定稿。门口还未接室内场景，角色仍沿用原审验占位角色。屋顶采用横向分层，复杂烟囱/山墙的精确掩码以后再细化。

正式M02与修道院不因样段替换。下一步依据实际视觉反馈细化门楼、比例与各栋朝向，随后将街坊方法扩展到贵族区；不可重新启用矩形住宅均匀填空脚本。

## 可复现检查

C:/1/Godot_v4.7.1-stable_win64_console.exe --headless --path C:/游戏 --script maps/leyton/street_sample_v3/check.gd

GPU截图运行本目录capture.ps1。素材机械注册工具为assets/maps/leyton/street_sample_v3/register.gd；原图须先保留再处理，不在游戏运行时读取原图。
