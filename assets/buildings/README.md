# assets/buildings/ —— 大型建筑资产包

每座大型建筑一个目录，目录名 = `building_id`（ASCII 小写下划线）。
**标准格式、字段含义、掩码规范、Agent 用法全部见
[docs/world/building_pipeline.md](../../docs/world/building_pipeline.md)。**

## 目录结构

```
<building_id>/
├── building.spec.json      手写/工具产出：几何与游戏字段的唯一定义
├── <PascalCaseId>.tscn     生成：Building Prefab（地图唯一需要引用的文件）
├── visual/                 原图（source_*.png）+ 生成的主视觉与屋顶层
├── masks/                  5 张逻辑掩码（1 像素 = 1 格）+ legend.json
├── collision/              生成：碰撞矩形清单
├── metadata/               生成：building.json（Agent 唯一需要读的文件）
├── preview/                生成：预览图 + 掩码叠查图
└── source/                 美术线原始平面图留档（溯源）
```

## 一句话用法

```bat
:: 改 spec 后重新生成
… --script maps/godot/tools/build_building.gd -- --id <building_id>
:: 放进地图
… --script maps/godot/tools/building_tool.gd -- place --id <building_id> --map <场景> --at x,y
```

（`…` = `C:\1\Godot_v4.7.1-stable_win64_console.exe`）

## 约定

1. **`building.spec.json` 是唯一手写输入**，其余全是生成物 —— 别手改生成物（跟地图管线的 `*.tres` 一个道理）。
2. 例外：想手调每一格时，直接改 `masks/*.png`，再跑 `--from-masks` 回灌 metadata。
3. **视觉尺寸与逻辑 footprint 故意不绑定**，别把两者对齐当成要求。
4. 新建筑不要改核心代码，只加一个目录 + 跑生成工具。

## 已入库

| building_id | 显示名 | 视觉 | 逻辑 footprint | 备注 |
| --- | --- | --- | --- | --- |
| `iserra_monastery` | 伊瑟拉修道院 | 2880×3312 px（地面层 + 屋顶层） | 57×66 格 | 12 房间 / 8 门；来源：美术线 `交付素材\12_修道院` |
