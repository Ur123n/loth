extends Node2D
const ROOT := "res://assets/maps/leyton/props_batch_01/"
var manifest: Dictionary
var items: Array = []
var font: Font
var backgrounds: Array[Texture2D] = []
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	font = ThemeDB.fallback_font
	for name_text in ["grass","dirt","road_stone"]:
		backgrounds.append(load("res://assets/maps/leyton/surface_v2/tiles/"+name_text+".png"))
	manifest = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
	for i in manifest.assets.size():
		var entry: Dictionary = manifest.assets[i]
		var origin := Vector2(14+(i%3)*422,70+(i/3)*438)
		var sorting := Node2D.new()
		sorting.y_sort_enabled = true
		add_child(sorting)
		var prop: Node2D = load(ROOT+"scenes/"+entry.id+".tscn").instantiate()
		prop.position = origin+Vector2(136,255)
		prop.scale = Vector2(2,2)
		sorting.add_child(prop)
		var probe := Node2D.new()
		sorting.add_child(probe)
		var marker := Polygon2D.new()
		marker.polygon = PackedVector2Array([Vector2(-3,-3),Vector2(3,-3),Vector2(3,3),Vector2(-3,3)])
		marker.color = Color(1,0,1)
		probe.add_child(marker)
		probe.visible = false
		items.append({"prop":prop,"probe":probe,"marker":marker,"entry":entry})
		for j in 3:
			var native := Sprite2D.new()
			native.texture = load(ROOT+entry.sprite)
			native.centered = false
			native.position = origin+Vector2(67+j*132,415)-Vector2(entry.anchor[0],entry.anchor[1])
			add_child(native)
	queue_redraw()
func _draw() -> void:
	if manifest.is_empty(): return
	draw_rect(Rect2(0,0,1280,960),Color("171b20"))
	draw_string(font,Vector2(22,28),"莱顿共享物件 01｜六件候选素材验收",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("e4dfcf"))
	draw_string(font,Vector2(22,52),"上：2倍像素 + 1.8米人体标尺   下：原尺寸分别放在草地 / 泥地 / 石路   48px = 1m",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("aaa99b"))
	for i in manifest.assets.size():
		var entry: Dictionary = manifest.assets[i]
		var o := Vector2(14+(i%3)*422,70+(i/3)*438)
		draw_rect(Rect2(o,Vector2(410,430)),Color("242a2e"))
		draw_string(font,o+Vector2(12,24),"%02d  %s / %s" % [i+1,entry.name,entry.id],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("ded5bd"))
		for y in 20:
			for x in 32:
				draw_rect(Rect2(o+Vector2(12+x*12,38+y*12),Vector2(12,12)),Color("343b3e") if (x+y)%2==0 else Color("3d4446"))
		draw_line(o+Vector2(26,255),o+Vector2(374,255),Color("86918b"),1)
		# Neutral measurement diagram; legacy character art has an inconsistent body scale.
		var foot := o+Vector2(294,255)
		var ink := Color("9bafa9")
		draw_circle(foot+Vector2(0,-156),16,ink,false,2)
		for line: Array in [[Vector2(0,-70),Vector2(0,-32)],[Vector2(0,-62),Vector2(-17,-40)],[Vector2(0,-62),Vector2(17,-40)],[Vector2(0,-32),Vector2(-12,0)],[Vector2(0,-32),Vector2(12,0)]]:
			draw_line(foot+line[0]*2,foot+line[1]*2,ink,3)
		draw_string(font,o+Vector2(267,275),"1.8 m",HORIZONTAL_ALIGNMENT_LEFT,-1,14,ink)
		draw_string(font,o+Vector2(12,298),"实际轮廓 %d×%d px" % entry.visible_size,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("b4bbb1"))
		for j in 3:
			draw_texture_rect(backgrounds[j],Rect2(o+Vector2(4+j*132,310),Vector2(128,115)),true)
