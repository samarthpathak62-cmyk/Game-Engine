@tool
extends StaticBody3D
class_name CityProp
## CityProp (Intel UHD Crash-Proof Optimized)
## Real 3D Los Santos City Architecture & Road System with static PackedScene
## and ShaderMaterial caching, safe @export setter guards, and zero-light lamps.

enum PropType {
	DOWNTOWN_SKYSCRAPER = 0,
	MODERN_HIGHRISE_A = 1,
	MODERN_HIGHRISE_B = 2,
	OFFICE_BUILDING_A = 3,
	COMMERCIAL_PLAZA = 4,
	CORNER_STOREFRONT = 5,
	VINEWOOD_MANSION_A = 6,
	VINEWOOD_MANSION_B = 7,
	APARTMENT_BLOCK = 8,
	ROAD_AVENUE_STRAIGHT = 9,
	ROAD_INTERSECTION = 10,
	STUNT_BRIDGE_RAMP = 11,
	STREETLIGHT_CURVED = 12,
	TRAFFIC_SIGNAL = 13,
	CITY_TREE_LUSH = 14,
	PARK_FOUNTAIN = 15,
	VESPUCCI_OCEAN = 16,
	SANDY_BEACH = 17,
	VINEWOOD_HILL = 18,
	LOS_SANTOS_GROUND = 19,
}

static var _scene_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}

@export var prop_type: PropType = PropType.DOWNTOWN_SKYSCRAPER:
	set(value):
		prop_type = value
		if is_node_ready():
			_rebuild_prop()

@export_range(8.0, 140.0, 2.0) var prop_length: float = 36.0:
	set(value):
		prop_length = value
		if is_node_ready():
			_rebuild_prop()

@export_range(6.0, 60.0, 1.0) var prop_width: float = 14.0:
	set(value):
		prop_width = value
		if is_node_ready():
			_rebuild_prop()

@export_range(0.5, 5.0, 0.05) var model_scale_multiplier: float = 1.0:
	set(value):
		model_scale_multiplier = value
		if is_node_ready():
			_rebuild_prop()


func _ready() -> void:
	_rebuild_prop()


static func _get_cached_scene(res_path: String) -> PackedScene:
	if _scene_cache.has(res_path):
		return _scene_cache[res_path] as PackedScene
	var loaded: PackedScene = load(res_path) as PackedScene
	if loaded != null:
		_scene_cache[res_path] = loaded
	return loaded


static func _get_road_material(is_intersection: bool, road_w: float) -> Material:
	var key: String = "road_inter" if is_intersection else "road_straight"
	if _mat_cache.has(key):
		return _mat_cache[key] as Material
	var road_shader: Shader = load("res://shaders/asphalt_road.gdshader") as Shader
	if road_shader != null:
		var smat := ShaderMaterial.new()
		smat.shader = road_shader
		smat.set_shader_parameter("road_width", road_w)
		smat.set_shader_parameter("is_intersection", 1 if is_intersection else 0)
		_mat_cache[key] = smat
		return smat
	var fallback := StandardMaterial3D.new()
	fallback.albedo_color = Color(0.14, 0.15, 0.17)
	_mat_cache[key] = fallback
	return fallback


static func _get_flat_material(key: String, color: Color, rough: float) -> StandardMaterial3D:
	if _mat_cache.has(key):
		return _mat_cache[key] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	_mat_cache[key] = mat
	return mat


