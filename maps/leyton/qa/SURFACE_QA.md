# 首批地表 QA

2026-09-27；Godot 4.7.1；规范源与实际加载路径 C:\游戏。

## 验证

- LEYTON passed=61 failed=0
- LEYTON_SURFACE passed=37 failed=0
- RESULT: passed=85 failed=0
- RESULT: passed=296 failed=0
- RESULT: passed=33 failed=0
- RESULT: scripts=136 failed=0

- 两张新图块48px、对边相等、全不透明、专用色板、零亮色越界均通过。
- 三图三门状态69,120格次通行性与灰盒完全一致；T切回灰盒使用原始单来源TileSet。
- 既有自动拼接无冲突；地表模式下原三图玩家/马车/桥梁/往返/城门/墙顶测试通过。
- 实际OpenGL六张1280×720截图已查看；新水体/墙顶资源加载正常，道路土质过渡可见。
- 验收运行源哈希见 surface_runtime_sources.json；此前灰盒哈希仍保留。

## 视觉限制

旧草地大面积平铺重复感明显，道路也仍有重复纹样；水岸硬边、桥面无立面、建筑占地块均须后续制作。两项新纹理通过数值门槛不代表整图美术完成。
