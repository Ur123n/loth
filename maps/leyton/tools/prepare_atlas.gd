extends SceneTree
## One-time migration of archived drafts; runtime source remains slice.json.
const ROOT := "res://maps/leyton/"
func _initialize() -> void:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"slice.json"))
	if doc.maps.size() != 3:
		printerr("Expected the three-map baseline; do not overwrite current atlas edits")
		quit(1)
		return
	var archive: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"archive/graybox/leyton_graybox_layouts_v01.json"))
	for draft: Dictionary in archive.layouts:
		if draft.map_id not in ["M02","M03","M05","M06","M08"]:
			continue
		var m := draft.duplicate(true)
		m.status = "playable_graybox_candidate"
		for key in ["water","walls","bridges","gate","wall_walk","stairs_ground","stairs_wall"]:
			if not m.has(key): m[key] = []
		m.exit_depth = 2
		match m.map_id:
			"M02":
				m.spawn = [44,40]
				m.structures.append({"rect":[55,68,18,9],"kind":"stable","label":"私家马厩"})
			"M03":
				m.spawn = [48,4]
				m.walls = [{"rect":[0,83,44,5],"kind":"city_wall"},{"rect":[50,83,46,5],"kind":"city_wall"}]
				m.roads.append({"shape":"rect","rect":[44,79,6,9],"kind":"main"})
				m.structures.append({"rect":[26,46,5,5],"kind":"utility","label":"公共水井"})
			"M05":
				m.spawn = [44,55]
				m.gate = [41,61,6,11]
				m.wall_walk = [0,68,88,3]
				m.stairs_ground = [54,59]
				m.stairs_wall = [54,69]
			"M06":
				m.spawn = [44,26]
				m.gate = [41,0,6,11]
				m.wall_walk = [0,1,88,3]
				m.stairs_ground = [54,10]
				m.stairs_wall = [54,2]
				for item: Dictionary in m.structures:
					if item.kind == "refugee": item.rect = [22,12,17,8]
			"M08":
				m.spawn = [18,36]
				m.gate = [0,33,11,6]
				m.wall_walk = [1,0,3,72]
				m.stairs_ground = [12,46]
				m.stairs_wall = [2,46]
				m.bridges = [[52,52,6,8]]
				m.roads.append({"shape":"rect","rect":[52,39,6,30],"kind":"bridge_road"})
				for item: Dictionary in m.structures:
					if item.kind == "mill": item.rect = [69,42,16,11]
		for water: Dictionary in m.water: water.navigable = false
		doc.maps.append(m)
	for m: Dictionary in doc.maps:
		for ex: Dictionary in m.exits:
			ex.to = String(ex.to).replace(":south_gate",":south").replace(":north_gate",":north")
			ex.enabled = not String(ex.to).begins_with("world:")
		# Named anchors are reservations, not spawned NPC implementations.
		m["npc_spawns"] = [{"id":"district_greeter","cell":m.spawn,"role":"reserved"}]
		m["event_anchors"] = [{"id":"district_entry","cell":m.spawn,"implemented":false}]
		m["patrol_routes"] = []
		if not m.wall_walk.is_empty():
			var r: Array = m.wall_walk
			var vertical: bool = r[3] > r[2]
			var points: Array = [[r[0]+1,3],[r[0]+1,r[3]-4]] if vertical else [[3,r[1]+1],[r[2]-4,r[1]+1]]
			m.patrol_routes.append({"id":"wall_patrol","level":"wall","points":points,"implemented":false})
	doc.maps.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.map_id < b.map_id)
	doc.version = "0.3-eight-map-graybox"
	var file := FileAccess.open(ROOT+"slice.atlas.staged.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(doc,"\t")+"\n")
	print("ATLAS_STAGED maps=",doc.maps.size())
	quit()
