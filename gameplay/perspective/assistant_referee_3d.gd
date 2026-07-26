extends Node3D
class_name AssistantReferee3D

var touchline_x: float = 35.2
var target_z: float = 0.0
var flag_timer: float = 0.0
var flag_pivot: Node3D
var signal_label: Label3D


func setup(side_sign: float) -> void:
	touchline_x = side_sign * 35.2
	global_position = Vector3(touchline_x, 0.0, 0.0)
	rotation.y = deg_to_rad(90.0 if side_sign < 0.0 else -90.0)
	_build_visuals()


func _process(delta: float) -> void:
	global_position.z = move_toward(global_position.z, target_z, delta * 6.5)
	if flag_timer > 0.0:
		flag_timer -= delta
	var raised := flag_timer > 0.0
	flag_pivot.rotation.z = lerp_angle(
		flag_pivot.rotation.z,
		deg_to_rad(-82.0) if raised else deg_to_rad(-8.0),
		clampf(delta * 9.0, 0.0, 1.0)
	)
	signal_label.visible = raised


func follow_offside_line(line_z: float) -> void:
	target_z = clampf(line_z, -46.0, 46.0)


func signal_offside() -> void:
	flag_timer = 4.5


func clear_signal() -> void:
	flag_timer = 0.0


func is_flag_raised() -> bool:
	return flag_timer > 0.0


func _build_visuals() -> void:
	var body_material := _material(Color("#161616"))
	var skin_material := _material(Color("#c98f68"))
	var yellow_material := _material(Color("#facc15"))
	var orange_material := _material(Color("#fb6b24"))

	_add_capsule(Vector3(0.0, 1.12, 0.0), 0.28, 0.88, body_material)
	_add_sphere(Vector3(0.0, 1.82, 0.0), 0.21, skin_material)
	_add_capsule(Vector3(-0.15, 0.4, 0.0), 0.09, 0.68, body_material)
	_add_capsule(Vector3(0.15, 0.4, 0.0), 0.09, 0.68, body_material)

	flag_pivot = Node3D.new()
	flag_pivot.position = Vector3(0.32, 1.18, 0.0)
	flag_pivot.rotation.z = deg_to_rad(-8.0)
	add_child(flag_pivot)
	_add_box_to(
		flag_pivot,
		Vector3(0.0, 0.42, 0.0),
		Vector3(0.035, 0.85, 0.035),
		yellow_material
	)
	_add_box_to(
		flag_pivot,
		Vector3(0.24, 0.73, 0.0),
		Vector3(0.48, 0.34, 0.035),
		orange_material
	)

	signal_label = Label3D.new()
	signal_label.text = "HORS-JEU"
	signal_label.font_size = 48
	signal_label.outline_size = 10
	signal_label.modulate = Color("#fde047")
	signal_label.position = Vector3(0.0, 2.42, 0.0)
	signal_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	signal_label.no_depth_test = true
	signal_label.visible = false
	add_child(signal_label)


func _add_capsule(
	mesh_position: Vector3,
	radius: float,
	height: float,
	material: Material
) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = mesh_position
	add_child(mesh_instance)


func _add_sphere(
	mesh_position: Vector3,
	radius: float,
	material: Material
) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = mesh_position
	add_child(mesh_instance)


func _add_box_to(
	parent: Node3D,
	mesh_position: Vector3,
	size: Vector3,
	material: Material
) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = mesh_position
	parent.add_child(mesh_instance)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	return material
