# 莱顿城八区地图集

## 当前阶段

八区均已接入1:1基础可玩灰盒，14条城区有向连接可往返，四门可上下墙并切换三态。M01/M04/M07保留已接入美术。完整地图交付仍为0/8；逐图缺口见 `planning/PRODUCTION_BOARD.md`，验收见 `qa/ATLAS_PLAYABLE_QA.md`。
Tile 类地表使用独立 leyton_surface_v2 TileSet；大型结构仍显示占地，不作为建筑美术图块交付。

M04货运石桥已接入注册后的分层美术、独立入口与护栏碰撞，实际角色遮挡通过。M07西门楼已接入独立Building四层静态美术：地面六格门洞、上层三格巡逻道、三态动态阻挡。见 `qa/BRIDGE_ART_QA.md`、`GATEHOUSE_PLAN.md`、`qa/GATEHOUSE_QA.md`。门楼屋顶、立面与巡逻道已完成静态美术接入，见 `qa/GATEHOUSE_ART_QA.md`；动态门扇、水门与其余大型结构仍待制作。

## 规范源

- `slice.json`：三图当前布局、出生点、桥梁、出口、门洞和墙顶数据。
- `planning/`：当前八区规划与制作计划，已修订河流不通航。
- `archive/`：原始规划、拓扑、九张缩略灰盒及渲染器，保持原样。
- `source_manifest.json`：历史来源与 SHA256。
- `WORKLOG.md`：当前进度；`qa/`：验证证据。

## 运行

打开 `res://maps/leyton/scenes/slice_test.tscn`，或：

```powershell
& 'C:\1\Godot_v4.7.1-stable_win64_console.exe' --path 'C:\游戏' 'res://maps/leyton/scenes/slice_test.tscn'
```

WASD 移动，C 切换玩家/2×3 格马车占位体，E 在四门墙梯附近上下墙，G 切换全城门禁开放/宵禁/封锁，Tab 总览，T 地表/灰盒切换，R 复位，1—8 跳图。
绿色为启用的两格出口带；红色为尚未开放出口；橙色为墙梯。水体不可行走，桥面可通过。西门石砌高架通道为上层巡逻道；黄/红色门洞仍是宵禁/封锁的诊断显示，真实门扇待制作。

## 灰盒规则与验收

- 复用 `MapScene` 的六层与碰撞语义、一期玩家场景；验收控制器用小步长扫掠查询整个占位矩形，避免跨格穿墙。
- 马车暂定 2×3 格，不含转向车体、NPC 会车或拥堵模拟；该规格仍待用户验收。
- 八图四向连接使用两格触发带，入图放在边界内四格，整个马车避开回传带。
- 切图前验证完整占位落点；西门关闭时拒绝进入阻挡门洞，保留源地图并退回源侧安全位置，重新开放后可正常进入。
- 西门净宽六格；宵禁与封锁均阻挡地面，切换前必须离开门洞。两状态的剧情/NPC 差异留待后续。
- 墙顶为独立三格宽通行层，只允许玩家从墙梯交互进入，覆盖主门与水门上方；墙顶不能跨图。
- M01 城卫值房与公共水源移至河道北岸；增加南轴桥。M07 待检区向北退让主路，湖岸收至道路北侧，增加入湖河道桥并对齐水门。
- 五区已补齐基础可玩场景；四条世界道路仍有可见阻挡。M01与M08双向显示住宅区抽象路程，未修改生产主场景。

## 验证命令

```powershell
& 'C:\1\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\游戏' --script 'tests/map/test_leyton.gd'
```

当前布局继续沿用。v2已替换草土道路并添加水岸；下一步推进桥/城防立面、门楼、完整建筑与Prop；旧六项材质未整批发布。


## 首批地表 v1

- 新制深水、深青石墙顶各1张；原始图、完整提示词、色板与QA见 `assets/maps/leyton/surface_v1/`。
- 复用 dark48 五项地面和四组自动拼接，独立 TileSet 共139块/6来源/4地形集。
- 道路与草间添加两格土质边带，使用既有 MapPalette 计算过渡；不更改碰撞。
- T 切换地表/灰盒。三图三种城门状态共69,120格次的通行一致性检查通过。
- 实际渲染：`qa/surface_v1_m01_overview.png`、`surface_v1_m04_overview.png`、`surface_v1_m07_overview.png`，各有 detail 近景。
- 已知限制：旧草地与道路重复感明显；水岸仍为硬边；桥无立面；大型建筑仍为占地块。此轮不作为完整地图美术验收。


## 当前地表 v2（替代上节v1显示）

- 3张新生成基础图，草/路各4种共边变体，64块新过渡和81种水岸组合；TileSet共156块。
- 坐标稳定选变体、不翻转；水岸仍按原水格阻挡，T可切回灰盒。
- 当前截图 `qa/surface_v2_m01_detail.png`、`surface_v2_m04_detail.png`、`surface_v2_m07_detail.png`，各有overview总览。
- 完整记录见 `assets/maps/leyton/surface_v2/README.md` 与 `qa/SURFACE_V2_QA.md`。
- v1源图/素材/截图保留作对照，v2前脚本备份位于 `archive/pre_surface_v2/`。

## 八区验证与预览

运行 tools/validate.ps1 做全套回归；tools/run_atlas_capture.ps1 启动隐藏GPU截图实例并返回PID，结果在qa/atlas_capture.log。八图总览为qa/atlas_contact_sheet.png；单图为qa/atlas_m01_overview.png至atlas_m08_overview.png。当前1121断言与140脚本检查通过；这不包含真实马车转向、会车或NPC拥堵。


## 当前城市重构 v2

城内四区已换砖石铺装，M02曲折路网与34处建筑占地，四区新增完整住宅Pattern和68件独立装饰。此前灰盒阶段记录保留为历史。当前布局/密度/修道院重构/限制与验收见rework_v2/README.md和WORKLOG.md。
