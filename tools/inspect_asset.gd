extends SceneTree
func _init() -> void:
	var scene = load("res://assets/models/track/roof_wide.glb").instantiate()
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var m = node.mesh.surface_get_material(0)
		print(node.name, " ", m, " vertex ", m.vertex_color_use_as_albedo, " color ",m.albedo_color)
	scene.free()
	quit()
