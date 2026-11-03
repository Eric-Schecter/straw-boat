extends Node2D

const ToyUI = preload("res://scripts/toy_ui.gd")
const Art = preload("res://scripts/boat_art.gd")
var river_material: ShaderMaterial
var draw_usec := 0
var boat_texture: ViewportTexture

var VIEW := Vector2(1280,720)
var C := Vector2(674,380)
const BOAT_SCALE := 1.0
var LAUNCH_X := 245.0
const FLIGHT_SCALE := 1.0
var PAUSE_POS := Vector2(1210,50)
var river: ColorRect
var hud_target := Vector2(640,54)
var panel_center := Vector2(640,390)
const INK := Color("142d36")
const PAPER := Color("5d607f")
const UI_ACCENT := Color("825824")
const GOLD := Color("e8bb65")
var rewards: Node2D
var combo := 0
var best_combo := 0
var reward_score := 0
var win_delay := 0.0
var rating := 0
var medals: Array[int] = [0,0,0,0,0,0]
var new_medal := false
var font: Font
var phase := "play"
var heading := 0.0
var time := 0.0
var game_time := 0.0
var spawn_timer := 1.8
const LESSONS = [
	{"name":"First Breeze", "volleys":8, "goal":8, "speed":160.0, "burst":2, "gap":0.90, "rest":3.2, "prepare":4.0, "hint":"Ready to catch. Release and let the arrows come."},
	{"name":"Steady Sailing", "volleys":7, "goal":12, "speed":190.0, "burst":3, "gap":0.75, "rest":3.0, "prepare":3.5, "hint":"Turn gently to face an empty bale toward the arrows."},
	{"name":"One Full Side", "volleys":9, "goal":18, "speed":220.0, "burst":3, "gap":0.65, "rest":2.8, "prepare":3.5, "hint":"Four gold dots mean a bale is full."},
	{"name":"Turn the Tide", "volleys":9, "goal":26, "speed":250.0, "burst":4, "gap":0.55, "rest":3.5, "prepare":3.5, "hint":"Turn between volleys to use the other side."},
	{"name":"Arrow Shower", "volleys":8, "goal":32, "speed":285.0, "burst":5, "gap":0.45, "rest":3.0, "prepare":3.0, "hint":"More arrows incoming. Keep an empty bale ready."},
	{"name":"Homeward Bound", "volleys":7, "goal":36, "speed":320.0, "burst":6, "gap":0.35, "rest":2.8, "prepare":3.0, "hint":"Steady, catch, turn. Bring the arrows home!"}
]
var shot_rng = RandomNumberGenerator.new()
var level := 1
var fired := 0
var input_armed := true
var damage_cooldown := 0.0
var wave := 0
var burst_left := 0
var burst_timer := 0.0
var lane := 450.0
var collected := 0
var health := 6
var slots: Array[int] = []
var arrows: Array[Dictionary] = []
var stuck: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var deflected: Array[Dictionary] = []
var failure_delay := 0.0
var failure_reason := ""
var feedback := "Face the straw bales toward the arrows."
var feedback_time := 0.0
var hit_flash := 0.0
var turn_input := false
var pointer_direction := 0.0
var active_touch := -1
var paused := false
var bgm: AudioStreamPlayer
var bgm_enabled := true
var bgm_button: Button

