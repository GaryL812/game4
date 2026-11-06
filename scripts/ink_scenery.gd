extends MultiMeshInstance3D

enum Tile { MOUNTAINS, MIST, WATERFALL, BAMBOO, PAVILION, LEAVES }

func build() -> void:
	var cards := MultiMesh.new()
	cards.transform_format = MultiMesh.TRANSFORM_3D
	cards.use_custom_data = true
	cards.mesh = QuadMesh.new()
	cards.instance_count = 7
	# The shader places the cards in the view. Keep the batch visible along the track.
	cards.custom_aabb = AABB(Vector3(-160, -65, -55), Vector3(320, 145, TrackData.FINISH + 240))
	multimesh = cards
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/ink_scenery.gdshader")
	material.set_shader_parameter("scenery_atlas", preload("res://assets/textures/ink_scenery.webp"))
	material.render_priority = -1
	material_override = material

	# Back to front. Rectangles are relative to the viewport, with a top-left origin.
	add_card(0, Tile.MOUNTAINS, Rect2(-.03, -.055, 1.06, .59), 190.0, .60)
	add_card(1, Tile.MIST, Rect2(-.08, .23, 1.16, .72), 181.0, .33)
	add_card(2, Tile.WATERFALL, Rect2(.68, .025, .45, .79), 168.0, .92)
	add_card(3, Tile.PAVILION, Rect2(-.062, .015, .43, .68), 157.0, .92)
	add_card(4, Tile.BAMBOO, Rect2(-.016, .18, .15, .59), 149.0, .82)
	add_card(5, Tile.MIST, Rect2(-.09, .43, 1.18, .65), 142.0, .39)
	add_card(6, Tile.LEAVES, Rect2(-.012, -.066, .25, .59), 137.0, .91)

func add_card(index: int, tile: Tile, rect: Rect2, depth: float, opacity: float) -> void:
	var center := rect.get_center()
	var position := Vector3(center.x * 2.0 - 1.0, 1.0 - center.y * 2.0, depth)
	var basis := Basis.from_scale(Vector3(rect.size.x * 2.0, rect.size.y * 2.0, 1.0))
	multimesh.set_instance_transform(index, Transform3D(basis, position))
	multimesh.set_instance_custom_data(index, Color(tile, opacity, 0, 1))
