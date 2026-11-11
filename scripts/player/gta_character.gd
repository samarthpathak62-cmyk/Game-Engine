@tool
extends CharacterBody3D
class_name GTACharacter
## GTACharacter (Intel UHD Crash-Proof Optimized)
## Real 3D Rigged & Skeletal-Animated GTA Protagonist Controller with static
## PackedScene caching, safe @export setter guards, 360° Mouse Look & Aim/Shoot.

enum CharacterSkin {
	FRANKLIN_STREET = 0,
	MICHAEL_SUIT = 1,
	TREVOR_BIKER = 2,
	TACTICAL_PBR = 3,
}

const SKIN_PATHS: Array[String] = [
	"res://assets/models/characters/franklin_casual.glb",
	"res://assets/models/characters/michael_suit.glb",
	"res://assets/models/characters/trevor_punk.glb",
	"res://assets/models/characters/protagonist_tactical.glb",
]

const RIFLE_MODEL_PATH: String = "res://assets/models/weapons/assault_rifle.glb"
static var _char_cache: Dictionary = {}

@export_group("Identity & 3D Character Skin")
@export var character_name: String = "Franklin"
@export_range(0, 2, 1) var protagonist_slot: int = 0
@export var is_starting_player: bool = true
@export var character_skin: CharacterSkin = CharacterSkin.FRANKLIN_STREET:
	set(value):
		character_skin = value
		if is_node_ready():
			_rebuild_character()
@export var custom_character_model: PackedScene:
	set(value):
		custom_character_model = value
		if is_node_ready():
			_rebuild_character()

@export_group("Movement & Combat Sliders")
@export_range(2.5, 10.0, 0.2) var walk_speed: float = 4.8
@export_range(6.0, 16.0, 0.2) var sprint_speed: float = 8.8
@export_range(3.5, 11.0, 0.2) var jump_velocity: float = 5.8

var _rig_root: Node3D = null
var _visual_pivot: Node3D = null
var _cam_yaw: Node3D = null
var _spring_arm: SpringArm3D = null
var _camera: Camera3D = null
var _anim_player: AnimationPlayer = null
var _weapon_visual: Node3D = null

var _anim_idle: StringName = &""
var _anim_walk: StringName = &""
var _anim_run: StringName = &""
var _anim_aim: StringName = &""
var _anim_shoot: StringName = &""
var _anim_punch: StringName = &""
var _anim_roll: StringName = &""
var _current_anim: StringName = &""

var _player_controlled: bool = false
var _inside_vehicle: Node3D = null
var _nearest_vehicle: Node3D = null
var _weapon_equipped: bool = true
var _is_aiming: bool = false
var _fire_cooldown: float = 0.0
var _action_lock_timer: float = 0.0
var _desired_cam_dist: float = 3.8
var _gravity: float = 16.5


func _ready() -> void:
	add_to_group(&"player")
	_rebuild_character()
	if Engine.is_editor_hint():
		return

	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * 1.55
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("register_protagonist"):
		gm.call("register_protagonist", self, protagonist_slot, is_starting_player)
	set_player_controlled(is_starting_player)


func set_player_controlled(enabled: bool) -> void:
	_player_controlled = enabled
	if _camera != null and not Engine.is_editor_hint():
		var gm: Node = get_node_or_null("/root/GameManager")
		var in_play: bool = gm == null or int(gm.get("app_mode")) == 1
		if enabled and _inside_vehicle == null and in_play:
			_camera.make_current()


func on_entered_vehicle(vehicle: Node3D) -> void:
	_inside_vehicle = vehicle
	_is_aiming = false
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


func _is_gameplay_active() -> bool:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm == null:
		return true
	return int(gm.get("app_mode")) == 1 and not bool(gm.get("is_switching_character"))


