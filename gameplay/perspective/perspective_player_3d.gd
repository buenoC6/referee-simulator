extends CharacterBody3D
class_name PerspectivePlayer3D

var target_position := Vector3.ZERO
var movement_speed: float = 4.8
var moving: bool = false
var visual_root: Node3D
var shirt_material: StandardMaterial3D
var team_id: int = -1
var shirt_number: int = 0
var caution_count: int = 0
var active: bool = true
var stumble_timer: float = 0.0
var status_label: Label3D
var torso: MeshInstance3D
var left_leg_pivot: Node3D
var right_leg_pivot: Node3D
var left_knee_pivot: Node3D
var right_knee_pivot: Node3D
var left_arm_pivot: Node3D
var right_arm_pivot: Node3D
var left_elbow_pivot: Node3D
var right_elbow_pivot: Node3D
var animation_time: float = 0.0
var inspection_marker: Label3D
var var_marker: Label3D
var stumble_elapsed: float = 0.0
var stumble_duration: float = 0.0
var stumble_lean_degrees: float = 0.0
var tackle_timer: float = 0.0
var tackle_elapsed: float = 0.0
var tackle_duration: float = 0.0
var tackle_side: float = 1.0


func setup(
	player_name: String,
	shirt_color: Color,
	number: int,
	player_team_id: int,
	is_goalkeeper: bool = false
) -> void:
	name = player_name
	team_id = player_team_id
	shirt_number = number
	collision_layer = 2
	collision_mask = 0
	add_to_group("perspective_players")
	_build_visuals(shirt_color, number, is_goalkeeper)


func _physics_process(delta: float) -> void:
	if stumble_timer > 0.0:
		stumble_elapsed += delta
		stumble_timer = maxf(0.0, stumble_timer - delta)
		_animate_stumble()
		velocity = Vector3.ZERO
		if stumble_timer <= 0.0:
			reset_pose()
		return
	if tackle_timer > 0.0:
		tackle_elapsed += delta
		tackle_timer = maxf(0.0, tackle_timer - delta)
		_animate_tackle()
		velocity = Vector3.ZERO
		if tackle_timer <= 0.0:
			reset_pose()
		return
	if not active:
		velocity = Vector3.ZERO
		_animate_idle(delta)
		return
	if not moving:
		velocity = Vector3.ZERO
		_animate_idle(delta)
		return

	var offset := target_position - global_position
	offset.y = 0.0
	if offset.length() <= 0.12:
		global_position.x = target_position.x
		global_position.z = target_position.z
		velocity = Vector3.ZERO
		moving = false
		_animate_idle(delta)
		return

	var direction := offset.normalized()
	velocity = direction * movement_speed
	rotation.y = atan2(-direction.x, -direction.z)
	move_and_slide()
	_animate_run(delta)


func move_to(next_target: Vector3, speed: float = 4.8) -> void:
	target_position = next_target
	movement_speed = speed
	moving = true


func freeze_actor() -> void:
	moving = false
	velocity = Vector3.ZERO


func set_fallen(lean_degrees: float) -> void:
	visual_root.rotation.z = deg_to_rad(lean_degrees)
	visual_root.position.y = 0.28


func stumble(duration: float = 1.75, lean_degrees: float = -72.0) -> void:
	freeze_actor()
	stumble_elapsed = 0.0
	stumble_duration = duration
	stumble_lean_degrees = lean_degrees
	stumble_timer = duration


func perform_tackle(
	target_direction: Vector3,
	duration: float = 0.9
) -> void:
	freeze_actor()
	var flat_direction := Vector3(
		target_direction.x,
		0.0,
		target_direction.z
	)
	if flat_direction.length_squared() > 0.001:
		flat_direction = flat_direction.normalized()
		rotation.y = atan2(-flat_direction.x, -flat_direction.z)
	tackle_elapsed = 0.0
	tackle_duration = duration
	tackle_timer = duration
	tackle_side = -1.0 if shirt_number % 2 == 0 else 1.0


