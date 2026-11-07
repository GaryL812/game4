class_name SkylineHUD
extends Control

const INK := Color("293d34")
const MUTED := Color("7e826e")
const LIME := Color("aa4939")
const PAPER := Color("f2ead4")
const PaperRunner = preload("res://scripts/paper_runner.gd")
const SCROLL_TEXTURE = preload("res://assets/ui/progress_scroll_clean.png")
const SCROLL_SHADER = preload("res://scripts/progress_scroll.gdshader")
const ENERGY_TEXTURE = preload("res://assets/ui/energy_bar.png")
const ENERGY_SHADER = preload("res://scripts/energy_bar.gdshader")
var game
var font: Font
var bold: Font
var buttons: Array[Dictionary] = []
var toast := ""
var toast_left := 0.0
var pulse := 0.0
var styles: Dictionary = {}
var wind_time := 0.0
var wind_strength := 0.0
var progress_scroll: Control
var scroll_paper: TextureRect
var scroll_left: TextureRect
var scroll_right: TextureRect
var scroll_marker: Polygon2D
var scroll_roller_motion: Node2D
var scroll_display_progress := 0.0
var energy_bar: Control
var energy_back: TextureRect
var energy_fill: TextureRect
var energy_material: ShaderMaterial
var energy_display := 0.0

func setup(owner_game) -> void:
	game = owner_game
	font = load("res://assets/fonts/ink.ttf")
	bold = load("res://assets/fonts/ink_bold.ttf")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	setup_progress_scroll()
	setup_energy_bar()

func setup_energy_bar() -> void:
	energy_bar = Control.new()
	energy_bar.name = "EnergyBar"
	energy_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	energy_bar.show_behind_parent = true
	add_child(energy_bar)
	energy_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	energy_back = TextureRect.new()
	energy_back.name = "EmptyInk"
	energy_back.texture = ENERGY_TEXTURE
	energy_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	energy_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var empty_ink := ShaderMaterial.new()
	empty_ink.shader = ENERGY_SHADER
	empty_ink.set_shader_parameter("opacity",.12)
	energy_back.material = empty_ink
	energy_bar.add_child(energy_back)
	energy_fill = TextureRect.new()
	energy_fill.name = "RisingInk"
	energy_fill.texture = ENERGY_TEXTURE
	energy_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	energy_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	energy_material = ShaderMaterial.new()
	energy_material.shader = ENERGY_SHADER
	energy_fill.material = energy_material
	energy_bar.add_child(energy_fill)
	energy_bar.visible = false

func reset_energy_bar() -> void:
	energy_display = 0.0

func update_energy_bar(dt: float) -> void:
	energy_bar.visible = game.state in ["countdown","race","paused"]
	if not energy_bar.visible: return
	var active: bool = game.player.charge_left>0
	var ratio: float = game.player.charge_left/RoofRunner.CHARGE_DURATION if active else float(game.player.charge_coins)/RoofRunner.CHARGE_COINS
	if game.state!="paused":
		energy_display = lerpf(energy_display,clampf(ratio,0,1),1.0-exp(-dt*12))
		if absf(energy_display-ratio)<.00001: energy_display=ratio
	var height := clampf(size.y*.43,180,300)
	var bottom := size.y*.18
	energy_bar.offset_left = -58
	energy_bar.offset_right = -24
	energy_bar.offset_top = -bottom-height
	energy_bar.offset_bottom = -bottom
	energy_back.size = Vector2(34,height)
	energy_fill.size = energy_back.size
	energy_fill.pivot_offset = Vector2(17,height)
	energy_fill.scale.y = energy_display
	energy_fill.visible = energy_display>.00001
	energy_material.set_shader_parameter("density",1.55 if active else 1.0)
	energy_material.set_shader_parameter("opacity",1.0 if active else .72)

func scroll_piece(piece_name: String, region: Vector4, roller: bool) -> TextureRect:
	var piece := TextureRect.new()
	piece.name = piece_name
	piece.texture = SCROLL_TEXTURE
	piece.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ink := ShaderMaterial.new()
	ink.shader = SCROLL_SHADER
	ink.set_shader_parameter("source_region",region)
	ink.set_shader_parameter("wooden_roller",roller)
	piece.material = ink
	progress_scroll.add_child(piece)
	return piece

