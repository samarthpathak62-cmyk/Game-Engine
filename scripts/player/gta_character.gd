@tool
extends CharacterBody3D
class_name GTACharacter
## GTACharacter
## No-Code 3rd-Person GTA Protagonist Controller with SpringArm Camera,
## procedural walk/sprint animation, 1-slot custom .glb model support, and Car Enter/Hijack.

@export_group("Identity & Role")
@export var character_name: String = "Franklin"
@export_range(0, 2, 1) var protagonist_slot: int = 0
@export var is_starting_player: bool = true

@export_group("Appearance (No-Code)")
@export var outfit_color: Color = Color(0.16, 0.58, 0.32):
	set(value):
		outfit_color = value
		_rebuild_character()
@export var custom_character_model: PackedScene:
	set(value):
		custom_character_model = value
		_rebuild_character()

@export_group("Movement Sliders")
@export_range(2.0, 12.0, 0.2) var walk_speed: float = 5.2
@export_range(5.0, 18.0, 0.2) var sprint_speed: float = 9.2
@export_range(3.0, 12.0, 0.2) var jump_velocity: float = 5.6
@export_range(0.0005, 0.008, 0.0002) var mouse_sensitivity: float = 0.0026

var _rig_root: Node3D = null
var _visual_pivot: Node3D = null
var _cam_yaw: Node3D = null
var _spring_arm: SpringArm3D = null
var _camera: Camera3D = null

var _left_arm: Node3D = null
var _right_arm: Node3D = null
var _left_leg: Node3D = null
var _right_leg: Node3D = null

var _player_controlled: bool = false
var _inside_vehicle: Node3D = null
var _nearest_vehicle: Node3D = null
var _anim_phase: float = 0.0
var _mouse_idle_time: float = 2.0
var _gravity: float = 16.0


func _ready() -> void:
	add_to_group(&"player")
	_rebuild_character()
	if Engine.is_editor_hint():
		return

	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * 1.45
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("register_protagonist"):
		gm.call("register_protagonist", self, protagonist_slot, is_starting_player)
	set_player_controlled(is_starting_player)


func set_player_controlled(enabled: bool) -> void:
	_player_controlled = enabled
	if _camera != null and not Engine.is_editor_hint():
		if enabled and _inside_vehicle == null:
			_camera.make_current()


