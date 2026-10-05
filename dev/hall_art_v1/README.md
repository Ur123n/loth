# 石砌会堂美术样板 v1

资产类别 Building/Structure；边境修道院石砌会堂，12×10m，48px/m，南北各2格门。

本样板复用已验证的workflow_hall几何、碰撞、门和屋顶掩码。内置imagegen制作墙体、地面与屋顶候选。生成图作为表面材质，ShaderMaterial使用原灰盒alpha约束显示、按672×576逻辑像素采样，并映射到项目map_env色板。

这是一种独立开发审验表示，尚未转换为标准分层PNG发布包。源图保持原始分辨率和alpha；没有从图像反推碰撞，也没有通过修改碰撞迁就生成偏移。

## 操作
- WASD移动；R回入口；F手动切换屋顶；T恢复自动屋顶；B看碰撞；C切换美术/原灰盒。
- 场景：`res://dev/hall_art_v1/hall_art_v1.tscn`；游戏根目录启动器 `启动会堂美术审验.bat`。
- `review_outside.png`、`review_inside.png`、`review_north.png` 为本轮实际渲染产物。

## 边界
- 用户继续指令授权制作候选，不代替最终美术批准。
- 整体母稿与层语义继续保留；分区排序仍使用已有north/sides/south/padding。
- 生成图不保证像素级对齐：灰盒alpha才是显示轮廓的确定来源；采样缺色处使用对应材质基色。
- 美术源、提示词、收据和QA位于 `C:/美术素材制作/working/hall_art_v1_20261004`。
