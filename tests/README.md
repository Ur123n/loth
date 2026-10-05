# 测试

核心系统使用 Godot 无头测试（`extends SceneTree`，`RESULT: passed=N failed=0` 为通过）。

## 运行方式

```bat
C:\1\Godot_v4.7.1-stable_win64_console.exe --headless --path C:\游戏 --script tests\<模块>\test_*.gd
```

完整检查（全部 Godot 测试、剧情/JSON 校验、主场景与战斗场景冒烟）：

```powershell
pwsh -File tests/run_all.ps1
```

单个测试示例：

```bat
godot --headless --path C:\游戏 --script tests/ai/test_ai_decisions.gd
```

## 目录

| 目录 | 覆盖 |
| --- | --- |
| tests/battle/ | 战斗回归、边长 20 六边格、统一尸骸状态、敌方小队、地图寻路、Demo 系统 |
| tests/card/ | 卡牌逻辑链、重平衡、条件判断 |
| tests/character/ | 道途被动、道途系统 |
| tests/ai/ | AI 决策引擎（行为模板/目标/评分/位置） |
| tests/map/ | 48px Godot 地图、建筑管线与第一阶段实验场（Pattern/Prop/Interior/Ghost/YSort/Roof） |
| tests/save/ | 存档往返（v6：含剧情、任务、世界状态/时钟与旧档迁移） |
| tests/story/ | 剧情数据 / 触发器 / 执行器（阻塞 / 并行 / 分支 / Flag / 防重） |

剧情测试与数据检查：

```bat
godot --headless --path C:\游戏 --script tests/story/test_story_data.gd
python 编辑器\剧情检查.py            :: 校验全部剧情与触发器
python 编辑器\剧情检查.py --list     :: 查看指令目录
```

修改核心系统后必须运行对应模块测试；全部测试须 `failed=0`。

地图架构第一阶段验收：

```bat
godot --headless --path C:\游戏 --script tests/map/test_map_pipeline_phase_one.gd
```

## 地图管线工具（非测试）

```bat
:: 新素材导入（改了素材/图集后要先跑）
godot --headless --path C:\游戏 --import
:: 素材/spec → TileSet（产出 .tres + 图块清单 + 对照表 + 打包图集）
godot --headless --path C:\游戏 --script maps/godot/tools/build_tileset.gd
:: 生成模板 / 示例地图 / 新地图脚手架
godot --headless --path C:\游戏 --script maps/godot/tools/make_map.gd
:: 手绘地图的边缘块修正（--check 只检查）
godot --headless --path C:\游戏 --script maps/godot/tools/autotile_fixup.gd -- res://maps/godot/scenes/<地图>.tscn
:: 预览图 + 画面占比（75/20/5）
godot --headless --path C:\游戏 --script maps/godot/tools/preview_map.gd
```

说明见 [docs/world/map_pipeline.md](../docs/world/map_pipeline.md)（当前规格 48px，风格见 [docs/art/style_guide.md](../docs/art/style_guide.md)）。
