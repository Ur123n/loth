# 莱顿城 M04 货运石桥

状态：独立结构灰盒已运行验收，正式美术尚未验收。

- 规范源 building.spec.json；独立场景 LeytonCargoBridge.tscn。
- 当前运行 Base 来自 visual/source_graybox.png。12×11格，48px/格，四周1格透明边。
- source/concept_v1.png 是内置 image_gen 概念原图，不参与运行；准确提示词 exact_bridge_prompt.txt，审核记录 bridge_prompts.md。
- source/make_bridge_draft.py 只在其旁边的 bridge_draft/ 生成测量参考和初始spec，不自动覆盖正式资产。
- masks/、collision/、metadata/、preview/ 和场景均由 maps/godot/tools/build_building.gd 生成。
- 重建顺序：--id leyton_cargo_bridge --phase masks；--phase visual；Godot --headless --editor --import；--phase prefab。
- 完整需求：maps/leyton/BRIDGE_PLAN.md；验收：maps/leyton/qa/BRIDGE_QA.md。
- 露天桥无屋顶；正式桥面/护栏分层和遮挡待后续美术增量。