func _get_mouse_sens() -> float:
	var gm: Node = get_node_or_null("/root/GameManager")
	return float(gm.get("mouse_sensitivity")) if gm != null else 0.0026


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not _player_controlled or _inside_vehicle != null:
		return
	if not _is_gameplay_active():
		return

	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_desired_cam_dist = clampf(_desired_cam_dist - 0.45, 2.1, 6.8)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_desired_cam_dist = clampf(_desired_cam_dist + 0.45, 2.1, 6.8)

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = _get_mouse_sens() * (0.65 if _is_aiming else 1.0)
		if _cam_yaw != null:
			_cam_yaw.rotation.y -= event.relative.x * sens
		if _spring_arm != null:
			_spring_arm.rotation.x = clampf(
				_spring_arm.rotation.x - event.relative.y * sens,
				deg_to_rad(-55.0),
				deg_to_rad(32.0)
			)

	if event.is_action_pressed(&"interact_vehicle"):
		_try_enter_nearest_vehicle()
	elif event.is_action_pressed(&"toggle_weapon"):
		_weapon_equipped = not _weapon_equipped
		if _weapon_visual != null:
			_weapon_visual.visible = _weapon_equipped or _is_aiming
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm != null and gm.has_method("push_banner"):
			gm.call("push_banner", "CARBINE RIFLE" if _weapon_equipped else "UNARMED (FISTS)", "Press [Q] to switch weapon", Color(0.95, 0.78, 0.25))
	elif event.is_action_pressed(&"dodge_roll") and is_on_floor() and _anim_roll != &"":
		_play_anim(_anim_roll, 0.1)
		_action_lock_timer = 0.55


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _inside_vehicle != null:
		return

	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta
	if _action_lock_timer > 0.0:
		_action_lock_timer -= delta

	if not is_on_floor():
		velocity.y -= _gravity * delta

	if not _player_controlled or not _is_gameplay_active():
		velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 16.0 * delta)
		move_and_slide()
		_play_anim(_anim_idle, 0.2)
		return

	var want_aim: bool = Input.is_action_pressed(&"aim_weapon")
	if want_aim != _is_aiming:
		_is_aiming = want_aim
		if _weapon_visual != null:
			_weapon_visual.visible = _weapon_equipped or _is_aiming
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm != null and gm.has_method("notify_aiming"):
			gm.call("notify_aiming", _is_aiming, "CARBINE RIFLE")

	if Input.is_action_pressed(&"fire_weapon") and _fire_cooldown <= 0.0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if _is_aiming or _weapon_equipped:
			_fire_rifle()
		elif Input.is_action_just_pressed(&"fire_weapon"):
			_perform_melee_punch()

	if Input.is_action_just_pressed(&"jump_handbrake") and is_on_floor():
		velocity.y = jump_velocity

	var input_vec: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var is_sprinting: bool = Input.is_action_pressed(&"sprint_boost") and not _is_aiming
	var target_speed: float = sprint_speed if is_sprinting else (walk_speed * 0.78 if _is_aiming else walk_speed)

	var cam_basis: Basis = _cam_yaw.global_transform.basis if _cam_yaw != null else global_transform.basis
	var forward_dir: Vector3 = -cam_basis.z
	forward_dir.y = 0.0
	forward_dir = forward_dir.normalized()
	var right_dir: Vector3 = cam_basis.x
	right_dir.y = 0.0
	right_dir = right_dir.normalized()

	var move_dir: Vector3 = (right_dir * input_vec.x + forward_dir * (-input_vec.y)).normalized()

	if move_dir.length_squared() > 0.001:
		velocity.x = move_toward(velocity.x, move_dir.x * target_speed, 30.0 * delta)
		velocity.z = move_toward(velocity.z, move_dir.z * target_speed, 30.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 26.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 26.0 * delta)

	if _visual_pivot != null:
		if _is_aiming:
			var aim_yaw: float = atan2(forward_dir.x, forward_dir.z)
			_visual_pivot.rotation.y = lerp_angle(_visual_pivot.rotation.y, aim_yaw, 18.0 * delta)
		elif move_dir.length_squared() > 0.001:
			var move_yaw: float = atan2(move_dir.x, move_dir.z)
			_visual_pivot.rotation.y = lerp_angle(_visual_pivot.rotation.y, move_yaw, 13.0 * delta)

	move_and_slide()

	if _spring_arm != null and _camera != null:
		var target_len: float = 1.95 if _is_aiming else _desired_cam_dist
		var target_side: float = 0.52 if _is_aiming else 0.22
		_spring_arm.spring_length = lerpf(_spring_arm.spring_length, target_len, 10.0 * delta)
		_spring_arm.position.x = lerpf(_spring_arm.position.x, target_side, 10.0 * delta)
		var target_fov: float = 50.0 if _is_aiming else (74.0 if is_sprinting and move_dir.length() > 0.1 else 65.0)
		_camera.fov = lerpf(_camera.fov, target_fov, 8.0 * delta)

	var horiz_speed: float = Vector2(velocity.x, velocity.z).length()
	_update_character_animation(horiz_speed, is_sprinting)
	_scan_nearby_vehicles()


