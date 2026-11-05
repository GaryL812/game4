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
	check(game.runners.size() == 7, "player plus six AI")
	check(game.track.platform_at(0, 0), "start is safe")
	check(not game.track.platform_at(0, 18), "first gap is open")
	check(not game.track.platform_at(8, 0), "roof side has a fall edge")
	for runner in game.runners:
		check(runner.animation != null and runner.animation.get_animation_list().size() >= 6, "six imported Blender animations: runner %d" % runner.runner_id)
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
	check(game.player.target_x > before_x, "right half tap moves the player right")
	game.player.target_x = 0
	game.player.position = Vector3(0, 0, 14.8)
	game.player.tick(1.0 / 60, 0)
	check(not game.player.grounded and game.player.vertical_speed > 0, "edge automatically triggers a jump")
	game.player.position = Vector3(0, -8, 200)
	game.player.checkpoint = 165
	game.player.tick(1.0 / 60, 0)
	check(is_equal_approx(game.player.position.z, 165), "fall returns to saved checkpoint")
	var pad: Dictionary = game.track.boosts[0]
	game.player.respawn()
	game.player.position = Vector3(pad.x, 0, pad.z)
	game.player.tick(1.0 / 60, 0)
	check(game.player.boost_left > 0 and game.player.flip_time > 0, "pad triggers speed boost and somersault")
	var boost_count: int = game.player.boost_count
	game.player.tick(1.0 / 60, 0)
	check(game.player.boost_count == boost_count, "a boost pad grants once per runner")
	game.start_race()
	game.state = "race"
	game.player.ai_skill = .97
	var max_falls := 0
	for tick in 8400:
		game.player.update_ai(1.0 / 60)
		game._physics_process(1.0 / 60)
		if game.state == "result": break
	check(game.state == "result", "complete first level within 140 simulated seconds")
	check(game.elapsed >= 60 and game.elapsed <= 120, "race length is one to two minutes")
	check(game.final_rank >= 1 and game.final_rank <= 7, "final ranking has a valid place")
	check(game.player.collected > 0 and game.reward > 0, "collect coins and bank completion reward")
	for runner in game.runners: max_falls = maxi(max_falls, runner.falls)
	check(max_falls <= 2, "AI automatic jumps traverse the course reliably")
	print("RACE_METRICS ", JSON.stringify({"seconds": game.elapsed, "rank": game.final_rank, "coins": game.player.collected, "boosts": game.player.boost_count, "max_falls": max_falls}))
	Save.data.coins = 1000
	check(Save.buy_skin(3) and 3 in Save.data.owned and Save.data.skin == 3, "skin purchase unlocks and equips")
	var balance: int = Save.data.coins
	Save.buy_skin(3)
	check(Save.data.coins == balance, "equipping owned skin does not charge twice")
	var serialized := JSON.stringify(Save.data)
	Save.data.coins = 0
	Save.data.skin = 0
	Save.data.owned = [0]
	Save.load_json(serialized)
	check(Save.data.coins == balance and Save.data.skin == 3 and 3 in Save.data.owned, "save round-trip preserves JSON numbers and unlocked skins")
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
