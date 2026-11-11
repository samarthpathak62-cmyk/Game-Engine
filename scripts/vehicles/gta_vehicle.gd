@tool
extends VehicleBody3D
class_name GTAVehicle
## GTAVehicle
## Real 3D .glb Vehicles (Photorealistic PBR Supercar, Mercedes G63 AMG SUV,
## LSPD Police Cruiser, Los Santos Taxi, Muscle Coupe, Street Sedan) with
## 4-Wheel Raycast Suspension, Handbrake Drift, Nitro, Sirens & Full 360° Mouse Camera.

enum VehiclePreset {
	SUPERCAR_SU7 = 0,
	POLICE_CRUISER = 1,
	GWAGON_LUXURY_SUV = 2,
	CITY_TAXI = 3,
	MUSCLE_COUPE = 4,
	STREET_SEDAN = 5,
	OFFROAD_SUV = 6,
}

const MODEL_PATHS: Array[String] = [
	"res://assets/models/vehicles/supercar_su7.glb",
	"res://assets/models/vehicles/police_cruiser.glb",
	"res://assets/models/vehicles/gwagon_suv.glb",
	"res://assets/models/vehicles/city_taxi.glb",
	"res://assets/models/vehicles/muscle_coupe.glb",
	"res://assets/models/vehicles/street_sedan.glb",
	"res://assets/models/vehicles/offroad_suv.glb",
]

@export_group("Vehicle Model & Preset")
@export var vehicle_name: String = "Pegassi SU7 GT"
@export var vehicle_preset: VehiclePreset = VehiclePreset.SUPERCAR_SU7:
	set(value):
		vehicle_preset = value
		_apply_preset_defaults()
		_rebuild_vehicle()
@export var body_color: Color = Color(0.92, 0.16, 0.18)
@export var custom_car_model: PackedScene:
	set(value):
		custom_car_model = value
		_rebuild_vehicle()

@export_group("Performance & Drift Sliders")
@export_range(50.0, 380.0, 5.0) var max_engine_force: float = 175.0
@export_range(70.0, 300.0, 5.0) var max_speed_kmh: float = 210.0
@export_range(0.22, 0.60, 0.02) var steer_limit: float = 0.42
@export_range(0.9, 3.0, 0.1) var grip_friction: float = 1.75
@export_range(1.1, 2.5, 0.1) var nitro_multiplier: float = 1.7

@export_group("AI Traffic & Police Toggles")
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
var _wheel_spin_angle: float = 0.0
var _cam_yaw_offset: float = 0.0
var _cam_pitch_deg: float = -13.0
var _cam_dist: float = 6.2
var _cam_idle_timer: float = 2.0

var _cam_pivot: Node3D = null
var _spring_arm: SpringArm3D = null
var _camera: Camera3D = null
var _front_ray: RayCast3D = null
var _left_ray: RayCast3D = null
var _right_ray: RayCast3D = null
var _rear_wheels: Array[VehicleWheel3D] = []
var _visual_front_wheels: Array[Node3D] = []
var _visual_all_wheels: Array[Node3D] = []
var _headlights: Array[SpotLight3D] = []
var _siren_red_light: OmniLight3D = null
var _siren_blue_light: OmniLight3D = null


func _ready() -> void:
	add_to_group(&"vehicles")
	if vehicle_preset == VehiclePreset.POLICE_CRUISER or police_pursuit_ai:
		add_to_group(&"police")

	mass = 58.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, 0.10, 0.0)

	_rebuild_vehicle()


func activate_vehicle_camera() -> void:
	if _camera != null and not Engine.is_editor_hint():
		_camera.make_current()


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
		_cam_pitch_deg = -13.0
		_camera.make_current()

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

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
	brake = 2.8
	is_boosting = false

	var exit_pos: Vector3 = global_position + global_transform.basis.x * 2.25 + Vector3(0.0, 0.45, 0.0)
	var forward_vec: Vector3 = global_transform.basis.z
	var car_yaw: float = atan2(forward_vec.x, forward_vec.z)

	if exiting_char.has_method("on_exited_vehicle"):
		exiting_char.call("on_exited_vehicle", exit_pos, car_yaw)

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("notify_exited_vehicle"):
		gm.call("notify_exited_vehicle", exiting_char)


func _is_gameplay_active() -> bool:
	var gm: Node = get_node_or_null("/root/GameManager")
	return gm == null or int(gm.get("app_mode")) == 1