func reset_pose() -> void:
	visual_root.rotation = Vector3.ZERO
	visual_root.position = Vector3.ZERO
	if left_leg_pivot != null:
		left_leg_pivot.rotation = Vector3.ZERO
		right_leg_pivot.rotation = Vector3.ZERO
		left_arm_pivot.rotation = Vector3.ZERO
		right_arm_pivot.rotation = Vector3.ZERO
	if left_knee_pivot != null:
		left_knee_pivot.rotation = Vector3.ZERO
		right_knee_pivot.rotation = Vector3.ZERO
		left_elbow_pivot.rotation = Vector3.ZERO
		right_elbow_pivot.rotation = Vector3.ZERO
	if torso != null:
		torso.rotation = Vector3.ZERO


func reset_for_match() -> void:
	active = true
	visible = true
	collision_layer = 2
	caution_count = 0
	stumble_timer = 0.0
	stumble_elapsed = 0.0
	stumble_duration = 0.0
	tackle_timer = 0.0
	tackle_elapsed = 0.0
	tackle_duration = 0.0
	animation_time = float(shirt_number) * 0.37
	status_label.text = ""
	inspection_marker.visible = false
	var_marker.visible = false
	set_physics_process(true)
	reset_pose()


func set_inspection_highlight(is_looked_at: bool, is_identified: bool) -> void:
	inspection_marker.visible = is_looked_at or is_identified
	inspection_marker.text = (
		"IDENTIFIÉ"
		if is_identified
		else "CIBLE"
	)
	inspection_marker.modulate = (
		Color("#86efac")
		if is_identified
		else Color("#facc15")
	)


func set_var_review_signal(value: bool) -> void:
	var_marker.visible = value


func apply_discipline(discipline_id: String) -> String:
	match discipline_id:
		"verbal_warning":
			status_label.text = "RAPPEL"
			status_label.modulate = Color("#f8fafc")
			return "Rappel à l’ordre pour %s" % name
		"yellow_card":
			caution_count += 1
			if caution_count >= 2:
				_send_off("2J")
				return "Second avertissement : %s est exclu" % name
			status_label.text = "■"
			status_label.modulate = Color("#fde047")
			return "Carton jaune pour %s" % name
		"second_yellow":
			caution_count = maxi(caution_count, 2)
			_send_off("2J")
			return "Second jaune : %s est exclu" % name
		"red_card":
			_send_off("■")
			return "Carton rouge pour %s" % name
	return "Aucune sanction disciplinaire"


func _send_off(marker: String) -> void:
	active = false
	moving = false
	status_label.text = marker
	status_label.modulate = Color("#fb7185")
	visible = false
	collision_layer = 0
	velocity = Vector3.ZERO


