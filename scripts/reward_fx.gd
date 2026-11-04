extends Node2D

const GOLD = Color("f5cf7b")
var font: Font
var boat_center := Vector2(860,380)
var hud_target := Vector2(640,52)
var banner_position := Vector2(860,620)
var rings: Array[Dictionary] = []
var motes: Array[Dictionary] = []
var floats: Array[Dictionary] = []
var pulse := 0.0
var banner := ""
var banner_left := 0.0
var victory := 0.0
var progress := 0.0
var target_progress := 0.0
var audio: AudioStreamPlayer
var notes: Array[AudioStreamWAV] = []
var fanfare: AudioStreamWAV
var victory_audio: AudioStreamPlayer
var impact_audio: AudioStreamPlayer
var impact_sounds: Dictionary = {}
var last_impact := ""
var launch_audio: AudioStreamPlayer
var launch_rng := RandomNumberGenerator.new()
var last_launch := -1
var launch_sounds: Array[AudioStreamWAV] = [
	preload("res://assets/audio/launch-1.wav"),
	preload("res://assets/audio/launch-2.wav"),
	preload("res://assets/audio/launch-3.wav"),
	preload("res://assets/audio/launch-4.wav")
]

func _ready() -> void:
	launch_rng.randomize()
	launch_audio = AudioStreamPlayer.new()
	launch_audio.max_polyphony = 4
	launch_audio.volume_db = -6.0
	add_child(launch_audio)
	audio = AudioStreamPlayer.new()
	add_child(audio)
	for hz in [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5]:
		notes.append(make_sound([hz], 0.24))
	impact_audio = AudioStreamPlayer.new()
	impact_audio.max_polyphony = 4
	add_child(impact_audio)
	for kind in ["hull","clang","defeat"]: impact_sounds[kind] = make_impact(kind)
	fanfare = make_sound([523.25,659.25,783.99,1046.5], 1.45)
	# The final catch and victory occur in one frame. Keep the fanfare on a
	# preassigned, independent player rather than replacing the catch sample.
	victory_audio = AudioStreamPlayer.new()
	victory_audio.stream = fanfare
	victory_audio.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(victory_audio)

func make_sound(pitches: Array, duration: float) -> AudioStreamWAV:
	var data = PackedByteArray()
	data.resize(int(22050*duration)*2)
	for i in range(data.size()/2):
		var t = i / 22050.0
		var v = 0.0
		for j in range(pitches.size()):
			var age = t - j*0.15
			if age >= 0:
				var hz: float = pitches[j]
				v += (sin(TAU*hz*age) + 0.26*sin(TAU*hz*2.01*age)) * exp(-age*9) * minf(age*600,1)*0.19
		# Brief woody attack under the bell-like pitch.
		v += sin(i*1.93)*exp(-t*160)*0.12
		data.encode_s16(i*2,int(clampf(v,-0.9,0.9)*32767))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	return stream

func make_impact(kind: String) -> AudioStreamWAV:
	var duration = 0.75 if kind == "defeat" else 0.30
	var data = PackedByteArray()
	data.resize(int(22050*duration)*2)
	for i in range(data.size()/2):
		var t = i/22050.0
		var v = 0.0
		if kind == "clang":
			v = (sin(TAU*1260*t)+0.55*sin(TAU*1937*t)+0.3*sin(TAU*2841*t))*exp(-t*19)*0.18
		elif kind == "hull":
			v = sin(TAU*(155*t-95*t*t))*exp(-t*18)*0.36 + sin(i*2.317)*exp(-t*85)*0.18
		else:
			v = (sin(TAU*(240*t-105*t*t))+0.25*sin(TAU*118*t))*exp(-t*5)*0.26
		data.encode_s16(i*2,int(clampf(v,-0.85,0.85)*32767))
	var result = AudioStreamWAV.new()
	result.format = AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate = 22050
	result.data = data
	return result

func play_launch() -> void:
	if "--boat-test" in OS.get_cmdline_user_args(): return
	var pick = launch_rng.randi_range(0,launch_sounds.size()-1) if last_launch < 0 else launch_rng.randi_range(0,launch_sounds.size()-2)
	if last_launch >= 0 and pick >= last_launch: pick += 1
	last_launch = pick
	launch_audio.stream = launch_sounds[pick]
	launch_audio.play()

