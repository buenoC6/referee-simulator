extends Node3D
class_name MatchAudioDirector

const SAMPLE_RATE := 22050
const CROWD_LOOP_SECONDS := 4.0
const NON_SPATIAL_POOL_SIZE := 6
const SPATIAL_POOL_SIZE := 8

static var shared_streams: Dictionary = {}

var ambience_stream: AudioStreamWAV
var whistle_streams: Dictionary = {}
var ball_kick_stream: AudioStreamWAV
var ball_shot_stream: AudioStreamWAV
var ball_control_stream: AudioStreamWAV
var contact_stream: AudioStreamWAV
var player_protest_stream: AudioStreamWAV
var crowd_anticipation_stream: AudioStreamWAV
var crowd_cheer_stream: AudioStreamWAV
var crowd_boo_stream: AudioStreamWAV
var crowd_groan_stream: AudioStreamWAV

var ambience_player: AudioStreamPlayer
var non_spatial_players: Array[AudioStreamPlayer] = []
var spatial_players: Array[AudioStreamPlayer3D] = []
var played_events := PackedStringArray()
var muted: bool = false
var decision_mode: bool = false
var crowd_target_db: float = -18.0
var next_non_spatial_player: int = 0
var next_spatial_player: int = 0
var audio_random := RandomNumberGenerator.new()


func _ready() -> void:
	if shared_streams.is_empty():
		shared_streams = _build_shared_streams()
	_assign_shared_streams()
	_build_players()
	ambience_player.stream = ambience_stream
	ambience_player.volume_db = crowd_target_db
	ambience_player.play()


func _process(delta: float) -> void:
	if ambience_player == null:
		return
	var desired_volume := (
		-80.0
		if muted
		else crowd_target_db - (4.5 if decision_mode else 0.0)
	)
	ambience_player.volume_db = move_toward(
		ambience_player.volume_db,
		desired_volume,
		delta * 8.0
	)


func reset_for_match(match_seed: int) -> void:
	audio_random.seed = match_seed ^ 0x5A17D10
	played_events.clear()
	decision_mode = false
	for player in non_spatial_players:
		player.stop()
	for player in spatial_players:
		player.stop()
	if not muted:
		ambience_player.stop()
		ambience_player.play()


func set_tension(home_tension: float, away_tension: float) -> void:
	var tension_ratio := clampf(
		maxf(home_tension, away_tension) / 100.0,
		0.0,
		1.0
	)
	crowd_target_db = lerpf(-20.0, -10.5, tension_ratio)
	ambience_player.pitch_scale = lerpf(0.97, 1.04, tension_ratio)


func set_decision_mode(enabled: bool) -> void:
	decision_mode = enabled


func toggle_muted() -> bool:
	muted = not muted
	if muted:
		ambience_player.stop()
		for player in non_spatial_players:
			player.stop()
		for player in spatial_players:
			player.stop()
	else:
		ambience_player.play()
	return muted


func is_muted() -> bool:
	return muted


func event_count(event_name: String) -> int:
	return played_events.count(event_name)


func play_whistle(kind: String = "stoppage") -> void:
	var resolved_kind := kind if whistle_streams.has(kind) else "stoppage"
	_record_event("whistle_%s" % resolved_kind)
	_play_non_spatial(
		whistle_streams[resolved_kind],
		-2.0,
		audio_random.randf_range(0.985, 1.015)
	)


func play_ball_kick(position: Vector3, strong: bool = false) -> void:
	_record_event("ball_shot" if strong else "ball_kick")
	_play_spatial(
		ball_shot_stream if strong else ball_kick_stream,
		position,
		-3.0 if strong else -6.0,
		audio_random.randf_range(0.94, 1.06)
	)


func play_ball_control(position: Vector3) -> void:
	_record_event("ball_control")
	_play_spatial(
		ball_control_stream,
		position,
		-9.0,
		audio_random.randf_range(0.92, 1.08)
	)


func play_contact(position: Vector3, intensity: float = 1.0) -> void:
	_record_event("contact")
	_play_spatial(
		contact_stream,
		position,
		lerpf(-8.0, -2.5, clampf(intensity, 0.0, 1.0)),
		audio_random.randf_range(0.92, 1.04)
	)