func _build_visuals(shirt_color: Color, number: int, is_goalkeeper: bool) -> void:
	visual_root = Node3D.new()
	visual_root.name = "Visuals"
	add_child(visual_root)

	shirt_material = _material(
		Color("#38bdf8") if is_goalkeeper else shirt_color,
		0.64
	)
	var shorts_material := _material(Color("#101827"), 0.74)
	var skin_colors := [
		Color("#8a563d"),
		Color("#ad7354"),
		Color("#d09a73"),
		Color("#edc09b"),
	]
	var skin_color: Color = skin_colors[number % skin_colors.size()]
	var skin_material := _material(skin_color, 0.86)
	var socks_color := (
		Color("#38bdf8").lightened(0.08)
		if is_goalkeeper
		else shirt_color.lightened(0.12)
	)
	var socks_material := _material(socks_color, 0.72)
	var boots_material := _material(Color("#111318"), 0.52)
	var hair_material := _material(
		Color("#17120e") if number % 3 else Color("#4b2c1a"),
		0.82
	)

	var shadow := MeshInstance3D.new()
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = 0.34
	shadow_mesh.bottom_radius = 0.34
	shadow_mesh.height = 0.012
	shadow.mesh = shadow_mesh
	shadow.position.y = 0.012
	var shadow_material := StandardMaterial3D.new()
	shadow_material.albedo_color = Color(0.015, 0.025, 0.02, 0.26)
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = shadow_material
	add_child(shadow)

	torso = _add_capsule(
		visual_root,
		Vector3(0.0, 1.39, 0.0),
		0.32,
		0.76,
		shirt_material
	)
	torso.scale = Vector3(1.04, 1.0, 0.78)
	var pelvis := _add_capsule(
		visual_root,
		Vector3(0.0, 1.01, 0.0),
		0.27,
		0.38,
		shorts_material
	)
	pelvis.scale = Vector3(1.16, 1.0, 0.86)
	var collar := _add_capsule(
		visual_root,
		Vector3(0.0, 1.78, 0.0),
		0.085,
		0.2,
		skin_material
	)
	collar.scale = Vector3(0.9, 1.0, 0.9)
	var head := _add_sphere(
		visual_root,
		Vector3(0.0, 1.98, 0.0),
		0.225,
		skin_material
	)
	head.scale = Vector3(0.92, 1.04, 0.9)
	var hair := _add_sphere(
		visual_root,
		Vector3(0.0, 2.105, 0.0),
		0.19,
		hair_material
	)
	hair.scale = Vector3(1.0, 0.46, 1.0)
	var nose := _add_sphere(
		visual_root,
		Vector3(0.0, 2.0, -0.205),
		0.045,
		skin_material
	)
	nose.scale = Vector3(0.72, 0.86, 1.15)
	for eye_x in [-0.075, 0.075]:
		var eye := _add_sphere(
			visual_root,
			Vector3(eye_x, 2.055, -0.207),
			0.025,
			hair_material
		)
		eye.scale = Vector3(0.72, 0.78, 0.42)
	for ear_x in [-0.215, 0.215]:
		var ear := _add_sphere(
			visual_root,
			Vector3(ear_x, 2.0, 0.0),
			0.047,
			skin_material
		)
		ear.scale = Vector3(0.52, 0.9, 0.68)

	var left_leg := _build_leg(
		Vector3(-0.18, 0.88, 0.0),
		shorts_material,
		skin_material,
		socks_material,
		boots_material
	)
	left_leg_pivot = left_leg[0]
	left_knee_pivot = left_leg[1]
	var right_leg := _build_leg(
		Vector3(0.18, 0.88, 0.0),
		shorts_material,
		skin_material,
		socks_material,
		boots_material
	)
	right_leg_pivot = right_leg[0]
	right_knee_pivot = right_leg[1]
	var left_arm := _build_arm(
		Vector3(-0.38, 1.57, 0.0),
		shirt_material,
		skin_material
	)
	left_arm_pivot = left_arm[0]
	left_elbow_pivot = left_arm[1]
	var right_arm := _build_arm(
		Vector3(0.38, 1.57, 0.0),
		shirt_material,
		skin_material
	)
	right_arm_pivot = right_arm[0]
	right_elbow_pivot = right_arm[1]

	var number_label := Label3D.new()
	number_label.text = str(number)
	number_label.font_size = 36
	number_label.modulate = Color.WHITE
	number_label.outline_size = 4
	number_label.position = Vector3(0.0, 1.38, 0.34)
	number_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	number_label.no_depth_test = true
	visual_root.add_child(number_label)

	status_label = Label3D.new()
	status_label.text = ""
	status_label.font_size = 54
	status_label.outline_size = 8
	status_label.position = Vector3(0.0, 2.43, 0.0)
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status_label.no_depth_test = true
	visual_root.add_child(status_label)

	inspection_marker = Label3D.new()
	inspection_marker.text = "CIBLE"
	inspection_marker.font_size = 18
	inspection_marker.outline_size = 5
	inspection_marker.position = Vector3(0.0, 2.7, 0.0)
	inspection_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	inspection_marker.no_depth_test = true
	inspection_marker.fixed_size = true
	inspection_marker.pixel_size = 0.00145
	inspection_marker.visible = false
	add_child(inspection_marker)

	var_marker = Label3D.new()
	var_marker.text = "VAR"
	var_marker.font_size = 18
	var_marker.outline_size = 5
	var_marker.position = Vector3(0.0, 3.02, 0.0)
	var_marker.modulate = Color("#c4b5fd")
	var_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var_marker.no_depth_test = true
	var_marker.fixed_size = true
	var_marker.pixel_size = 0.00145
	var_marker.visible = false
	add_child(var_marker)

	var collision_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.86
	collision_shape.shape = capsule
	collision_shape.position = Vector3(0.0, 0.94, 0.0)
	add_child(collision_shape)