func _rebuild_prop() -> void:
	for child: Node in get_children(true):
		if child.get_meta("gta_internal", false):
			child.queue_free()

	var root := Node3D.new()
	root.set_meta("gta_internal", true)
	add_child(root, false, Node.INTERNAL_MODE_BACK)

	match prop_type:
		PropType.DOWNTOWN_SKYSCRAPER:
			_spawn_glb_building(root, "res://assets/models/city/skyscraper_6story.glb", Vector3.ONE * (5.2 * model_scale_multiplier), Vector3(11.2, 40.5, 13.0) * model_scale_multiplier)
		PropType.MODERN_HIGHRISE_A:
			_spawn_glb_building(root, "res://assets/models/city/tower_modern_g.glb", Vector3.ONE * (11.5 * model_scale_multiplier), Vector3(26.0, 29.0, 20.5) * model_scale_multiplier)
		PropType.MODERN_HIGHRISE_B:
			_spawn_glb_building(root, "res://assets/models/city/tower_modern_e.glb", Vector3.ONE * (13.5 * model_scale_multiplier), Vector3(16.8, 28.0, 18.0) * model_scale_multiplier)
		PropType.OFFICE_BUILDING_A:
			_spawn_glb_building(root, "res://assets/models/city/building_office_tower.glb", Vector3.ONE * (3.5 * model_scale_multiplier), Vector3(20.0, 20.7, 7.8) * model_scale_multiplier)
		PropType.COMMERCIAL_PLAZA:
			_spawn_glb_building(root, "res://assets/models/city/commercial_wide.glb", Vector3.ONE * (3.0 * model_scale_multiplier), Vector3(20.4, 17.0, 8.1) * model_scale_multiplier)
		PropType.CORNER_STOREFRONT:
			_spawn_glb_building(root, "res://assets/models/city/building_downtown_block.glb", Vector3.ONE * (2.8 * model_scale_multiplier), Vector3(22.3, 13.0, 7.6) * model_scale_multiplier)
		PropType.VINEWOOD_MANSION_A:
			_spawn_glb_building(root, "res://assets/models/city/vinewood_mansion_1.glb", Vector3.ONE * (3.2 * model_scale_multiplier), Vector3(8.2, 10.2, 12.4) * model_scale_multiplier)
		PropType.VINEWOOD_MANSION_B:
			_spawn_glb_building(root, "res://assets/models/city/vinewood_mansion_2.glb", Vector3.ONE * (3.2 * model_scale_multiplier), Vector3(11.6, 9.4, 9.8) * model_scale_multiplier)
		PropType.APARTMENT_BLOCK:
			_spawn_glb_building(root, "res://assets/models/city/building_apartments.glb", Vector3.ONE * (3.3 * model_scale_multiplier), Vector3(15.3, 18.1, 12.7) * model_scale_multiplier)
		PropType.ROAD_AVENUE_STRAIGHT:
			_build_shader_road(root, false)
		PropType.ROAD_INTERSECTION:
			_build_shader_road(root, true)
		PropType.STUNT_BRIDGE_RAMP:
			_spawn_glb_ramp(root)
		PropType.STREETLIGHT_CURVED:
			_spawn_streetlight(root)
		PropType.TRAFFIC_SIGNAL:
			_spawn_glb_building(root, "res://assets/models/city/traffic_light.glb", Vector3.ONE * (5.8 * model_scale_multiplier), Vector3(0.7, 5.0, 0.7))
		PropType.CITY_TREE_LUSH:
			_spawn_glb_building(root, "res://assets/models/city/city_tree_tall.glb", Vector3.ONE * (2.35 * model_scale_multiplier), Vector3(0.9, 5.5, 0.9))
		PropType.PARK_FOUNTAIN:
			_spawn_glb_building(root, "res://assets/models/city/fountain_plaza.glb", Vector3.ONE * (4.2 * model_scale_multiplier), Vector3(8.2, 2.1, 8.2))
		PropType.VESPUCCI_OCEAN:
			_build_ocean(root)
		PropType.SANDY_BEACH:
			_build_beach(root)
		PropType.VINEWOOD_HILL:
			_build_vinewood_hill(root)
		PropType.LOS_SANTOS_GROUND:
			_build_city_ground(root)