func _fire_rifle() -> void:
	_fire_cooldown = 0.13
	_action_lock_timer = 0.22
	if _anim_shoot != &"":
		_play_anim(_anim_shoot, 0.05)

	if _weapon_visual != null:
		_weapon_visual.visible = true

	if _cam_yaw != null and _visual_pivot != null:
		var fwd: Vector3 = -_cam_yaw.global_transform.basis.z
		_visual_pivot.rotation.y = atan2(fwd.x, fwd.z)

	if _camera == null:
		return

	var ray_from: Vector3 = _camera.global_position
	var ray_dir: Vector3 = -_camera.global_transform.basis.z.normalized()
	var ray_to: Vector3 = ray_from + ray_dir * 130.0

	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)

	var end_point: Vector3 = ray_to
	if not hit.is_empty():
		end_point = hit["position"] as Vector3
		var collider: Object = hit["collider"]
		_spawn_hit_spark(end_point)
		if collider is Node:
			if collider.has_method("on_bullet_hit"):
				collider.call("on_bullet_hit", ray_dir, end_point)
			elif collider is RigidBody3D:
				(collider as RigidBody3D).apply_central_impulse(ray_dir * 45.0)

	_spawn_tracer_beam(global_position + Vector3(0.0, 1.38, 0.0) + global_transform.basis.z * 0.4, end_point)

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("report_crime") and randf() < 0.35:
		gm.call("report_crime", 1, "SHOTS FIRED IN LOS SANTOS")


func _perform_melee_punch() -> void:
	_fire_cooldown = 0.48
	_action_lock_timer = 0.45
	if _anim_punch != &"":
		_play_anim(_anim_punch, 0.08)

	var fwd: Vector3 = _visual_pivot.global_transform.basis.z.normalized() if _visual_pivot != null else Vector3.FORWARD
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0.0, 1.1, 0.0), global_position + Vector3(0.0, 1.1, 0.0) + fwd * 2.0)
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var col: Object = hit["collider"]
		if col is Node and col.has_method("on_bullet_hit"):
			col.call("on_bullet_hit", fwd, hit["position"] as Vector3)


func _spawn_tracer_beam(start_pt: Vector3, end_pt: Vector3) -> void:
	var dist: float = start_pt.distance_to(end_pt)
	if dist < 0.5:
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return

	var beam := MeshInstance3D.new()
	var bmesh := BoxMesh.new()
	bmesh.size = Vector3(0.03, 0.03, dist)
	beam.mesh = bmesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.88, 0.38)
	beam.material_override = mat
	scene_root.add_child(beam)
	beam.global_position = (start_pt + end_pt) * 0.5
	beam.look_at(end_pt, Vector3.UP)

	var tw: Tween = get_tree().create_tween()
	tw.tween_interval(0.045)
	tw.tween_callback(beam.queue_free)


func _spawn_hit_spark(pos: Vector3) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var spark := MeshInstance3D.new()
	var smesh := SphereMesh.new()
	smesh.radius = 0.14
	smesh.height = 0.28
	spark.mesh = smesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.65, 0.15)
	spark.material_override = mat
	scene_root.add_child(spark)
	spark.global_position = pos
	var tw: Tween = get_tree().create_tween()
	tw.tween_property(spark, "scale", Vector3(0.05, 0.05, 0.05), 0.14)
	tw.tween_callback(spark.queue_free)


func _update_character_animation(horiz_speed: float, is_sprinting: bool) -> void:
	if _anim_player == null or _action_lock_timer > 0.0:
		return
	if _is_aiming and horiz_speed < 0.4 and _anim_aim != &"":
		_play_anim(_anim_aim, 0.12)
	elif horiz_speed > 5.8 and is_sprinting and _anim_run != &"":
		_play_anim(_anim_run, 0.16)
	elif horiz_speed > 0.35 and _anim_walk != &"":
		_play_anim(_anim_walk, 0.16)
	elif _anim_idle != &"":
		_play_anim(_anim_idle, 0.20)


func _play_anim(anim_name: StringName, blend: float = 0.15) -> void:
	if _anim_player == null or anim_name == &"" or _current_anim == anim_name:
		return
	if _anim_player.has_animation(anim_name):
		_current_anim = anim_name
		_anim_player.play(anim_name, blend)


func _scan_nearby_vehicles() -> void:
	_nearest_vehicle = null
	var best_dist: float = 4.2
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
			gm.call("set_interaction_prompt", "Press [F] to Enter " + vname)
		else:
			gm.call("set_interaction_prompt", "")


func _try_enter_nearest_vehicle() -> void:
	if _nearest_vehicle != null and _nearest_vehicle.has_method("enter_driver"):
		_nearest_vehicle.call("enter_driver", self)


static func _get_cached_scene(res_path: String) -> PackedScene:
	if _char_cache.has(res_path):
		return _char_cache[res_path] as PackedScene
	var loaded: PackedScene = load(res_path) as PackedScene
	if loaded != null:
		_char_cache[res_path] = loaded
	return loaded


