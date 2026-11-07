extends Node

var game
var fx
var checks := 0
var failed := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func _ready() -> void:
	call_deferred("run")

func warm_up(seconds: float) -> void:
	for i in ceili(seconds * 60):
		fx.tick(1.0 / 60, game.player)

func capture(label: String) -> void:
	if not "--visual" in OS.get_cmdline_user_args(): return
	game.player.paper_visual.update_pose()
	for i in 3:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/trail_%s.png" % label)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game.state = "race"
	game.audio.muted = true
	game.player.position = Vector3(0, 0, 5)
	game.player.target_x = 0
	game.player.grounded = true
	game.update_camera(1)
	for i in 3: game.taken_coins[i] = true
	game.world.update_view(5, 0)
	fx = game.world.sword_fx
	fx.clear()
	warm_up(.3)
	check(fx.trail.visible and fx.trail.multimesh.visible_instance_count == 1, "ordinary running displays one faint brush stroke")
	check(fx.trail_material.get_shader_parameter("trail_texture").resource_path.ends_with("/trail.png"), "foot trail uses the supplied brush texture")
	var ordinary: Color = fx.trail.multimesh.get_instance_custom_data(0)
	var ordinary_frame: Transform3D = fx.trail.multimesh.get_instance_transform(0)
	check(ordinary.r > .2 and ordinary.r < .3 and ordinary_frame.basis.y.z < 0, "normal stroke stays pale and extends behind the feet")
	await capture("run")
	game.player.charge_left = 5
	warm_up(.3)
	var sprint: Color = fx.trail.multimesh.get_instance_custom_data(0)
	var sprint_frame: Transform3D = fx.trail.multimesh.get_instance_transform(0)
	check(sprint.r > ordinary.r * 2 and sprint_frame.basis.x.length() > ordinary_frame.basis.x.length() * 1.5, "sprint smoothly widens and darkens the same brush stroke")
	await capture("sprint")
	game.player.charge_left = 0
	game.player.attack_left = .1
	warm_up(.3)
	check(fx.trail_strength > .95, "slashing strengthens the trail without requiring a speed buff")
	game.player.attack_left = 0
	game.player.boost_left = 1
	warm_up(.3)
	check(fx.trail_strength > .95, "existing jump-pad boosts also strengthen the brush stroke")
	game.emit_fx(game.player.position, "jump")
	var takeoff: Transform3D = fx.jump_mark_transform
	check(fx.jump_mark_left > 0 and game.world.particles.all(func(p): return p.life <= 0), "jump replaces round particles with a ground brush print")
	game.player.grounded = false
	game.player.position += Vector3(0, 1.1, 1.0)
	game.player.vertical_speed = 5
	game.player.update_visual(0)
	fx.tick(.05, game.player)
	var airborne: Color = fx.trail.multimesh.get_instance_custom_data(0)
	var air_frame: Transform3D = fx.trail.multimesh.get_instance_transform(0)
	check(fx.trail.multimesh.visible_instance_count == 2 and fx.jump_mark_transform == takeoff, "takeoff print stays on the roof while the airborne ribbon follows the runner")
	check(airborne.b == 0 and air_frame.origin.y > .1 and air_frame.basis.x.length() < ordinary_frame.basis.x.length(), "airborne trail becomes a thin ribbon instead of a floating ground patch")
	fx.tick(.05, game.player)
	check(fx.trail_opacity < sprint.r * .5, "airborne ink fades to a lighter opacity")
	await capture("jump")
	game.state = "paused"
	var before_pause: float = fx.jump_mark_left
	game._physics_process(.25)
	check(fx.jump_mark_left == before_pause, "pause freezes the takeoff print fade")
	game.state = "race"
	warm_up(.4)
	check(fx.jump_mark_left == 0 and fx.trail.multimesh.visible_instance_count == 1, "takeoff print expires without accumulating extra nodes")
	game.player.position = Vector3(0, 0, 1)
	game.player.grounded = true
	game.player.vertical_speed = 0
	game.player.update_visual(0)
	game.emit_fx(game.player.position, "land")
	fx.tick(.05, game.player)
	check(fx.trail.multimesh.get_instance_custom_data(0).b == 1 and fx.jump_mark_left > 0, "landing restores the ground trail and adds a short brush impression")
	await capture("land")
	game.player.boost_left = 0
	warm_up(.5)
	check(fx.trail_strength < .01 and fx.trail_opacity < .3, "boost expiry returns to ordinary pale running ink")
	fx.clear()
	check(not fx.trail.visible and fx.trail.multimesh.visible_instance_count == 0 and fx.jump_mark_left == 0, "restart clears both brush instances and their fade state")
	print("TRAIL_TESTS %d/%d passed" % [checks - failed, checks])
	game.audio.shutdown()
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
