@tool
extends VehicleBody3D
class_name GTAVehicle
## GTAVehicle
## No-Code 4-Wheel Raycast GTA Vehicle (Sports, Police Cruiser, SUV, Sedan)
## Supports Player Driving, Handbrake Drifting, Nitro Boost, Headlights, Police Sirens,
## AI Traffic Autopilot, Police Pursuit AI, and 1-Slot Custom .glb Car Model replacement.

enum VehiclePreset {
	SPORTS = 0,
	POLICE = 1,
	SUV = 2,
	SEDAN = 3,
}

@export_group("Vehicle Preset & Look")
@export var vehicle_name: String = "Infernus GT"
@export var vehicle_preset: VehiclePreset = VehiclePreset.SPORTS:
	set(value):
		vehicle_preset = value
		_apply_preset_defaults()
		_rebuild_vehicle()
@export var body_color: Color = Color(0.92, 0.16, 0.18):
	set(value):
		body_color = value
		_rebuild_vehicle()
@export var custom_car_model: PackedScene:
	set(value):
		custom_car_model = value
		_rebuild_vehicle()

@export_group("Handling & Speed Sliders")
@export_range(40.0, 350.0, 5.0) var max_engine_force: float = 145.0
@export_range(60.0, 280.0, 5.0) var max_speed_kmh: float = 175.0
@export_range(0.2, 0.65, 0.02) var steer_limit: float = 0.42
@export_range(0.8, 3.0, 0.1) var grip_friction: float = 1.65
@export_range(1.1, 2.5, 0.1) var nitro_multiplier: float = 1.65

@export_group("AI Behavior (No-Code Toggles)")
@export var ai_traffic_mode: bool = false
@export var police_pursuit_ai: bool = false

var current_driver: Node3D = null
var speed_kmh: float = 0.0
var nitro_charge: float = 100.0
var is_boosting: bool = false
var siren_active: bool = false
var headlights_on: bool = true

var _steer_target: float = 0.0
var _siren_timer: float = 0.0
var _cam_yaw_offset: float = 0.0
var _cam_idle_timer: float = 2.0

var _cam_pivot: Node3D = null
var _spring_arm: SpringArm3D = null
var _camera: Camera3D = null
var _front_ray: RayCast3D = null
var _rear_wheels: Array[VehicleWheel3D] = []
var _headlights: Array[SpotLight3D] = []
var _siren_red_light: OmniLight3D = null
var _siren_blue_light: OmniLight3D = null


func _ready() -> void:
	add_to_group(&"vehicles")
	if vehicle_preset == VehiclePreset.POLICE or police_pursuit_ai:
		add_to_group(&"police")

	mass = 55.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, 0.12, 0.0)

	_rebuild_vehicle()
	if Engine.is_editor_hint():
		return


func enter_driver(character: Node3D) -> void:
	if current_driver != null:
		return

	var hijacked_ai: bool = ai_traffic_mode or police_pursuit_ai
	ai_traffic_mode = false
	current_driver = character

	if character.has_method("on_entered_vehicle"):
		character.call("on_entered_vehicle", self)

	if _camera != null:
		_cam_yaw_offset = 0.0
		_camera.make_current()

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null:
		if gm.has_method("notify_entered_vehicle"):
			gm.call("notify_entered_vehicle", character, self)
		if hijacked_ai and gm.has_method("report_crime"):
			gm.call("report_crime", 1, "GRAND THEFT AUTO: " + vehicle_name)