func setup_progress_scroll() -> void:
	progress_scroll = Control.new()
	progress_scroll.name = "ProgressScroll"
	progress_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_scroll.show_behind_parent = true
	add_child(progress_scroll)
	progress_scroll.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	progress_scroll.offset_left = 140
	progress_scroll.offset_right = -90
	progress_scroll.offset_top = 12
	progress_scroll.offset_bottom = 94
	scroll_paper = scroll_piece("Paper",Vector4(.124,0,.769,1),false)
	scroll_paper.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	# Reuse and mirror the new dark wooden cylinder for the traveling roller.
	scroll_left = scroll_piece("MovingRoller",Vector4(.970,0,-.084,1),true)
	scroll_roller_motion = Node2D.new()
	scroll_roller_motion.name = "RollerMotion"
	progress_scroll.add_child(scroll_roller_motion)
	scroll_left.reparent(scroll_roller_motion)
	scroll_right = scroll_piece("FixedRoller",Vector4(.886,0,.084,1),true)
	scroll_marker = Polygon2D.new()
	scroll_marker.name = "InkMarker"
	scroll_marker.polygon = PackedVector2Array([
		Vector2(-3,-1),Vector2(-2,-3),Vector2(1,-3.5),Vector2(3,-1),
		Vector2(3.5,1),Vector2(1.5,3),Vector2(-1,3.5),Vector2(-3,1)])
	scroll_marker.color = INK
	progress_scroll.add_child(scroll_marker)
	progress_scroll.visible = false

func reset_progress_scroll() -> void:
	scroll_display_progress = 0.0

func update_progress_scroll(dt: float = 0.0) -> void:
	progress_scroll.visible = game.state in ["countdown","race","paused"]
	if not progress_scroll.visible: return
	var progress := clampf(game.player.position.z/TrackData.FINISH,0,1)
	if game.state == "countdown":
		scroll_display_progress = 0.0
	elif game.state != "paused":
		# Render-frame smoothing follows physics updates and also eases rewinds.
		scroll_display_progress = lerpf(scroll_display_progress,progress,1.0-exp(-dt*12.0))
		if absf(scroll_display_progress-progress)<.00001:
			scroll_display_progress=progress
	var remaining := 1.0-scroll_display_progress
	var height := progress_scroll.size.y
	var roller_width := clampf(progress_scroll.size.x*.065,27,34)
	var paper_width := maxf(1,progress_scroll.size.x-roller_width)
	var paper_right := progress_scroll.size.x-roller_width*.48
	scroll_paper.size = Vector2(paper_width,height)
	scroll_paper.position = Vector2(paper_right-paper_width,0)
	scroll_paper.pivot_offset = Vector2(paper_width,height*.5)
	scroll_paper.scale.x = remaining
	scroll_paper.visible = remaining>.00001
	scroll_right.size = Vector2(roller_width,height)
	scroll_right.position = Vector2(progress_scroll.size.x-roller_width,0)
	scroll_right.pivot_offset = Vector2(roller_width*.5,height*.5)
	scroll_right.rotation = -.12
	scroll_left.size = Vector2(roller_width,height)
	scroll_left.pivot_offset = Vector2(roller_width*.5,height*.5)
	scroll_left.rotation = .10
	# Node2D keeps the traveling roller at subpixel positions, independent of UI layout rounding.
	scroll_roller_motion.position = Vector2(paper_right-paper_width*remaining-roller_width*.52,0)
	scroll_left.position = Vector2.ZERO
	scroll_left.visible = remaining>.00001
	scroll_left.modulate.a = clampf(remaining/.025,0,1)
	scroll_marker.position = Vector2(paper_right-paper_width*remaining+minf(12,paper_width*remaining*.5),height*.51)
	scroll_marker.visible = remaining>.00001
	scroll_marker.modulate.a = clampf(remaining/.025,0,1)