func play_player_protest(position: Vector3, intensity: float = 0.7) -> void:
	_record_event("player_protest")
	_play_spatial(
		player_protest_stream,
		position,
		lerpf(-11.0, -3.0, clampf(intensity, 0.0, 1.0)),
		audio_random.randf_range(0.88, 1.13)
	)


func play_goal_chance(scoring_team_id: int) -> void:
	_record_event(
		"goal_chance_home" if scoring_team_id == 0 else "goal_chance_away"
	)
	_play_non_spatial(
		crowd_anticipation_stream,
		-3.0 if scoring_team_id == 0 else -7.0,
		1.0
	)


func play_goal_decision(scoring_team_id: int, awarded: bool) -> void:
	if awarded and scoring_team_id == 0:
		_record_event("crowd_cheer_home")
		_play_non_spatial(crowd_cheer_stream, -0.5, 1.0)
	elif awarded:
		_record_event("crowd_boo_away_goal")
		_play_non_spatial(crowd_boo_stream, -2.0, 0.98)
	elif scoring_team_id == 0:
		_record_event("crowd_groan_home_goal_denied")
		_play_non_spatial(crowd_groan_stream, -2.0, 0.96)
	else:
		_record_event("crowd_approval_away_goal_denied")
		_play_non_spatial(crowd_cheer_stream, -7.0, 1.05)


func play_shot_missed(shooting_team_id: int) -> void:
	_record_event(
		"crowd_groan_home_miss"
		if shooting_team_id == 0
		else "crowd_approval_away_miss"
	)
	_play_non_spatial(
		crowd_groan_stream if shooting_team_id == 0 else crowd_cheer_stream,
		-5.0 if shooting_team_id == 0 else -10.0,
		1.04 if shooting_team_id == 0 else 1.08
	)


func play_missed_call(affected_team_id: int) -> void:
	_record_event(
		"crowd_boo_missed_home_call"
		if affected_team_id == 0
		else "crowd_murmur_missed_away_call"
	)
	_play_non_spatial(
		crowd_boo_stream,
		-2.0 if affected_team_id == 0 else -8.0,
		1.0
	)


func play_advantage(beneficiary_team_id: int) -> void:
	_record_event(
		"crowd_approval_advantage"
		if beneficiary_team_id == 0
		else "crowd_murmur_advantage"
	)
	_play_non_spatial(
		crowd_cheer_stream,
		-8.0 if beneficiary_team_id == 0 else -12.0,
		1.08
	)


func play_decision_reaction(
	quality: float,
	home_delta: float,
	away_delta: float,
	awarded_team_id: int
) -> void:
	if home_delta >= 5.0 and home_delta > away_delta:
		_record_event("crowd_boo_decision")
		_play_non_spatial(
			crowd_boo_stream,
			lerpf(-7.0, -1.5, clampf(home_delta / 18.0, 0.0, 1.0)),
			1.0
		)
	elif quality >= 0.82 and awarded_team_id == 0:
		_record_event("crowd_approval_decision")
		_play_non_spatial(crowd_cheer_stream, -8.0, 1.08)
	elif away_delta >= 7.0:
		_record_event("crowd_home_approval_away_protest")
		_play_non_spatial(crowd_cheer_stream, -10.0, 1.03)
	else:
		_record_event("crowd_murmur_decision")
		_play_non_spatial(crowd_groan_stream, -12.0, 1.08)


func _record_event(event_name: String) -> void:
	if played_events.size() >= 80:
		played_events.remove_at(0)
	played_events.append(event_name)


func _play_non_spatial(
	stream: AudioStream,
	volume_db: float,
	pitch_scale: float
) -> void:
	if muted or stream == null or non_spatial_players.is_empty():
		return
	var player := _available_non_spatial_player()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()


func _play_spatial(
	stream: AudioStream,
	position: Vector3,
	volume_db: float,
	pitch_scale: float
) -> void:
	if muted or stream == null or spatial_players.is_empty():
		return
	var player := _available_spatial_player()
	player.global_position = position
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()


func _available_non_spatial_player() -> AudioStreamPlayer:
	for player in non_spatial_players:
		if not player.playing:
			return player
	var player := non_spatial_players[next_non_spatial_player]
	next_non_spatial_player = (
		(next_non_spatial_player + 1) % non_spatial_players.size()
	)
	return player