func exit_driver() -> void:
	if current_driver == null:
		return

	var exiting_char: Node3D = current_driver
	current_driver = null
	engine_force = 0.0
	brake = 2.5
	is_boosting = false

	# Place character cleanly beside driver's left door (+X in +Z-forward car)
	var exit_pos: Vector3 = global_position + global_transform.basis.x * 2.1 + Vector3(0.0, 0.45, 0.0)
	var forward_vec: Vector3 = global_transform.basis.z
	var car_yaw: float = atan2(forward_vec.x, forward_vec.z)

	if exiting_char.has_method("on_exited_vehicle"):
		exiting_char.call("on_exited_vehicle", exit_pos, car_yaw)

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("notify_exited_vehicle"):
		gm.call("notify_exited_vehicle", exiting_char)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or current_driver == null:
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_cam_idle_timer = 0.0
		_cam_yaw_offset -= event.relative.x * 0.0028

	if event.is_action_pressed(&"toggle_mouse"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event.is_action_pressed(&"interact_vehicle"):
		exit_driver()
	elif event.is_action_pressed(&"headlights"):
		_toggle_headlights()
	elif event.is_action_pressed(&"horn_siren"):
		siren_active = not siren_active


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	speed_kmh = linear_velocity.length() * 3.6
	_update_siren_lights(delta)

	if current_driver != null:
		_process_player_driving(delta)
	elif police_pursuit_ai:
		_process_police_ai(delta)
	elif ai_traffic_mode:
		_process_traffic_ai(delta)
	else:
		engine_force = 0.0
		brake = 1.8
		steering = move_toward(steering, 0.0, 2.0 * delta)


func _process_player_driving(delta: float) -> void:
	_cam_idle_timer += delta
	if _cam_idle_timer > 1.2 and speed_kmh > 4.0:
		_cam_yaw_offset = lerpf(_cam_yaw_offset, 0.0, 3.2 * delta)
	if _cam_pivot != null:
		_cam_pivot.rotation.y = PI + _cam_yaw_offset

	var steer_in: float = Input.get_axis(&"move_right", &"move_left")
	var speed_factor: float = clampf(1.0 - (speed_kmh / (max_speed_kmh * 1.45)), 0.42, 1.0)
	_steer_target = steer_in * steer_limit * speed_factor
	steering = move_toward(steering, _steer_target, 2.2 * delta)

	var throttle: float = Input.get_action_strength(&"move_forward")
	var rev_in: float = Input.get_action_strength(&"move_back")
	var handbrake: bool = Input.is_action_pressed(&"jump_handbrake")
	var want_boost: bool = Input.is_action_pressed(&"sprint_boost") and throttle > 0.1 and nitro_charge > 2.0

	is_boosting = want_boost
	if is_boosting:
		nitro_charge = maxf(0.0, nitro_charge - 28.0 * delta)
	else:
		nitro_charge = minf(100.0, nitro_charge + 12.0 * delta)

	var forward_dot: float = linear_velocity.dot(global_transform.basis.z)

	if handbrake:
		engine_force = 0.0
		brake = 2.6
		_set_rear_slip(0.48)
	else:
		_set_rear_slip(grip_friction)
		if throttle > 0.05:
			brake = 0.0
			if speed_kmh < max_speed_kmh:
				var low_speed_boost: float = 1.35 if speed_kmh < 28.0 else 1.0
				var boost_mult: float = nitro_multiplier if is_boosting else 1.0
				engine_force = max_engine_force * throttle * low_speed_boost * boost_mult
			else:
				engine_force = 0.0
		elif rev_in > 0.05:
			if forward_dot > 1.5:
				engine_force = 0.0
				brake = 4.2 * rev_in
			else:
				brake = 0.0
				engine_force = -max_engine_force * 0.68 * rev_in
		else:
			engine_force = 0.0
			brake = 0.35

	if _camera != null:
		var target_fov: float = 78.0 if is_boosting else clampf(66.0 + speed_kmh * 0.05, 66.0, 75.0)
		_camera.fov = lerpf(_camera.fov, target_fov, 5.0 * delta)


func _process_police_ai(delta: float) -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	var stars: int = int(gm.get("wanted_level")) if gm != null else 0
	if stars <= 0:
		siren_active = false
		engine_force = 0.0
		brake = 2.0
		return

	siren_active = true
	var target: Node3D = (gm.call("get_focus_target") as Node3D) if (gm != null and gm.has_method("get_focus_target")) else null
	if not is_instance_valid(target):
		engine_force = 0.0
		return

	var to_target: Vector3 = target.global_position - global_position
	var dist: float = to_target.length()
	var local_dir: Vector3 = global_transform.basis.inverse() * to_target.normalized()

	var desired_steer: float = clampf(atan2(local_dir.x, local_dir.z), -steer_limit, steer_limit)
	steering = move_toward(steering, desired_steer, 2.5 * delta)

	if dist > 4.5 and speed_kmh < (95.0 + float(stars) * 15.0):
		brake = 0.0
		engine_force = max_engine_force * 0.85
	else:
		engine_force = 0.0
		brake = 1.5


func _process_traffic_ai(delta: float) -> void:
	var blocked: bool = _front_ray != null and _front_ray.is_colliding()
	if blocked:
		engine_force = 0.0
		brake = 3.2
		steering = move_toward(steering, steer_limit * 0.65, 1.5 * delta)
	else:
		brake = 0.0
		steering = move_toward(steering, 0.0, 1.5 * delta)
		if speed_kmh < 42.0:
			engine_force = max_engine_force * 0.45
		else:
			engine_force = 0.0


func _set_rear_slip(slip_val: float) -> void:
	for rw: VehicleWheel3D in _rear_wheels:
		if is_instance_valid(rw):
			rw.wheel_friction_slip = slip_val


func _toggle_headlights() -> void:
	headlights_on = not headlights_on
	for light: SpotLight3D in _headlights:
		if is_instance_valid(light):
			light.visible = headlights_on


func _update_siren_lights(delta: float) -> void:
	if _siren_red_light == null or _siren_blue_light == null:
		return
	if not siren_active:
		_siren_red_light.visible = false
		_siren_blue_light.visible = false
		return
	_siren_timer += delta * 9.0
	var red_phase: bool = sin(_siren_timer) >= 0.0
	_siren_red_light.visible = red_phase
	_siren_blue_light.visible = not red_phase


func _apply_preset_defaults() -> void:
	match vehicle_preset:
		VehiclePreset.SPORTS:
			vehicle_name = "Infernus GT"
			max_engine_force = 155.0
			max_speed_kmh = 185.0
			body_color = Color(0.92, 0.16, 0.18)
		VehiclePreset.POLICE:
			vehicle_name = "LSPD Cruiser"
			max_engine_force = 140.0
			max_speed_kmh = 165.0
			body_color = Color(0.10, 0.12, 0.16)
		VehiclePreset.SUV:
			vehicle_name = "Goliath 4x4"
			max_engine_force = 135.0
			max_speed_kmh = 140.0
			body_color = Color(0.18, 0.42, 0.28)
		VehiclePreset.SEDAN:
			vehicle_name = "Los Santos Taxi"
			max_engine_force = 115.0
			max_speed_kmh = 135.0
			body_color = Color(0.95, 0.76, 0.12)


func _rebuild_vehicle() -> void:
	for child: Node in get_children(true):
		if child.get_meta("gta_internal", false):
			child.queue_free()

	_rear_wheels.clear()
	_headlights.clear()
	_siren_red_light = null
	_siren_blue_light = null

	var is_suv: bool = vehicle_preset == VehiclePreset.SUV
	var is_sports: bool = vehicle_preset == VehiclePreset.SPORTS
	var is_police: bool = vehicle_preset == VehiclePreset.POLICE

	var chassis_h: float = 0.62 if is_suv else (0.44 if is_sports else 0.52)
	var wheel_rad: float = 0.40 if is_suv else 0.34

	# Physics Collision Box
	var col := CollisionShape3D.new()
	col.set_meta("gta_internal", true)
	var box := BoxShape3D.new()
	box.size = Vector3(1.85, chassis_h + 0.48, 4.15)
	col.shape = box
	col.position = Vector3(0.0, 0.72, 0.0)
	add_child(col, false, Node.INTERNAL_MODE_BACK)

	# 4 Raycast VehicleWheel3D nodes (+Z is forward in Godot VehicleBody3D)
	var wheel_positions: Array[Dictionary] = [
		{"name": "WheelFL", "pos": Vector3(0.92, wheel_rad, 1.32), "steer": true},
		{"name": "WheelFR", "pos": Vector3(-0.92, wheel_rad, 1.32), "steer": true},
		{"name": "WheelRL", "pos": Vector3(0.92, wheel_rad, -1.28), "steer": false},
		{"name": "WheelRR", "pos": Vector3(-0.92, wheel_rad, -1.28), "steer": false},
	]

	var tire_mat := StandardMaterial3D.new()
	tire_mat.albedo_color = Color(0.11, 0.11, 0.12)
	tire_mat.roughness = 0.88

	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.82, 0.84, 0.88)
	rim_mat.metallic = 0.85
	rim_mat.roughness = 0.25

	for wp: Dictionary in wheel_positions:
		var wheel := VehicleWheel3D.new()
		wheel.name = String(wp["name"])
		wheel.set_meta("gta_internal", true)
		wheel.position = wp["pos"] as Vector3
		wheel.use_as_traction = true
		wheel.use_as_steering = bool(wp["steer"])
		wheel.wheel_radius = wheel_rad
		wheel.wheel_roll_influence = 0.32
		wheel.wheel_friction_slip = grip_friction
		wheel.suspension_travel = 0.35
		wheel.suspension_stiffness = 42.0
		wheel.damping_compression = 0.85
		wheel.damping_relaxation = 0.88
		add_child(wheel, false, Node.INTERNAL_MODE_BACK)

		if not bool(wp["steer"]):
			_rear_wheels.append(wheel)

		var tire_mesh_inst := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = wheel_rad
		cyl.bottom_radius = wheel_rad
		cyl.height = 0.28
		cyl.radial_segments = 18
		tire_mesh_inst.mesh = cyl
		tire_mesh_inst.material_override = tire_mat
		tire_mesh_inst.rotation.z = PI * 0.5
		wheel.add_child(tire_mesh_inst)

		var rim_inst := MeshInstance3D.new()
		var rim_cyl := CylinderMesh.new()
		rim_cyl.top_radius = wheel_rad * 0.58
		rim_cyl.bottom_radius = wheel_rad * 0.58
		rim_cyl.height = 0.30
		rim_cyl.radial_segments = 12
		rim_inst.mesh = rim_cyl
		rim_inst.material_override = rim_mat
		rim_inst.rotation.z = PI * 0.5
		wheel.add_child(rim_inst)

	# Visual Car Body Container
	var visual_root := Node3D.new()
	visual_root.set_meta("gta_internal", true)
	add_child(visual_root, false, Node.INTERNAL_MODE_BACK)

	if custom_car_model != null:
		var custom_inst: Node = custom_car_model.instantiate()
		visual_root.add_child(custom_inst)
	else:
		_build_stylized_car_mesh(visual_root, chassis_h, is_sports, is_suv, is_police)

	# Headlights (+Z forward; SpotLight3D shines along -Z so rotate Y by PI)
	for side_x: float in [-0.66, 0.66]:
		var spot := SpotLight3D.new()
		spot.position = Vector3(side_x, 0.68, 2.08)
		spot.rotation.y = PI
		spot.light_color = Color(1.0, 0.96, 0.86)
		spot.light_energy = 2.6
		spot.spot_range = 28.0
		spot.spot_angle = 34.0
		visual_root.add_child(spot)
		_headlights.append(spot)

	# AI obstacle RayCast3D
	_front_ray = RayCast3D.new()
	_front_ray.set_meta("gta_internal", true)
	_front_ray.position = Vector3(0.0, 0.65, 2.15)
	_front_ray.target_position = Vector3(0.0, 0.0, 7.5)
	_front_ray.enabled = true
	add_child(_front_ray, false, Node.INTERNAL_MODE_BACK)

	# Follow Camera Rig
	_cam_pivot = Node3D.new()
	_cam_pivot.set_meta("gta_internal", true)
	_cam_pivot.position = Vector3(0.0, 1.45, 0.0)
	_cam_pivot.rotation.y = PI
	add_child(_cam_pivot, false, Node.INTERNAL_MODE_BACK)

	_spring_arm = SpringArm3D.new()
	_spring_arm.spring_length = 6.2
	_spring_arm.margin = 0.35
	_spring_arm.rotation.x = deg_to_rad(-13.0)
	_spring_arm.add_excluded_object(get_rid())
	_cam_pivot.add_child(_spring_arm)

	_camera = Camera3D.new()
	_camera.fov = 68.0
	_camera.near = 0.1
	_camera.far = 650.0
	_spring_arm.add_child(_camera)


