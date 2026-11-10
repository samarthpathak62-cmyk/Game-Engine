@tool
extends StaticBody3D
class_name CityProp
## CityProp
## Modular No-Code Open-World Building Block (Roads, Crossroads, Skyscrapers,
## Shops, Stunt Ramps, Streetlights, Palm Trees, Ground Plaza) with auto-collision.

enum PropType {
	GROUND_PLAZA = 0,
	ROAD_STRAIGHT = 1,
	ROAD_CROSS = 2,
	SKYSCRAPER = 3,
	APARTMENT_SHOP = 4,
	STUNT_RAMP = 5,
	STREETLIGHT = 6,
	PALM_TREE = 7,
}

@export var prop_type: PropType = PropType.SKYSCRAPER:
	set(value):
		prop_type = value
		_rebuild_prop()

@export var primary_color: Color = Color(0.22, 0.28, 0.38):
	set(value):
		primary_color = value
		_rebuild_prop()

@export_range(1, 20, 1) var floors: int = 8:
	set(value):
		floors = value
		_rebuild_prop()

@export var prop_size: Vector3 = Vector3(14.0, 1.0, 24.0):
	set(value):
		prop_size = value
		_rebuild_prop()

@export var custom_prop_model: PackedScene:
	set(value):
		custom_prop_model = value
		_rebuild_prop()


func _ready() -> void:
	_rebuild_prop()


func _rebuild_prop() -> void:
	for child: Node in get_children(true):
		if child.get_meta("gta_internal", false):
			child.queue_free()

	var root := Node3D.new()
	root.set_meta("gta_internal", true)
	add_child(root, false, Node.INTERNAL_MODE_BACK)

	if custom_prop_model != null:
		var inst: Node = custom_prop_model.instantiate()
		root.add_child(inst)
		_add_box_collider(Vector3(4.0, 4.0, 4.0), Vector3(0.0, 2.0, 0.0))
		return

	match prop_type:
		PropType.GROUND_PLAZA:
			_build_ground(root)
		PropType.ROAD_STRAIGHT:
			_build_road_straight(root)
		PropType.ROAD_CROSS:
			_build_road_cross(root)
		PropType.SKYSCRAPER:
			_build_skyscraper(root)
		PropType.APARTMENT_SHOP:
			_build_shop(root)
		PropType.STUNT_RAMP:
			_build_ramp(root)
		PropType.STREETLIGHT:
			_build_streetlight(root)
		PropType.PALM_TREE:
			_build_palm_tree(root)


func _build_ground(root: Node3D) -> void:
	var gx: float = maxf(20.0, prop_size.x)
	var gz: float = maxf(20.0, prop_size.z)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = primary_color
	mat.roughness = 0.92
	_add_mesh_box(root, Vector3(gx, 1.0, gz), Vector3(0.0, -0.5, 0.0), mat)
	_add_box_collider(Vector3(gx, 1.0, gz), Vector3(0.0, -0.5, 0.0))


func _build_road_straight(root: Node3D) -> void:
	var width: float = maxf(8.0, prop_size.x)
	var length: float = maxf(8.0, prop_size.z)

	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_color = Color(0.14, 0.15, 0.17)
	asphalt.roughness = 0.88

	var sidewalk := StandardMaterial3D.new()
	sidewalk.albedo_color = Color(0.56, 0.57, 0.59)
	sidewalk.roughness = 0.85

	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color(0.96, 0.78, 0.18)
	line_mat.roughness = 0.5

	_add_mesh_box(root, Vector3(width, 0.12, length), Vector3(0.0, 0.04, 0.0), asphalt)
	_add_box_collider(Vector3(width + 3.6, 0.16, length), Vector3(0.0, 0.04, 0.0))

	# Raised sidewalks on left & right
	for sx: float in [-(width * 0.5 + 0.9), width * 0.5 + 0.9]:
		_add_mesh_box(root, Vector3(1.8, 0.22, length), Vector3(sx, 0.11, 0.0), sidewalk)

	# Dashed yellow center road markings
	var count: int = maxi(2, int(length / 4.5))
	var start_z: float = -length * 0.5 + 2.2
	for i: int in range(count):
		var z_pos: float = start_z + float(i) * 4.5
		if z_pos < length * 0.5 - 1.0:
			_add_mesh_box(root, Vector3(0.22, 0.03, 2.1), Vector3(0.0, 0.11, z_pos), line_mat)