func _process(dt: float) -> void:
	pulse += dt
	toast_left = maxf(0, toast_left - dt)
	if game != null and is_instance_valid(game.player):
		update_progress_scroll(dt)
		update_energy_bar(dt)
	if game != null and game.state != "paused":
		var sprinting: bool = game.state=="race" and (game.player.charge_left>0 or game.player.boost_left>0 or game.player.slash_boost_left>0)
		wind_strength=move_toward(wind_strength,1.0 if sprinting else 0.0,dt*5)
		if sprinting: wind_time+=dt
	queue_redraw()

func say(message: String) -> void:
	toast = message
	toast_left = 3.0

func card(rect: Rect2, color: Color, radius: float = 20, border: Color = Color.TRANSPARENT) -> void:
	var key := color.to_html() + str(int(radius)) + border.to_html()
	if not styles.has(key):
		var created := StyleBoxFlat.new()
		created.bg_color = color
		# Square paper panels need no rounded-corner tessellation or AA skirt.
		created.set_corner_radius_all(0)
		created.anti_aliasing=false
		if border.a > 0:
			created.border_color = border
			created.set_border_width_all(1)
		styles[key] = created
	var style: StyleBoxFlat = styles[key]
	draw_style_box(style, rect)

func txt(value: String, pos: Vector2, size_value: int = 20, color: Color = INK) -> void:
	draw_string(bold if size_value >= 30 else font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value, color)

func center(value: String, x: float, y: float, size_value: int, color: Color = INK) -> void:
	var width := (bold if size_value >= 30 else font).get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value).x
	txt(value, Vector2(x - width * .5, y), size_value, color)

func button(rect: Rect2, label: String, action: String, primary := false, extra: int = -1) -> void:
	card(Rect2(rect.position + Vector2(2, 2), rect.size), Color("465447"), 17)
	card(rect, LIME if primary else PAPER, 17)
	center(label, rect.get_center().x, rect.get_center().y + 8, 20, PAPER if primary else INK)
	buttons.append({"rect": rect, "action": action, "extra": extra})

func coin_pill(x: float, y: float, value: int) -> void:
	card(Rect2(x, y, 108, 40), PAPER, 20)
	draw_circle(Vector2(x + 22, y + 20), 10, Color("bda369"))
	center("文", x + 22, y + 25, 12, INK)
	txt(str(value), Vector2(x + 41, y + 27), 18)

func _draw() -> void:
	if game == null or font == null: return
	buttons.clear()
	var w := size.x
	var h := size.y
	var wide := w > h
	match game.state:
		"menu": draw_home(w, h, wide)
		"countdown", "race", "paused": draw_race(w, h)
		"result": draw_result(w, h)
		"shop": draw_shop(w, h)
		"daily": draw_daily(w, h)
		"leaderboard": draw_board(w, h)
	if game.state == "paused":
		draw_rect(Rect2(Vector2.ZERO, size), Color(.14, .19, .15, .52))
		var x := w * .5
		card(Rect2(x - 180, h * .5 - 140, 360, 280), PAPER, 28)
		center("歇一口气", x, h * .5 - 80, 32)
		center("屋顶在等你，继续向前", x, h * .5 - 43, 16, MUTED)
		button(Rect2(x - 150, h * .5 - 12, 300, 56), "继续奔跑  →", "resume", true)
		button(Rect2(x - 150, h * .5 + 62, 300, 48), "返回主页", "home")
	if toast_left > 0 and game.state not in ["countdown", "race", "paused"]:
		var tw := minf(w - 32, 470)
		card(Rect2((w - tw) * .5, h - 104, tw, 48), INK, 16)
		center(toast, w * .5, h - 73, 16, PAPER)

func stamp(rect: Rect2, words: String="踏云通关") -> void:
	draw_rect(rect,LIME,false,2)
	draw_rect(rect.grow(-4),LIME,false,1)
	center(words.substr(0,2),rect.get_center().x,rect.position.y+22,16,LIME)
	center(words.substr(2,2),rect.get_center().x,rect.position.y+43,16,LIME)

