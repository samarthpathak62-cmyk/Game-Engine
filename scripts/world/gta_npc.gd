@tool
extends CharacterBody3D
class_name GTANPC
## GTANPC
## No-Code AI Civilian Pedestrian: walks sidewalks, panics & sprints if cars
## speed dangerously close, and triggers Police Wanted Stars on hit-and-run.

@export var shirt_color: Color = Color(0.88, 0.56, 0.22):
	set(value):
		shirt_color = value
		_rebuild_npc()

@export_range(3.0, 40.0, 1.0) var patrol_distance: float = 14.0
@export_range(1.2, 4.0, 0.2) var stroll_speed: float = 2.1

var _origin_pos: Vector3 = Vector3.ZERO
var _direction_sign: float = 1.0
var _panic_timer: float = 0.0
var _hit_cooldown: float = 0.0
var _anim_t: float = 0.0
var _gravity: float = 15.0

var _visual_root: Node3D = null
var _leg_l: Node3D = null
var _leg_r: Node3D = null


func _ready() -> void:
	add_to_group(&"npcs")
	_rebuild_npc()
	if Engine.is_editor_hint():
		return
	_origin_pos = global_position
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * 1.4


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if _hit_cooldown > 0.0:
		_hit_cooldown -= delta

	if _panic_timer > 0.0:
		_panic_timer -= delta

	if not is_on_floor():
		velocity.y -= _gravity * delta

	_check_nearby_vehicle_danger()

	var spd: float = stroll_speed * (2.6 if _panic_timer > 0.0 else 1.0)
	var forward_axis: Vector3 = global_transform.basis.z.normalized()
	var move_vec: Vector3 = forward_axis * _direction_sign

	if global_position.distance_to(_origin_pos) > patrol_distance and _panic_timer <= 0.0:
		_direction_sign *= -1.0
		_origin_pos = global_position

	velocity.x = move_vec.x * spd
	velocity.z = move_vec.z * spd
	move_and_slide()

	if is_on_wall():
		_direction_sign *= -1.0

	if _visual_root != null:
		_visual_root.rotation.y = 0.0 if _direction_sign > 0.0 else PI

	_anim_t += delta * (5.5 + spd * 1.6)
	if _leg_l != null and _leg_r != null:
		var sw: float = sin(_anim_t) * 0.48
		_leg_l.rotation.x = sw
		_leg_r.rotation.x = -sw


func _check_nearby_vehicle_danger() -> void:
	for v: Node in get_tree().get_nodes_in_group(&"vehicles"):
		if v is RigidBody3D:
			var d: float = global_position.distance_to(v.global_position)
			var v_speed_kmh: float = v.linear_velocity.length() * 3.6
			if d < 5.5 and v_speed_kmh > 32.0:
				_panic_timer = 5.0
			if d < 2.1 and v_speed_kmh > 18.0 and _hit_cooldown <= 0.0:
				_hit_cooldown = 4.0
				_panic_timer = 7.0
				var away: Vector3 = (global_position - v.global_position).normalized()
				velocity = away * 7.5 + Vector3(0.0, 4.2, 0.0)
				var gm: Node = get_node_or_null("/root/GameManager")
				if gm != null and gm.has_method("report_crime"):
					gm.call("report_crime", 1, "HIT & RUN")


func _rebuild_npc() -> void:
	for child: Node in get_children(true):
		if child.get_meta("gta_internal", false):
			child.queue_free()

	var col := CollisionShape3D.new()
	col.set_meta("gta_internal", true)
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.72
	col.shape = cap
	col.position = Vector3(0.0, 0.86, 0.0)
	add_child(col, false, Node.INTERNAL_MODE_BACK)

	_visual_root = Node3D.new()
	_visual_root.set_meta("gta_internal", true)
	add_child(_visual_root, false, Node.INTERNAL_MODE_BACK)

	var top_mat := StandardMaterial3D.new()
	top_mat.albedo_color = shirt_color
	top_mat.roughness = 0.72

	var pants_mat := StandardMaterial3D.new()
	pants_mat.albedo_color = Color(0.22, 0.22, 0.26)
	pants_mat.roughness = 0.85

	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.82, 0.64, 0.50)
	skin_mat.roughness = 0.7

	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.44, 0.58, 0.24)
	body.mesh = bm
	body.material_override = top_mat
	body.position = Vector3(0.0, 1.05, 0.0)
	_visual_root.add_child(body)

	var head := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.30, 0.30, 0.30)
	head.mesh = hm
	head.material_override = skin_mat
	head.position = Vector3(0.0, 1.54, 0.0)
	_visual_root.add_child(head)

	_leg_l = _create_leg(Vector3(0.12, 0.74, 0.0), pants_mat)
	_leg_r = _create_leg(Vector3(-0.12, 0.74, 0.0), pants_mat)
	_visual_root.add_child(_leg_l)
	_visual_root.add_child(_leg_r)


func _create_leg(pos: Vector3, mat: Material) -> Node3D:
	var piv := Node3D.new()
	piv.position = pos
	var mi := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.16, 0.72, 0.16)
	mi.mesh = lm
	mi.material_override = mat
	mi.position = Vector3(0.0, -0.36, 0.0)
	piv.add_child(mi)
	return piv