func _build_road_cross(root: Node3D) -> void:
	var w: float = maxf(12.0, prop_size.x)
	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_color = Color(0.13, 0.14, 0.16)
	asphalt.roughness = 0.88

	var zebra := StandardMaterial3D.new()
	zebra.albedo_color = Color(0.90, 0.91, 0.93)
	zebra.roughness = 0.65

	_add_mesh_box(root, Vector3(w, 0.12, w), Vector3(0.0, 0.04, 0.0), asphalt)
	_add_box_collider(Vector3(w, 0.16, w), Vector3(0.0, 0.04, 0.0))

	for i: int in range(-2, 3):
		var offset: float = float(i) * 1.4
		_add_mesh_box(root, Vector3(0.55, 0.03, 2.2), Vector3(offset, 0.11, w * 0.40), zebra)
		_add_mesh_box(root, Vector3(0.55, 0.03, 2.2), Vector3(offset, 0.11, -w * 0.40), zebra)


func _build_skyscraper(root: Node3D) -> void:
	var h: float = float(floors) * 3.6
	var w: float = maxf(8.0, prop_size.x)
	var d: float = maxf(8.0, prop_size.z)

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = primary_color
	wall_mat.metallic = 0.35
	wall_mat.roughness = 0.38

	var glass_band := StandardMaterial3D.new()
	glass_band.albedo_color = Color(0.16, 0.28, 0.42)
	glass_band.metallic = 0.78
	glass_band.roughness = 0.14
	glass_band.emission_enabled = true
	glass_band.emission = Color(0.18, 0.34, 0.52)
	glass_band.emission_energy_multiplier = 0.45

	_add_mesh_box(root, Vector3(w, h, d), Vector3(0.0, h * 0.5, 0.0), wall_mat)
	_add_box_collider(Vector3(w, h, d), Vector3(0.0, h * 0.5, 0.0))

	# Horizontal illuminated glass floor bands
	for f: int in range(1, floors + 1):
		var fy: float = float(f) * 3.6 - 1.4
		_add_mesh_box(root, Vector3(w + 0.14, 1.35, d + 0.14), Vector3(0.0, fy, 0.0), glass_band)

	# Rooftop penthouse crown
	_add_mesh_box(root, Vector3(w * 0.65, 2.2, d * 0.65), Vector3(0.0, h + 1.1, 0.0), wall_mat)


func _build_shop(root: Node3D) -> void:
	var h: float = float(maxi(2, mini(floors, 5))) * 3.4
	var w: float = maxf(7.0, prop_size.x)
	var d: float = maxf(7.0, prop_size.z)

	var stucco := StandardMaterial3D.new()
	stucco.albedo_color = primary_color
	stucco.roughness = 0.78

	var neon_sign := StandardMaterial3D.new()
	neon_sign.albedo_color = Color(1.0, 0.35, 0.58)
	neon_sign.emission_enabled = true
	neon_sign.emission = Color(1.0, 0.28, 0.55)
	neon_sign.emission_energy_multiplier = 2.0

	_add_mesh_box(root, Vector3(w, h, d), Vector3(0.0, h * 0.5, 0.0), stucco)
	_add_box_collider(Vector3(w, h, d), Vector3(0.0, h * 0.5, 0.0))

	# Storefront neon awning facing +Z
	_add_mesh_box(root, Vector3(w * 0.78, 0.65, 0.35), Vector3(0.0, 3.2, d * 0.5 + 0.18), neon_sign)