func draw_home(w: float, h: float, wide: bool) -> void:
	var margin := 28.0
	stamp(Rect2(182,94,48,53),"踏云而行")
	for line in 300:
		draw_line(Vector2(0, line), Vector2(w, line), Color(.96, .94, .87, .55 * (1.0 - float(line) / 300)), 1)
	card(Rect2(margin, 26, 134, 30), INK, 15)
	center("山海卷  /  壹", margin + 67, 47, 12, PAPER)
	coin_pill(w - 136, 23, int(Save.data.coins))
	button(Rect2(w - 193, 23, 42, 40), "静" if game.audio.muted else "♪", "sound")
	txt("云端", Vector2(margin - 2, 124), 57)
	txt("飞奔", Vector2(margin - 2, 182), 57)
	txt("山水之间，自在踏云", Vector2(margin + 2, 224), 19)
	txt("一笔入山海  ·  三路竞烟岚", Vector2(margin + 3, 249), 14, MUTED)
	var cw := minf(484, w - 56)
	var y := h - 302 if not wide else 274.0
	if wide: cw = minf(400, w * .48)
	card(Rect2(margin, y, cw, 106), Color(.95, .92, .83, .95), 22)
	txt("01", Vector2(margin + 18, y + 45), 30)
	txt("云栈烟岚", Vector2(margin + 78, y + 35), 21)
	txt("7人追逐   /   高低分叉   /   自动攀爬", Vector2(margin + 79, y + 62), 13, MUTED)
	for i in 3: draw_circle(Vector2(margin + 83 + i * 13, y + 83), 3, INK if i == 0 else Color("c9c6af"))
	button(Rect2(margin, y + 124, cw, 60), "开始飞奔     →", "start", true)
	if not wide:
		var bw := (cw - 20) / 3
		button(Rect2(margin, y + 204, bw, 48), "衣橱", "shop")
		button(Rect2(margin + bw + 10, y + 204, bw, 48), "每日挑战", "daily")
		button(Rect2(margin + 2 * (bw + 10), y + 204, bw, 48), "排行榜", "board")
		center("左右滑动或点按 · 跳跃交给我们", w * .5, h - 20, 13, MUTED)
	else:
		button(Rect2(w - 180, 84, 150, 44), "衣橱", "shop")
		button(Rect2(w - 180, 144, 150, 44), "每日挑战", "daily")
		button(Rect2(w - 180, 204, 150, 44), "排行榜", "board")

func draw_speed_wind(w: float, h: float) -> void:
	var vanishing_point := Vector2(w*.5,h*.32)
	for side in [-1.0,1.0]:
		for i in 7:
			var phase := fposmod(wind_time*1.8+float(i)*.173,1.0)
			var end := Vector2(w*(.5+side*(.32+phase*.28)),h*(.17+float(i)*.12))
			var start := end.lerp(vanishing_point,.10+.06*phase)
			var opacity := sin(phase*PI)*wind_strength*.4
			draw_line(start,end,Color(.80,.80,.72,opacity*.4),4.0)
			draw_line(start,end,Color(.30,.32,.28,opacity),1.5)

func draw_race(w: float, h: float) -> void:
	if wind_strength>0: draw_speed_wind(w,h)
	var player = game.player
	card(Rect2(22, 26, 104, 92), INK, 20)
	txt("名次", Vector2(40, 51), 12, PAPER)
	txt("%02d" % game.player_rank(), Vector2(38, 97), 39, PAPER)
	txt("/ 7", Vector2(91, 95), 13, Color("b9b5a0"))
	button(Rect2(w - 72, 28, 50, 50), "Ⅱ", "pause")
	txt("%02d:%02d" % [int(game.elapsed) / 60, int(game.elapsed) % 60], Vector2(145, 113), 17)
	coin_pill(w - 133, 98, player.collected)
	# A compact field of seven progress markers.
	var bar_y := 143.0
	for racer in game.runners:
		var x := 28 + clampf(racer.position.z / TrackData.FINISH, 0, 1) * (w - 56)
		draw_circle(Vector2(x, bar_y), 5 if racer.is_player else 3, LIME if racer.is_player else Color("768477"))
	if game.state == "countdown":
		var text_value := str(maxi(1, ceili(game.countdown)))
		center(text_value, w * .5, h * .43, 100, PAPER)

func panel_header(w: float, title_value: String, eyebrow: String) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(.94, .91, .82, .97))
	button(Rect2(26, 28, 64, 44), "←", "home")
	coin_pill(w - 136, 30, int(Save.data.coins))
	txt(eyebrow, Vector2(28, 118), 13, MUTED)
	txt(title_value, Vector2(26, 165), 36)