func _build_leg(
	pivot_position: Vector3,
	shorts_material: Material,
	skin_material: Material,
	socks_material: Material,
	boots_material: Material
) -> Array[Node3D]:
	var hip := Node3D.new()
	hip.position = pivot_position
	visual_root.add_child(hip)
	var shorts_leg := _add_capsule(
		hip,
		Vector3(0.0, -0.1, 0.0),
		0.14,
		0.25,
		shorts_material
	)
	shorts_leg.scale = Vector3(1.0, 1.0, 0.88)
	_add_capsule(
		hip,
		Vector3(0.0, -0.31, 0.0),
		0.105,
		0.34,
		skin_material
	)
	var knee := Node3D.new()
	knee.position = Vector3(0.0, -0.48, 0.0)
	hip.add_child(knee)
	_add_sphere(
		knee,
		Vector3.ZERO,
		0.108,
		skin_material
	)
	_add_capsule(
		knee,
		Vector3(0.0, -0.2, 0.0),
		0.096,
		0.39,
		socks_material
	)
	var boot := _add_sphere(
		knee,
		Vector3(0.0, -0.43, -0.085),
		0.14,
		boots_material
	)
	boot.scale = Vector3(0.82, 0.5, 1.52)
	return [hip, knee]


func _build_arm(
	pivot_position: Vector3,
	sleeve_material: Material,
	skin_material: Material
) -> Array[Node3D]:
	var shoulder := Node3D.new()
	shoulder.position = pivot_position
	visual_root.add_child(shoulder)
	var shoulder_cap := _add_sphere(
		shoulder,
		Vector3.ZERO,
		0.132,
		sleeve_material
	)
	shoulder_cap.scale = Vector3(0.92, 1.08, 0.86)
	_add_capsule(
		shoulder,
		Vector3(0.0, -0.14, 0.0),
		0.1,
		0.29,
		sleeve_material
	)
	var elbow := Node3D.new()
	elbow.position = Vector3(0.0, -0.31, 0.0)
	shoulder.add_child(elbow)
	_add_sphere(
		elbow,
		Vector3.ZERO,
		0.085,
		skin_material
	)
	_add_capsule(
		elbow,
		Vector3(0.0, -0.15, 0.0),
		0.078,
		0.3,
		skin_material
	)
	var hand := _add_sphere(
		elbow,
		Vector3(0.0, -0.33, 0.0),
		0.09,
		skin_material
	)
	hand.scale = Vector3(0.82, 1.08, 0.78)
	return [shoulder, elbow]


func _animate_run(delta: float) -> void:
	if stumble_timer > 0.0:
		return
	animation_time += delta * (6.2 + movement_speed * 0.72)
	var stride_wave := sin(animation_time)
	var stride := stride_wave * 0.72
	left_leg_pivot.rotation.x = stride
	right_leg_pivot.rotation.x = -stride
	left_knee_pivot.rotation.x = maxf(0.0, -stride_wave) * 0.92
	right_knee_pivot.rotation.x = maxf(0.0, stride_wave) * 0.92
	left_arm_pivot.rotation.x = -stride * 0.68
	right_arm_pivot.rotation.x = stride * 0.68
	left_arm_pivot.rotation.z = -0.08
	right_arm_pivot.rotation.z = 0.08
	left_elbow_pivot.rotation.x = -0.24 - maxf(0.0, stride_wave) * 0.22
	right_elbow_pivot.rotation.x = -0.24 - maxf(0.0, -stride_wave) * 0.22
	torso.rotation.x = -0.055
	torso.rotation.y = stride_wave * 0.065
	torso.rotation.z = sin(animation_time * 2.0) * 0.022
	var step_bounce := 0.5 - 0.5 * cos(animation_time * 2.0)
	visual_root.position.y = step_bounce * 0.038
	visual_root.position.x = stride_wave * 0.012


