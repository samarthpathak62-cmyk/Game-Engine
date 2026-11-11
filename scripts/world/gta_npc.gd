@tool
extends CharacterBody3D
class_name GTANPC
## GTANPC
## Real 3D Rigged & Skeletal-Animated Los Santos Civilian Pedestrian:
## Uses real .glb human models with Walk, Run, Hit & Death animations.

enum NPCSkin {
	WOMAN_CASUAL = 0,
	WOMAN_FORMAL = 1,
	MAN_BUSINESS = 2,
	MAN_STREET = 3,
}

const NPC_MODELS: Array[String] = [
	"res://assets/models/characters/civilian_woman_casual.glb",
	"res://assets/models/characters/civilian_woman_formal.glb",
	"res://assets/models/characters/michael_suit.glb",
	"res://assets/models/characters/franklin_casual.glb",
]

@export var npc_skin: NPCSkin = NPCSkin.WOMAN_CASUAL:
	set(value):
		npc_skin = value
		_rebuild_npc()
@export_range(6.0, 60.0, 1.0) var patrol_distance: float = 22.0
@export_range(1.2, 3.8, 0.2) var stroll_speed: float = 1.9

var _origin_pos: Vector3 = Vector3.ZERO
var _direction_sign: float = 1.0
var _panic_timer: float = 0.0
var _hit_cooldown: float = 0.0
var _is_down: bool = false
var _respawn_timer: float = 0.0
var _health: int = 2
var _gravity: float = 15.0

var _visual_root: Node3D = null
var _anim_player: AnimationPlayer = null
var _anim_walk: StringName = &""
var _anim_run: StringName = &""
var _anim_hit: StringName = &""
var _anim_death: StringName = &""
var _current_anim: StringName = &""


func _ready() -> void:
	add_to_group(&"npcs")
	_rebuild_npc()
	if Engine.is_editor_hint():
		return
	_origin_pos = global_position
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * 1.45


func on_bullet_hit(shot_dir: Vector3, _hit_pos: Vector3) -> void:
	if _is_down:
		return
	_health -= 1
	_panic_timer = 9.0
	velocity = shot_dir.normalized() * 4.5 + Vector3(0.0, 2.2, 0.0)

	var gm: Node = get_node_or_null("/root/GameManager")
	if _health <= 0:
		_is_down = true
		_respawn_timer = 14.0
		_play_anim(_anim_death)
		if gm != null:
			if gm.has_method("report_crime"):
				gm.call("report_crime", 2, "ASSAULT WITH DEADLY WEAPON")
			if gm.has_method("add_cash"):
				gm.call("add_cash", 150, "")
	else:
		_play_anim(_anim_hit)
		if gm != null and gm.has_method("report_crime"):
			gm.call("report_crime", 1, "CIVILIAN ASSAULTED")


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta

	if _is_down:
		velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
		move_and_slide()
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_is_down = false
			_health = 2
			_current_anim = &""
		return

	if _hit_cooldown > 0.0:
		_hit_cooldown -= delta
	if _panic_timer > 0.0:
		_panic_timer -= delta

	_check_nearby_vehicle_danger()

	var is_panicking: bool = _panic_timer > 0.0
	var spd: float = stroll_speed * (2.75 if is_panicking else 1.0)
	var forward_axis: Vector3 = global_transform.basis.z.normalized()
	var move_vec: Vector3 = forward_axis * _direction_sign

	if global_position.distance_to(_origin_pos) > patrol_distance and not is_panicking:
		_direction_sign *= -1.0
		_origin_pos = global_position

	velocity.x = move_vec.x * spd
	velocity.z = move_vec.z * spd
	move_and_slide()

	if is_on_wall():
		_direction_sign *= -1.0

	if _visual_root != null:
		_visual_root.rotation.y = 0.0 if _direction_sign > 0.0 else PI

	_play_anim(_anim_run if is_panicking else _anim_walk)


func _check_nearby_vehicle_danger() -> void:
	for v: Node in get_tree().get_nodes_in_group(&"vehicles"):
		if v is RigidBody3D:
			var rb: RigidBody3D = v as RigidBody3D
			var d: float = global_position.distance_to(rb.global_position)
			var v_speed_kmh: float = rb.linear_velocity.length() * 3.6
			if d < 6.0 and v_speed_kmh > 30.0:
				_panic_timer = 6.0
			if d < 2.2 and v_speed_kmh > 18.0 and _hit_cooldown <= 0.0:
				_hit_cooldown = 4.0
				_is_down = true
				_respawn_timer = 10.0
				var away: Vector3 = (global_position - rb.global_position).normalized()
				velocity = away * 8.5 + Vector3(0.0, 4.2, 0.0)
				_play_anim(_anim_death)
				var gm: Node = get_node_or_null("/root/GameManager")
				if gm != null and gm.has_method("report_crime"):
					gm.call("report_crime", 1, "HIT & RUN")


func _play_anim(anim_name: StringName) -> void:
	if _anim_player == null or anim_name == &"" or _current_anim == anim_name:
		return
	if _anim_player.has_animation(anim_name):
		_current_anim = anim_name
		_anim_player.play(anim_name, 0.16)


func _rebuild_npc() -> void:
	for child: Node in get_children(true):
		if child.get_meta("gta_internal", false):
			child.queue_free()

	_anim_player = null
	_current_anim = &""

	var col := CollisionShape3D.new()
	col.set_meta("gta_internal", true)
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.78
	col.shape = cap
	col.position = Vector3(0.0, 0.89, 0.0)
	add_child(col, false, Node.INTERNAL_MODE_BACK)

	_visual_root = Node3D.new()
	_visual_root.set_meta("gta_internal", true)
	add_child(_visual_root, false, Node.INTERNAL_MODE_BACK)

	var idx: int = clampi(int(npc_skin), 0, NPC_MODELS.size() - 1)
	var packed: PackedScene = load(NPC_MODELS[idx]) as PackedScene
	if packed != null:
		var inst: Node3D = packed.instantiate() as Node3D
		if inst != null:
			_visual_root.add_child(inst)
			_bind_animations(inst)


func _bind_animations(inst: Node3D) -> void:
	var players: Array[Node] = inst.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	_anim_player = players[0] as AnimationPlayer
	if _anim_player == null:
		return

	var anim_list: PackedStringArray = _anim_player.get_animation_list()
	for aname: String in anim_list:
		var anim: Animation = _anim_player.get_animation(aname)
		var low: String = aname.to_lower()
		if anim != null and ("walk" in low or "run" in low or "idle" in low):
			anim.loop_mode = Animation.LOOP_LINEAR

	for a: String in anim_list:
		var low: String = a.to_lower()
		if low.ends_with("walk"):
			_anim_walk = StringName(a)
		elif low.ends_with("run"):
			_anim_run = StringName(a)
		elif "hitrecieve" in low and _anim_hit == &"":
			_anim_hit = StringName(a)
		elif low.ends_with("death"):
			_anim_death = StringName(a)

	if _anim_walk != &"":
		_anim_player.play(_anim_walk)