func _get_mouse_sens() -> float:
	var gm: Node = get_node_or_null("/root/GameManager")
	return float(gm.get("mouse_sensitivity")) if gm != null else 0.0026


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or current_driver == null or not _is_gameplay_active():
		return

	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_dist = clampf(_cam_dist - 0.5, 4.2, 10.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_dist = clampf(_cam_dist + 0.5, 4.2, 10.5)

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = _get_mouse_sens()
		_cam_idle_timer = 0.0
		_cam_yaw_offset -= event.relative.x * sens
		_cam_pitch_deg = clampf(_cam_pitch_deg - rad_to_deg(event.relative.y * sens), -48.0, 8.0)

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
	_animate_visual_wheels(delta)

	if not _is_gameplay_active() and current_driver != null:
		engine_force = 0.0
		brake = 2.5
		return

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
	if _cam_idle_timer > 1.6 and speed_kmh > 6.0:
		_cam_yaw_offset = lerpf(_cam_yaw_offset, 0.0, 2.6 * delta)
		_cam_pitch_deg = lerpf(_cam_pitch_deg, -13.0, 2.2 * delta)

	if _cam_pivot != null:
		_cam_pivot.rotation.y = PI + _cam_yaw_offset
	if _spring_arm != null:
		_spring_arm.rotation.x = deg_to_rad(_cam_pitch_deg)
		_spring_arm.spring_length = lerpf(_spring_arm.spring_length, _cam_dist, 8.0 * delta)

	var steer_in: float = Input.get_axis(&"move_right", &"move_left")
	var speed_factor: float = clampf(1.0 - (speed_kmh / (max_speed_kmh * 1.45)), 0.40, 1.0)
	_steer_target = steer_in * steer_limit * speed_factor
	steering = move_toward(steering, _steer_target, 2.35 * delta)

	var throttle: float = Input.get_action_strength(&"move_forward")
	var rev_in: float = Input.get_action_strength(&"move_back")
	var handbrake: bool = Input.is_action_pressed(&"jump_handbrake")
	var want_boost: bool = Input.is_action_pressed(&"sprint_boost") and throttle > 0.1 and nitro_charge > 2.0

	is_boosting = want_boost
	if is_boosting:
		nitro_charge = maxf(0.0, nitro_charge - 26.0 * delta)
	else:
		nitro_charge = minf(100.0, nitro_charge + 14.0 * delta)

	var forward_dot: float = linear_velocity.dot(global_transform.basis.z)

	if handbrake:
		engine_force = 0.0
		brake = 2.6
		_set_rear_slip(0.45)
	else:
		_set_rear_slip(grip_friction)
		if throttle > 0.05:
			brake = 0.0
			if speed_kmh < max_speed_kmh:
				var low_kick: float = 1.40 if speed_kmh < 32.0 else 1.0
				var boost_mult: float = nitro_multiplier if is_boosting else 1.0
				engine_force = max_engine_force * throttle * low_kick * boost_mult
			else:
				engine_force = 0.0
		elif rev_in > 0.05:
			if forward_dot > 1.5:
				engine_force = 0.0
				brake = 4.6 * rev_in
			else:
				brake = 0.0
				engine_force = -max_engine_force * 0.72 * rev_in
		else:
			engine_force = 0.0
			brake = 0.35

	if _camera != null:
		var target_fov: float = 78.0 if is_boosting else clampf(65.0 + speed_kmh * 0.055, 65.0, 76.0)
		_camera.fov = lerpf(_camera.fov, target_fov, 5.5 * delta)


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
	steering = move_toward(steering, desired_steer, 2.6 * delta)

	if dist > 4.5 and speed_kmh < (100.0 + float(stars) * 16.0):
		brake = 0.0
		engine_force = max_engine_force * 0.88
	else:
		engine_force = 0.0
		brake = 1.6


func _process_traffic_ai(delta: float) -> void:
	var front_blocked: bool = _front_ray != null and _front_ray.is_colliding()
	var left_clear: bool = _left_ray == null or not _left_ray.is_colliding()

	# Keep within city bounds (-145..145) by turning smoothly back toward downtown
	var out_of_bounds: bool = absf(global_position.x) > 132.0 or absf(global_position.z) > 132.0
	if out_of_bounds:
		var to_center: Vector3 = (Vector3.ZERO - global_position).normalized()
		var local_c: Vector3 = global_transform.basis.inverse() * to_center
		steering = move_toward(steering, clampf(atan2(local_c.x, local_c.z), -steer_limit, steer_limit), 2.2 * delta)
		brake = 0.0
		engine_force = max_engine_force * 0.45
		return

	if front_blocked:
		var turn_dir: float = steer_limit * (0.85 if left_clear else -0.85)
		steering = move_toward(steering, turn_dir, 2.0 * delta)
		if speed_kmh > 18.0:
			engine_force = 0.0
			brake = 2.4
		else:
			brake = 0.0
			engine_force = max_engine_force * 0.38
	else:
		brake = 0.0
		steering = move_toward(steering, 0.0, 1.8 * delta)
		engine_force = (max_engine_force * 0.48) if speed_kmh < 46.0 else 0.0


func _animate_visual_wheels(delta: float) -> void:
	var forward_spd: float = linear_velocity.dot(global_transform.basis.z)
	_wheel_spin_angle += (forward_spd / 0.34) * delta
	for w: Node3D in _visual_all_wheels:
		if is_instance_valid(w):
			w.rotation.x = _wheel_spin_angle
	for fw: Node3D in _visual_front_wheels:
		if is_instance_valid(fw):
			fw.rotation.y = steering


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
	_siren_timer += delta * 9.5
	var red_phase: bool = sin(_siren_timer) >= 0.0
	_siren_red_light.visible = red_phase
	_siren_blue_light.visible = not red_phase


func _apply_preset_defaults() -> void:
	match vehicle_preset:
		VehiclePreset.SUPERCAR_SU7:
			vehicle_name = "Pegassi SU7 GT"
			max_engine_force = 185.0
			max_speed_kmh = 225.0
		VehiclePreset.POLICE_CRUISER:
			vehicle_name = "LSPD Interceptor"
			max_engine_force = 155.0
			max_speed_kmh = 180.0
		VehiclePreset.GWAGON_LUXURY_SUV:
			vehicle_name = "Benefactor G63 AMG"
			max_engine_force = 165.0
			max_speed_kmh = 175.0
		VehiclePreset.CITY_TAXI:
			vehicle_name = "Downtown Cab Co."
			max_engine_force = 125.0
			max_speed_kmh = 145.0
		VehiclePreset.MUSCLE_COUPE:
			vehicle_name = "Bravado Dominator"
			max_engine_force = 160.0
			max_speed_kmh = 185.0
		VehiclePreset.STREET_SEDAN:
			vehicle_name = "Obey Tailgater"
			max_engine_force = 130.0
			max_speed_kmh = 155.0
		VehiclePreset.OFFROAD_SUV:
			vehicle_name = "Canis Patriot 4x4"
			max_engine_force = 145.0
			max_speed_kmh = 150.0


func _rebuild_vehicle() -> void:
	for child: Node in get_children(true):
		if child.get_meta("gta_internal", false):
			child.queue_free()

	_rear_wheels.clear()
	_visual_front_wheels.clear()
	_visual_all_wheels.clear()
	_headlights.clear()
	_siren_red_light = null
	_siren_blue_light = null

	var is_suv: bool = vehicle_preset == VehiclePreset.GWAGON_LUXURY_SUV or vehicle_preset == VehiclePreset.OFFROAD_SUV
	var is_police: bool = vehicle_preset == VehiclePreset.POLICE_CRUISER
	var wheel_rad: float = 0.38 if is_suv else 0.33

	# Physics Chassis Collision
	var col := CollisionShape3D.new()
	col.set_meta("gta_internal", true)
	var box := BoxShape3D.new()
	box.size = Vector3(1.88, 1.15, 4.25)
	col.shape = box
	col.position = Vector3(0.0, 0.72, 0.0)
	add_child(col, false, Node.INTERNAL_MODE_BACK)

	# 4 Physics Raycast VehicleWheel3D nodes (+Z forward)
	var wheel_defs: Array[Dictionary] = [
		{"name": "WheelFL", "pos": Vector3(0.86, wheel_rad, 1.32), "steer": true},
		{"name": "WheelFR", "pos": Vector3(-0.86, wheel_rad, 1.32), "steer": true},
		{"name": "WheelRL", "pos": Vector3(0.86, wheel_rad, -1.26), "steer": false},
		{"name": "WheelRR", "pos": Vector3(-0.86, wheel_rad, -1.26), "steer": false},
	]

	for wd: Dictionary in wheel_defs:
		var wheel := VehicleWheel3D.new()
		wheel.name = String(wd["name"])
		wheel.set_meta("gta_internal", true)
		wheel.position = wd["pos"] as Vector3
		wheel.use_as_traction = true
		wheel.use_as_steering = bool(wd["steer"])
		wheel.wheel_radius = wheel_rad
		wheel.wheel_roll_influence = 0.28
		wheel.wheel_friction_slip = grip_friction
		wheel.suspension_travel = 0.34
		wheel.suspension_stiffness = 44.0
		wheel.damping_compression = 0.86
		wheel.damping_relaxation = 0.88
		add_child(wheel, false, Node.INTERNAL_MODE_BACK)
		if not bool(wd["steer"]):
			_rear_wheels.append(wheel)

	# Real 3D .glb Vehicle Model
	var visual_root := Node3D.new()
	visual_root.set_meta("gta_internal", true)
	add_child(visual_root, false, Node.INTERNAL_MODE_BACK)

	var packed: PackedScene = custom_car_model
	var model_scale: float = 1.06
	var model_y_offset: float = 0.02
	if packed == null:
		var idx: int = clampi(int(vehicle_preset), 0, MODEL_PATHS.size() - 1)
		packed = load(MODEL_PATHS[idx]) as PackedScene
		if vehicle_preset == VehiclePreset.SUPERCAR_SU7 or vehicle_preset == VehiclePreset.GWAGON_LUXURY_SUV:
			model_scale = 92.0
			model_y_offset = 0.04

	if packed != null:
		var car_inst: Node3D = packed.instantiate() as Node3D
		if car_inst != null:
			car_inst.scale = Vector3(model_scale, model_scale, model_scale)
			car_inst.position = Vector3(0.0, model_y_offset, 0.0)
			visual_root.add_child(car_inst)
			_discover_glb_wheels(car_inst)

	# Police Siren Lights
	if is_police or police_pursuit_ai:
		_siren_red_light = OmniLight3D.new()
		_siren_red_light.light_color = Color(1.0, 0.14, 0.14)
		_siren_red_light.light_energy = 4.2
		_siren_red_light.omni_range = 16.0
		_siren_red_light.position = Vector3(0.35, 1.55, -0.1)
		_siren_red_light.visible = false
		visual_root.add_child(_siren_red_light)

		_siren_blue_light = OmniLight3D.new()
		_siren_blue_light.light_color = Color(0.18, 0.48, 1.0)
		_siren_blue_light.light_energy = 4.2
		_siren_blue_light.omni_range = 16.0
		_siren_blue_light.position = Vector3(-0.35, 1.55, -0.1)
		_siren_blue_light.visible = false
		visual_root.add_child(_siren_blue_light)

	# Headlight Beams
	for side_x: float in [-0.66, 0.66]:
		var spot := SpotLight3D.new()
		spot.position = Vector3(side_x, 0.68, 2.15)
		spot.rotation.y = PI
		spot.light_color = Color(1.0, 0.96, 0.88)
		spot.light_energy = 2.8
		spot.spot_range = 32.0
		spot.spot_angle = 34.0
		visual_root.add_child(spot)
		_headlights.append(spot)

	# AI Traffic Obstacle RayCasts
	_front_ray = _make_ray(Vector3(0.0, 0.65, 2.2), Vector3(0.0, 0.0, 8.5))
	_left_ray = _make_ray(Vector3(0.8, 0.65, 1.8), Vector3(5.0, 0.0, 5.0))
	_right_ray = _make_ray(Vector3(-0.8, 0.65, 1.8), Vector3(-5.0, 0.0, 5.0))

	# 360° Mouse Orbit Chase Camera Rig
	_cam_pivot = Node3D.new()
	_cam_pivot.set_meta("gta_internal", true)
	_cam_pivot.position = Vector3(0.0, 1.48, 0.0)
	_cam_pivot.rotation.y = PI
	add_child(_cam_pivot, false, Node.INTERNAL_MODE_BACK)

	_spring_arm = SpringArm3D.new()
	_spring_arm.spring_length = _cam_dist
	_spring_arm.margin = 0.35
	_spring_arm.rotation.x = deg_to_rad(_cam_pitch_deg)
	_spring_arm.add_excluded_object(get_rid())
	_cam_pivot.add_child(_spring_arm)

	_camera = Camera3D.new()
	_camera.fov = 66.0
	_camera.near = 0.1
	_camera.far = 900.0
	_spring_arm.add_child(_camera)


func _make_ray(origin: Vector3, target_vec: Vector3) -> RayCast3D:
	var r := RayCast3D.new()
	r.set_meta("gta_internal", true)
	r.position = origin
	r.target_position = target_vec
	r.enabled = true
	add_child(r, false, Node.INTERNAL_MODE_BACK)
	return r


func _discover_glb_wheels(car_inst: Node3D) -> void:
	for node: Node in car_inst.find_children("*", "Node3D", true, false):
		var nm: String = node.name.to_lower()
		if nm.ends_with("frontleftwheel") or nm.ends_with("frontrightwheel") or nm == "3dwheel front l" or nm == "3dwheel front r":
			_visual_front_wheels.append(node as Node3D)
			_visual_all_wheels.append(node as Node3D)
		elif nm.ends_with("backwheels") or nm == "3dwheel rear l" or nm == "3dwheel rear r":
			_visual_all_wheels.append(node as Node3D)