func _build_stylized_car_mesh(parent_node: Node3D, chassis_h: float, is_sports: bool, is_suv: bool, is_police: bool) -> void:
	var paint_mat := StandardMaterial3D.new()
	paint_mat.albedo_color = body_color
	paint_mat.metallic = 0.62
	paint_mat.roughness = 0.24

	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.08, 0.12, 0.18)
	glass_mat.metallic = 0.85
	glass_mat.roughness = 0.10

	# Lower Chassis
	var lower := MeshInstance3D.new()
	var lower_mesh := BoxMesh.new()
	lower_mesh.size = Vector3(1.88, chassis_h, 4.18)
	lower.mesh = lower_mesh
	lower.material_override = paint_mat
	lower.position = Vector3(0.0, 0.56, 0.0)
	parent_node.add_child(lower)

	# Police White Door Stripe
	if is_police:
		var white_mat := StandardMaterial3D.new()
		white_mat.albedo_color = Color(0.95, 0.96, 0.98)
		white_mat.roughness = 0.3
		var door_stripe := MeshInstance3D.new()
		var stripe_mesh := BoxMesh.new()
		stripe_mesh.size = Vector3(1.90, chassis_h * 0.82, 1.85)
		door_stripe.mesh = stripe_mesh
		door_stripe.material_override = white_mat
		door_stripe.position = Vector3(0.0, 0.56, -0.05)
		parent_node.add_child(door_stripe)

	# Upper Cabin
	var cabin := MeshInstance3D.new()
	var cabin_mesh := BoxMesh.new()
	var cabin_len: float = 2.45 if is_suv else (1.78 if is_sports else 2.05)
	var cabin_h: float = 0.56 if is_suv else (0.40 if is_sports else 0.48)
	cabin_mesh.size = Vector3(1.56, cabin_h, cabin_len)
	cabin.mesh = cabin_mesh
	cabin.material_override = glass_mat
	cabin.position = Vector3(0.0, 0.56 + chassis_h * 0.5 + cabin_h * 0.46, -0.18)
	parent_node.add_child(cabin)

	# Roof Cap
	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(1.48, 0.08, cabin_len * 0.86)
	roof.mesh = roof_mesh
	roof.material_override = paint_mat
	roof.position = cabin.position + Vector3(0.0, cabin_h * 0.5, 0.0)
	parent_node.add_child(roof)

	# Sports Rear Wing Spoiler
	if is_sports:
		var wing := MeshInstance3D.new()
		var wing_mesh := BoxMesh.new()
		wing_mesh.size = Vector3(1.78, 0.07, 0.34)
		wing.mesh = wing_mesh
		wing.material_override = paint_mat
		wing.position = Vector3(0.0, 0.98, -1.92)
		parent_node.add_child(wing)

	# Police Rooftop Siren Lightbar
	if is_police:
		var red_mat := StandardMaterial3D.new()
		red_mat.albedo_color = Color(1.0, 0.12, 0.12)
		red_mat.emission_enabled = true
		red_mat.emission = Color(1.0, 0.15, 0.15)
		red_mat.emission_energy_multiplier = 2.6

		var blue_mat := StandardMaterial3D.new()
		blue_mat.albedo_color = Color(0.15, 0.42, 1.0)
		blue_mat.emission_enabled = true
		blue_mat.emission = Color(0.18, 0.48, 1.0)
		blue_mat.emission_energy_multiplier = 2.6

		var bar_y: float = roof.position.y + 0.10
		var red_bar := MeshInstance3D.new()
		var b_mesh := BoxMesh.new()
		b_mesh.size = Vector3(0.52, 0.12, 0.22)
		red_bar.mesh = b_mesh
		red_bar.material_override = red_mat
		red_bar.position = Vector3(0.28, bar_y, -0.15)
		parent_node.add_child(red_bar)

		var blue_bar := MeshInstance3D.new()
		blue_bar.mesh = b_mesh
		blue_bar.material_override = blue_mat
		blue_bar.position = Vector3(-0.28, bar_y, -0.15)
		parent_node.add_child(blue_bar)

		_siren_red_light = OmniLight3D.new()
		_siren_red_light.light_color = Color(1.0, 0.15, 0.15)
		_siren_red_light.light_energy = 3.2
		_siren_red_light.omni_range = 14.0
		_siren_red_light.position = Vector3(0.35, bar_y + 0.2, -0.15)
		_siren_red_light.visible = false
		parent_node.add_child(_siren_red_light)

		_siren_blue_light = OmniLight3D.new()
		_siren_blue_light.light_color = Color(0.2, 0.5, 1.0)
		_siren_blue_light.light_energy = 3.2
		_siren_blue_light.omni_range = 14.0
		_siren_blue_light.position = Vector3(-0.35, bar_y + 0.2, -0.15)
		_siren_blue_light.visible = false
		parent_node.add_child(_siren_blue_light)

	# Glowing Headlight & Taillight Strips
	var hl_mat := StandardMaterial3D.new()
	hl_mat.albedo_color = Color(1.0, 0.96, 0.82)
	hl_mat.emission_enabled = true
	hl_mat.emission = Color(1.0, 0.95, 0.8)
	hl_mat.emission_energy_multiplier = 2.2

	var tl_mat := StandardMaterial3D.new()
	tl_mat.albedo_color = Color(1.0, 0.1, 0.1)
	tl_mat.emission_enabled = true
	tl_mat.emission = Color(1.0, 0.12, 0.12)
	tl_mat.emission_energy_multiplier = 2.0

	for sx: float in [-0.62, 0.62]:
		var hl := MeshInstance3D.new()
		var lamp_m := BoxMesh.new()
		lamp_m.size = Vector3(0.34, 0.14, 0.08)
		hl.mesh = lamp_m
		hl.material_override = hl_mat
		hl.position = Vector3(sx, 0.64, 2.09)
		parent_node.add_child(hl)

		var tl := MeshInstance3D.new()
		tl.mesh = lamp_m
		tl.material_override = tl_mat
		tl.position = Vector3(sx, 0.66, -2.09)
		parent_node.add_child(tl)