func play_impact(kind: String) -> void:
	last_impact = kind
	if "--boat-test" in OS.get_cmdline_user_args(): return
	impact_audio.stream = impact_sounds[kind]
	impact_audio.play()

func reset() -> void:
	rings.clear()
	motes.clear()
	floats.clear()
	pulse = 0
	banner_left = 0
	victory = 0
	progress = 0
	target_progress = 0
	launch_audio.stop()
	audio.stop()
	impact_audio.stop()
	victory_audio.stop()
	last_impact = ""

func catch_arrow(pos: Vector2, combo: int, goal: int, count: int, _points: int) -> void:
	pulse = 1
	target_progress = float(count)/goal
	rings.append({"p":pos,"age":0.0,"color":GOLD})
	floats.append({"p":pos-Vector2(0,22),"age":0.0,"text":"+1"})
	for i in range(5):
		motes.append({"from":pos,"to":hud_target,"age":-i*0.035,"bend":Vector2(-45-i*7,-100)})
	if combo >= 4 and combo % 4 == 0:
		banner = "%d IN A ROW" % combo
		banner_left = 1.45
		rings.append({"p":boat_center,"age":0.0,"color":Color("8ecbb4")})
	if not "--boat-test" in OS.get_cmdline_user_args():
		audio.stream = notes[mini(combo/2,notes.size()-1)]
		audio.play()

func celebrate(perfect: bool) -> void:
	victory = 2.0
	banner = "FLAWLESS!" if perfect else "WELL CAUGHT!"
	banner_left = 2.0
	for i in range(3): rings.append({"p":boat_center,"age":-i*0.2,"color":GOLD})
	if not "--boat-test" in OS.get_cmdline_user_args():
		victory_audio.play()

func tick(dt: float) -> void:
	pulse = maxf(0,pulse-dt*4)
	banner_left = maxf(0,banner_left-dt)
	victory = maxf(0,victory-dt)
	progress = lerpf(progress,target_progress,1-exp(-dt*9))
	for i in range(rings.size()-1,-1,-1):
		rings[i].age += dt
		if rings[i].age > 0.65: rings.remove_at(i)
	for i in range(motes.size()-1,-1,-1):
		motes[i].age += dt
		if motes[i].age > 0.7: motes.remove_at(i)
	for i in range(floats.size()-1,-1,-1):
		floats[i].age += dt
		if floats[i].age > 0.85: floats.remove_at(i)
	queue_redraw()

func text(s: String, p: Vector2, size: int, color: Color) -> void:
	var origin = p-Vector2(font.get_string_size(s,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x/2,0)
	draw_string_outline(font,origin,s,HORIZONTAL_ALIGNMENT_LEFT,-1,size,3,Color(0.30,0.39,0.49,color.a*0.45))
	draw_string(font,origin,s,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _draw() -> void:
	if font == null: return
	for r in rings:
		if r.age < 0: continue
		var col: Color = r.color
		col.a = (1-r.age/0.65)*0.75
		draw_arc(r.p,8+84*r.age,0,TAU,64,col,2,true)
	for m in motes:
		if m.age < 0: continue
		var t = clampf(m.age/0.7,0,1)
		var pos: Vector2 = m.from.lerp(m.to,t) + m.bend*sin(t*PI)
		draw_circle(pos,3.4,GOLD,true,-1,true)
		draw_circle(pos,7,Color(1,0.8,0.4,0.1),true,-1,true)
	for f in floats:
		text(f.text,f.p-Vector2(0,f.age*48),19+int((1-minf(f.age*6,1))*9),Color(1,0.9,0.65,1-f.age/0.85))
	if banner_left > 0:
		var alpha = minf(banner_left*3,1)
		var y = banner_position.y + sin(minf(banner_left,1)*PI)*3
		text(banner,Vector2(banner_position.x,y),26 if victory > 0 else 22,Color(1,0.85,0.52,alpha))
	if victory > 0:
		for i in range(24):
			var a = i*TAU/24
			var p = boat_center+Vector2.from_angle(a)*(230+(2-victory)*35)
			draw_line(p,p+Vector2.from_angle(a)*8,Color(1,0.83,0.5,victory*0.22),2,true)