func _available_spatial_player() -> AudioStreamPlayer3D:
	for player in spatial_players:
		if not player.playing:
			return player
	var player := spatial_players[next_spatial_player]
	next_spatial_player = (
		(next_spatial_player + 1) % spatial_players.size()
	)
	return player


func _build_players() -> void:
	ambience_player = AudioStreamPlayer.new()
	ambience_player.name = "CrowdAmbience"
	add_child(ambience_player)
	for index in range(NON_SPATIAL_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "CrowdReaction%02d" % (index + 1)
		add_child(player)
		non_spatial_players.append(player)
	for index in range(SPATIAL_POOL_SIZE):
		var player := AudioStreamPlayer3D.new()
		player.name = "PitchSound%02d" % (index + 1)
		player.unit_size = 12.0
		player.max_distance = 105.0
		player.attenuation_filter_db = -10.0
		add_child(player)
		spatial_players.append(player)


func _assign_shared_streams() -> void:
	ambience_stream = shared_streams["ambience"]
	whistle_streams = shared_streams["whistles"]
	ball_kick_stream = shared_streams["ball_kick"]
	ball_shot_stream = shared_streams["ball_shot"]
	ball_control_stream = shared_streams["ball_control"]
	contact_stream = shared_streams["contact"]
	player_protest_stream = shared_streams["player_protest"]
	crowd_anticipation_stream = shared_streams["crowd_anticipation"]
	crowd_cheer_stream = shared_streams["crowd_cheer"]
	crowd_boo_stream = shared_streams["crowd_boo"]
	crowd_groan_stream = shared_streams["crowd_groan"]


static func _build_shared_streams() -> Dictionary:
	return {
		"ambience": _generate_crowd_bed(),
		"whistles": {
			"kickoff": _generate_whistle(1, 0.28),
			"stoppage": _generate_whistle(1, 0.38),
			"half_time": _generate_whistle(2, 0.31),
			"full_time": _generate_whistle(3, 0.34),
		},
		"ball_kick": _generate_ball_impact(0.14, 0.72),
		"ball_shot": _generate_ball_impact(0.21, 1.0),
		"ball_control": _generate_ball_impact(0.10, 0.42),
		"contact": _generate_contact(),
		"player_protest": _generate_player_protest(),
		"crowd_anticipation": _generate_crowd_anticipation(),
		"crowd_cheer": _generate_crowd_reaction("cheer"),
		"crowd_boo": _generate_crowd_reaction("boo"),
		"crowd_groan": _generate_crowd_reaction("groan"),
	}


static func _generate_crowd_bed() -> AudioStreamWAV:
	var frame_count := roundi(SAMPLE_RATE * CROWD_LOOP_SECONDS)
	var left := PackedFloat32Array()
	var right := PackedFloat32Array()
	left.resize(frame_count)
	right.resize(frame_count)
	var generator := RandomNumberGenerator.new()
	generator.seed = 90210
	var components: Array[Dictionary] = []
	for index in range(18):
		components.append({
			"cycles": generator.randi_range(220, 4800),
			"phase_left": generator.randf_range(0.0, TAU),
			"phase_right": generator.randf_range(0.0, TAU),
			"amplitude": generator.randf_range(0.018, 0.055),
		})
	for frame in range(frame_count):
		var progress := float(frame) / float(frame_count)
		var left_sample := 0.0
		var right_sample := 0.0
		for component in components:
			var angle := TAU * float(component["cycles"]) * progress
			left_sample += sin(angle + float(component["phase_left"])) * float(
				component["amplitude"]
			)
			right_sample += sin(angle + float(component["phase_right"])) * float(
				component["amplitude"]
			)
		var crowd_breath := (
			0.76
			+ 0.12 * sin(TAU * 2.0 * progress)
			+ 0.08 * sin(TAU * 5.0 * progress + 0.7)
		)
		var chant := (
			sin(TAU * 420.0 * progress)
			+ 0.45 * sin(TAU * 680.0 * progress + 0.4)
		) * (0.035 + 0.025 * sin(TAU * 3.0 * progress))
		left[frame] = clampf(left_sample * crowd_breath + chant, -0.8, 0.8)
		right[frame] = clampf(
			right_sample * crowd_breath + chant * 0.87,
			-0.8,
			0.8
		)
	return _stereo_wav(left, right, true)


static func _generate_whistle(
	pulse_count: int,
	pulse_duration: float
) -> AudioStreamWAV:
	var gap := 0.105
	var duration := pulse_count * pulse_duration + (pulse_count - 1) * gap
	var frame_count := roundi(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(frame_count)
	var cycle_duration := pulse_duration + gap
	for frame in range(frame_count):
		var time := float(frame) / SAMPLE_RATE
		var pulse_index := floori(time / cycle_duration)
		var local_time := fmod(time, cycle_duration)
		if pulse_index >= pulse_count or local_time >= pulse_duration:
			continue
		var envelope := _attack_release(
			local_time,
			pulse_duration,
			0.018,
			0.045
		)
		var vibrato := sin(TAU * 7.5 * time) * 24.0
		var sample := (
			sin(TAU * (3180.0 + vibrato) * time) * 0.58
			+ sin(TAU * (3560.0 + vibrato * 0.7) * time) * 0.34
			+ sin(TAU * 6360.0 * time) * 0.08
		)
		samples[frame] = sample * envelope * 0.78
	return _mono_wav(samples)


static func _generate_ball_impact(
	duration: float,
	strength: float
) -> AudioStreamWAV:
	var frame_count := roundi(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(frame_count)
	var generator := RandomNumberGenerator.new()
	generator.seed = roundi(4517.0 * strength)
	var filtered_noise := 0.0
	for frame in range(frame_count):
		var time := float(frame) / SAMPLE_RATE
		var progress := time / duration
		filtered_noise = lerpf(
			filtered_noise,
			generator.randf_range(-1.0, 1.0),
			0.38
		)
		var body := (
			sin(TAU * lerpf(155.0, 72.0, progress) * time)
			+ 0.42 * sin(TAU * 255.0 * time)
		)
		var click := filtered_noise * exp(-34.0 * time)
		var envelope := exp(-15.0 * time)
		samples[frame] = clampf(
			(body * 0.48 * envelope + click * 0.36) * strength,
			-1.0,
			1.0
		)
	return _mono_wav(samples)


static func _generate_contact() -> AudioStreamWAV:
	var duration := 0.32
	var frame_count := roundi(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(frame_count)
	var generator := RandomNumberGenerator.new()
	generator.seed = 741109
	var filtered_noise := 0.0
	for frame in range(frame_count):
		var time := float(frame) / SAMPLE_RATE
		filtered_noise = lerpf(
			filtered_noise,
			generator.randf_range(-1.0, 1.0),
			0.26
		)
		var thump := (
			sin(TAU * 92.0 * time)
			+ 0.45 * sin(TAU * 141.0 * time)
		) * exp(-11.0 * time)
		var scrape := filtered_noise * exp(-7.5 * time)
		samples[frame] = clampf(thump * 0.52 + scrape * 0.31, -1.0, 1.0)
	return _mono_wav(samples)


static func _generate_player_protest() -> AudioStreamWAV:
	var duration := 0.78
	var frame_count := roundi(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(frame_count)
	var generator := RandomNumberGenerator.new()
	generator.seed = 1729
	var phase := 0.0
	var breath := 0.0
	for frame in range(frame_count):
		var time := float(frame) / SAMPLE_RATE
		var progress := time / duration
		var pitch := lerpf(168.0, 112.0, progress) + sin(TAU * 3.2 * time) * 9.0
		phase += TAU * pitch / SAMPLE_RATE
		breath = lerpf(
			breath,
			generator.randf_range(-1.0, 1.0),
			0.16
		)
		var syllable_a := _attack_release(time, 0.34, 0.025, 0.08)
		var syllable_b := (
			_attack_release(time - 0.39, 0.34, 0.025, 0.11)
			if time >= 0.39
			else 0.0
		)
		var voice := (
			sin(phase)
			+ 0.52 * sin(phase * 2.0)
			+ 0.22 * sin(phase * 3.0)
			+ 0.16 * sin(TAU * 730.0 * time)
			+ 0.09 * sin(TAU * 1180.0 * time)
		)
		samples[frame] = clampf(
			voice * (syllable_a + syllable_b * 0.86) * 0.36
			+ breath * (syllable_a + syllable_b) * 0.08,
			-1.0,
			1.0
		)
	return _mono_wav(samples)


static func _generate_crowd_anticipation() -> AudioStreamWAV:
	var duration := 0.95
	var frame_count := roundi(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(frame_count)
	var generator := RandomNumberGenerator.new()
	generator.seed = 8881
	var filtered_noise := 0.0
	var phase := 0.0
	for frame in range(frame_count):
		var time := float(frame) / SAMPLE_RATE
		var progress := time / duration
		filtered_noise = lerpf(
			filtered_noise,
			generator.randf_range(-1.0, 1.0),
			0.12
		)
		phase += TAU * lerpf(105.0, 188.0, progress) / SAMPLE_RATE
		var envelope := sin(PI * progress) * lerpf(0.35, 1.0, progress)
		samples[frame] = clampf(
			(
				sin(phase) * 0.24
				+ sin(phase * 1.5) * 0.16
				+ filtered_noise * 0.29
			) * envelope,
			-1.0,
			1.0
		)
	return _mono_wav(samples)


static func _generate_crowd_reaction(kind: String) -> AudioStreamWAV:
	var duration := 2.15 if kind == "cheer" else 1.72
	var frame_count := roundi(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(frame_count)
	var generator := RandomNumberGenerator.new()
	generator.seed = hash(kind)
	var filtered_noise := 0.0
	var phase_low := 0.0
	var phase_high := 0.0
	for frame in range(frame_count):
		var time := float(frame) / SAMPLE_RATE
		var progress := time / duration
		filtered_noise = lerpf(
			filtered_noise,
			generator.randf_range(-1.0, 1.0),
			0.18
		)
		var base_pitch := (
			lerpf(132.0, 185.0, progress)
			if kind == "cheer"
			else lerpf(118.0, 92.0, progress)
			if kind == "boo"
			else lerpf(178.0, 86.0, progress)
		)
		phase_low += TAU * base_pitch / SAMPLE_RATE
		phase_high += TAU * (base_pitch * 1.47) / SAMPLE_RATE
		var envelope := _attack_release(time, duration, 0.08, 0.42)
		var voices := (
			sin(phase_low) * 0.27
			+ sin(phase_high) * 0.18
			+ sin(phase_low * 0.74 + 1.1) * 0.15
		)
		var claps := (
			pow(maxf(0.0, sin(TAU * 7.2 * time)), 18.0)
			* filtered_noise
			* (0.28 if kind == "cheer" else 0.05)
		)
		var noise_amount := 0.34 if kind == "cheer" else 0.19
		samples[frame] = clampf(
			(voices + filtered_noise * noise_amount + claps)
			* envelope,
			-1.0,
			1.0
		)
	return _mono_wav(samples)


static func _attack_release(
	time: float,
	duration: float,
	attack: float,
	release: float
) -> float:
	if time < 0.0 or time > duration:
		return 0.0
	var attack_gain := clampf(time / maxf(attack, 0.001), 0.0, 1.0)
	var release_gain := clampf(
		(duration - time) / maxf(release, 0.001),
		0.0,
		1.0
	)
	return attack_gain * release_gain


static func _mono_wav(
	samples: PackedFloat32Array,
	loop: bool = false
) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for index in range(samples.size()):
		_write_s16(data, index * 2, samples[index])
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream


static func _stereo_wav(
	left: PackedFloat32Array,
	right: PackedFloat32Array,
	loop: bool = false
) -> AudioStreamWAV:
	var frame_count := mini(left.size(), right.size())
	var data := PackedByteArray()
	data.resize(frame_count * 4)
	for index in range(frame_count):
		_write_s16(data, index * 4, left[index])
		_write_s16(data, index * 4 + 2, right[index])
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = true
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = frame_count
	return stream


static func _write_s16(
	data: PackedByteArray,
	offset: int,
	normalized_sample: float
) -> void:
	var encoded := clampi(
		roundi(clampf(normalized_sample, -1.0, 1.0) * 32767.0),
		-32768,
		32767
	)
	if encoded < 0:
		encoded += 65536
	data[offset] = encoded & 0xFF
	data[offset + 1] = (encoded >> 8) & 0xFF