func _ready() -> void:
	bgm = AudioStreamPlayer.new()
	var music = preload("res://assets/audio/strawboat-bgm.wav")
	music.loop_mode = AudioStreamWAV.LOOP_FORWARD
	music.loop_begin = 0
	music.loop_end = music.data.size() / (4 if music.stereo else 2)
	bgm.stream = music
	bgm.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	var settings = ConfigFile.new()
	if settings.load("user://audio.cfg") == OK:
		bgm_enabled = bool(settings.get_value("audio", "bgm_enabled", true))
	bgm.volume_db = -16.0 if bgm_enabled else -80.0
	add_child(bgm)
	bgm.play()
	shot_rng.randomize()
	river = ColorRect.new()
	river.size = VIEW
	river.mouse_filter = Control.MOUSE_FILTER_IGNORE
	river.show_behind_parent = true
	river_material = ShaderMaterial.new()
	river_material.shader = preload("res://shaders/river.gdshader")
	river.material = river_material
	add_child(river)
	# Render invariant hull/material detail once, at 2x resolution.
	var surface = SubViewport.new()
	surface.size = Vector2i(860,440)
	surface.transparent_bg = true
	surface.render_target_update_mode = SubViewport.UPDATE_ONCE
	surface.disable_3d = true
	add_child(surface)
	var painter = preload("res://scripts/boat_surface.gd").new()
	painter.scale = Vector2(2,2)
	surface.add_child(painter)
	boat_texture = surface.get_texture()
	if OS.has_feature("web"):
		var rounded = FontVariation.new()
		rounded.base_font = preload("res://assets/fonts/Nunito.ttf")
		rounded.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):750.0}
		rounded.variation_embolden = 0.7
		font = rounded
	else:
		var system_font = SystemFont.new()
		system_font.font_names = PackedStringArray(["Arial Rounded MT Bold", "Arial Rounded MT", "Arial", "PingFang SC"])
		system_font.font_weight = 700
		font = system_font
	var music_ui = CanvasLayer.new()
	add_child(music_ui)
	bgm_button = Button.new()
	bgm_button.text = "BGM ON" if bgm_enabled else "BGM OFF"
	bgm_button.tooltip_text = "Toggle background music"
	bgm_button.add_theme_font_override("font", font)
	bgm_button.add_theme_font_size_override("font_size", 14)
	bgm_button.add_theme_color_override("font_color", ToyUI.TEXT)
	var music_style = StyleBoxFlat.new()
	music_style.bg_color = ToyUI.CREAM
	music_style.set_corner_radius_all(16)
	music_style.set_border_width_all(2)
	music_style.border_color = Color.WHITE
	bgm_button.add_theme_stylebox_override("normal", music_style)
	bgm_button.add_theme_stylebox_override("hover", music_style)
	bgm_button.add_theme_stylebox_override("pressed", music_style)
	bgm_button.custom_minimum_size = Vector2(100,44)
	bgm_button.pressed.connect(toggle_bgm)
	music_ui.add_child(bgm_button)
	rewards = preload("res://scripts/reward_fx.gd").new()
	rewards.font = font
	rewards.boat_center = C
	rewards.hud_target = Vector2(640,52)
	rewards.banner_position = Vector2(860,620)
	add_child(rewards)
	if not "--boat-test" in OS.get_cmdline_user_args() and not "--boat-capture" in OS.get_cmdline_user_args() and not "--reward-film" in OS.get_cmdline_user_args() and not "--boat-perf" in OS.get_cmdline_user_args():
		var cfg = ConfigFile.new()
		if cfg.load("user://rewards.cfg") == OK:
			for i in range(6): medals[i] = clampi(int(cfg.get_value("medals",str(i),0)),0,3)
	slots.resize(12)
	slots.fill(0)
	apply_layout(get_viewport_rect().size)
	get_viewport().size_changed.connect(_resize_layout)
	start()
	if "--boat-test" in OS.get_cmdline_user_args(): test_game.call_deferred()
	if "--boat-capture" in OS.get_cmdline_user_args(): capture.call_deferred()
	if "--reward-film" in OS.get_cmdline_user_args(): reward_film.call_deferred()
	if "--boat-perf" in OS.get_cmdline_user_args(): perf_run.call_deferred()

func _resize_layout() -> void:
	apply_layout(get_viewport_rect().size)

func apply_layout(size: Vector2) -> void:
	var old_center = C
	VIEW = size
	C = Vector2(VIEW.x*0.5+34,VIEW.y*0.5+20)
	LAUNCH_X = C.x-429
	PAUSE_POS = Vector2((VIEW.x-minf(VIEW.x-48,940))/2+minf(VIEW.x-48,940)-30,57)
	hud_target = Vector2(VIEW.x*0.5,151 if VIEW.x < VIEW.y else 68)
	panel_center = VIEW*0.5+Vector2(0,24)
	var shift = C-old_center
	for a in arrows: a.p += shift
	for a in deflected: a.p += shift
	for p in effects: p.p += shift
	for r in rewards.rings: r.p += shift
	for f in rewards.floats: f.p += shift
	for m in rewards.motes:
		m.from += shift
		m.to = hud_target
	river.size = VIEW
	rewards.boat_center = C
	rewards.hud_target = hud_target
	rewards.banner_position = Vector2(C.x,VIEW.y-108)
	river_material.set_shader_parameter("focus",C/VIEW)
	river_material.set_shader_parameter("view_size",VIEW)
	queue_redraw()

func lesson() -> Dictionary:
	return LESSONS[level - 1]

