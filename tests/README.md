# 测试

核心系统使用 Godot 无头测试（`extends SceneTree`，`RESULT: passed=N failed=0` 为通过）。

## 运行方式

```bat
C:\1\Godot_v4.7.1-stable_win64_console.exe --headless --path C:\游戏 --script tests\<模块>\test_*.gd
```

单个测试示例：

```bat
godot --headless --path C:\游戏 --script tests/ai/test_ai_decisions.gd
```

## 目录

| 目录 | 覆盖 |
| --- | --- |
| tests/battle/ | 战斗回归、敌方小队、地图寻路、Demo 系统 |
| tests/card/ | 卡牌逻辑链、重平衡、条件判断 |
| tests/character/ | 道途被动、道途系统 |
| tests/ai/ | AI 决策引擎（行为模板/目标/评分/位置） |
| tests/world/、tests/save/ | 预留 |

修改核心系统后必须运行对应模块测试；全部测试须 `failed=0`。