func _spawn_glb_building(root: Node3D, res_path: String, scale_vec: Vector3, col_size: Vector3) -> void:
	var packed: PackedScene = _get_cached_scene(res_path)
	if packed != null:
		var inst: Node3D = packed.instantiate() as Node3D
		if inst != null:
			inst.scale = scale_vec
			root.add_child(inst)

	var col := CollisionShape3D.new()
	col.set_meta("gta_internal", true)
	var shape := BoxShape3D.new()
	shape.size = col_size
	col.shape = shape
	col.position = Vector3(0.0, col_size.y * 0.5, 0.0)
	add_child(col, false, Node.INTERNAL_MODE_BACK)


func _build_shader_road(root: Node3D, is_inter: bool) -> void:
	var length_z: float = prop_width if is_inter else prop_length
	var width_x: float = prop_width

	var road_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width_x, 0.14, length_z)
	road_mesh.mesh = box
	road_mesh.position = Vector3(0.0, 0.07, 0.0)
	road_mesh.material_override = _get_road_material(is_inter, width_x)
	root.add_child(road_mesh)

	if not is_inter:
		var walk_mat: StandardMaterial3D = _get_flat_material("sidewalk", Color(0.58, 0.57, 0.55), 0.90)
		for side: float in [-1.0, 1.0]:
			var curb := MeshInstance3D.new()
			var cmesh := BoxMesh.new()
			cmesh.size = Vector3(2.2, 0.22, length_z)
			curb.mesh = cmesh
			curb.position = Vector3(side * (width_x * 0.5 + 1.1), 0.11, 0.0)
			curb.material_override = walk_mat
			root.add_child(curb)

	var col := CollisionShape3D.new()
	col.set_meta("gta_internal", true)
	var cshape := BoxShape3D.new()
	cshape.size = Vector3(width_x + (0.0 if is_inter else 4.4), 0.20, length_z)
	col.shape = cshape
	col.position = Vector3(0.0, 0.08, 0.0)
	add_child(col, false, Node.INTERNAL_MODE_BACK)


func _spawn_glb_ramp(root: Node3D) -> void:
	var packed: PackedScene = _get_cached_scene("res://assets/models/city/bridge_ramp.glb")
	if packed != null:
		var inst: Node3D = packed.instantiate() as Node3D
		if inst != null:
			inst.scale = Vector3(3.2, 3.6, 5.2) * model_scale_multiplier
			root.add_child(inst)

	var ramp_col := CollisionShape3D.new()
	ramp_col.set_meta("gta_internal", true)
	var shape := BoxShape3D.new()
	shape.size = Vector3(6.2, 0.45, 10.2) * model_scale_multiplier
	ramp_col.shape = shape
	ramp_col.position = Vector3(0.0, 1.25 * model_scale_multiplier, 0.0)
	ramp_col.rotation_degrees.x = -16.5
	add_child(ramp_col, false, Node.INTERNAL_MODE_BACK)


func _spawn_streetlight(root: Node3D) -> void:
	var packed: PackedScene = _get_cached_scene("res://assets/models/city/streetlight_double.glb")
	if packed != null:
		var inst: Node3D = packed.instantiate() as Node3D
		if inst != null:
			inst.scale = Vector3(5.5, 5.5, 5.5) * model_scale_multiplier
			root.add_child(inst)

	# Unshaded warm bulb glow — zero dynamic OmniLight3D shader overhead on Intel UHD!
	var bulb := MeshInstance3D.new()
	var smesh := SphereMesh.new()
	smesh.radius = 0.24
	smesh.height = 0.36
	bulb.mesh = smesh
	bulb.position = Vector3(0.0, 5.7, 0.0) * model_scale_multiplier
	var bulb_mat: StandardMaterial3D = _get_flat_material("lamp_bulb", Color(1.0, 0.90, 0.65), 0.2)
	bulb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bulb.material_override = bulb_mat
	root.add_child(bulb)

	var col := CollisionShape3D.new()
	col.set_meta("gta_internal", true)
	var shape := CylinderShape3D.new()
	shape.radius = 0.24
	shape.height = 5.8
	col.shape = shape
	col.position = Vector3(0.0, 2.9, 0.0)
	add_child(col, false, Node.INTERNAL_MODE_BACK)