func on_entered_vehicle(vehicle: Node3D) -> void:
	_inside_vehicle = vehicle
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func on_exited_vehicle(exit_global_pos: Vector3, exit_yaw: float) -> void:
	_inside_vehicle = null
	process_mode = Node.PROCESS_MODE_INHERIT
	global_position = exit_global_pos
	velocity = Vector3.ZERO
	visible = true
	if _visual_pivot != null:
		_visual_pivot.rotation.y = exit_yaw
	if _cam_yaw != null:
		_cam_yaw.rotation.y = exit_yaw + PI
	set_player_controlled(true)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not _player_controlled or _inside_vehicle != null:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event.is_action_pressed(&"toggle_mouse"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_idle_time = 0.0
		if _cam_yaw != null:
			_cam_yaw.rotation.y -= event.relative.x * mouse_sensitivity
		if _spring_arm != null:
			_spring_arm.rotation.x = clampf(
				_spring_arm.rotation.x - event.relative.y * mouse_sensitivity,
				deg_to_rad(-52.0),
				deg_to_rad(28.0)
			)

	if event.is_action_pressed(&"interact_vehicle"):
		_try_enter_nearest_vehicle()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _inside_vehicle != null:
		return

	_mouse_idle_time += delta

	if not is_on_floor():
		velocity.y -= _gravity * delta

	if not _player_controlled:
		velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
		move_and_slide()
		_animate_limbs(0.0, delta)
		return

	if Input.is_action_just_pressed(&"jump_handbrake") and is_on_floor():
		velocity.y = jump_velocity

	var input_vec: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var is_sprinting: bool = Input.is_action_pressed(&"sprint_boost")
	var target_speed: float = sprint_speed if is_sprinting else walk_speed

	var cam_basis: Basis = _cam_yaw.global_transform.basis if _cam_yaw != null else global_transform.basis
	var forward_dir: Vector3 = -cam_basis.z
	forward_dir.y = 0.0
	forward_dir = forward_dir.normalized()
	var right_dir: Vector3 = cam_basis.x
	right_dir.y = 0.0
	right_dir = right_dir.normalized()

	var move_dir: Vector3 = (right_dir * input_vec.x + forward_dir * (-input_vec.y)).normalized()

	if move_dir.length_squared() > 0.001:
		velocity.x = move_toward(velocity.x, move_dir.x * target_speed, 28.0 * delta)
		velocity.z = move_toward(velocity.z, move_dir.z * target_speed, 28.0 * delta)

		var target_yaw: float = atan2(move_dir.x, move_dir.z)
		if _visual_pivot != null:
			_visual_pivot.rotation.y = lerp_angle(_visual_pivot.rotation.y, target_yaw, 12.0 * delta)

		# Gentle auto-follow camera for trackpad / keyboard-only play
		if _mouse_idle_time > 1.0 and _cam_yaw != null and absf(input_vec.x) > 0.2:
			_cam_yaw.rotation.y = lerp_angle(_cam_yaw.rotation.y, target_yaw + PI, 1.8 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 24.0 * delta)

	move_and_slide()

	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	_animate_limbs(horizontal_speed, delta)

	if _camera != null:
		var desired_fov: float = 74.0 if (is_sprinting and horizontal_speed > 6.0) else 66.0
		_camera.fov = lerpf(_camera.fov, desired_fov, 6.0 * delta)

	_scan_nearby_vehicles()


func _scan_nearby_vehicles() -> void:
	_nearest_vehicle = null
	var best_dist: float = 4.0
	for node: Node in get_tree().get_nodes_in_group(&"vehicles"):
		if node is Node3D:
			var d: float = global_position.distance_to(node.global_position)
			if d < best_dist:
				best_dist = d
				_nearest_vehicle = node

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("set_interaction_prompt"):
		if _nearest_vehicle != null:
			var vname: String = String(_nearest_vehicle.get("vehicle_name"))
			gm.call("set_interaction_prompt", "Press [F] to Drive " + vname)
		else:
			gm.call("set_interaction_prompt", "")


func _try_enter_nearest_vehicle() -> void:
	if _nearest_vehicle != null and _nearest_vehicle.has_method("enter_driver"):
		_nearest_vehicle.call("enter_driver", self)


func _animate_limbs(speed: float, delta: float) -> void:
	if _left_leg == null or _right_leg == null or _left_arm == null or _right_arm == null:
		return
	if speed > 0.25 and is_on_floor():
		_anim_phase += delta * (6.0 + speed * 1.15)
		var swing: float = sin(_anim_phase) * clampf(speed / sprint_speed, 0.25, 0.85)
		_left_leg.rotation.x = swing
		_right_leg.rotation.x = -swing
		_left_arm.rotation.x = -swing * 0.75
		_right_arm.rotation.x = swing * 0.75
	else:
		_left_leg.rotation.x = lerpf(_left_leg.rotation.x, 0.0, 10.0 * delta)
		_right_leg.rotation.x = lerpf(_right_leg.rotation.x, 0.0, 10.0 * delta)
		_left_arm.rotation.x = lerpf(_left_arm.rotation.x, 0.0, 10.0 * delta)
		_right_arm.rotation.x = lerpf(_right_arm.rotation.x, 0.0, 10.0 * delta)


func _rebuild_character() -> void:
	if _rig_root != null and is_instance_valid(_rig_root):
		_rig_root.queue_free()
		_rig_root = null

	# Clean any older internal collisions
	for child: Node in get_children(true):
		if child.get_meta("gta_internal", false):
			child.queue_free()

	var col := CollisionShape3D.new()
	col.set_meta("gta_internal", true)
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.8
	col.shape = cap
	col.position = Vector3(0.0, 0.9, 0.0)
	add_child(col, false, Node.INTERNAL_MODE_BACK)

	_rig_root = Node3D.new()
	_rig_root.set_meta("gta_internal", true)
	add_child(_rig_root, false, Node.INTERNAL_MODE_BACK)

	_visual_pivot = Node3D.new()
	_rig_root.add_child(_visual_pivot)

	if custom_character_model != null:
		var custom_inst: Node = custom_character_model.instantiate()
		_visual_pivot.add_child(custom_inst)
		_left_arm = null
		_right_arm = null
		_left_leg = null
		_right_leg = null
	else:
		_build_stylized_human(_visual_pivot)

	# 3rd-person SpringArm Camera Rig
	_cam_yaw = Node3D.new()
	_cam_yaw.position = Vector3(0.0, 1.52, 0.0)
	_cam_yaw.rotation.y = PI
	_rig_root.add_child(_cam_yaw)

	_spring_arm = SpringArm3D.new()
	_spring_arm.spring_length = 4.1
	_spring_arm.margin = 0.25
	_spring_arm.rotation.x = deg_to_rad(-14.0)
	_spring_arm.add_excluded_object(get_rid())
	_cam_yaw.add_child(_spring_arm)

	_camera = Camera3D.new()
	_camera.fov = 66.0
	_camera.near = 0.1
	_camera.far = 600.0
	_spring_arm.add_child(_camera)


func _build_stylized_human(parent_node: Node3D) -> void:
	var jacket_mat := StandardMaterial3D.new()
	jacket_mat.albedo_color = outfit_color
	jacket_mat.roughness = 0.65

	var jeans_mat := StandardMaterial3D.new()
	jeans_mat.albedo_color = Color(0.14, 0.17, 0.24)
	jeans_mat.roughness = 0.85

	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.76, 0.56, 0.42)
	skin_mat.roughness = 0.7

	var glasses_mat := StandardMaterial3D.new()
	glasses_mat.albedo_color = Color(0.06, 0.06, 0.08)
	glasses_mat.metallic = 0.8
	glasses_mat.roughness = 0.15

	# Torso
	var torso := MeshInstance3D.new()
	var torso_mesh := BoxMesh.new()
	torso_mesh.size = Vector3(0.48, 0.62, 0.26)
	torso.mesh = torso_mesh
	torso.material_override = jacket_mat
	torso.position = Vector3(0.0, 1.1, 0.0)
	parent_node.add_child(torso)

	# Head
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.32, 0.34, 0.32)
	head.mesh = head_mesh
	head.material_override = skin_mat
	head.position = Vector3(0.0, 1.62, 0.0)
	parent_node.add_child(head)

	# Sunglasses (faces +Z forward direction)
	var shades := MeshInstance3D.new()
	var shades_mesh := BoxMesh.new()
	shades_mesh.size = Vector3(0.30, 0.08, 0.06)
	shades.mesh = shades_mesh
	shades.material_override = glasses_mat
	shades.position = Vector3(0.0, 1.65, 0.15)
	parent_node.add_child(shades)

	# Limbs with shoulder/hip pivots
	_left_arm = _make_limb(Vector3(0.33, 1.36, 0.0), Vector3(0.15, 0.54, 0.15), jacket_mat)
	_right_arm = _make_limb(Vector3(-0.33, 1.36, 0.0), Vector3(0.15, 0.54, 0.15), jacket_mat)
	_left_leg = _make_limb(Vector3(0.13, 0.78, 0.0), Vector3(0.18, 0.76, 0.18), jeans_mat)
	_right_leg = _make_limb(Vector3(-0.13, 0.78, 0.0), Vector3(0.18, 0.76, 0.18), jeans_mat)

	parent_node.add_child(_left_arm)
	parent_node.add_child(_right_arm)
	parent_node.add_child(_left_leg)
	parent_node.add_child(_right_leg)


func _make_limb(pivot_pos: Vector3, limb_size: Vector3, mat: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	var mesh_inst := MeshInstance3D.new()
	var bmesh := BoxMesh.new()
	bmesh.size = limb_size
	mesh_inst.mesh = bmesh
	mesh_inst.material_override = mat
	mesh_inst.position = Vector3(0.0, -limb_size.y * 0.5, 0.0)
	pivot.add_child(mesh_inst)
	return pivot