func start() -> void:
	rewards.reset()
	combo = 0
	best_combo = 0
	reward_score = 0
	win_delay = 0
	rating = 0
	new_medal = false
	phase = "play"
	paused = false
	heading = PI / 2
	collected = 0
	health = 6
	game_time = 0
	spawn_timer = lesson().prepare
	wave = 0
	fired = 0
	burst_left = 0
	burst_timer = 0
	damage_cooldown = 0
	clear_pointer()
	input_armed = false
	arrows.clear()
	stuck.clear()
	effects.clear()
	deflected.clear()
	failure_delay = 0
	failure_reason = ""
	slots.fill(0)
	feedback = lesson().hint
	feedback_time = lesson().prepare + 2

func advance() -> void:
	if failure_delay > 0 or win_delay > 0: return
	if phase == "win":
		level = level + 1 if level < LESSONS.size() else 1
	start()

func toggle_bgm() -> void:
	bgm_enabled = not bgm_enabled
	bgm.volume_db = -16.0 if bgm_enabled else -80.0
	bgm_button.text = "BGM ON" if bgm_enabled else "BGM OFF"
	clear_pointer()
	var settings = ConfigFile.new()
	settings.set_value("audio", "bgm_enabled", bgm_enabled)
	settings.save("user://audio.cfg")

func clear_pointer() -> void:
	turn_input = false
	pointer_direction = 0
	active_touch = -1

func pointer_event(position: Vector2, pressed: bool) -> void:
	if not pressed:
		clear_pointer()
		return
	if phase == "play" and position.distance_to(PAUSE_POS) < 28:
		paused = not paused
		clear_pointer()
		return
	if paused and phase == "play":
		paused = false
		clear_pointer()
		return
	if phase != "play":
		advance()
		clear_pointer()
		return
	turn_input = true
	pointer_direction = -1 if position.x < VIEW.x/2 else 1

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_R: start()
		if e.keycode in [KEY_P,KEY_ESCAPE] and phase == "play":
			paused = not paused
			clear_pointer()
		if e.keycode in [KEY_ENTER,KEY_SPACE] and phase != "play": advance()
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and active_touch < 0 and e.device != -1:
		pointer_event(e.position,e.pressed)
	if e is InputEventMouseMotion and turn_input and active_touch < 0:
		pointer_direction = -1 if e.position.x < VIEW.x/2 else 1
	if e is InputEventScreenTouch:
		if e.pressed and active_touch < 0:
			pointer_event(e.position,true)
			if turn_input: active_touch = e.index
		elif not e.pressed and e.index == active_touch:
			pointer_event(e.position,false)
	if e is InputEventScreenDrag and turn_input and e.index == active_touch:
		pointer_direction = -1 if e.position.x < VIEW.x/2 else 1

func turn_direction() -> float:
	var right = Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
	var left = Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
	var direction = (pointer_direction if turn_input and input_armed else 0.0) + float(right) - float(left)
	return clampf(direction,-1,1)

func next_shot_offset() -> float:
	# Sample freely; never inspect stuck arrows or steer toward empty straw.
	var spread = lerpf(78.0,108.0,float(level-1)/5.0)
	return shot_rng.randf_range(-spread,spread)

func next_shot_gap() -> float:
	var variation = lerpf(0.10,0.22,float(level-1)/5.0)
	return float(lesson().gap)*shot_rng.randf_range(1-variation,1+variation)

func check_volley_limit() -> void:
	if phase == "play" and wave >= int(lesson().volleys) and burst_left == 0 and arrows.is_empty() and deflected.is_empty():
		phase = "lose"
		failure_reason = "Out of volleys. Not enough arrows caught."
		clear_pointer()
		rewards.banner_left = 0
		rewards.play_impact("defeat")

func local_point(p: Vector2) -> Vector2:
	return (p - C).rotated(-heading) / BOAT_SCALE

func world(p: Vector2) -> Vector2:
	return C + (p * BOAT_SCALE).rotated(heading)

func slot_for(p: Vector2) -> int:
	if absf(p.y) < 22 or absf(p.x) > 126: return -1
	return clampi(int((p.x + 126) / 42), 0, 5) + (6 if p.y > 0 else 0)

