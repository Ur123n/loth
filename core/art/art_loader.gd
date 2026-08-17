class_name ArtLoader
extends RefCounted

## 统一美术资源加载器（接口层）。
## 各库的美术字段（icon_path / art_path / portrait_path / animation_path）
## 统一通过本类加载：路径为空或资源不存在时返回 null，不报错。
## 卡牌的 icon/art/animation 为相对 卡牌/ 目录的路径，调用前请拼接为 res:// 路径。
## 用法示例：
##   var tex := ArtLoader.load_texture(character_data.art_path)
##   var scene := ArtLoader.load_scene(enemy_data.animation_path)

static func load_texture(path: String) -> Texture2D:
	var res := _load(path)
	return res as Texture2D


static func load_scene(path: String) -> PackedScene:
	var res := _load(path)
	return res as PackedScene


static func load_resource(path: String) -> Resource:
	return _load(path)


static func _load(path: String) -> Resource:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path)
