extends Node
var failed := 0
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed += 1
		push_error("FAIL: " + message)
	else: print("PASS: " + message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	game.set_physics_process(false)
	game.set_process(false)
	var saved: Dictionary = Save.data.duplicate(true)
	check(game.world.grain.get_width()==128 and game.world.grain.get_height()==128,"all ink materials share one small repeatable grain texture")
	var aligned := true
	for i in game.track.roofs.size():
		var roof: Dictionary=game.track.roofs[i]
		var deck: Node3D=game.world.chunks[i].get_child(0)
		var mesh: MeshInstance3D=deck.find_children("*","MeshInstance3D",true,false)[0]
		var span: float=mesh.material_override.get_shader_parameter("platform_span")
		if not is_equal_approx(span+TrackData.BUILDING_BASE,float(roof.height)): aligned=false
	check(aligned,"ink deck surfaces retain the exact collision heights on every route")
	check(game.world.find_children("crate","Node3D",true,false).is_empty() and game.world.find_children("city_block","Node3D",true,false).is_empty(),"modern crates and city towers are absent from the rendered world")
	game.world.burst(Vector3.ZERO,35,"jump")
	game.world.update_view(0,.01)
	check(game.world.sparks_multi.multimesh.visible_instance_count==20,"ink splashes reuse a hard-capped 20-particle pool")
	for particle in game.world.particles: particle.life=0
	var quality: bool=Platform.low_end
	Platform.low_end=true
	game.world.burst(Vector3.ZERO,20,"boost")
	game.world.update_view(0,.01)
	check(game.world.sparks_multi.multimesh.visible_instance_count==0,"low-end mode suppresses ink particles")
	Platform.low_end=quality
	check(game.runners.size() == 7, "player plus six AI")
	check(game.player_rank()==7,"player starts behind all six opponents")
	var first_start: Vector3 = game.player.position
	game.reset_runners()
	check(game.player.position!=first_start and game.player_rank()==7,"starting positions randomize while player stays last")
	check(game.track.sections[2].size()==3,"rooftops split into left, center and right paths")
	check(game.track.sections[5].size()==1,"alternative paths merge back together")
	check(game.track.height_at(-4.5,55)>game.track.height_at(0,0),"platform collision follows authored rooftop elevations")
	check(not game.track.platform_at(3,55),"fork has a real gap between buildings")
	check(game.track.platform_at(0, 0), "start is safe")
	check(not game.track.platform_at(0, 18), "first gap is open")
	check(not game.track.platform_at(10.5, 0), "roof side has a fall edge")
	var parts: Array = game.player.paper_visual.find_children("*", "Sprite3D", true, false)
	check(parts.size() == 12 and parts[0].texture.get_size() == Vector2(1024, 512), "paper hero uses twelve sprites from one texture atlas")
	check(game.player.paper_visual.has_node("PaperPlane/HeadPivot/Hat"), "headwear has its own pivot and follows the head")
	var seen:=0
	for racer in game.runners:
		if not racer.is_player and racer.visible: seen+=1
	check(seen==2,"only two nearby opponents are drawn at the start")
	check(game.runners[3].position.z-game.player.position.z>74,"remaining opponents start beyond the loaded track window")
	for racer in game.runners:
		var roof: Dictionary=game.track.surface_at(racer.position.x,racer.position.z)
		check(not roof.is_empty() and is_equal_approx(float(roof.height),racer.position.y),"spawn matches actual roof elevation for runner %d"%racer.runner_id)
	var rival_skins := []
	var nearby_skins := []
	for runner in game.runners:
		if not runner.is_player:
			rival_skins.append(runner.paper_visual.skin_id)
			if runner.visible:
				nearby_skins.append(runner.paper_visual.skin_id)
	check(nearby_skins.size() == 2 and nearby_skins[0] != nearby_skins[1], "the two nearest rivals draw different outfits")
	check(Save.RIVAL_SKINS.all(func(skin): return rival_skins.count(skin) == 2), "all three outfits appear in each race")
	game.start_race()
	game.state = "race"
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = game.get_viewport().get_visible_rect().size * Vector2(.85, .75)
	down.pressed = true
	game._unhandled_input(down)
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = down.position
	up.pressed = false
	var before_x: float = game.player.target_x
	game._unhandled_input(up)
	check(game.screen_horizontal(game.player.target_x-before_x)>0, "right half tap moves the player toward screen-right")
	check(game.player.target_x in TrackData.LANES,"tap input targets a rooftop lane instead of the gap between routes")
	var original_window_size: Vector2i = game.get_window().size
	for window_size in [Vector2i(540,960),Vector2i(960,540)]:
		game.get_window().size = window_size
		game.adapt_window()
		await get_tree().process_frame
		for screen_direction in [-1.0,1.0]:
			for drag_input in [false,true]:
				game.player.position = Vector3.ZERO
				game.player.target_x = 0
				game.player.grounded = true
				game.update_camera(1.0)
				var before_screen: Vector2 = game.camera.unproject_position(game.player.position)
				var viewport_width: float = game.get_viewport().get_visible_rect().size.x
				down.position = Vector2(viewport_width*(.75 if screen_direction>0 else .25),200)
				game._unhandled_input(down)
				up.position = down.position
				if drag_input:
					var swipe := InputEventScreenDrag.new()
					swipe.index = 0
					swipe.position = down.position+Vector2(screen_direction*viewport_width*.2,0)
					game._unhandled_input(swipe)
					up.position = swipe.position
				game._unhandled_input(up)
				game.player.tick(1.0/60,0)
				var after_screen: Vector2 = game.camera.unproject_position(game.player.position)
				check((after_screen.x-before_screen.x)*screen_direction>0,
					"touch moves in screen direction %s, drag=%s, window=%s"%[screen_direction,drag_input,window_size])
	game.get_window().size = original_window_size
	game.adapt_window()
	await get_tree().process_frame
	game.player.target_x = 0
	game.player.position = Vector3(0, 0, 14.8)
	game.player.tick(1.0 / 60, 0)
	check(not game.player.grounded and game.player.vertical_speed > 0 and game.player.paper_visual.action=="Jump","edge triggers a jump and plays the new hero's jump")
	game.player.position = Vector3(0,0,13)
	game.player.grounded=true
	game.player.remember_safe(game.track.sections[0][0])
	var safe: Vector3 = game.player.safe_position
	game.player.position = Vector3(14, -11, 18)
	game.player.target_x=14
	game.player.grounded=false
	game.player.tick(1.0 / 60, 0)
	check(game.player.position.is_equal_approx(safe), "fall rewinds a few meters onto the immediately preceding roof")
	check(game.state=="race" and game.player.stun_left==0,"recovery does not pause, show ads, or stun the runner")
	var raised: Dictionary=game.track.sections[1][0]
	var near_front := Vector3(raised.x,float(raised.height)-TrackData.MAX_CLIMB_DEPTH,float(raised.start)-.4)
	var beyond_front := near_front + Vector3(0,0,.2)
	check(not game.track.wall_contact(near_front,beyond_front).is_empty(),"front wall at the three-meter climbing boundary is reachable")
	check(game.track.wall_contact(near_front-Vector3(0,.01,0),beyond_front-Vector3(0,.01,0)).is_empty(),
		"front wall just below the climbing boundary is rejected")
	game.player.position=Vector3(raised.x,float(raised.height)-TrackData.MAX_CLIMB_DEPTH-.2,float(raised.start)-.4)
	game.player.target_x=float(raised.x)
	game.player.grounded=false
	game.player.wall_cooldown=0
	game.player.vertical_speed=0
	game.player.tick(1.0/60,0)
	check(game.player.traversal=="run" and not game.player.grounded,"front wall below the reachable top band does not start a long climb")
	game.player.position=Vector3(raised.x,.2,float(raised.start)-.4)
	game.player.target_x=float(raised.x)
	game.player.grounded=false
	game.player.wall_cooldown=0
	game.player.tick(1.0/60,0)
	check(game.player.traversal=="climb" and game.player.paper_visual.action=="Climb","contact with a higher building front plays the new hero's climb")
	var climb_steps := 0
	for step in 60:
		game.player.tick(1.0/60,0)
		climb_steps+=1
		if game.player.grounded: break
	check(game.player.grounded and is_equal_approx(game.player.position.y,float(raised.height)),"climbing pulls the runner safely onto the actual roof height")
	check(climb_steps<=43,"near-top climbing finishes within roughly 0.72 seconds")
	var left: float=float(raised.x)-float(raised.width)*.5
	game.player.position=Vector3(left-.3,float(raised.height)-1.8,float(raised.start)+8)
	game.player.target_x=left-.25
	game.player.grounded=false
	game.player.wall_cooldown=0
	game.player.tick(1.0/60,0)
	check(game.player.traversal=="side_slide" and game.player.paper_visual.action=="SideSlide","side wall contact plays the new hero's slide")
	var slide_start: Vector3=game.player.position
	game.player.tick(.2,0)
	check(game.player.position.z>slide_start.z and game.player.position.y<slide_start.y,"side slide advances along the wall with a controlled descent")
	var pad: Dictionary = game.track.boosts[0]
	game.player.respawn()
	game.player.position = Vector3(pad.x, pad.y, pad.z)
	game.player.tick(1.0 / 60, 0)
	check(game.player.boost_left > 0 and game.player.flip_time > 0 and game.player.paper_visual.action=="Flip", "pad triggers speed boost and the new hero's somersault")
	var boost_count: int = game.player.boost_count
	game.player.tick(1.0 / 60, 0)
	check(game.player.boost_count == boost_count, "a boost pad grants once per runner")
	for transfer in [[2, 0], [2, 2], [3, 0]]:
		game.reset_runners()
		var player: RoofRunner = game.player
		var source: Dictionary = game.track.sections[transfer[0]][1]
		var destination: Dictionary = game.track.sections[transfer[0]][transfer[1]]
		player.position = Vector3(source.x, source.height, float(source.start) + 3.0)
		player.target_x = player.position.x
		down.position = game.get_viewport().get_visible_rect().size * Vector2(.85, .75)
		game._unhandled_input(down)
		up.position = down.position
		if transfer[1] == 2:
			var drag := InputEventScreenDrag.new()
			drag.index = 0
			drag.position = down.position - Vector2(game.get_viewport().get_visible_rect().size.x * .15, 0)
			game._unhandled_input(drag)
			up.position = drag.position
		game._unhandled_input(up)
		player.tick(1.0 / 60, 0)
		check(not player.grounded and player.vertical_speed > 0, "lateral input launches a hop on branch %s" % [transfer])
		for step in 90:
			player.tick(1.0 / 60, 0)
			if player.grounded or player.traversal != "run": break
		check(player.grounded and player.safe_roof_id == int(destination.id) and player.falls == 0,
			"lateral hop lands on the adjacent roof on branch %s" % [transfer])
	game.reset_runners()
	var outer: Dictionary = game.track.sections[2][0]
	game.player.position = Vector3(float(outer.x) - float(outer.width) * .5 + .1, outer.height, float(outer.start) + 3.0)
	game.player.target_x = -10
	for step in 3:
		game.player.tick(1.0 / 60, 0)
	check(not game.player.grounded and game.player.vertical_speed < 0, "steering off an outer edge without a neighbouring roof still falls")
	game.race_rng.seed=55213
	game.start_race()
	game.state = "race"
	game.player.ai_skill = .97
	var max_falls := 0
	var max_visible := 0
	for tick in 8400:
		game.player.update_ai(1.0 / 60)
		game._physics_process(1.0 / 60)
		var visible_count:=0
		for rival in game.runners:
			if not rival.is_player and rival.visible: visible_count+=1
		max_visible=maxi(max_visible,visible_count)
		if game.state == "result": break
	check(game.state == "result", "complete first level within 140 simulated seconds")
	check(game.finish_reveal==0,"crossing the finish starts a rolled-up scroll")
	game._process(.7)
	check(game.finish_reveal==1,"finish scroll opens before result controls are shown")
	if game.state!="result": print("STUCK ",game.player.position," ",game.player.traversal," falls ",game.player.falls," safe ",game.player.safe_position)
	check(game.elapsed >= 55 and game.elapsed <= 120, "sprint-assisted race stays around one to two minutes")
	check(game.final_rank >= 1 and game.final_rank <= 7, "final ranking has a valid place")
	check(game.player.collected > 0 and game.reward > 0, "collect coins and bank completion reward")
	for runner in game.runners: max_falls = maxi(max_falls, runner.falls)
	check(max_falls <= 3, "AI follows elevated branching routes reliably")
	check(max_visible<=2,"no more than two opponents are rendered throughout the race")
	print("RACE_METRICS ", JSON.stringify({"seconds": game.elapsed, "rank": game.final_rank, "coins": game.player.collected, "boosts": game.player.boost_count, "max_falls": max_falls}))
	Save.data.coins = 1000
	check(Save.buy_skin(3) and 3 in Save.data.owned and Save.data.skin == 3, "skin purchase unlocks and equips")
	var balance: int = Save.data.coins
	Save.buy_skin(3)
	check(Save.data.coins == balance, "equipping owned skin does not charge twice")
	Save.data.owned.erase(Save.STREET_SKIN)
	Save.data.coins = 79
	check(not Save.buy_skin(Save.STREET_SKIN) and Save.data.coins == 79, "street outfit requires 80 coins")
	Save.data.coins = 80
	var rival_skin: int = game.runners[1].paper_visual.skin_id
	game.ui_action("skin", Save.STREET_SKIN)
	var player_atlas: Texture2D = game.player.paper_visual.torso.texture
	check(Save.data.coins == 0 and Save.STREET_SKIN in Save.data.owned and player_atlas.resource_path.ends_with("paper_runner_street.png"), "the shop buys and equips the street outfit")
	check(game.runners[1].paper_visual.skin_id == rival_skin, "equipping a player outfit leaves the rival's race outfit in place")
	Save.data.owned.erase(Save.FELINE_SKIN)
	Save.data.coins = 159
	check(not Save.buy_skin(Save.FELINE_SKIN), "feline outfit requires 160 coins")
	Save.data.coins = 160
	game.ui_action("skin", Save.FELINE_SKIN)
	player_atlas = game.player.paper_visual.back_accessory.texture
	check(Save.data.coins == 0 and player_atlas.resource_path.ends_with("paper_runner_feline.png"), "shop equips the new outfit and its back accessory")
	balance = Save.data.coins
	var serialized := JSON.stringify(Save.data)
	Save.data.coins = 0
	Save.data.skin = 0
	Save.data.owned = [0]
	Save.load_json(serialized)
	check(Save.data.coins == balance and Save.data.skin == Save.FELINE_SKIN and Save.STREET_SKIN in Save.data.owned and Save.FELINE_SKIN in Save.data.owned and 3 in Save.data.owned, "save round-trip preserves outfits and existing skin IDs")
	Save.data.daily.races = 3
	Save.data.daily.claimed = []
	check(Save.claim_task(0) and not Save.claim_task(0), "daily rewards cannot be claimed twice")
	game.doubled = false
	balance = Save.data.coins
	game.ad_context = "double"
	game._ad_finished(false)
	check(Save.data.coins == balance, "failed or absent advertisement grants no reward")
	game._ad_finished(true)
	game._ad_finished(true)
	check(Save.data.coins == balance + game.reward, "ad reward remains idempotent")
	game.state = "race"
	game._pause_on_hide()
	check(game.state == "paused", "backgrounding pauses the race")
	Save.data = saved
	Save.persist()
	print("GAME_TESTS %d/%d passed" % [checks - failed, checks])
	game.audio.shutdown()
	await get_tree().process_frame
	await get_tree().process_frame
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
