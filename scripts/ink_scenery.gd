extends MultiMeshInstance3D

enum Tile { MOUNTAINS, MIST, WATERFALL, BAMBOO_LEFT, BAMBOO_RIGHT }

const CAPACITY := 16
const MIST_DEPTH := [26.0, 61.0, 111.0]
const MIST_WIDTH := [53.0, 92.0, 146.0]
const MIST_HEIGHT := [21.0, 32.0, 48.0]
const MIST_OPACITY := [.53, .41, .33]

var props: Array[Dictionary] = []
var mist: Array[Dictionary] = []
var visible_cards: Array[Dictionary] = []

func build(track: TrackData) -> void:
	var cards := MultiMesh.new()
	cards.transform_format = MultiMesh.TRANSFORM_3D
	cards.use_custom_data = true
	cards.mesh = QuadMesh.new()
	cards.instance_count = CAPACITY
	cards.visible_instance_count = 0
	cards.custom_aabb = AABB(Vector3(-160, -65, -55), Vector3(320, 145, TrackData.FINISH + 240))
	multimesh = cards
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/ink_scenery.gdshader")
	material.set_shader_parameter("scenery_atlas", preload("res://assets/textures/ink_scenery.webp"))
	material.render_priority = -1
	material_override = material

	cards.set_instance_transform(0, Transform3D.IDENTITY)
	cards.set_instance_custom_data(0, Color(Tile.MOUNTAINS, .65, 0, 1))
	for i in MIST_DEPTH.size():
		mist.append({
			"transform": Transform3D(Basis.from_scale(Vector3(MIST_WIDTH[i], MIST_HEIGHT[i], 1.0)), Vector3.ZERO),
			"paint": Color(Tile.MIST, MIST_OPACITY[i], 0, 1),
		})

	# A dedicated seed varies the scenery without affecting spawns or race AI.
	var rng := RandomNumberGenerator.new()
	rng.seed = 43176
	for i in track.sections.size():
		var side := 1.0 if i % 2 == 0 else -1.0
		if i == 1:
			side = 1.0
		var roof: Dictionary = track.sections[i][0]
		var z := float(roof.start)
		var bamboo := Tile.BAMBOO_LEFT if side > 0 else Tile.BAMBOO_RIGHT
		add_prop(bamboo, side, z + rng.randf_range(17.0, 22.0), rng.randf_range(6.4, 9.0), .76, rng)
		if i % 3 == 1:
			add_prop(Tile.WATERFALL, -side, z + rng.randf_range(19.0, 25.0), rng.randf_range(18.0, 24.0), .77, rng)

func add_prop(tile: int, side: float, z: float, width: float, opacity: float, rng: RandomNumberGenerator) -> void:
	var waterfall := tile == Tile.WATERFALL
	var height := width if waterfall else width * 2.42
	var basis := Basis(Vector3.UP, rng.randf_range(-.13, .13)) * Basis.from_scale(Vector3(width, height, 1.0))
	# The nearest edge of every card remains outside all three roof routes.
	var x := side * (11.4 + width * .5 + rng.randf_range(0.0, 3.0))
	var base := -11.5 if waterfall else -8.5
	var y := base + height * .5 + rng.randf_range(-2.0, 2.0)
	props.append({
		"transform": Transform3D(basis, Vector3(x, y, z)),
		"paint": Color(tile, opacity * rng.randf_range(.84, 1.0), 0, 1),
	})

func update_view(z: float, phase: float, low_end: bool) -> void:
	visible_cards.clear()
	for card in props:
		var depth: float = card.transform.origin.z - z
		if depth > -14.0 and depth < 134.0:
			visible_cards.append(card)
	for i in (2 if low_end else MIST_DEPTH.size()):
		var layer := mist[i]
		var transform: Transform3D = layer.transform
		var drift := sin(phase * (.031 + i * .008) + i) * (2.0 + i * 1.2)
		transform.origin = Vector3(drift, -7.7 - i * 3.3, z + MIST_DEPTH[i])
		layer.transform = transform
		visible_cards.append(layer)

	# Transparent instances blend in draw order. The painting stays first,
	# then distant fog and props precede those nearer the player.
	visible_cards.sort_custom(farther_first)
	var count := mini(visible_cards.size(), CAPACITY - 1)
	for i in count:
		var card := visible_cards[i]
		multimesh.set_instance_transform(i + 1, card.transform)
		multimesh.set_instance_custom_data(i + 1, card.paint)
	multimesh.visible_instance_count = count + 1

func farther_first(a: Dictionary, b: Dictionary) -> bool:
	return a.transform.origin.z > b.transform.origin.z