func draw_shop(w: float, h: float) -> void:
	panel_header(w, "换个心情，再出发", "衣冠  /  浪客行装")
	var cols := 2 if w < 700 else 5
	var skin_ids := Save.RIVAL_SKINS.duplicate()
	for i in range(1, Save.STREET_SKIN):
		skin_ids.append(i)
	var cw := (w - 56 - (cols - 1) * 14) / cols
	var ch := minf(157, (h - 224) / ceilf(float(skin_ids.size()) / cols) - 12)
	for slot in skin_ids.size():
		var i: int = skin_ids[slot]
		var x := 28 + (slot % cols) * (cw + 14)
		var y := 194 + floorf(float(slot) / cols) * (ch + 12)
		card(Rect2(x, y, cw, ch), PAPER, 20, INK if int(Save.data.skin) == i else Color.TRANSPARENT)
		var outfit := PaperRunner.outfit_atlas(i)
		if outfit:
			draw_texture_rect_region(outfit, Rect2(x + 12, y + 8, 36, 49), Rect2(345, 65, 78, 113))
		else:
			draw_circle(Vector2(x + 30, y + 32), 13, Color(Save.COLORS[i]))
		txt(Save.NAMES[i], Vector2(x + 52, y + 39), 17)
		var label := "使用中" if int(Save.data.skin) == i else ("穿上" if i in Save.data.owned else "%d 金币解锁" % Save.skin_cost(i))
		button(Rect2(x + 12, y + ch - 61, cw - 24, 43), label, "skin", int(Save.data.skin) == i, i)

func draw_daily(w: float, h: float) -> void:
	Save.ensure_day()
	panel_header(w, "每天，都有小目标", "今日修习 / " + str(Save.data.day))
	var labels := ["完成 3 场屋顶竞速", "在赛道收集 30 枚金币", "踩中 5 次加速跳板"]
	var keys := ["races", "coins", "boosts"]
	var goals := [3, 30, 5]
	for i in 3:
		if w > h:
			var cw := (w - 84) / 3
			var x := 28 + i * (cw + 14)
			card(Rect2(x, 214, cw, 220), PAPER, 22)
			txt("0%d" % (i+1), Vector2(x+20, 254), 30)
			txt(labels[i], Vector2(x+20, 300), 17)
			var count := mini(int(Save.data.daily.get(keys[i], 0)), goals[i])
			txt("%d / %d   ·   +%d 金币" % [count, goals[i], [100,80,60][i]], Vector2(x+20, 336), 15, MUTED)
			button(Rect2(x+20, 367, cw-40, 46), "已领取" if i in Save.data.daily.claimed else "领取奖励", "claim", count == goals[i], i)
			continue
		var y := 204 + i * minf(170, (h - 250) / 3)
		card(Rect2(28, y, w - 56, 142), PAPER, 22)
		txt(labels[i], Vector2(48, y + 37), 20)
		var count := mini(int(Save.data.daily.get(keys[i], 0)), goals[i])
		txt("%d / %d   ·   奖励 %d 金币" % [count, goals[i], [100,80,60][i]], Vector2(48, y + 67), 14, MUTED)
		button(Rect2(w - 174, y + 83, 126, 42), "已领取" if i in Save.data.daily.claimed else "领取奖励", "claim", count == goals[i], i)
		card(Rect2(48, y + 101, w - 244, 8), Color("dad6bf"), 4)
		card(Rect2(48, y + 101, maxf(8, (w - 244) * float(count) / goals[i]), 8), INK, 4)

func draw_board(w: float, h: float) -> void:
	panel_header(w, "每一次，超越自己", "行迹  /  本机纪录")
	button(Rect2(28, 189, w - 56, 49), "查看微信好友排行", "friends", true)
	if Save.data.records.is_empty(): center("还没有纪录，去完成第一场吧", w * .5, 320, 18, MUTED)
	for i in mini(mini(8, maxi(0, int((h-264) / 66))), Save.data.records.size()):
		var record: Dictionary = Save.data.records[i]
		var y := 264 + i * 66
		card(Rect2(28, y, w - 56, 56), PAPER, 14)
		txt("%02d" % (i+1), Vector2(46, y+36), 23)
		txt("%.2f 秒" % float(record.time), Vector2(110, y+35), 21)
		txt("第%d名" % int(record.rank), Vector2(w - 113, y+34), 17, MUTED)

