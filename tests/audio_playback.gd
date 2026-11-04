extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var fx = preload("res://scripts/reward_fx.gd").new()
	root.add_child(fx)
	for attempt in range(20):
		fx.reset()
		# Reproduce the last arrow's two immediate audio events.
		fx.catch_arrow(Vector2.ZERO,8,8,8,10)
		fx.celebrate(true)
		assert(fx.victory_audio != fx.audio)
		assert(fx.audio.stream != fx.fanfare)
		assert(fx.victory_audio.stream == fx.fanfare)
		assert(fx.victory_audio.playback_type == AudioServer.PLAYBACK_TYPE_STREAM)
		assert(fx.audio.playing and fx.victory_audio.playing)
		# Another sound must not stop or replace the celebration.
		fx.play_launch()
		assert(fx.launch_audio.playing)
		assert(fx.launch_audio != fx.audio)
		fx.play_impact("clang")
		await process_frame
		assert(fx.victory_audio.playing)
		assert(fx.victory_audio.stream == fx.fanfare)
	fx.reset()
	assert(not fx.audio.playing and not fx.victory_audio.playing and not fx.launch_audio.playing)
	fx.queue_free()
	await process_frame
	print("PASS: 20 final-catch/victory overlaps, impact isolation and reset")
	quit()
