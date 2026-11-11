@tool
extends StaticBody3D
class_name CityProp
## CityProp
## High-Detail 3D Los Santos World Prop & Architecture Builder:
## Uses real 3D .glb Skyscrapers, Office Towers, Commercial Blocks, Mansions,
## Streetlights, Traffic Signals, Fountains, Trees + PBR Asphalt & Ocean Water Shaders!

enum PropType {
	LOS_SANTOS_TERRAIN = 0,
	ROAD_STRAIGHT = 1,
	ROAD_CROSS = 2,
	SKYSCRAPER = 3,
	COMMERCIAL_SHOP = 4,
	STUNT_RAMP = 5,
	STREETLIGHT = 6,
	CITY_TREE = 7,
	TRAFFIC_PROP = 8,
}

const AsphaltShader = preload("res://shaders/asphalt_road.gdshader")
const OceanShader = preload("res://shaders/ocean_water.gdshader")

const SKYSCRAPER_DEFS: Array[Dictionary] = [
	{"path": "res://assets/models/city/skyscraper_6story.glb", "scale": 5.2, "col": Vector3(11.2, 40.5, 13.0)},
	{"path": "res://assets/models/city/tower_modern_g.glb", "scale": 12.5, "col": Vector3(28.5, 31.0, 22.5)},
	{"path": "res://assets/models/city/tower_modern_e.glb", "scale": 14.5, "col": Vector3(18.0, 30.0, 19.4)},
	{"path": "res://assets/models/city/building_office_tower.glb", "scale": 3.5, "col": Vector3(20.0, 20.7, 7.8)},
	{"path": "res://assets/models/city/tower_modern_a.glb", "scale": 11.5, "col": Vector3(23.4, 19.3, 14.2)},
	{"path": "res://assets/models/city/tower_modern_c.glb", "scale": 15.0, "col": Vector3(14.5, 25.2, 12.6)},
]

const COMMERCIAL_DEFS: Array[Dictionary] = [
	{"path": "res://assets/models/city/building_downtown_block.glb", "scale": 2.8, "col": Vector3(22.3, 13.0, 7.6)},
	{"path": "res://assets/models/city/building_hotel_plaza.glb", "scale": 3.4, "col": Vector3(16.0, 19.3, 14.9)},
	{"path": "res://assets/models/city/building_apartments.glb", "scale": 3.3, "col": Vector3(15.3, 18.1, 12.7)},
	{"path": "res://assets/models/city/commercial_wide.glb", "scale": 3.0, "col": Vector3(20.4, 17.0, 8.1)},
	{"path": "res://assets/models/city/storefront_sign.glb", "scale": 4.0, "col": Vector3(8.6, 11.0, 8.6)},
	{"path": "res://assets/models/city/vinewood_mansion_1.glb", "scale": 3.2, "col": Vector3(8.2, 10.2, 12.4)},
	{"path": "res://assets/models/city/vinewood_mansion_2.glb", "scale": 3.2, "col": Vector3(11.6, 9.4, 9.8)},
]

const TREE_DEFS: Array[Dictionary] = [
	{"path": "res://assets/models/city/tree_lush_1.glb", "scale": 1.85},
	{"path": "res://assets/models/city/tree_lush_2.glb", "scale": 1.55},
	{"path": "res://assets/models/city/city_tree_tall.glb", "scale": 2.45},
]

const TRAFFIC_PROP_DEFS: Array[Dictionary] = [
	{"path": "res://assets/models/city/traffic_light.glb", "scale": 5.8, "col": Vector3(0.7, 5.0, 0.7)},
	{"path": "res://assets/models/city/stop_sign.glb", "scale": 5.2, "col": Vector3(0.5, 2.8, 0.5)},
	{"path": "res://assets/models/city/fountain_plaza.glb", "scale": 4.5, "col": Vector3(8.8, 2.1, 8.8)},
	{"path": "res://assets/models/city/rock_boulder.glb", "scale": 2.8, "col": Vector3(5.5, 4.0, 6.5)},
]

@export var prop_type: PropType = PropType.SKYSCRAPER:
	set(value):
		prop_type = value
		_rebuild_prop()

@export_range(0, 6, 1) var variant_index: int = 0:
	set(value):
		variant_index = value
		_rebuild_prop()

@export var primary_color: Color = Color(0.22, 0.28, 0.36):
	set(value):
		primary_color = value
		_rebuild_prop()

@export_range(1, 20, 1) var floors: int = 8