func _animate_idle(delta: float) -> void:
	if stumble_timer > 0.0:
		return
	animation_time += delta * 1.35
	left_leg_pivot.rotation.x = lerp_angle(
		left_leg_pivot.rotation.x,
		0.0,
		clampf(delta * 8.0, 0.0, 1.0)
	)
	right_leg_pivot.rotation.x = lerp_angle(
		right_leg_pivot.rotation.x,
		0.0,
		clampf(delta * 8.0, 0.0, 1.0)
	)
	left_knee_pivot.rotation.x = lerp_angle(
		left_knee_pivot.rotation.x,
		0.04,
		clampf(delta * 7.0, 0.0, 1.0)
	)
	right_knee_pivot.rotation.x = lerp_angle(
		right_knee_pivot.rotation.x,
		0.04,
		clampf(delta * 7.0, 0.0, 1.0)
	)
	left_arm_pivot.rotation.x = lerp_angle(
		left_arm_pivot.rotation.x,
		sin(animation_time * 0.63) * 0.025,
		clampf(delta * 7.0, 0.0, 1.0)
	)
	right_arm_pivot.rotation.x = lerp_angle(
		right_arm_pivot.rotation.x,
		-sin(animation_time * 0.63) * 0.025,
		clampf(delta * 7.0, 0.0, 1.0)
	)
	left_arm_pivot.rotation.z = lerp_angle(
		left_arm_pivot.rotation.z,
		-0.045,
		clampf(delta * 7.0, 0.0, 1.0)
	)
	right_arm_pivot.rotation.z = lerp_angle(
		right_arm_pivot.rotation.z,
		0.045,
		clampf(delta * 7.0, 0.0, 1.0)
	)
	left_elbow_pivot.rotation.x = lerp_angle(
		left_elbow_pivot.rotation.x,
		-0.12,
		clampf(delta * 7.0, 0.0, 1.0)
	)
	right_elbow_pivot.rotation.x = lerp_angle(
		right_elbow_pivot.rotation.x,
		-0.12,
		clampf(delta * 7.0, 0.0, 1.0)
	)
	torso.rotation.x = lerp_angle(
		torso.rotation.x,
		0.0,
		clampf(delta * 6.0, 0.0, 1.0)
	)
	torso.rotation.y = lerp_angle(
		torso.rotation.y,
		sin(animation_time * 0.42) * 0.018,
		clampf(delta * 5.0, 0.0, 1.0)
	)
	torso.rotation.z = lerp_angle(
		torso.rotation.z,
		sin(animation_time * 0.5) * 0.008,
		clampf(delta * 7.0, 0.0, 1.0)
	)
	visual_root.position.x = lerpf(
		visual_root.position.x,
		sin(animation_time * 0.5) * 0.006,
		clampf(delta * 5.0, 0.0, 1.0)
	)
	visual_root.position.y = lerpf(
		visual_root.position.y,
		sin(animation_time) * 0.008,
		clampf(delta * 5.0, 0.0, 1.0)
	)