func draw_result(w: float, h: float) -> void:
	if game.finish_reveal<1:
		var width := minf(440,w-48)
		var height := minf(638,h-60)*sin(game.finish_reveal*PI*.5)
		var rect := Rect2((w-width)*.5,(h-height)*.5,width,height)
		draw_rect(Rect2(Vector2.ZERO,size),Color(.14,.19,.15,.35))
		card(rect,PAPER,0)
		card(Rect2(rect.position.x-8,rect.position.y-5,width+16,10),INK,2)
		card(Rect2(rect.position.x-8,rect.end.y-5,width+16,10),INK,2)
		if height>120: stamp(Rect2(w*.5-26,h*.5-28,52,56))
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(.14, .19, .15, .52))
	if w > h:
		var panel_w := minf(850, w - 48)
		var left := (w - panel_w) * .5
		card(Rect2(left, 30, panel_w, h-60), PAPER, 28)
		center("山海已越  ·  此卷告成", left+panel_w*.26, 86, 14, MUTED)
		stamp(Rect2(left+panel_w*.38,118,52,56))
		center("%02d" % game.final_rank, left+panel_w*.26, 193, 90)
		center("第 %d 名 / 7" % game.final_rank, left+panel_w*.26, 236, 24)
		center("%.2f 秒" % game.elapsed, left+panel_w*.26, 294, 25)
		center("本局获得 +%d 金币" % game.reward, left+panel_w*.26, 344, 22)
		var x := left + panel_w*.53
		var bw := panel_w*.43
		button(Rect2(x, 102, bw, 58), "再来一局 →", "start", true)
		button(Rect2(x, 184, bw, 50), "双倍奖励已领取" if game.doubled else "观看视频 · 双倍金币", "double")
		button(Rect2(x, 258, bw, 50), "分享战绩", "share")
		button(Rect2(x, 332, bw, 50), "返回主页", "home")
		return
	var cx := w * .5
	var pw := minf(440, w - 48)
	var ph := minf(638, h - 40)
	var top := (h - ph) * .5
	card(Rect2(cx - pw * .5, top, pw, ph), PAPER, 30)
	center("山海已越  ·  此卷告成", cx, top + 42, 13, MUTED)
	stamp(Rect2(cx+pw*.5-85,top+70,52,56))
	center("%02d" % game.final_rank, cx, top + 135, 85)
	center("第 %d 名 / 7" % game.final_rank, cx, top + 170, 21)
	center("漂亮的飞跃！" if game.final_rank <= 3 else "下一次，再快一点。", cx, top + 211, 26)
	center("%.2f 秒     ·     拾取 %d 金币" % [game.elapsed, game.player.collected], cx, top + 250, 17, MUTED)
	card(Rect2(cx - pw*.5 + 24, top + 275, pw - 48, 71), Color("e3dcc2"), 18)
	center("本局获得    + %d 金币" % game.reward, cx, top + 320, 24)
	var y := top + 367
	button(Rect2(cx - pw*.5 + 24, y, pw - 48, 56), "再来一局     →", "start", true)
	button(Rect2(cx - pw*.5 + 24, y + 72, pw - 48, 48), "观看视频 · 双倍金币" if not game.doubled else "双倍奖励已领取", "double")
	button(Rect2(cx - pw*.5 + 24, y + 135, (pw - 60)*.5, 48), "返回主页", "home")
	button(Rect2(cx + 6, y + 135, (pw - 60)*.5, 48), "分享战绩", "share")
	if ph > 610: center("每一步，都离天际更近。", cx, top + ph - 28, 14, MUTED)

func _input(event: InputEvent) -> void:
	if game.benchmark: return
	if not (event is InputEventScreenTouch) or not event.pressed: return
	for entry in buttons:
		if entry.rect.has_point(event.position):
			game.ui_action(entry.action, entry.extra)
			get_viewport().set_input_as_handled()
			return
	if game.state not in ["race", "countdown"]: get_viewport().set_input_as_handled()
