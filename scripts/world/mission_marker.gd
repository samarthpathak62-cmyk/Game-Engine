@tool
extends Area3D
class_name MissionMarker
## MissionMarker (Intel UHD Crash-Proof Optimized)
## GTA 5 Glowing Yellow Mission Corona with safe @export setter guards.

@export var mission_title: String = "SIMEON LUXURY EXPORT"
@export_range(500, 100000, 500) var cash_reward: int = 8500
@export var marker_color: Color = Color(1.0, 0.84, 0.12):
	set(value):
		marker_color = value
		if is_node_ready():
			_rebuild_marker()

var _ring_mesh: MeshInstance3D = null
var _cooldown: float = 0.0


func _ready() -> void:
	add_to_group(&"missions")
	_rebuild_marker()
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _ring_mesh != null and not Engine.is_editor_hint():
		_ring_mesh.rotation.y += delta * 1.4
	if _cooldown > 0.0:
		_cooldown -= delta


func _on_body_entered(body: Node3D) -> void:
	if Engine.is_editor_hint() or _cooldown > 0.0:
		return
	if body.is_in_group(&"player") or (body.is_in_group(&"vehicles") and bool(body.get("_is_player_driving"))):
		_cooldown = 14.0
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm != null and gm.has_method("complete_mission"):
			gm.call("complete_mission", mission_title, cash_reward)


func _rebuild_marker() -> void:
	for child: Node in get_children(true):
		if child.get_meta("gta_internal", false):
			child.queue_free()

	var root := Node3D.new()
	root.set_meta("gta_internal", true)
	add_child(root, false, Node.INTERNAL_MODE_BACK)

	_ring_mesh = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.65
	torus.outer_radius = 2.05
	_ring_mesh.mesh = torus
	_ring_mesh.position = Vector3(0.0, 0.18, 0.0)
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = marker_color
	_ring_mesh.material_override = rmat
	root.add_child(_ring_mesh)

	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.75
	cyl.bottom_radius = 1.85
	cyl.height = 3.2
	cyl.radial_segments = 16
	beam.mesh = cyl
	beam.position = Vector3(0.0, 1.6, 0.0)
	var bmat := StandardMaterial3D.new()
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bmat.albedo_color = Color(marker_color.r, marker_color.g, marker_color.b, 0.22)
	beam.material_override = bmat
	root.add_child(beam)

	if Engine.is_editor_hint():
		return

	var col := CollisionShape3D.new()
	col.set_meta("gta_internal", true)
	var cshape := CylinderShape3D.new()
	cshape.radius = 2.1
	cshape.height = 2.8
	col.shape = cshape
	col.position = Vector3(0.0, 1.4, 0.0)
	add_child(col, false, Node.INTERNAL_MODE_BACK)