@export var prop_size: Vector3 = Vector3(14.0, 1.0, 44.0):
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
		_add_box_collider(Vector3(6.0, 6.0, 6.0), Vector3(0.0, 3.0, 0.0))
		return

	match prop_type:
		PropType.LOS_SANTOS_TERRAIN:
			_build_los_santos_terrain(root)
		PropType.ROAD_STRAIGHT:
			_build_road_straight(root)
		PropType.ROAD_CROSS:
			_build_road_cross(root)
		PropType.SKYSCRAPER:
			_build_glb_entry(root, SKYSCRAPER_DEFS[variant_index % SKYSCRAPER_DEFS.size()])
		PropType.COMMERCIAL_SHOP:
			_build_glb_entry(root, COMMERCIAL_DEFS[variant_index % COMMERCIAL_DEFS.size()])
		PropType.STUNT_RAMP:
			_build_stunt_ramp(root)
		PropType.STREETLIGHT:
			_build_streetlight(root)
		PropType.CITY_TREE:
			_build_tree(root)
		PropType.TRAFFIC_PROP:
			_build_glb_entry(root, TRAFFIC_PROP_DEFS[variant_index % TRAFFIC_PROP_DEFS.size()])


func _build_los_santos_terrain(root: Node3D) -> void:
	# 1. Main City Concrete/Grass Ground Slab (340m x 340m)
	var turf_mat := StandardMaterial3D.new()
	turf_mat.albedo_color = Color(0.24, 0.29, 0.22)
	turf_mat.roughness = 0.90
	_add_mesh_box(root, Vector3(340.0, 2.0, 340.0), Vector3(0.0, -1.0, 0.0), turf_mat)
	_add_box_collider(Vector3(340.0, 2.0, 340.0), Vector3(0.0, -1.0, 0.0))

	# 2. Vespucci Sandy Beach Shoreline (South Coast Z = -145..-215)
	var sand_mat := StandardMaterial3D.new()
	sand_mat.albedo_color = Color(0.84, 0.76, 0.58)
	sand_mat.roughness = 0.88
	var beach := MeshInstance3D.new()
	var b_mesh := BoxMesh.new()
	b_mesh.size = Vector3(420.0, 1.4, 72.0)
	beach.mesh = b_mesh
	beach.material_override = sand_mat
	beach.position = Vector3(0.0, -0.62, -182.0)
	beach.rotation_degrees.x = 2.2
	root.add_child(beach)

	# 3. Animated Pacific Ocean Water Shader (South & West Horizon)
	var ocean_mat := ShaderMaterial.new()
	ocean_mat.shader = OceanShader
	var ocean := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(900.0, 420.0)
	plane.subdivide_width = 96
	plane.subdivide_depth = 64
	ocean.mesh = plane
	ocean.material_override = ocean_mat
	ocean.position = Vector3(0.0, -1.15, -395.0)
	root.add_child(ocean)

	# 4. Sculpted Smooth 3D Vinewood Hills Backdrop (North Z = +155..+265)
	_build_vinewood_hills(root)


func _build_vinewood_hills(root: Node3D) -> void:
	var hill_mat := StandardMaterial3D.new()
	hill_mat.albedo_color = Color(0.22, 0.34, 0.19)
	hill_mat.roughness = 0.92

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols: int = 36
	var rows: int = 16
	var start_x: float = -220.0
	var step_x: float = 440.0 / float(cols)
	var start_z: float = 148.0
	var step_z: float = 120.0 / float(rows)

	for rz: int in range(rows):
		for cx: int in range(cols):
			var x0: float = start_x + float(cx) * step_x
			var x1: float = x0 + step_x
			var z0: float = start_z + float(rz) * step_z
			var z1: float = z0 + step_z

			var p00 := Vector3(x0, _hill_h(x0, z0, start_z), z0)
			var p10 := Vector3(x1, _hill_h(x1, z0, start_z), z0)
			var p01 := Vector3(x0, _hill_h(x0, z1, start_z), z1)
			var p11 := Vector3(x1, _hill_h(x1, z1, start_z), z1)

			st.add_vertex(p00)
			st.add_vertex(p10)
			st.add_vertex(p11)

			st.add_vertex(p00)
			st.add_vertex(p11)
			st.add_vertex(p01)

	st.generate_normals()
	var hill_mesh: ArrayMesh = st.commit()
	var hill_inst := MeshInstance3D.new()
	hill_inst.mesh = hill_mesh
	hill_inst.material_override = hill_mat
	root.add_child(hill_inst)


func _hill_h(x: float, z: float, z_base: float) -> float:
	var dist_factor: float = clampf((z - z_base) / 95.0, 0.0, 1.0)
	var envelope: float = smoothstep(0.0, 1.0, dist_factor)
	var wave: float = 24.0 + sin(x * 0.028) * 11.0 + cos(x * 0.065 + z * 0.03) * 6.5
	return envelope * wave - 0.3