func _build_ramp(root: Node3D) -> void:
	var rw: float = 5.4
	var rl: float = 9.5
	var angle_rad: float = deg_to_rad(-19.0)

	var ramp_mat := StandardMaterial3D.new()
	ramp_mat.albedo_color = Color(0.95, 0.55, 0.12)
	ramp_mat.roughness = 0.55

	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.albedo_color = Color(0.12, 0.12, 0.14)
	stripe_mat.roughness = 0.7

	var deck := MeshInstance3D.new()
	var bmesh := BoxMesh.new()
	bmesh.size = Vector3(rw, 0.45, rl)
	deck.mesh = bmesh
	deck.material_override = ramp_mat
	deck.position = Vector3(0.0, 1.32, 0.0)
	deck.rotation.x = angle_rad
	root.add_child(deck)

	var col := CollisionShape3D.new()
	col.set_meta("gta_internal", true)
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(rw, 0.45, rl)
	col.shape = bshape
	col.position = deck.position
	col.rotation.x = angle_rad
	add_child(col, false, Node.INTERNAL_MODE_BACK)

	# Support pillars under high end (+Z)
	_add_mesh_box(root, Vector3(rw * 0.9, 2.5, 0.6), Vector3(0.0, 1.25, 3.8), stripe_mat)


func _build_streetlight(root: Node3D) -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.24, 0.26, 0.29)
	metal.metallic = 0.75
	metal.roughness = 0.35

	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.albedo_color = Color(1.0, 0.88, 0.62)
	bulb_mat.emission_enabled = true
	bulb_mat.emission = Color(1.0, 0.84, 0.52)
	bulb_mat.emission_energy_multiplier = 3.0

	_add_mesh_box(root, Vector3(0.22, 6.2, 0.22), Vector3(0.0, 3.1, 0.0), metal)
	_add_mesh_box(root, Vector3(0.18, 0.18, 1.8), Vector3(0.0, 6.1, 0.8), metal)
	_add_mesh_box(root, Vector3(0.42, 0.14, 0.62), Vector3(0.0, 5.98, 1.5), bulb_mat)
	_add_box_collider(Vector3(0.35, 6.2, 0.35), Vector3(0.0, 3.1, 0.0))

	var omni := OmniLight3D.new()
	omni.light_color = Color(1.0, 0.86, 0.58)
	omni.light_energy = 1.65
	omni.omni_range = 16.0
	omni.position = Vector3(0.0, 5.7, 1.5)
	root.add_child(omni)


func _build_palm_tree(root: Node3D) -> void:
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.46, 0.33, 0.22)
	bark.roughness = 0.9

	var frond_mat := StandardMaterial3D.new()
	frond_mat.albedo_color = Color(0.18, 0.56, 0.24)
	frond_mat.roughness = 0.75

	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.18
	cyl.bottom_radius = 0.30
	cyl.height = 6.8
	trunk.mesh = cyl
	trunk.material_override = bark
	trunk.position = Vector3(0.0, 3.4, 0.0)
	root.add_child(trunk)

	_add_box_collider(Vector3(0.55, 6.8, 0.55), Vector3(0.0, 3.4, 0.0))

	for i: int in range(6):
		var frond := MeshInstance3D.new()
		var fmesh := BoxMesh.new()
		fmesh.size = Vector3(0.55, 0.10, 2.6)
		frond.mesh = fmesh
		frond.material_override = frond_mat
		var ang: float = float(i) * (TAU / 6.0)
		frond.position = Vector3(sin(ang) * 1.1, 6.75, cos(ang) * 1.1)
		frond.rotation.y = ang
		frond.rotation.x = deg_to_rad(22.0)
		root.add_child(frond)


func _add_mesh_box(parent_node: Node3D, bsize: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = bsize
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent_node.add_child(mi)
	return mi


func _add_box_collider(bsize: Vector3, pos: Vector3) -> void:
	var col := CollisionShape3D.new()
	col.set_meta("gta_internal", true)
	var shape := BoxShape3D.new()
	shape.size = bsize
	col.shape = shape
	col.position = pos
	add_child(col, false, Node.INTERNAL_MODE_BACK)