func _build_ocean(root: Node3D) -> void:
	var ocean := MeshInstance3D.new()
	var pmesh := PlaneMesh.new()
	pmesh.size = Vector2(560.0, 260.0)
	pmesh.subdivide_width = 36
	pmesh.subdivide_depth = 24
	ocean.mesh = pmesh
	if _mat_cache.has("ocean_water"):
		ocean.material_override = _mat_cache["ocean_water"] as Material
	else:
		var wshader: Shader = load("res://shaders/ocean_water.gdshader") as Shader
		if wshader != null:
			var smat := ShaderMaterial.new()
			smat.shader = wshader
			_mat_cache["ocean_water"] = smat
			ocean.material_override = smat
	root.add_child(ocean)


func _build_beach(root: Node3D) -> void:
	var sand := MeshInstance3D.new()
	var bmesh := BoxMesh.new()
	bmesh.size = Vector3(prop_length * 2.5, 0.6, prop_width)
	sand.mesh = bmesh
	sand.position = Vector3(0.0, -0.1, 0.0)
	sand.material_override = _get_flat_material("beach_sand", Color(0.86, 0.78, 0.58), 0.95)
	root.add_child(sand)

	var col := CollisionShape3D.new()
	col.set_meta("gta_internal", true)
	var shape := BoxShape3D.new()
	shape.size = Vector3(prop_length * 2.5, 0.6, prop_width)
	col.shape = shape
	col.position = Vector3(0.0, -0.1, 0.0)
	add_child(col, false, Node.INTERNAL_MODE_BACK)


func _build_vinewood_hill(root: Node3D) -> void:
	var hill := MeshInstance3D.new()
	var cmesh := CylinderMesh.new()
	cmesh.bottom_radius = prop_length * 0.65
	cmesh.top_radius = prop_length * 0.26
	cmesh.height = prop_width
	cmesh.radial_segments = 16
	hill.mesh = cmesh
	hill.position = Vector3(0.0, prop_width * 0.5 - 0.5, 0.0)
	hill.material_override = _get_flat_material("vinewood_grass", Color(0.24, 0.38, 0.19), 0.96)
	root.add_child(hill)

	var rock_packed: PackedScene = _get_cached_scene("res://assets/models/city/rock_boulder.glb")
	if rock_packed != null:
		for i: int in range(3):
			var rinst: Node3D = rock_packed.instantiate() as Node3D
			if rinst != null:
				var ang: float = float(i) * 2.1
				rinst.position = Vector3(cos(ang) * prop_length * 0.35, 1.0, sin(ang) * prop_length * 0.35)
				rinst.scale = Vector3(2.8, 2.8, 2.8)
				root.add_child(rinst)


func _build_city_ground(root: Node3D) -> void:
	var ground := MeshInstance3D.new()
	var bmesh := BoxMesh.new()
	bmesh.size = Vector3(360.0, 2.0, 290.0)
	ground.mesh = bmesh
	ground.position = Vector3(0.0, -1.0, -35.0)
	ground.material_override = _get_flat_material("city_plaza_ground", Color(0.30, 0.33, 0.31), 0.94)
	root.add_child(ground)

	var park := MeshInstance3D.new()
	var pmesh := BoxMesh.new()
	pmesh.size = Vector3(30.0, 0.06, 30.0)
	park.mesh = pmesh
	park.position = Vector3(25.0, 0.03, 25.0)
	park.material_override = _get_flat_material("park_grass", Color(0.22, 0.44, 0.21), 0.95)
	root.add_child(park)

	var col := CollisionShape3D.new()
	col.set_meta("gta_internal", true)
	var shape := BoxShape3D.new()
	shape.size = Vector3(420.0, 2.0, 380.0)
	col.shape = shape
	col.position = Vector3(0.0, -1.0, 0.0)
	add_child(col, false, Node.INTERNAL_MODE_BACK)
