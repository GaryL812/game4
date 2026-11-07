extends Node3D

const ATLAS = preload("res://assets/textures/paper_runner.png")
const STREET_ATLAS = preload("res://assets/textures/paper_runner_street.png")
const FELINE_ATLAS = preload("res://assets/textures/paper_runner_feline.png")
const PIXELS_PER_METER := 128.0
const CELL := 256
const PIVOT := Vector2(128, 76)
const HEAD := 0
const TORSO := 1
const UPPER_ARM := 2
const FOREARM := 3
const THIGH := 4
const BOOT := 5
const BACK_ACCESSORY := 6
const HEAD_ACCESSORY := 7
const BODY_UPPER := .59
const UPPER_LEG := .435
const LOWER_LEG := .40
const UPPER_SLEEVE := .30
const LOWER_SLEEVE := .28

var action := "Run"
var paused := false
var vertical_speed := 0.0
var boosted := false
var run_cycle_scale := 1.0
var wall_side := 0
var phase := 0.15
var age := 0.0
var skin_id := 0
var paper := Node3D.new()
var head := Node3D.new()
var hat: Sprite3D
var torso: Sprite3D
var back_accessory: Sprite3D
var back_mount := Vector3(.26, -.095, .055)
var back_angle := -.88
var parts: Array[Sprite3D] = []
var arms: Array[Sprite3D] = []
var legs: Array[Sprite3D] = []
var pose := PackedVector3Array()
var previous_pose := PackedVector3Array()
var view_basis := Basis.IDENTITY
var view_origin := Vector3.ZERO
var slash_phase := 0.0
var slash_tween: Tween
var armed := false

