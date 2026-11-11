@tool
extends CharacterBody3D
class_name GTANPC
## GTANPC (Intel UHD Crash-Proof Optimized)
## Real 3D Animated Los Santos Pedestrian with static PackedScene caching,
## safe @export setter guards, sidewalk patrol AI, and panic flee reactions.

enum PedestrianOutfit {
	WOMAN_CASUAL = 0,
	WOMAN_FORMAL = 1,
	HOODIE_CITIZEN = 2,
	BUSINESS_SUIT = 3,
	BIKER_PUNK = 4,
}

const OUTFIT_PATHS: Array[String] = [
	"res://assets/models/characters/civilian_woman_casual.glb",
	"res://assets/models/characters/civilian_woman_formal.glb",
	"res://assets/models/characters/franklin_casual.glb",
	"res://assets/models/characters/michael_suit.glb",
	"res://assets/models/characters/trevor_punk.glb",
]

static var _npc_cache: Dictionary = {}

@export var outfit: PedestrianOutfit = PedestrianOutfit.WOMAN_CASUAL:
	set(value):
		outfit = value
		if is_node_ready():
			_rebuild_npc()
@export_range(1.2, 3.0, 0.1) var stroll_speed: float = 1.65
@export_range(4.5, 8.5, 0.2) var panic_speed: float = 6.2
@export_range(4.0, 40.0, 1.0) var patrol_radius: float = 16.0

var _visual_pivot: Node3D = null
var _anim_player: AnimationPlayer = null
var _anim_idle: StringName = &""
var _anim_walk: StringName = &""
var _anim_run: StringName = &""
var _anim_death: StringName = &""
var _current_anim: StringName = &""

var _home_pos: Vector3 = Vector3.ZERO
var _move_dir: Vector3 = Vector3.FORWARD
var _state_timer: float = 2.0
var _panicking: bool = false
var _knocked_down: bool = false
var _gravity: float = 15.0


func _ready() -> void:
	add_to_group(&"pedestrians")
	_rebuild_npc()
	if Engine.is_editor_hint():
		return

	_home_pos = global_position
	var angle: float = randf() * TAU
	_move_dir = Vector3(sin(angle), 0.0, cos(angle))
	_state_timer = randf_range(2.5, 6.0)


func on_bullet_hit(shot_dir: Vector3, _hit_pos: Vector3) -> void:
	if _knocked_down:
		return
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("report_crime"):
		gm.call("report_crime", 2, "ASSAULT ON LOS SANTOS CITIZEN")

	for ped: Node in get_tree().get_nodes_in_group(&"pedestrians"):
		if ped != self and ped is GTANPC and ped.global_position.distance_to(global_position) < 28.0:
			(ped as GTANPC).trigger_panic(global_position)

	_knocked_down = true
	velocity = shot_dir.normalized() * 4.5 + Vector3(0.0, 2.2, 0.0)
	if _anim_death != &"" and _anim_player != null:
		_anim_player.play(_anim_death, 0.1)
	_state_timer = 5.5


func trigger_panic(danger_pos: Vector3) -> void:
	if _knocked_down:
		return
	_panicking = true
	_state_timer = 7.0
	var away: Vector3 = global_position - danger_pos
	away.y = 0.0
	if away.length_squared() > 0.01:
		_move_dir = away.normalized()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta

	if _knocked_down:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		move_and_slide()
		_state_timer -= delta
		if _state_timer <= 0.0:
			_knocked_down = false
			_panicking = true
			_state_timer = 5.0
		return

	_state_timer -= delta
	if _state_timer <= 0.0:
		if _panicking:
			_panicking = false
		var to_home: Vector3 = _home_pos - global_position
		to_home.y = 0.0
		if to_home.length() > patrol_radius:
			_move_dir = to_home.normalized()
		else:
			var ang: float = randf() * TAU
			_move_dir = Vector3(sin(ang), 0.0, cos(ang))
		_state_timer = randf_range(3.0, 7.0)

	var spd: float = panic_speed if _panicking else stroll_speed
	velocity.x = move_toward(velocity.x, _move_dir.x * spd, 12.0 * delta)
	velocity.z = move_toward(velocity.z, _move_dir.z * spd, 12.0 * delta)

	move_and_slide()
	if is_on_wall():
		_move_dir = _move_dir.rotated(Vector3.UP, deg_to_rad(randf_range(110.0, 250.0)))

	if _visual_pivot != null and Vector2(velocity.x, velocity.z).length() > 0.2:
		var yaw: float = atan2(velocity.x, velocity.z)
		_visual_pivot.rotation.y = lerp_angle(_visual_pivot.rotation.y, yaw, 9.0 * delta)

	var hspd: float = Vector2(velocity.x, velocity.z).length()
	if hspd > 3.5 and _anim_run != &"":
		_play_anim(_anim_run)
	elif hspd > 0.25 and _anim_walk != &"":
		_play_anim(_anim_walk)
	elif _anim_idle != &"":
		_play_anim(_anim_idle)


func _play_anim(aname: StringName) -> void:
	if _anim_player == null or aname == &"" or _current_anim == aname:
		return
	if _anim_player.has_animation(aname):
		_current_anim = aname
		_anim_player.play(aname, 0.2)


static func _get_cached_scene(res_path: String) -> PackedScene:
	if _npc_cache.has(res_path):
		return _npc_cache[res_path] as PackedScene
	var loaded: PackedScene = load(res_path) as PackedScene
	if loaded != null:
		_npc_cache[res_path] = loaded
	return loaded


func _rebuild_npc() -> void:
	for child: Node in get_children(true):
		if child.get_meta("gta_internal", false):
			child.queue_free()

	_anim_player = null
	_current_anim = &""

	_visual_pivot = Node3D.new()
	_visual_pivot.set_meta("gta_internal", true)
	add_child(_visual_pivot, false, Node.INTERNAL_MODE_BACK)

	var idx: int = clampi(int(outfit), 0, OUTFIT_PATHS.size() - 1)
	var packed: PackedScene = _get_cached_scene(OUTFIT_PATHS[idx])
	if packed != null:
		var inst: Node3D = packed.instantiate() as Node3D
		if inst != null:
			_visual_pivot.add_child(inst)
			if not Engine.is_editor_hint():
				_setup_animations(inst)

	if Engine.is_editor_hint():
		return

	var col := CollisionShape3D.new()
	col.set_meta("gta_internal", true)
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.78
	col.shape = cap
	col.position = Vector3(0.0, 0.89, 0.0)
	add_child(col, false, Node.INTERNAL_MODE_BACK)


func _setup_animations(inst: Node3D) -> void:
	var players: Array[Node] = inst.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	_anim_player = players[0] as AnimationPlayer
	if _anim_player == null:
		return
	var list: PackedStringArray = _anim_player.get_animation_list()
	for aname: String in list:
		var anim: Animation = _anim_player.get_animation(aname)
		var low: String = aname.to_lower()
		if anim != null and ("idle" in low or "walk" in low or "run" in low):
			anim.loop_mode = Animation.LOOP_LINEAR
		if "idle" in low and _anim_idle == &"":
			_anim_idle = StringName(aname)
		elif "walk" in low and _anim_walk == &"":
			_anim_walk = StringName(aname)
		elif "run" in low and not "shoot" in low and _anim_run == &"":
			_anim_run = StringName(aname)
		elif "death" in low and _anim_death == &"":
			_anim_death = StringName(aname)
	if _anim_walk != &"":
		_play_anim(_anim_walk)