func impact(p: Vector2) -> void:
	var idx = slot_for(p)
	if idx >= 0 and slots[idx] < 4:
		slots[idx] += 1
		collected += 1
		stuck.append({"p":p,"a":PI-heading + randf_range(-0.08,0.08),"age":0.0})
		combo += 1
		best_combo = maxi(best_combo,combo)
		var points = 10 + mini(combo / 4, 5) * 5
		reward_score += points
		rewards.catch_arrow(world(p),combo,int(lesson().goal),collected,points)
		feedback_time = 0
		spray(world(p), GOLD, 7)
		if collected >= int(lesson().goal):
			finish_round()
	else:
		if idx >= 0:
			arrow_collision(world(p))
			return
		rewards.play_impact("hull")
		if damage_cooldown > 0: return
		damage_cooldown = 1.0 if level <= 2 else 0.5
		health -= 1
		combo = 0
		rewards.banner_left = 0
		hit_flash = 0.35
		feedback = "Bale full! Turn to the other side." if idx >= 0 else "Hull hit! Face the bales toward the arrows."
		feedback_time = 2
		spray(world(p), Color("d48266"), 12)
		if health <= 0:
			phase = "lose"
			failure_reason = "Your hull has no strength left."
			rewards.play_impact("defeat")

# Check actual arrow shafts, not just occupancy of a straw block.
func hits_embedded(tip: Vector2) -> bool:
	var tail = tip - Vector2(54, 0)
	for embedded in stuck:
		var a = world(embedded.p)
		var b = a + Vector2.from_angle(embedded.a + heading) * 47
		if Geometry2D.segment_intersects_segment(tail, tip, a, b) != null: return true
		for point in [tip, tail]:
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b)) <= 3.5: return true
		for point in [a, b]:
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point, tail, tip)) <= 3.5: return true
	return false

func arrow_collision(tip: Vector2) -> void:
	combo = 0
	rewards.banner_left = 0
	feedback = "Deflected — no arrow gained."
	feedback_time = 0.9
	deflected.append({"p":tip, "v":Vector2(-190,-150), "a":0.0, "spin":-8.0, "life":1.1})
	spray(tip, GOLD, 18)
	rewards.play_impact("clang")

func animate_deflections(dt: float) -> void:
	for i in range(deflected.size()-1,-1,-1):
		var a = deflected[i]
		a.v.y += 460 * dt
		a.p += a.v * dt
		a.a += a.spin * dt
		a.life -= dt
		if a.life <= 0:
			spray(a.p, Color("95c3c4"), 15)
			deflected.remove_at(i)

func finish_round() -> void:
	phase = "win"
	win_delay = 2.1
	rating = 3 if health == 6 else (2 if health >= 4 else 1)
	new_medal = rating > medals[level-1]
	medals[level-1] = maxi(medals[level-1],rating)
	reward_score += rating*50
	rewards.celebrate(health == 6)
	spray(C,GOLD,90)
	if not "--boat-test" in OS.get_cmdline_user_args() and not "--boat-capture" in OS.get_cmdline_user_args() and not "--reward-film" in OS.get_cmdline_user_args() and not "--boat-perf" in OS.get_cmdline_user_args():
		var cfg = ConfigFile.new()
		for i in range(6): cfg.set_value("medals",str(i),medals[i])
		cfg.save("user://rewards.cfg")

func spray(p: Vector2, color: Color, count: int) -> void:
	for i in range(count): effects.append({"p":p,"v":Vector2.from_angle(randf()*TAU)*randf_range(20,100),"life":randf_range(0.3,0.9),"c":color})

func _process(dt: float) -> void:
	bgm_button.position = Vector2(VIEW.x-124, VIEW.y-68)
	bgm.stream_paused = paused
	time += dt
	river_material.set_shader_parameter("flow_time",time)
	if not paused:
		rewards.tick(dt)
		win_delay = maxf(0,win_delay-dt)
		for a in stuck: a.age += dt
	if phase == "play" and not paused:
		game_time += dt
		damage_cooldown = maxf(0, damage_cooldown - dt)
		if not turn_input and not Input.is_physical_key_pressed(KEY_SPACE): input_armed = true
		heading += turn_direction() * dt * 1.35
		spawn_timer -= dt
		if spawn_timer <= 0 and burst_left == 0 and wave < int(lesson().volleys):
			wave += 1
			burst_left = int(lesson().burst)
			burst_timer = 0.0
			spawn_timer = 999
		if burst_left > 0:
			burst_timer -= dt
			if burst_timer <= 0:
				# Small early spread and rhythm variation grow with each stage.
				lane = C.y + next_shot_offset() * BOAT_SCALE
				arrows.append({"p":Vector2(LAUNCH_X, lane),"speed":lesson().speed * FLIGHT_SCALE})
				fired += 1
				burst_left -= 1
				burst_timer = next_shot_gap()
				if burst_left == 0: spawn_timer = lesson().rest
		for i in range(arrows.size()-1,-1,-1):
			if phase != "play": break
			var a = arrows[i]
			var steps = maxi(1, ceili(a.speed * dt / 5))
			var remove = false
			for j in range(steps):
				a.p.x += a.speed * dt / steps
				if hits_embedded(a.p):
					arrow_collision(a.p)
					remove = true
					break
				var p = local_point(a.p)
				if pow(p.x/162,2) + pow(p.y/61,2) < 1:
					impact(p)
					remove = true
					break
			if not remove and a.p.x > C.x + 240: combo = 0
			if remove or a.p.x > C.x + 240: arrows.remove_at(i)
	if not paused:
		failure_delay = maxf(0, failure_delay - dt)
		animate_deflections(dt)
		check_volley_limit()
	feedback_time = maxf(0,feedback_time-dt)
	hit_flash = maxf(0,hit_flash-dt)
	for i in range(effects.size()-1,-1,-1):
		effects[i].p += effects[i].v * dt
		effects[i].life -= dt
		if effects[i].life <= 0: effects.remove_at(i)
	river_material.set_shader_parameter("boat_angle",heading)
	queue_redraw()

