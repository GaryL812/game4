extends Node3D

const SLASH = preload("res://assets/ink_fx/sword_slash.png")
const TRAIL = preload("res://assets/ink_fx/trail.png")
var slash: Sprite3D
var slash_material: ShaderMaterial
var slash_fade: Tween
var impact: GPUParticles3D
var trail: MultiMeshInstance3D
var trail_material: ShaderMaterial
var impact_left := 0.0
var trail_opacity := 0.0
var trail_strength := 0.0
var jump_mark_left := 0.0
var jump_mark_duration := .28
var jump_mark_opacity := .3
var jump_mark_transform := Transform3D.IDENTITY
var previous_position := Vector3.ZERO
var has_previous_position := false
var forward := Vector3.BACK

func roof_bounds(roof: Dictionary) -> Vector4:
	return Vector4(float(roof.x) - float(roof.width) * .5, float(roof.x) + float(roof.width) * .5, roof.start, roof.end)

func brush_transform(pos: Vector3, direction: Vector3, normal: Vector3, width: float, length_value: float) -> Transform3D:
	var along := -direction.normalized()
	var across := along.cross(normal).normalized()
	along = normal.cross(across).normalized()
	var frame := Basis(across * width, along * length_value, normal)
	return Transform3D(frame, pos + normal * .04 + along * length_value * .43)

func footfall(pos: Vector3, kind: String, player) -> void:
	var roof: Dictionary = player.track.surface_at(pos.x, pos.z)
	if roof.is_empty(): return
	var strengthened: bool = player.charge_left > 0 or player.slash_boost_left > 0 or player.boost_left > 0
	jump_mark_duration = .3 if kind == "land" else .22
	jump_mark_left = jump_mark_duration
	jump_mark_opacity = .5 if strengthened else .3
	var width := 1.05 if kind == "land" else .65
	var length_value := 1.5 if kind == "land" else 2.1
	jump_mark_transform = brush_transform(Vector3(pos.x, roof.height, pos.z), forward, Vector3.UP, width, length_value)
	trail_material.set_shader_parameter("jump_roof", roof_bounds(roof))

