@tool
extends Area3D
class_name MissionMarker
## MissionMarker
## GTA 5 Style Glowing Yellow Cylinder Checkpoint.
## Walk or drive into the ring to trigger Mission Passed + Cash Reward!

@export var mission_title: String = "STREET DELIVERY PASSED"
@export_range(100, 100000, 100) var cash_reward: int = 2500
@export var marker_color: Color = Color(1.0, 0.84, 0.12):
	set(value):
		marker_color = value
		_rebuild_marker()
@export var repeatable: bool = true
@export_range(3.0, 60.0, 1.0) var respawn_seconds: float = 12.0

var _ring_mesh: MeshInstance3D = null
var _pulse_time: float = 0.0
var _cooldown: float = 0.0


func _ready() -> void:
	add_to_group(&"missions")
	_rebuild_marker()
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if _cooldown > 0.0:
		_cooldown -= delta
		if _cooldown <= 0.0:
			visible = true

	_pulse_time += delta * 2.8
	if _ring_mesh != null and visible:
		var s: float = 1.0 + sin(_pulse_time) * 0.07
		_ring_mesh.scale = Vector3(s, 1.0, s)


func _on_body_entered(body: Node3D) -> void:
	if _cooldown > 0.0 or not visible:
		return

	var is_valid_trigger: bool = false
	if body.is_in_group(&"player") and bool(body.get("_player_controlled")):
		is_valid_trigger = true
	elif body.is_in_group(&"vehicles") and body.get("current_driver") != null:
		is_valid_trigger = true

	if not is_valid_trigger:
		return

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("add_cash"):
		gm.call("add_cash", cash_reward, "MISSION PASSED: " + mission_title)

	if repeatable:
		visible = false
		_cooldown = respawn_seconds
	else:
		queue_free()


func _rebuild_marker() -> void:
	for child: Node in get_children(true):
		if child.get_meta("gta_internal", false):
			child.queue_free()

	var col := CollisionShape3D.new()
	col.set_meta("gta_internal", true)
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = 2.4
	cyl_shape.height = 3.2
	col.shape = cyl_shape
	col.position = Vector3(0.0, 1.6, 0.0)
	add_child(col, false, Node.INTERNAL_MODE_BACK)

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(marker_color.r, marker_color.g, marker_color.b, 0.42)

	_ring_mesh = MeshInstance3D.new()
	_ring_mesh.set_meta("gta_internal", true)
	var cyl_mesh := CylinderMesh.new()
	cyl_mesh.top_radius = 2.2
	cyl_mesh.bottom_radius = 2.2
	cyl_mesh.height = 2.6
	cyl_mesh.cap_top = false
	cyl_mesh.cap_bottom = false
	_ring_mesh.mesh = cyl_mesh
	_ring_mesh.material_override = mat
	_ring_mesh.position = Vector3(0.0, 1.3, 0.0)
	add_child(_ring_mesh, false, Node.INTERNAL_MODE_BACK)

	var omni := OmniLight3D.new()
	omni.set_meta("gta_internal", true)
	omni.light_color = marker_color
	omni.light_energy = 2.0
	omni.omni_range = 8.0
	omni.position = Vector3(0.0, 1.2, 0.0)
	add_child(omni, false, Node.INTERNAL_MODE_BACK)