func start_slash() -> void:
	if slash_tween and slash_tween.is_valid(): slash_tween.kill()
	slash_phase = 0.0
	slash_tween = create_tween()
	slash_tween.pause()
	slash_tween.tween_property(self, "slash_phase", 1.0, .05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	slash_tween.tween_property(self, "slash_phase", 2.0, .1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	slash_tween.tween_property(self, "slash_phase", 3.0, .05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func cancel_slash() -> void:
	if slash_tween and slash_tween.is_valid(): slash_tween.kill()
	slash_phase = 0.0
	if back_accessory:
		back_accessory.render_priority = 2
		set_skin(skin_id)

func _ready() -> void:
	paper.name = "PaperPlane"
	add_child(paper)
	torso = add_part(paper, "Torso", TORSO, 0)
	head.name = "HeadPivot"
	paper.add_child(head)
	add_part(head, "Head", HEAD, 3)
	hat = add_part(head, "Hat", HEAD_ACCESSORY, 4)
	back_accessory = add_part(paper, "BackAccessory", BACK_ACCESSORY, 2)
	for side in ["Left", "Right"]:
		arms.append(add_part(paper, side + "UpperArm", UPPER_ARM, -1))
		arms.append(add_part(paper, side + "Forearm", FOREARM, -1))
		legs.append(add_part(paper, side + "Thigh", THIGH, -2))
		legs.append(add_part(paper, side + "Boot", BOOT, -2))
		for part in [arms[-2], arms[-1], legs[-2], legs[-1]]:
			part.flip_h = side == "Left"
	set_skin(skin_id)
	update_pose()

func add_part(parent: Node3D, part_name: String, tile: int, layer: int) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.name = part_name
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2(tile % 4, floori(tile / 4.0)) * CELL, Vector2(CELL, CELL))
	sprite.pixel_size = 1.0 / PIXELS_PER_METER
	sprite.offset = Vector2(CELL * .5 - PIVOT.x, PIVOT.y - CELL * .5)
	sprite.render_priority = layer
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(sprite)
	parts.append(sprite)
	return sprite

func play(next_action: String) -> void:
	if action == next_action:
		return
	previous_pose = pose.duplicate()
	action = next_action
	age = 0.0

static func outfit_atlas(index: int) -> Texture2D:
	if index == Save.STREET_SKIN:
		return STREET_ATLAS
	if index == Save.FELINE_SKIN:
		return FELINE_ATLAS
	return null

func set_skin(index: int) -> void:
	skin_id = index
	var outfit := outfit_atlas(index)
	var atlas := outfit if outfit else ATLAS
	for part in parts:
		part.texture = atlas
	# The street sneaker points to the opposite side of the other shoe sprites.
	var street := index == Save.STREET_SKIN
	legs[1].flip_h = not street
	legs[3].flip_h = street
	hat.modulate = Color.WHITE if index == 0 or outfit else Color(Save.COLORS[index])
	if index == Save.FELINE_SKIN:
		hat.position = Vector3(0, .235, .012)
		hat.scale.x = 1.0
		back_mount = Vector3(.015, -.63, .055)
		back_angle = 2.20
	elif street:
		hat.position = Vector3(0, .16, .012)
		hat.scale.x = 1.0
		back_mount = Vector3(.22, -.13, .055)
		back_angle = -.69
	else:
		hat.position = Vector3(0, .195, .012)
		hat.scale.x = .92
		back_mount = Vector3(.26, -.095, .055)
		back_angle = -.88

func _process(dt: float) -> void:
	if not is_visible_in_tree():
		return
	if not paused:
		age += dt
		if action == "Run":
			phase = fposmod(phase + dt * (2.15 if boosted else 1.73) * run_cycle_scale, 1.0)
	update_pose()

func update_pose() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var toward := camera.global_position - global_position
	if toward.length_squared() < .01:
		return
	var facing := Basis.looking_at(toward, Vector3.UP, true)
	paper.global_basis = facing
	var flip := Basis.IDENTITY
	if action == "Flip":
		flip = Basis(Vector3.RIGHT, TAU * smoothstep(0.0, 1.0, clampf(age / .70, 0.0, 1.0)))
	var center := Vector3.UP * .85
	var local_to_paper := facing.transposed() * global_basis
	view_basis = local_to_paper * flip
	view_origin = local_to_paper * (center - flip * center)

	var target := make_pose()
	var blend := smoothstep(0.0, .09, age)
	if previous_pose.size() == target.size() and blend < 1.0:
		for i in target.size():
			target[i] = previous_pose[i].lerp(target[i], blend)
	pose = target
	place(torso, pose[0], pose[1], BODY_UPPER)
	head.position = project(pose[0])
	head.rotation.z = torso.rotation.z + .025 * sin(phase * TAU)
	hat.rotation.z = .035 * sin(phase * TAU - .9)
	back_accessory.position = torso.position + back_mount.rotated(Vector3.BACK, torso.rotation.z)
	var tail_sway := .16 * sin(phase * TAU - .8) if skin_id == Save.FELINE_SKIN else 0.0
	back_accessory.rotation.z = torso.rotation.z + back_angle + tail_sway
	if armed and slash_phase > 0.0:
		# Reuse the existing accessory sprite as the sword: no extra draw call.
		back_accessory.texture = ATLAS
		back_accessory.position = project(pose[10])
		back_accessory.render_priority = 3
		var angle := -.55
		if slash_phase <= 1.0: angle = lerpf(-.55, 3.7, slash_phase)
		elif slash_phase <= 2.0: angle = lerpf(3.7, .65, slash_phase - 1.0)
		else: angle = lerpf(.65, -.55, slash_phase - 2.0)
		back_accessory.rotation.z = angle

	for side in 2:
		var i := 2 + side * 6
		var j := side * 2
		place(arms[j], pose[i], pose[i + 1], UPPER_SLEEVE)
		place(arms[j + 1], pose[i + 1], pose[i + 2], LOWER_SLEEVE)
		place(legs[j], pose[i + 3], pose[i + 4], .407)
		place(legs[j + 1], pose[i + 4], pose[i + 5], LOWER_LEG)
		var near_arm := project(pose[i + 2]).z > project(pose[0]).z
		var near_leg := project(pose[i + 5]).z > project(pose[1]).z
		arms[j].render_priority = 1 if near_arm else -2
		arms[j + 1].render_priority = arms[j].render_priority
		legs[j].render_priority = -1 if near_leg else -3
		legs[j + 1].render_priority = legs[j].render_priority

func project(point: Vector3) -> Vector3:
	return view_origin + view_basis * point

func place(sprite: Sprite3D, start: Vector3, end: Vector3, length: float) -> void:
	var a := project(start)
	var b := project(end)
	var stroke := Vector2(b.x - a.x, b.y - a.y)
	sprite.position = a
	sprite.rotation.z = atan2(stroke.x, -stroke.y)
	sprite.scale.y = maxf(.20, stroke.length() / length)

func make_pose() -> PackedVector3Array:
	var wave := sin(phase * TAU)
	var hip := Vector3(.025 * wave, .88 + .035 * sin(phase * TAU * 2.0), 0)
	var neck := hip + Vector3(-.045 * wave, .59, .13)
	if slash_phase > 1.0:
		neck.z += .2 * (slash_phase - 1.0 if slash_phase < 2.0 else 3.0 - slash_phase)
	var ankles := PackedVector3Array()
	var wrists := PackedVector3Array()
	var climb_wave := sin(age * TAU * 1.7)
	for side in 2:
		var sign_side := -1.0 if side == 0 else 1.0
		var t := fposmod(phase + side * .5, 1.0)
		var swing := clampf((t - .43) / .57, 0.0, 1.0)
		var stride := lerpf(.37, -.42, minf(1.0, t / .43))
		if swing > 0.0:
			stride = lerpf(-.42, .37, smoothstep(0.0, 1.0, swing))
		var ankle := Vector3(sign_side * .124, .104 + .37 * sin(swing * PI), stride)
		var pump := -cos(t * TAU)
		var wrist := Vector3(sign_side * (.25 - .025 * pump), 1.02 + .19 * pump, .04 + .36 * pump)
		match action:
			"Jump":
				var tuck := 1.0 - clampf(absf(vertical_speed) / 10.0, 0.0, 1.0)
				ankle = Vector3(sign_side * .13, .20 + .32 * tuck, .24 * sign_side + .08)
				wrist = Vector3(sign_side * .29, 1.26 + .14 * sign_side, .26 * sign_side)
			"Land":
				var sink := sin(PI * sqrt(clampf(age / .32, 0.0, 1.0)))
				hip.y = .86 - .17 * sink
				neck = hip + Vector3(0, .56, .18 + .10 * sink)
				ankle = Vector3(sign_side * .13, .10, .12 * sign_side)
				wrist = Vector3(sign_side * .32, .96, .20)
			"Flip":
				var tuck := sin(PI * clampf(age / .70, 0.0, 1.0))
				ankle = Vector3(sign_side * .13, .16 + .38 * tuck, .24 + .09 * sign_side)
				wrist = Vector3(sign_side * .25, 1.03 + .10 * tuck, .32)
			"Climb":
				hip = Vector3(0, .85, 0)
				neck = hip + Vector3(0, .60, .08)
				ankle = Vector3(sign_side * .15, .28 + .19 * climb_wave * sign_side, .24)
				wrist = Vector3(sign_side * .27, 1.58 + .23 * climb_wave * sign_side, .22)
			"SideSlide":
				hip = Vector3(0, .72, 0)
				neck = hip + Vector3(0, .55, .15)
				ankle = Vector3(sign_side * .15, .16, .34 * sign_side)
				wrist = Vector3(sign_side * .37, 1.18 + .24 * sign_side * wall_side, .20)
			"Hit":
				hip = Vector3(0, .79, 0)
				neck = hip + Vector3(0, .56, -.13)
				ankle = Vector3(sign_side * .17, .10, .22 * sign_side)
				wrist = Vector3(sign_side * .39, 1.22, -.08)
			"Celebrate":
				hip = Vector3(0, .91 + .04 * sin(age * TAU * 1.6), 0)
				neck = hip + Vector3(0, .59, .04)
				ankle = Vector3(sign_side * .16, .105, 0)
				wrist = Vector3(sign_side * .40, 1.75 + .055 * climb_wave, .07)
		if armed and side == 1:
			var rest := wrist
			var raised := Vector3(.27, 1.86, -.18)
			var lowered := Vector3(-.12, 1.04, .51)
			if slash_phase <= 1.0: wrist = rest.lerp(raised, slash_phase)
			elif slash_phase <= 2.0: wrist = raised.lerp(lowered, slash_phase - 1.0)
			else: wrist = lowered.lerp(rest, slash_phase - 2.0)
		ankles.append(ankle)
		wrists.append(wrist)

	var result := PackedVector3Array([neck, hip])
	for side in 2:
		var sign_side := -1.0 if side == 0 else 1.0
		var shoulder := neck + Vector3(sign_side * .217, -.123, .038 * wave * sign_side)
		var wrist := limit_reach(shoulder, wrists[side], UPPER_SLEEVE + LOWER_SLEEVE)
		var arm := wrist - shoulder
		var elbow_pole := Vector3(.07 * sign_side, -arm.z, minf(-.09, arm.y))
		var elbow := joint(shoulder, wrist, UPPER_SLEEVE, LOWER_SLEEVE, elbow_pole)
		var leg := hip + Vector3(sign_side * .115, -.012, -.025 * wave * sign_side)
		var ankle := limit_reach(leg, ankles[side], UPPER_LEG + LOWER_LEG)
		var knee := joint(leg, ankle, UPPER_LEG, LOWER_LEG, Vector3.BACK)
		result.append_array(PackedVector3Array([shoulder, elbow, wrist, leg, knee, ankle]))
	return result

func limit_reach(start: Vector3, end: Vector3, reach: float) -> Vector3:
	return start + (end - start).limit_length(reach - .002)

func joint(start: Vector3, end: Vector3, first: float, second: float, pole: Vector3) -> Vector3:
	var delta := end - start
	var distance := maxf(delta.length(), .02)
	var along := delta / distance
	var perpendicular := (pole - along * pole.dot(along)).normalized()
	var center := (first * first - second * second + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(0.0, first * first - center * center))
	return start + along * center + perpendicular * height