func label(s: String, p: Vector2, size: int, color: Color = PAPER) -> void:
	draw_string(font,p-Vector2(font.get_string_size(s,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x/2,0),s,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func boat() -> void:
	# Keep moving water and capacity indicators separate from the cached hull.
	draw_set_transform(C,heading,Vector2.ONE*BOAT_SCALE)
	for i in range(3):
		var expansion = fposmod(time*8+i*21,64)
		var points = PackedVector2Array()
		for j in range(65):
			var a = j*TAU/64
			points.append(Vector2(cos(a)*(176+expansion),sin(a)*(70+expansion*0.45)))
		draw_polyline(points,Color(0.90,0.97,0.93,0.21*(1-expansion/64)),2.4,true)
	draw_texture_rect(boat_texture,Rect2(-215,-110,430,220),false)
	for side in [-1,1]:
		for j in range(6):
			var idx = j+(6 if side > 0 else 0)
			for k in range(slots[idx]):
				draw_circle(Vector2(-114+j*42+k*6,side*62),2,GOLD,true,-1,true)
	draw_set_transform(Vector2.ZERO)
	for a in stuck:
		var tip = world(a.p)
		var wobble = sin(a.age*48)*exp(-a.age*13)*0.20
		var direction = a.a+heading+wobble
		Art.draw_arrow(self,tip,direction+PI,39)

func arrow(p: Vector2) -> void:
	Art.draw_arrow(self,p,0)

func _draw() -> void:
	var draw_started = Time.get_ticks_usec()
	var portrait = VIEW.x < VIEW.y
	var header_width = minf(VIEW.x-48,940)
	var left = (VIEW.x-header_width)/2
	ToyUI.slab(self,Rect2(left,22,250,68))
	label("Strawboat",Vector2(left+125,52),23)
	label("STAGE %d · %s" % [level,lesson().name],Vector2(left+125,76),13,ToyUI.MUTED)
	var progress_top = 105.0 if portrait else 22.0
	ToyUI.slab(self,Rect2(VIEW.x/2-106,progress_top,212,106),Color("fff7e5"))
	label("ARROWS",Vector2(VIEW.x/2,progress_top+22),11,ToyUI.MUTED)
	label("%02d / %02d" % [collected,int(lesson().goal)],hud_target,28+int(rewards.pulse*3),UI_ACCENT)
	ToyUI.progress(self,Rect2(VIEW.x/2-73,progress_top+65,146,8),rewards.progress)
	label("VOLLEY %d / %d" % [wave,int(lesson().volleys)],Vector2(VIEW.x/2,progress_top+93),11,Color("b77669") if wave == int(lesson().volleys) else ToyUI.MUTED)
	ToyUI.slab(self,Rect2(PAUSE_POS.x-212,22,166,68),Color("f0f8f1"))
	label("HULL",Vector2(PAUSE_POS.x-129,44),11,ToyUI.MUTED)
	for i in range(6): ToyUI.bead(self,Vector2(PAUSE_POS.x-184+i*22,66),i < health)
	ToyUI.slab(self,Rect2(PAUSE_POS-Vector2(28,35),Vector2(56,68)),Color("f5f1fc"),19)
	if paused:
		draw_colored_polygon(PackedVector2Array([PAUSE_POS+Vector2(-5,-10),PAUSE_POS+Vector2(-5,8),PAUSE_POS+Vector2(9,-1)]),ToyUI.TEXT)
	else:
		for x in [-5,5]:
			draw_line(PAUSE_POS+Vector2(x,-9),PAUSE_POS+Vector2(x,7),ToyUI.TEXT,4,true)
	boat()
	for a in arrows: arrow(a.p)
	for p in effects:
		var col: Color = p.c
		col.a = minf(p.life*2,1)
		draw_circle(p.p,2,col,true,-1,true)
	if hit_flash > 0: draw_rect(Rect2(Vector2.ZERO,VIEW),Color(0.8,0.25,0.12,hit_flash*0.3))
	if rewards.banner_left <= 0 and feedback_time > 0 and phase == "play": label(feedback,Vector2(C.x,VIEW.y-108),18,UI_ACCENT)
	ToyUI.slab(self,Rect2(VIEW.x/2-139,VIEW.y-64,278,38),Color("eff5f4"),18,2)
	label("Hold left / right to turn",Vector2(VIEW.x*0.5,VIEW.y-39),14,ToyUI.MUTED)
	for a in deflected:
		Art.draw_arrow(self,a.p,a.a)
	if (phase != "play" and failure_delay <= 0 and win_delay <= 0) or paused:
		ToyUI.slab(self,Rect2(panel_center-Vector2(235,207),Vector2(470,414)),Color("fbf8ff"),32,7)
		# A small fabric-like ribbon gives the result card the boat's warm accent.
		ToyUI.slab(self,Rect2(panel_center+Vector2(-146,-173),Vector2(292,64)),Color("ffe4d8"),22,2)
		ToyUI.slab(self,Rect2(panel_center+Vector2(-156,110),Vector2(312,54)),Color("e1f1df"),22,4)
		if paused:
			label("Take a breather",panel_center+Vector2(0,-132),26)
			label("Your next breeze can wait.",panel_center+Vector2(0,-20),18,ToyUI.MUTED)
			label("Resume",panel_center+Vector2(0,143),21)
		else:
			label(("Homeward Bound" if level == LESSONS.size() else "Well Caught!") if phase == "win" else "Try another voyage",panel_center+Vector2(0,-132),26,ToyUI.TEXT)
			if phase == "win":
				for i in range(3): ToyUI.star(self,panel_center+Vector2(-44+i*44,-71),19,i < rating)
				label("Flawless · Gold Seal" if rating == 3 else ("Steady · Silver Seal" if rating == 2 else "Brave · Bronze Seal"),panel_center+Vector2(0,-25),16)
				label("New seal · %s" % lesson().name if new_medal else "Your best seal is saved.",panel_center+Vector2(0,78),13,UI_ACCENT)
			else:
				label("%d arrows collected" % collected,panel_center+Vector2(0,-52),19)
			if phase == "lose": label(failure_reason,panel_center+Vector2(0,22),16,Color("ae6670"))
			if phase == "win":
				label("Next · %s" % LESSONS[level].name if level < LESSONS.size() else "All six rounds complete!",panel_center+Vector2(0,22),16,Color("758099"))
			label(("Next Round" if level < LESSONS.size() else "Play Again") if phase == "win" else "Try Again",panel_center+Vector2(0,140),20)

	draw_usec = Time.get_ticks_usec() - draw_started

func test_game() -> void:
	shot_rng.seed = 42
	start()
	assert(slot_for(Vector2(0,-58)) == 3)
	assert(slot_for(Vector2(-151,0)) == -1)
	impact(Vector2(0,-58))
	assert(collected == 1 and health == 6)
	for i in range(3): impact(Vector2(0,-58))
	impact(Vector2(0,-58))
	assert(collected == 4 and health == 6 and phase == "play")
	damage_cooldown = 0
	impact(Vector2(151,0))
	assert(health == 5)
	heading = PI / 2
	assert(local_point(world(Vector2(12,50))).distance_to(Vector2(12,50)) < 0.001)
	start()
	assert(collected == 0 and health == 6 and stuck.is_empty())
	collected = int(lesson().goal) - 1
	impact(Vector2(0,58))
	assert(phase == "win" and rating == 3 and win_delay > 0)
	advance()
	assert(level == 1)
	win_delay = 0
	advance()
	assert(level == 2 and collected == 0 and health == 6 and arrows.is_empty())
	assert(is_equal_approx(heading, PI / 2))
	var previous_speed = 0.0
	var previous_goal = 0
	var previous_required = 0.0
	for config in LESSONS:
		assert(config.speed > previous_speed and config.goal > previous_goal)
		previous_speed = config.speed
		previous_goal = config.goal
		var required = float(config.goal)/(config.burst*config.volleys)
		assert(required > previous_required and required <= 1)
		previous_required = required
	# First lesson is winnable without touching controls, using real arrow motion.
	level = 1
	start()
	for tick in range(6000):
		_process(1.0 / 120.0)
		if phase != "play": break
	assert(phase == "win" and collected == 8 and health == 6)
	phase = "lose"
	win_delay = 0
	advance()
	assert(level == 1 and phase == "play")
	# Arrow-on-arrow collisions bounce without losing health or granting progress.
	start()
	impact(Vector2(0, 58))
	var tip = world(Vector2(0,58)) - Vector2(28,0)
	assert(hits_embedded(tip))
	assert(not hits_embedded(tip + Vector2(0,20)))
	assert(is_equal_approx(local_point(world(Vector2(125,53))).x,125))
	assert(absf((C.x-LAUNCH_X)-429.0) <= 2 and FLIGHT_SCALE == 1.0)
	arrows.append({"p":tip-Vector2(6,0),"speed":160.0})
	_process(0.04)
	assert(phase == "play" and health == 6 and deflected.size() == 1 and collected == 1)
	assert(failure_delay == 0 and combo == 0)
	assert(rewards.last_impact == "clang")
	var before: Vector2 = deflected[0].p
	animate_deflections(0.2)
	assert(deflected[0].p != before and deflected[0].a != 0)
	animate_deflections(1.0)
	assert(deflected.is_empty())
	start()
	assert(failure_delay == 0 and failure_reason.is_empty() and combo == 0 and reward_score == 0 and rewards.motes.is_empty())
	start()
	impact(Vector2(0,58))
	assert(combo == 1 and reward_score == 10 and rewards.motes.size() == 5)
	health = 4
	finish_round()
	assert(rating == 2 and medals[0] == 3)
	start()
	health = 3
	finish_round()
	assert(rating == 1 and medals[0] == 3)
	start()
	health = 1
	impact(Vector2(151,0))
	assert(phase == "lose" and health == 0 and rewards.last_impact == "defeat")
	assert(rewards.impact_sounds.hull.data != rewards.impact_sounds.clang.data)
	assert(rewards.impact_sounds.defeat.get_length() > 0.5)
	# Resize keeps arrows attached to the same boat-relative trajectory.
	start()
	arrows.append({"p":C-Vector2(200,42),"speed":160.0})
	apply_layout(Vector2(720,900))
	assert((arrows[0].p-C).distance_to(Vector2(-200,-42)) < 0.01)
	assert(absf(C.x-LAUNCH_X-429) < 0.01)
	apply_layout(Vector2(1280,720))
	assert((arrows[0].p-C).distance_to(Vector2(-200,-42)) < 0.01)
	level = 1
	apply_layout(Vector2(720,900))
	start()
	for tick in range(6000):
		_process(1.0/120.0)
		if phase != "play": break
	assert(phase == "win" and collected == 8 and health == 6)
	start()
	var click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = PAUSE_POS
	_unhandled_input(click)
	assert(paused and not turn_input)
	click.position = panel_center
	_unhandled_input(click)
	assert(not paused and not turn_input)
	# Last volley is allowed to finish, including the last in-flight arrow.
	start()
	wave = int(lesson().volleys)
	spawn_timer = -1
	burst_left = 1
	check_volley_limit()
	assert(phase == "play")
	burst_left = 0
	collected = int(lesson().goal)-1
	arrows.append({"p":C-Vector2(65,0),"speed":160.0})
	check_volley_limit()
	assert(phase == "play")
	_process(0.1)
	assert(phase == "win" and wave == int(lesson().volleys))
	start()
	wave = int(lesson().volleys)
	spawn_timer = -1
	arrow_collision(C)
	check_volley_limit()
	assert(phase == "play")
	animate_deflections(1.2)
	check_volley_limit()
	assert(phase == "lose" and health == 6 and rewards.last_impact == "defeat")
	advance()
	assert(phase == "play" and wave == 0 and fired == 0)
	# Simulate all first-stage volleys missing: exact cap, never an extra volley.
	heading = 0
	for tick in range(8400):
		_process(1.0/120.0)
		arrows.clear()
		if phase == "lose": break
	assert(phase == "lose" and wave == int(lesson().volleys) and fired == int(lesson().burst)*int(lesson().volleys))
	# Direction is based on screen half, and drag can cross the center.
	start()
	input_armed = true
	click.position = Vector2(VIEW.x*0.2,C.y)
	_unhandled_input(click)
	assert(turn_direction() == -1)
	var initial_heading = heading
	_process(0.1)
	assert(heading < initial_heading)
	var move = InputEventMouseMotion.new()
	move.position = Vector2(VIEW.x*0.8,C.y)
	_unhandled_input(move)
	assert(turn_direction() == 1)
	click.pressed = false
	_unhandled_input(click)
	assert(turn_direction() == 0 and not turn_input)
	var touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.position = Vector2(VIEW.x*0.8,C.y)
	touch.pressed = true
	_unhandled_input(touch)
	assert(turn_direction() == 1)
	touch.pressed = false
	_unhandled_input(touch)
	assert(turn_direction() == 0)
	# Seeded samples are repeatable for tests, but do not follow a fixed lane pattern.
	level = 1
	shot_rng.seed = 9
	var samples: Array[float] = []
	for i in range(200):
		var offset = next_shot_offset()
		assert(absf(offset) <= 78)
		samples.append(offset)
		assert(next_shot_gap() >= float(lesson().gap)*0.9)
	var close_pair = false
	for i in range(1,samples.size()):
		if absf(samples[i]-samples[i-1]) < 3.5: close_pair = true
	assert(close_pair) # Random shots can repeat or collide instead of avoiding one another.
	shot_rng.seed = 22
	var first = next_shot_offset()
	shot_rng.seed = 22
	assert(first == next_shot_offset())
	var wins = 0
	for trial in range(20):
		level = 1
		shot_rng.seed = trial+100
		start()
		for tick in range(9000):
			_process(1.0/120.0)
			if phase != "play": break
		if phase == "win": wins += 1
	print("Random first-stage no-input wins: ",wins," / 20")
	assert(wins >= 16)
	print("PASS: gameplay, volley limits, controls, random lanes, close repeats, varied timing and beginner tolerance")
	get_tree().quit()

func capture() -> void:
	shot_rng.seed = 42
	level = 4
	start()
	heading = 1.32
	for i in range(17):
		var p = Vector2(-105+(i%6)*42,-49)
		impact(p)
	wave = 4
	for i in range(7): arrows.append({"p":Vector2(35+i*32,C.y-70+i%4*35),"speed":350})
	feedback = "Arrows caught · Turn to the other side"
	feedback_time = 3
	if "--boat-intro" in OS.get_cmdline_user_args():
		level = 1
		start()
		for tick in range(720): _process(1.0 / 120.0)
		feedback = "Stay steady · A gentle first volley"
		feedback_time = 3
	if "--boat-bounce" in OS.get_cmdline_user_args():
		start()
		impact(Vector2(0,58))
		arrow_collision(world(Vector2(0,58))-Vector2(26,0))
		animate_deflections(0.2)
	if "--boat-reward" in OS.get_cmdline_user_args():
		level = 1
		start()
		for tick in range(6000):
			_process(1.0/120.0)
			if phase == "win": break
		for tick in range(30): _process(1.0/120.0)
	if "--boat-result" in OS.get_cmdline_user_args():
		for tick in range(300): _process(1.0/120.0)
	if "--boat-horizontal" in OS.get_cmdline_user_args(): heading = 0.15
	river_material.set_shader_parameter("boat_angle",heading)
	set_process(false)
	queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://boat-preview.png")
	get_tree().quit()

func reward_film() -> void:
	shot_rng.seed = 42
	set_process(false)
	level = 1
	start()
	for tick in range(6000):
		_process(1.0/120.0)
		if collected == 7: break
	DirAccess.make_dir_recursive_absolute("/tmp/boat-reward-frames")
	for frame in range(156):
		_process(1.0/24.0)
		queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/boat-reward-frames/%04d.png" % frame)
	get_tree().quit()

func perf_run() -> void:
	level = 6
	start()
	spawn_timer = 0.1
	var frames: Array[float] = []
	var draws: Array[int] = []
	var calls: Array[float] = []
	for i in range(210):
		await get_tree().process_frame
		if i >= 30:
			frames.append(get_process_delta_time()*1000)
			draws.append(draw_usec)
			calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	frames.sort()
	draws.sort()
	calls.sort()
	print("PERF frame_ms median=",frames[90]," p95=",frames[171]," draw_cpu_us median=",draws[90]," p95=",draws[171]," draw_calls=",calls[90])
	get_tree().quit()
