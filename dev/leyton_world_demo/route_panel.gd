extends Control
var world: Dictionary
var current_id := ""
var visited: Dictionary
func point(id: String) -> Vector2:
	var grid: Array = world.maps[id].diagram
	return Vector2(58+grid[0]*174,150+grid[1]*82)
func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0,0,1280,720),Color(0.06,0.08,0.10,0.97))
	draw_string(font,Vector2(48,45),"修道院与莱顿城 · 全路线",HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("e6d4a9"))
	draw_string(font,Vector2(48,76),"上北下南，左西右东。地图在边缘切换；按M或Esc返回行走。",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("a8bcb5"))
	for link: Array in world.connections:
		var a := point(link[0])
		var b := point(link[1])
		if link==["M01","M08"]:
			draw_dashed_line(a,b,Color("cfb27c"),2,8)
			draw_string(font,a+Vector2(80,-39),"普通住宅区 · 抽象路程",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("cfb27c"))
		else: draw_line(a,b,Color("6c9185"),3)
	for id: String in world.maps:
		var p := point(id)
		var area := Rect2(p-Vector2(76,24),Vector2(152,48))
		draw_rect(area,Color("826b43") if id==current_id else (Color("334b43") if visited.has(id) else Color("263138")))
		draw_rect(area,Color("e6ce94") if id==current_id else Color("647874"),false,2)
		draw_string(font,p+Vector2(-68,-3),world.maps[id].name,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("e8e6dc"))
		draw_string(font,p+Vector2(-68,17),"起点" if id=="MONASTERY" else id,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("a6b7b1"))
	draw_string(font,Vector2(48,660),"北线：修道院 ↔ 北门 ↔ 贵族区 ↔ 中心；西线：中心 ↔ 商业区 ↔ 西门",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("c4cfc5"))
	draw_string(font,Vector2(48,688),"南线：中心 ↔ 贫民窟 ↔ 南门；东线经住宅区接东门。其余城外道路暂未开放。",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("c4cfc5"))
