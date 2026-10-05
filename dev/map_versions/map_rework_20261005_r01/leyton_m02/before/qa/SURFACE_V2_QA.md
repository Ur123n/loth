# 地表v2验收 — 2026-09-27

规范源/实际运行：C:\游戏；Godot4.7.1，NVIDIA/OpenGL实际渲染6张1280×720。

## 结果

- LEYTON passed=61 failed=0
- LEYTON_SURFACE passed=60 failed=0
- RESULT: passed=85 failed=0
- RESULT: passed=296 failed=0
- RESULT: passed=33 failed=0
- RESULT: scripts=136 failed=0

- 素材生成器580条完整边缘（混合交点角像素除外）检查通过；48px/alpha/基础色板与变体共边通过。
- 三图三门状态69,120格次通行性完全一致；水岸仅位于原阻挡水格；南北水岸方向正确。
- 三图重建后变体选择稳定；四种草地/道路图块共享边缘。
- 实际六张截图全部已查看：草地/道路强重复纹样减弱，草/土混合水岸可见；未出现资源空白。
- 新清单最初使用英文地形显示名触发构建器默认透明颜色警告，已改为其内置中文名；最终构建及运行无该警告。
- 运行源与图集哈希：surface_v2_runtime_sources.json；结果快照surface_v2_results.json。

## 未完成

仍无桥梁/城墙立面、栏杆、门楼及完整建筑。地表视感还有细节迭代空间；四邻岸线仍服从逻辑网格。完整地图交付仍0/8。