func _animate_stumble() -> void:
	var progress := clampf(
		stumble_elapsed / maxf(stumble_duration, 0.001),
		0.0,
		1.0
	)
	var impact := _smooth_range(progress, 0.0, 0.16)
	var fall := _smooth_range(progress, 0.16, 0.56)
	var recovery := _smooth_range(progress, 0.72, 1.0)
	var fall_amount := (
		impact * 0.16
		if progress < 0.16
		else lerpf(0.16, 1.0, fall)
		if progress < 0.56
		else 1.0
		if progress < 0.72
		else 1.0 - recovery
	)
	var side := signf(stumble_lean_degrees)
	var lean := deg_to_rad(absf(stumble_lean_degrees)) * side
	visual_root.rotation.z = lean * fall_amount
	visual_root.rotation.x = -0.12 * fall_amount
	visual_root.position.x = side * 0.12 * fall_amount
	visual_root.position.y = 0.15 * sin(fall_amount * PI * 0.5)
	torso.rotation.x = 0.2 * impact - 0.08 * fall_amount
	torso.rotation.y = -side * 0.22 * fall_amount
	left_leg_pivot.rotation.x = -0.28 * fall_amount
	right_leg_pivot.rotation.x = 0.48 * fall_amount
	left_knee_pivot.rotation.x = 0.62 * fall_amount
	right_knee_pivot.rotation.x = 0.92 * fall_amount
	left_arm_pivot.rotation.x = -0.52 * fall_amount
	right_arm_pivot.rotation.x = 0.38 * fall_amount
	left_arm_pivot.rotation.z = -0.72 * fall_amount
	right_arm_pivot.rotation.z = 0.8 * fall_amount
	left_elbow_pivot.rotation.x = -0.55 * fall_amount
	right_elbow_pivot.rotation.x = -0.4 * fall_amount


func _animate_tackle() -> void:
	var progress := clampf(
		tackle_elapsed / maxf(tackle_duration, 0.001),
		0.0,
		1.0
	)
	var drive := _smooth_range(progress, 0.0, 0.38)
	var recover := _smooth_range(progress, 0.58, 1.0)
	var amount := drive if progress < 0.58 else 1.0 - recover
	var tackling_leg := (
		left_leg_pivot
		if tackle_side < 0.0
		else right_leg_pivot
	)
	var tackling_knee := (
		left_knee_pivot
		if tackle_side < 0.0
		else right_knee_pivot
	)
	var support_leg := (
		right_leg_pivot
		if tackle_side < 0.0
		else left_leg_pivot
	)
	var support_knee := (
		right_knee_pivot
		if tackle_side < 0.0
		else left_knee_pivot
	)
	visual_root.position.y = -0.12 * amount
	visual_root.position.z = -0.16 * amount
	visual_root.rotation.x = -0.18 * amount
	torso.rotation.x = -0.18 * amount
	torso.rotation.z = tackle_side * 0.12 * amount
	tackling_leg.rotation.x = 1.02 * amount
	tackling_knee.rotation.x = 0.12 * amount
	support_leg.rotation.x = -0.38 * amount
	support_knee.rotation.x = 1.05 * amount
	left_arm_pivot.rotation.x = 0.42 * amount
	right_arm_pivot.rotation.x = -0.42 * amount
	left_arm_pivot.rotation.z = -0.5 * amount
	right_arm_pivot.rotation.z = 0.5 * amount
	left_elbow_pivot.rotation.x = -0.42 * amount
	right_elbow_pivot.rotation.x = -0.42 * amount


func _smooth_range(value: float, start: float, finish: float) -> float:
	if is_equal_approx(start, finish):
		return 1.0
	var normalized := clampf((value - start) / (finish - start), 0.0, 1.0)
	return normalized * normalized * (3.0 - 2.0 * normalized)


func _add_capsule(
	parent: Node3D,
	mesh_position: Vector3,
	radius: float,
	height: float,
	material: Material
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh.rings = 8
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = mesh_position
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mesh_instance)
	return mesh_instance


func _add_sphere(
	parent: Node3D,
	mesh_position: Vector3,
	radius: float,
	material: Material
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 12
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = mesh_position
	parent.add_child(mesh_instance)
	return mesh_instance


func _add_box(
	parent: Node3D,
	mesh_position: Vector3,
	size: Vector3,
	material: Material
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = mesh_position
	parent.add_child(mesh_instance)
	return mesh_instance


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.0
	material.metallic_specular = 0.28
	material.roughness = roughness
	return material
