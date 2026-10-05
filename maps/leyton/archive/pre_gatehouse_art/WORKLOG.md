# 莱顿城地图集工作日志

Updated: 2026-09-27 Asia/Shanghai
Status: M07_gatehouse_graybox_runtime_verified

## Objective / 本轮完成

M07西门楼独立Building灰盒、地面/墙顶分层、三态动态阻挡、墙梯和水闸通路及安全切图。本轮结构增量完成；门楼正式美术和完整地图集未完成。

## Canonical source and runtime target

- 规范源/运行：C:\游戏，Godot C:\1\Godot_v4.7.1-stable_win64_console.exe（4.7.1）。
- 入口：maps/leyton/scenes/slice_test.tscn，按7进入M07。
- 当前灰盒几何源：maps/leyton/tools/prepare_gatehouse.gd；生成assets/buildings/leyton_west_gatehouse/building.spec.json与三层源图，再经既有Building生成器封装。
- 运行场景：assets/buildings/leyton_west_gatehouse/LeytonWestGatehouse.tscn，由slice.json显式引用。
- 备份：maps/leyton/archive/pre_gatehouse/（旧slice/viewer/graybox_map/日志/测试入口/桥测试，.gdignore排除导入）。更早石桥资产备份保留。
- C:\Users\njw\game_stage\leyton_gatehouse只为补丁暂存，不参与运行。

## Completed / 验收

- [x] 门楼(85,32,11,16)，中央六格东西门洞y=37..42；176占用、66可走、110实体，两入口、两翼碰撞矩形。
- [x] 624×864三层灰盒：Base/Floor/WallWalk，独立3格墙顶x=92..94；上层不加入地面可走掩码。
- [x] ground z=0、wall actor z=5、upper surface z=4；墙梯保留(87,49)/(93,49)，马车不能登墙。
- [x] gate_state同时控制动态地图阻挡、物理碰撞和黄/红状态显示，避免Building优先通行绕过关门。
- [x] 三种状态下，96×80全图地面/墙顶通行摘要均与接入前完全一致；水闸和河流保持独立。
- [x] 切图前检查目的地占位落点，关闭门洞时保留源地图/玩家并退回安全接点；开放后恢复玩家和马车入图。
- [x] 换肤不重复实例化，旧地图/门楼释放，上下墙和切图高度复位。
- [x] 实际OpenGL八张截图生成；四张代表画面已直接检查；同XY玩家地面被遮、墙顶可见的像素对照通过。

## Validation

- 门楼专项69项通过，资产包校验errors=0/warnings=0。
- 全回归：LEYTON 61、BRIDGE 138、GATEHOUSE 69、SURFACE 60、Map 85、Building 296、Phase one 33，共742断言；脚本编译138项；failed=0。
- 基线：qa/gatehouse_before.json（接入前，不允许生成器覆盖）；截图/像素结果：qa/gatehouse_render.json（ground/upper均passed=true）。
- qa/gatehouse_{open_ground,open_cart,curfew,sealed,wall_over_closed_gate,wall_over_water_gate,probe_ground,probe_upper}.png。
- 最终导入无ERROR/WARNING；截图stderr为空；全部相关进程已退出。
- 图谱generation为2026-09-14，相关freshness缺失；已回读当前源文件，不以旧图谱代替验证。

## Prior completed

- M04石桥分层正式源图接入、护栏YSort与玩家/马车通行已验证，原碰撞不变。证据qa/BRIDGE_ART_QA.md；上一轮完整日志在archive/pre_gatehouse/WORKLOG.md。
- 三张地点地图沿用v2地表；M01/M04/M07仍为可玩制作切片，生产主场景未迁移。

## Pending / limitations

- 门楼灰盒不是最终美术：立面、屋顶、门扇、徽记、室内和NPC岗哨待制作；水门仍是独立占位对象。
- 马车为2×3测试矩形，未实现转向/会车/交通；宵禁与封锁当前均关闭地面，剧情差异未实现。
- 其余完整建筑/Prop、剩余五图及生产接入待完成；完整地图交付仍0/8。
- 默认建筑preview.png仅显示Base翼楼，完整双层效果看运行截图。

## Next exact action

读取GATEHOUSE_PLAN.md及planning内莱顿城市设定，核对西门徽记/守卫/屋顶风格，完成整座门楼概念设计。以当前624×864三层灰盒、六格门洞和三格墙顶作为测量参考再调用image_gen；不得让生成屋顶封死上层路线或缩窄门洞。

## Changed paths

- maps/leyton/tools/{prepare_gatehouse,gate_baseline,capture_gatehouse}.gd、run_gatehouse_capture.ps1。
- assets/buildings/leyton_west_gatehouse/完整灰盒资产包；maps/leyton/slice.json增加独立prefab引用。
- maps/leyton/{graybox_map,viewer}.gd：动态阻挡、上下层绘制、安全切图。
- tests/map/test_leyton_gatehouse.gd、test_leyton_bridge.gd、maps/leyton/tools/validate.ps1。
- GATEHOUSE_PLAN.md、qa/GATEHOUSE_QA.md、README、world/rules、changelog和本日志。

## Runtime state

- 本轮导入/测试/截图实例已退出。当前资源为M04分层石桥+M07双层灰盒门楼+v2地表。