func _build_road_straight(root: Node3D) -> void:
	var width: float = maxf(10.0, prop_size.x)
	var length: float = maxf(10.0, prop_size.z)

	var road_mat := ShaderMaterial.new()
	road_mat.shader = AsphaltShader
	road_mat.set_shader_parameter("road_width", width)
	road_mat.set_shader_parameter("is_intersection", 0)

	var sidewalk_mat := StandardMaterial3D.new()
	sidewalk_mat.albedo_color = Color(0.62, 0.63, 0.65)
	sidewalk_mat.roughness = 0.82

	_add_mesh_box(root, Vector3(width, 0.10, length), Vector3(0.0, 0.05, 0.0), road_mat)
	_add_box_collider(Vector3(width + 4.4, 0.14, length), Vector3(0.0, 0.05, 0.0))

	# Raised Tiled Sidewalks + Curbs
	for sx: float in [-(width * 0.5 + 1.1), width * 0.5 + 1.1]:
		_add_mesh_box(root, Vector3(2.2, 0.20, length), Vector3(sx, 0.10, 0.0), sidewalk_mat)


func _build_road_cross(root: Node3D) -> void:
	var w: float = maxf(12.0, prop_size.x)

	var cross_mat := ShaderMaterial.new()
	cross_mat.shader = AsphaltShader
	cross_mat.set_shader_parameter("road_width", w)
	cross_mat.set_shader_parameter("is_intersection", 1)

	var corner_mat := StandardMaterial3D.new()
	corner_mat.albedo_color = Color(0.62, 0.63, 0.65)
	corner_mat.roughness = 0.82

	_add_mesh_box(root, Vector3(w, 0.10, w), Vector3(0.0, 0.05, 0.0), cross_mat)
	_add_box_collider(Vector3(w + 4.4, 0.14, w + 4.4), Vector3(0.0, 0.05, 0.0))

	# 4 Sidewalk Corner Plazas
	var c_off: float = w * 0.5 + 1.1
	for cx: float in [-c_off, c_off]:
		for cz: float in [-c_off, c_off]:
			_add_mesh_box(root, Vector3(2.2, 0.20, 2.2), Vector3(cx, 0.10, cz), corner_mat)


func _build_glb_entry(root: Node3D, def: Dictionary) -> void:
	var packed: PackedScene = load(String(def["path"])) as PackedScene
	var sc: float = float(def["scale"])
	if packed != null:
		var inst: Node3D = packed.instantiate() as Node3D
		if inst != null:
			inst.scale = Vector3(sc, sc, sc)
			root.add_child(inst)
	if def.has("col"):
		var csize: Vector3 = def["col"] as Vector3
		_add_box_collider(csize, Vector3(0.0, csize.y * 0.5, 0.0))


func _build_stunt_ramp(root: Node3D) -> void:
	var packed: PackedScene = load("res://assets/models/city/bridge_ramp.glb") as PackedScene
	if packed != null:
		var inst: Node3D = packed.instantiate() as Node3D
		if inst != null:
			inst.scale = Vector3(3.2, 3.6, 5.2)
			root.add_child(inst)

	var col := CollisionShape3D.new()
	col.set_meta("gta_internal", true)
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(6.2, 0.45, 10.2)
	col.shape = bshape
	col.position = Vector3(0.0, 1.25, 0.0)
	col.rotation_degrees.x = -16.5
	add_child(col, false, Node.INTERNAL_MODE_BACK)


func _build_streetlight(root: Node3D) -> void:
	var path: String = "res://assets/models/city/streetlight_double.glb" if variant_index % 2 == 0 else "res://assets/models/city/streetlight_single.glb"
	var packed: PackedScene = load(path) as PackedScene
	if packed != null:
		var inst: Node3D = packed.instantiate() as Node3D
		if inst != null:
			inst.scale = Vector3(5.5, 5.5, 5.5)
			root.add_child(inst)

	_add_box_collider(Vector3(0.45, 6.0, 0.45), Vector3(0.0, 3.0, 0.0))

	var omni := OmniLight3D.new()
	omni.light_color = Color(1.0, 0.86, 0.62)
	omni.light_energy = 1.9
	omni.omni_range = 18.0
	omni.position = Vector3(0.0, 5.8, 0.0)
	root.add_child(omni)


func _build_tree(root: Node3D) -> void:
	var def: Dictionary = TREE_DEFS[variant_index % TREE_DEFS.size()]
	var packed: PackedScene = load(String(def["path"])) as PackedScene
	var sc: float = float(def["scale"])
	if packed != null:
		var inst: Node3D = packed.instantiate() as Node3D
		if inst != null:
			inst.scale = Vector3(sc, sc, sc)
			root.add_child(inst)
	_add_box_collider(Vector3(0.85, 5.5, 0.85), Vector3(0.0, 2.75, 0.0))


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
