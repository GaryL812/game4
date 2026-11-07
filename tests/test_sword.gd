extends Node
var game
var checks := 0
var failed := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: ",message)
	else:
		failed += 1
		push_error("FAIL: "+message)

func _ready() -> void:
	call_deferred("run")

func approach(index: int) -> void:
	var obstacle: Dictionary = game.track.obstacles[index]
	game.player.position = Vector3(obstacle.x,obstacle.y,float(obstacle.z)-2.3)
	game.player.target_x = game.player.position.x
	game.player.grounded = true
	game.player.vertical_speed = 0
	game.player.traversal = "run"
	game.player.wall_cooldown = .3
	game.update_camera(1)
	game.world.update_view(game.player.position.z,0)

func step(seconds: float) -> void:
	for i in ceili(seconds*120):
		game.player.tick(1.0/120,0)
		game.world.update_view(game.player.position.z,1.0/120)
		game.update_camera(1.0/120)

func fill_charge() -> void:
	for i in RoofRunner.CHARGE_COINS:
		game.player.charge_from_coin()

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game.audio.muted=true
	check(not game.player.attack(),"menu blocks attacks")
	game.state="race"
	for i in RoofRunner.CHARGE_COINS-1:
		var coin: Dictionary=game.track.coins[i]
		game.player.position=Vector3(coin.x,float(coin.y)-1,coin.z)
		game.collect_coins(game.player)
	check(game.player.charge_coins==RoofRunner.CHARGE_COINS-1 and game.player.attack_left==0,"fourteen collected coins charge without firing")
	game.collect_coins(game.player)
	check(game.player.charge_coins==RoofRunner.CHARGE_COINS-1,"duplicate collection cannot add charge")
	var final_coin: Dictionary=game.track.coins[RoofRunner.CHARGE_COINS-1]
	game.player.position=Vector3(final_coin.x,float(final_coin.y)-1,final_coin.z)
	game.collect_coins(game.player)
	check(game.player.collected==RoofRunner.CHARGE_COINS and game.player.charge_left==5 and game.player.attack_left==0,"fifteenth coin activates sprint without swinging on an open route")
	fill_charge()
	check(game.player.charge_left==5 and game.player.charge_coins==0,"active pickups cannot stack or extend the window")
	approach(0)
	step(.025)
	check(game.world.destroyed_obstacles.is_empty(),"windup preserves slash timing")
	step(.075)
	check(game.world.destroyed_obstacles.has(0) and not game.world.obstacle_nodes[0].visible and game.player.stun_left==0,"downstroke cuts the obstacle before collision slowdown")
	check(game.world.sword_fx.slash.visible and game.world.sword_fx.impact.visible and game.world.sword_fx.trail.visible,"supplied slash, ink impact and trail activate together")
	game.world.update_view(game.player.position.z,0)
	check(not game.world.obstacle_nodes[0].visible,"streaming keeps cut obstacles hidden")
	var remaining: float=game.player.charge_left
	var phase: float=game.player.paper_visual.slash_phase
	game.hud._process(.3)
	check(game.hud.wind_strength>0,"sprint displays the wind lines")
	var wind_time: float=game.hud.wind_time
	game.state="paused"
	game._physics_process(.5)
	game.hud._process(.5)
	check(game.player.charge_left==remaining and game.player.paper_visual.slash_phase==phase,"pause freezes charge and slash")
	check(game.hud.wind_time==wind_time,"pause freezes the wind animation")
	check(game.world.sword_fx.impact.speed_scale==0,"pause freezes GPU ink")
	game.state="race"
	game.update_runner_visibility()
	step(.125)
	check(game.player.charge_left>0 and game.player.attack_left==0,"after a hit the sword returns to rest until another target approaches")
	approach(1)
	step(.4)
	check(game.world.destroyed_obstacles.has(1),"approaching another obstacle triggers the next automatic slash")
	var rival: RoofRunner=game.runners[1]
	var roof: Dictionary=game.track.surface_at(game.player.position.x,game.player.position.z)
	rival.position=game.player.position+Vector3(0,0,2)
	rival.remember_safe(roof)
	var safe: Vector3=rival.safe_position
	var falls := rival.falls
	step(.45)
	game.update_runner_visibility()
	check(rival.defeated_left>0 and not rival.visible,"a nearby rival is cut and hidden")
	var recovery: float=rival.defeated_left
	game.state="paused"
	game._physics_process(.5)
	check(rival.defeated_left==recovery,"pause freezes rival recovery")
	game.state="race"
	for i in 240: rival.tick(1.0/120,0)
	check(rival.defeated_left==0 and rival.position.is_equal_approx(safe) and rival.falls==falls,"rival returns safely after two seconds")
	check(rival.invulnerable>0,"recovered rival gets brief repeat-hit protection")
	game.player.position=Vector3.ZERO
	game.player.target_x=0
	game.player.grounded=true
	game.player.traversal="run"
	game.player.speed=0
	rival.position.z=200
	step(game.player.charge_left+.25)
	game.world.update_view(0,.2)
	check(game.player.charge_left==0 and game.player.attack_left==0 and game.player.slash_boost_left==0,"expiry stops automatic attacks and boosts")
	check(not game.world.sword_fx.slash.visible and not game.world.sword_fx.trail.visible,"expired effects fade out")
	check(not game.player.attack(),"manual calls cannot bypass empty charge")
	fill_charge()
	check(game.player.charge_left==5 and game.player.attack_left==0,"a fresh charge starts sprinting with the sword at rest")
	game.player.speed=TrackData.BASE_SPEED
	var sprint_start: float=game.player.position.z
	step(.1)
	check(is_equal_approx(game.player.position.z-sprint_start,TrackData.BASE_SPEED*RoofRunner.CHARGE_SPEED_MULTIPLIER*.1),"charged running immediately uses the sustained speed multiplier")
	check(game.player.attack_left==0 and game.player.paper_visual.slash_phase==0,"an open route keeps the sword at rest during sprint")
	game.player.respawn()
	check(game.player.charge_left==0 and game.player.attack_left==0,"respawn clears the active window")
	game.player.charge_from_coin()
	game.player.respawn()
	check(game.player.charge_coins==1,"partial charge survives a fall")
	game.reset_runners()
	game.state="race"
	check(game.player.charge_coins==0 and game.world.destroyed_obstacles.is_empty(),"restart resets charge and restores obstacles")
	approach(0)
	game.player.position.z=game.track.obstacles[0].z
	step(.01)
	check(game.player.stun_left>0,"uncharged obstacles still slow the player")
	for offset in [Vector3(0,0,-6),Vector3(4,0,0),Vector3(0,3,0)]:
		game.reset_runners()
		game.state="race"
		approach(0)
		game.player.position+=offset
		game.player.target_x=game.player.position.x
		if offset.y>0: game.player.grounded=false
		fill_charge()
		step(.225)
		check(game.world.destroyed_obstacles.is_empty(),"slash rejects unreachable target at %s"%offset)
	game.reset_runners()
	game.state="race"
	approach(0)
	game.player.position.z=float(game.track.obstacles[0].z)-.3
	fill_charge()
	game.player.tick(1.0/30,0)
	check(game.world.destroyed_obstacles.has(0) and game.player.stun_left==0,"a target already touching the runner is cut before slowdown at 30 FPS")
	game.reset_runners()
	game.state="race"
	approach(0)
	rival=game.runners[1]
	rival.position=game.player.position+Vector3(4,0,1)
	fill_charge()
	step(.1)
	check(rival.defeated_left==0,"a rival in another lane stays outside sword reach")
	if "--visual" in OS.get_cmdline_user_args():
		game.reset_runners()
		game.state="race"
		game.player.position=Vector3.ZERO
		game.player.target_x=0
		fill_charge()
		game.player.update_visual(0)
		game.update_camera(1)
		game.world.update_view(0,.01)
		game.hud._process(.3)
		await render_frames(4)
		get_viewport().get_texture().get_image().save_png("res://build/charged_sprint_preview.png")
		approach(0)
		step(.1)
		game.player.paper_visual.update_pose()
		await render_frames(4)
		get_viewport().get_texture().get_image().save_png("res://build/charged_slash_preview.png")
		var after := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		game.world.sword_fx.slash.visible=false
		game.world.sword_fx.impact.visible=false
		game.world.sword_fx.trail.visible=false
		await render_frames(4)
		var before := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		check(after-before<=3,"pooled effects add at most three draw calls")
		print("SWORD_RENDER_METRICS ",JSON.stringify({"without_fx":before,"with_fx":after,"delta":after-before}))
	print("SWORD_TESTS %d/%d passed"%[checks-failed,checks])
	game.audio.shutdown()
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)

func render_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