func _ready() -> void:
	slash = Sprite3D.new()
	slash.name = "InkSlash"
	slash.texture = SLASH
	slash.pixel_size = 3.4 / SLASH.get_width()
	slash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	slash_material = ShaderMaterial.new()
	slash_material.shader = preload("res://scripts/ink_slash.gdshader")
	slash_material.set_shader_parameter("slash_texture", SLASH)
	slash.material_override = slash_material
	add_child(slash)

	impact = GPUParticles3D.new()
	impact.name = "InkImpact"
	impact.amount = 20
	impact.lifetime = .3
	impact.one_shot = true
	impact.explosiveness = 1.0
	impact.emitting = false
	impact.visibility_aabb = AABB(Vector3(-4, -2, -4), Vector3(8, 6, 8))
	impact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var motion := ParticleProcessMaterial.new()
	motion.direction = Vector3.UP
	motion.spread = 85
	motion.initial_velocity_min = 2.0
	motion.initial_velocity_max = 5.5
	motion.gravity = Vector3(0, -8, 0)
	motion.scale_min = .045
	motion.scale_max = .13
	var fade := Gradient.new()
	fade.set_color(0, Color(.02, .025, .02, 1))
	fade.set_color(1, Color(.02, .025, .02, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	motion.color_ramp = ramp
	impact.process_material = motion
	var drop := QuadMesh.new()
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ink.vertex_color_use_as_albedo = true
	ink.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	ink.billboard_keep_scale = true
	# A tiny round ink dot, generated once and shared by all GPU particles.
	var dot_image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var radius := Vector2(x - 7.5, y - 7.5).length() / 7.5
			dot_image.set_pixel(x, y, Color(1, 1, 1, 1.0 - smoothstep(.5, 1.0, radius)))
	ink.albedo_texture = ImageTexture.create_from_image(dot_image)
	drop.material = ink
	impact.draw_pass_1 = drop
	add_child(impact)

	trail = MultiMeshInstance3D.new()
	trail.name = "InkFootTrail"
	var brush := QuadMesh.new()
	brush.size = Vector2.ONE
	var strokes := MultiMesh.new()
	strokes.transform_format = MultiMesh.TRANSFORM_3D
	strokes.use_custom_data = true
	strokes.mesh = brush
	strokes.instance_count = 2
	strokes.visible_instance_count = 0
	trail.multimesh = strokes
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail_material = ShaderMaterial.new()
	trail_material.shader = preload("res://scripts/ink_speed_trail.gdshader")
	trail_material.set_shader_parameter("trail_texture", TRAIL)
	trail.material_override = trail_material
	add_child(trail)
	clear()

func show_slash(pos: Vector3, empowered: bool) -> void:
	if slash_fade: slash_fade.kill()
	slash.position = pos + Vector3(0, 1.25, .6)
	slash.scale = Vector3.ONE * (1.3 if empowered else 1.0)
	slash_material.set_shader_parameter("density", 1.75 if empowered else 1.0)
	slash_material.set_shader_parameter("opacity", 1.0)
	slash.visible = true
	slash_fade = create_tween()
	slash_fade.pause()
	slash_fade.tween_method(func(alpha: float): slash_material.set_shader_parameter("opacity", alpha), 1.0, 0.0, .1)
	slash_fade.tween_callback(func(): slash.visible = false)

func splash(pos: Vector3) -> void:
	impact.position = pos + Vector3(0, .65, 0)
	impact.visible = true
	impact_left = .3
	impact.restart()

func tick(dt: float, player) -> void:
	if slash_fade and slash_fade.is_valid(): slash_fade.custom_step(dt)
	impact_left = maxf(0, impact_left - dt)
	impact.visible = impact_left > 0
	tick_trail(dt, player)

func tick_trail(dt: float, player) -> void:
	var motion := Vector3(0, 0, player.speed)
	if has_previous_position and dt > 0:
		if previous_position.distance_to(player.position) > 8:
			jump_mark_left = 0
			trail_opacity = 0
		else:
			motion = (player.position - previous_position) / dt
	previous_position = player.position
	has_previous_position = true
	var heading := Vector3(motion.x, 0, motion.z)
	if heading.length_squared() > .01:
		forward = forward.lerp(heading.normalized(), 1 - exp(-dt * 12)).normalized()
	var active: bool = player.traversal == "run" and not player.finished and player.speed > 0
	var powered: bool = player.charge_left > 0 or player.slash_boost_left > 0 or player.boost_left > 0 or player.attack_left > 0
	trail_strength = lerpf(trail_strength, 1.0 if powered else 0.0, 1 - exp(-dt * 18))
	var on_roof: bool = player.grounded and active
	var target_opacity := lerpf(.24, .74, trail_strength) if on_roof else (.14 + .12 * trail_strength if active else 0.0)
	trail_opacity = lerpf(trail_opacity, target_opacity, 1 - exp(-dt * 28))
	var count := 0
	if trail_opacity > .003 and active:
		var frame: Transform3D
		var ground_mode := 0.0
		if on_roof:
			var roof: Dictionary = player.track.surface_at(player.position.x, player.position.z)
			if not roof.is_empty():
				trail_material.set_shader_parameter("live_roof", roof_bounds(roof))
			ground_mode = 1.0
			frame = brush_transform(player.position, forward, Vector3.UP, lerpf(.72, 1.22, trail_strength), lerpf(2.6, 4.3, trail_strength))
		else:
			# A thin ribbon follows flight; the ground print stays at takeoff.
			var direction := Vector3(forward.x, clampf(player.vertical_speed / maxf(player.speed, 1), -.7, .7), forward.z).normalized()
			var camera := get_viewport().get_camera_3d()
			var normal: Vector3 = (camera.global_position - player.position).normalized() if camera else Vector3.UP
			frame = brush_transform(player.position + Vector3.UP * .12, direction, normal, lerpf(.23, .4, trail_strength), lerpf(1.35, 2.1, trail_strength))
		trail.multimesh.set_instance_transform(count, frame)
		trail.multimesh.set_instance_custom_data(count, Color(trail_opacity, lerpf(1.0, 1.45, trail_strength), ground_mode, 1))
		count += 1
	jump_mark_left = maxf(0, jump_mark_left - dt)
	if jump_mark_left > 0:
		var fade := smoothstep(0, 1, jump_mark_left / jump_mark_duration)
		trail.multimesh.set_instance_transform(count, jump_mark_transform)
		trail.multimesh.set_instance_custom_data(count, Color(jump_mark_opacity * fade, 1, 2, 1))
		count += 1
	trail.multimesh.visible_instance_count = count
	trail.visible = count > 0

func set_frozen(frozen: bool) -> void:
	impact.speed_scale = 0.0 if frozen else 1.0

func clear() -> void:
	if slash_fade: slash_fade.kill()
	slash.visible = false
	impact.emitting = false
	impact.visible = false
	impact_left = 0
	trail.visible = false
	trail.multimesh.visible_instance_count = 0
	trail_opacity = 0
	trail_strength = 0
	jump_mark_left = 0
	has_previous_position = false
	forward = Vector3.BACK