func _rebuild_character() -> void:
	for child: Node in get_children(true):
		if child.get_meta("gta_internal", false):
			child.queue_free()

	_anim_player = null
	_current_anim = &""

	_rig_root = Node3D.new()
	_rig_root.set_meta("gta_internal", true)
	add_child(_rig_root, false, Node.INTERNAL_MODE_BACK)

	_visual_pivot = Node3D.new()
	_rig_root.add_child(_visual_pivot)

	var packed: PackedScene = custom_character_model
	var flip_z: bool = false
	if packed == null:
		var idx: int = clampi(int(character_skin), 0, SKIN_PATHS.size() - 1)
		packed = _get_cached_scene(SKIN_PATHS[idx])
		flip_z = (character_skin == CharacterSkin.TACTICAL_PBR)

	if packed != null:
		var model_inst: Node3D = packed.instantiate() as Node3D
		if model_inst != null:
			if flip_z:
				model_inst.rotation.y = PI
			_visual_pivot.add_child(model_inst)
			if not Engine.is_editor_hint():
				_bind_character_animations(model_inst)

	# In Editor mode, skip physics RIDs & runtime camera rigs!
	if Engine.is_editor_hint():
		return

	var col := CollisionShape3D.new()
	col.set_meta("gta_internal", true)
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.82
	col.shape = cap
	col.position = Vector3(0.0, 0.91, 0.0)
	add_child(col, false, Node.INTERNAL_MODE_BACK)

	_weapon_visual = Node3D.new()
	_weapon_visual.position = Vector3(-0.24, 1.12, 0.34)
	_visual_pivot.add_child(_weapon_visual)

	var rifle_packed: PackedScene = _get_cached_scene(RIFLE_MODEL_PATH)
	if rifle_packed != null:
		var rifle_inst: Node3D = rifle_packed.instantiate() as Node3D
		if rifle_inst != null:
			rifle_inst.scale = Vector3(0.42, 0.42, 0.42)
			rifle_inst.rotation_degrees = Vector3(0.0, 90.0, 0.0)
			_weapon_visual.add_child(rifle_inst)

	_cam_yaw = Node3D.new()
	_cam_yaw.position = Vector3(0.0, 1.56, 0.0)
	_cam_yaw.rotation.y = PI
	_rig_root.add_child(_cam_yaw)

	_spring_arm = SpringArm3D.new()
	_spring_arm.position = Vector3(0.22, 0.0, 0.0)
	_spring_arm.spring_length = _desired_cam_dist
	_spring_arm.margin = 0.25
	_spring_arm.rotation.x = deg_to_rad(-12.0)
	_spring_arm.add_excluded_object(get_rid())
	_cam_yaw.add_child(_spring_arm)

	_camera = Camera3D.new()
	_camera.fov = 65.0
	_camera.near = 0.1
	_camera.far = 650.0
	_spring_arm.add_child(_camera)


func _bind_character_animations(model_inst: Node3D) -> void:
	var players: Array[Node] = model_inst.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	_anim_player = players[0] as AnimationPlayer
	if _anim_player == null:
		return

	var anim_list: PackedStringArray = _anim_player.get_animation_list()
	for aname: String in anim_list:
		var anim: Animation = _anim_player.get_animation(aname)
		var low: String = aname.to_lower()
		if anim != null and ("idle" in low or "walk" in low or "run" in low):
			anim.loop_mode = Animation.LOOP_LINEAR

	_anim_idle = _pick_anim(anim_list, ["characterarmature|idle", "idle"])
	_anim_walk = _pick_anim(anim_list, ["characterarmature|walk", "walk"])
	_anim_run = _pick_anim(anim_list, ["characterarmature|run", "run"])
	_anim_aim = _pick_anim(anim_list, ["idle_gun_pointing", "idle_gun", "idle"])
	_anim_shoot = _pick_anim(anim_list, ["gun_shoot", "run_shoot"])
	_anim_punch = _pick_anim(anim_list, ["punch_right", "punch_left"])
	_anim_roll = _pick_anim(anim_list, ["roll"])

	if _anim_idle != &"":
		_anim_player.play(_anim_idle)


func _pick_anim(anim_list: PackedStringArray, candidates: Array[String]) -> StringName:
	for cand: String in candidates:
		for actual: String in anim_list:
			if actual.to_lower() == cand or actual.to_lower().ends_with(cand):
				return StringName(actual)
	for cand: String in candidates:
		for actual: String in anim_list:
			if cand in actual.to_lower():
				return StringName(actual)
	return &""
