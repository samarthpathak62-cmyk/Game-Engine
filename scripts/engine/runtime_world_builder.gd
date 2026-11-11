extends Node3D
class_name RuntimeWorldBuilder
## RuntimeWorldBuilder
## Live No-Code 3D GTA Game Engine Mode (Accessible from Main Menu or [TAB] key!).
## Lets the user fly around Los Santos, click to place Real 3D Buildings, Supercars,
## Police, Ramps, Trees, Pedestrians & Missions, Save their custom map, and Play instantly!

const SAVE_PATH: String = "user://custom_los_santos_map.json"
const CityPropScript = preload("res://scripts/world/city_prop.gd")
const GTAVehicleScript = preload("res://scripts/vehicles/gta_vehicle.gd")
const GTANPCScript = preload("res://scripts/world/gta_npc.gd")
const MissionMarkerScript = preload("res://scripts/world/mission_marker.gd")

const CATALOG: Array[Dictionary] = [
	{"id": "skyscraper", "label": "Skyscraper", "kind": "prop", "ptype": 3, "var": 0},
	{"id": "modern_tower", "label": "Glass Tower", "kind": "prop", "ptype": 3, "var": 1},
	{"id": "hotel", "label": "Hotel Block", "kind": "prop", "ptype": 4, "var": 1},
	{"id": "villa", "label": "Mansion", "kind": "prop", "ptype": 4, "var": 5},
	{"id": "road", "label": "Road Strip", "kind": "prop", "ptype": 1, "var": 0},
	{"id": "ramp", "label": "Stunt Ramp", "kind": "prop", "ptype": 5, "var": 0},
	{"id": "supercar", "label": "SU7 Supercar", "kind": "car", "preset": 0},
	{"id": "gwagon", "label": "G63 AMG SUV", "kind": "car", "preset": 2},
	{"id": "police", "label": "Police Car", "kind": "car", "preset": 1},
	{"id": "npc", "label": "3D Civilian", "kind": "npc", "skin": 0},
	{"id": "tree", "label": "Lush Tree", "kind": "prop", "ptype": 7, "var": 0},
	{"id": "mission", "label": "Mission ($)", "kind": "mission"},
]

var _active: bool = false
var _fly_cam: Camera3D = null
var _cursor_ring: MeshInstance3D = null
var _ui_layer: CanvasLayer = null
var _selected_label: Label = null
var _status_label: Label = null

var _selected_index: int = 0
var _place_rot_deg: float = 0.0
var _cam_yaw: float = 0.0
var _cam_pitch: float = -28.0
var _cursor_world_pos: Vector3 = Vector3.ZERO
var _placed_records: Array[Dictionary] = []
var _spawned_nodes: Array[Node3D] = []


func _ready() -> void:
	_setup_builder_nodes()
	_load_saved_custom_objects()
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null:
		gm.connect("app_mode_changed", _on_app_mode_changed)


func _on_app_mode_changed(new_mode: int) -> void:
	var want_active: bool = (new_mode == 3)
	if want_active == _active:
		return
	_active = want_active
	_ui_layer.visible = _active
	_cursor_ring.visible = _active

	if _active:
		var gm: Node = get_node_or_null("/root/GameManager")
		var focus: Node3D = (gm.call("get_focus_target") as Node3D) if (gm != null and gm.has_method("get_focus_target")) else null
		if is_instance_valid(focus):
			_fly_cam.global_position = focus.global_position + Vector3(0.0, 22.0, -24.0)
			_cam_yaw = PI
			_cam_pitch = -32.0
		else:
			_fly_cam.global_position = Vector3(0.0, 28.0, -35.0)
		_update_fly_cam_rotation()
		_fly_cam.make_current()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return

	# Hold Right Mouse Button to rotate Engine Camera
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_cam_yaw -= event.relative.x * 0.0032
		_cam_pitch = clampf(_cam_pitch - rad_to_deg(event.relative.y * 0.0032), -85.0, 45.0)
		_update_fly_cam_rotation()

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_place_rot_deg = fmod(_place_rot_deg + 45.0, 360.0)
			_refresh_selected_text()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_place_rot_deg = fmod(_place_rot_deg - 45.0 + 360.0, 360.0)
			_refresh_selected_text()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_place_selected_at_cursor()

	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_Z or event.physical_keycode == KEY_BACKSPACE:
			_undo_last_placed()


func _process(delta: float) -> void:
	if not _active or _fly_cam == null:
		return

	var move_in: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var up_down: float = 0.0
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE):
		up_down += 1.0
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_CTRL):
		up_down -= 1.0

	var fly_speed: float = 54.0 if Input.is_action_pressed(&"sprint_boost") else 24.0
	var fwd: Vector3 = -_fly_cam.global_transform.basis.z
	var right: Vector3 = _fly_cam.global_transform.basis.x
	var vel: Vector3 = (right * move_in.x + fwd * (-move_in.y) + Vector3.UP * up_down)
	if vel.length_squared() > 0.001:
		_fly_cam.global_position += vel.normalized() * fly_speed * delta
		_fly_cam.global_position.y = clampf(_fly_cam.global_position.y, 2.0, 165.0)

	_update_ground_cursor()


func _update_fly_cam_rotation() -> void:
	if _fly_cam != null:
		_fly_cam.rotation = Vector3(deg_to_rad(_cam_pitch), _cam_yaw, 0.0)


func _update_ground_cursor() -> void:
	var vp: Viewport = get_viewport()
	if vp == null or _fly_cam == null:
		return
	var mouse_pos: Vector2 = vp.get_mouse_position()
	var ray_origin: Vector3 = _fly_cam.project_ray_origin(mouse_pos)
	var ray_dir: Vector3 = _fly_cam.project_ray_normal(mouse_pos)

	var hit_pt: Vector3 = ray_origin + ray_dir * 30.0
	if ray_dir.y < -0.02:
		var t: float = clampf(-ray_origin.y / ray_dir.y, 2.0, 260.0)
		hit_pt = ray_origin + ray_dir * t

	_cursor_world_pos = Vector3(snappedf(hit_pt.x, 1.0), 0.08, snappedf(hit_pt.z, 1.0))
	_cursor_ring.global_position = _cursor_world_pos
	_cursor_ring.rotation_degrees.y = _place_rot_deg


func _place_selected_at_cursor() -> void:
	var item: Dictionary = CATALOG[_selected_index]
	var rec: Dictionary = {
		"id": String(item["id"]),
		"x": _cursor_world_pos.x,
		"z": _cursor_world_pos.z,
		"rot": _place_rot_deg,
	}
	var spawned: Node3D = _instantiate_from_record(rec)
	if spawned != null:
		_placed_records.append(rec)
		_spawned_nodes.append(spawned)
		_status_label.text = "Placed: " + String(item["label"]) + " (" + str(_placed_records.size()) + " objects)"


func _undo_last_placed() -> void:
	if _spawned_nodes.is_empty():
		_status_label.text = "Nothing to undo."
		return
	var last_node: Node3D = _spawned_nodes.pop_back() as Node3D
	if is_instance_valid(last_node):
		last_node.queue_free()
	if not _placed_records.is_empty():
		_placed_records.pop_back()
	_status_label.text = "Removed last placed object (" + str(_placed_records.size()) + " remaining)"


func _save_custom_map() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_placed_records, "\t"))
		file.close()
		_status_label.text = "Saved custom world (" + str(_placed_records.size()) + " objects) to disk!"


func _clear_custom_map() -> void:
	for n: Node3D in _spawned_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_spawned_nodes.clear()
	_placed_records.clear()
	_save_custom_map()
	_status_label.text = "Cleared custom placed objects."


func _load_saved_custom_objects() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Array:
		var arr: Array = parsed as Array
		for entry: Variant in arr:
			if entry is Dictionary:
				var d: Dictionary = entry as Dictionary
				var node: Node3D = _instantiate_from_record(d)
				if node != null:
					_placed_records.append(d)
					_spawned_nodes.append(node)


func _instantiate_from_record(rec: Dictionary) -> Node3D:
	var id_str: String = String(rec.get("id", "skyscraper"))
	var found: Dictionary = CATALOG[0]
	for c: Dictionary in CATALOG:
		if String(c["id"]) == id_str:
			found = c
			break

	var kind: String = String(found["kind"])
	var inst: Node3D = null

	if kind == "prop":
		var p := StaticBody3D.new()
		p.set_script(CityPropScript)
		p.set("prop_type", int(found["ptype"]))
		p.set("variant_index", int(found["var"]))
		if int(found["ptype"]) == 1:
			p.set("prop_size", Vector3(14.0, 1.0, 36.0))
		inst = p
	elif kind == "car":
		var v := VehicleBody3D.new()
		v.set_script(GTAVehicleScript)
		v.set("vehicle_preset", int(found["preset"]))
		if int(found["preset"]) == 1:
			v.set("police_pursuit_ai", true)
		inst = v
	elif kind == "npc":
		var npc := CharacterBody3D.new()
		npc.set_script(GTANPCScript)
		npc.set("npc_skin", randi() % 4)
		inst = npc
	elif kind == "mission":
		var m := Area3D.new()
		m.set_script(MissionMarkerScript)
		m.set("mission_title", "CUSTOM MISSION")
		m.set("cash_reward", 3000)
		inst = m

	if inst != null:
		add_child(inst)
		var y_pos: float = 0.35 if kind == "car" else 0.05
		inst.global_position = Vector3(float(rec.get("x", 0.0)), y_pos, float(rec.get("z", 0.0)))
		inst.rotation_degrees.y = float(rec.get("rot", 0.0))
	return inst


func _drop_player_and_play() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm == null:
		return
	var active_char: Node3D = gm.get("active_character") as Node3D
	if is_instance_valid(active_char) and gm.get("active_vehicle") == null:
		active_char.global_position = _cursor_world_pos + Vector3(0.0, 0.5, 0.0)
	if gm.has_method("set_app_mode"):
		gm.call("set_app_mode", 1)


func _setup_builder_nodes() -> void:
	_fly_cam = Camera3D.new()
	_fly_cam.fov = 68.0
	_fly_cam.far = 950.0
	add_child(_fly_cam)

	# Glowing Placement Cursor Ring
	_cursor_ring = MeshInstance3D.new()
	_cursor_ring.visible = false
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.4
	cyl.bottom_radius = 2.4
	cyl.height = 0.25
	cyl.cap_top = false
	cyl.cap_bottom = false
	_cursor_ring.mesh = cyl
	var rmat := StandardMaterial3D.new()
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = Color(0.25, 1.0, 0.55, 0.68)
	_cursor_ring.material_override = rmat
	add_child(_cursor_ring)

	# Engine UI Overlay
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 25
	_ui_layer.visible = false
	add_child(_ui_layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(root)

	# Top Engine Header Bar
	var top_bar := PanelContainer.new()
	top_bar.anchor_right = 1.0
	top_bar.offset_left = 16.0
	top_bar.offset_right = -16.0
	top_bar.offset_top = 12.0
	top_bar.offset_bottom = 66.0
	top_bar.add_theme_stylebox_override("panel", _panel_style(Color(0.05, 0.07, 0.11, 0.92), Color(0.32, 0.94, 0.55)))
	root.add_child(top_bar)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 14)
	top_bar.add_child(top_hbox)

	var badge := Label.new()
	badge.text = "🛠 GTA 3D WORLD ENGINE STUDIO"
	badge.add_theme_font_size_override("font_size", 17)
	badge.add_theme_color_override("font_color", Color(0.35, 0.96, 0.56))
	top_hbox.add_child(badge)

	_selected_label = Label.new()
	_selected_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selected_label.add_theme_font_size_override("font_size", 14)
	top_hbox.add_child(_selected_label)

	var undo_btn := Button.new()
	undo_btn.text = "Undo [Z]"
	undo_btn.pressed.connect(_undo_last_placed)
	top_hbox.add_child(undo_btn)

	var save_btn := Button.new()
	save_btn.text = "Save Map"
	save_btn.pressed.connect(_save_custom_map)
	top_hbox.add_child(save_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear Added"
	clear_btn.pressed.connect(_clear_custom_map)
	top_hbox.add_child(clear_btn)

	var play_btn := Button.new()
	play_btn.text = "▶ PLAY HERE [TAB]"
	play_btn.pressed.connect(_drop_player_and_play)
	top_hbox.add_child(play_btn)

	# Bottom 1-Click 3D Asset Palette Bar
	var bot_panel := PanelContainer.new()
	bot_panel.anchor_top = 1.0
	bot_panel.anchor_bottom = 1.0
	bot_panel.anchor_right = 1.0
	bot_panel.offset_left = 16.0
	bot_panel.offset_right = -16.0
	bot_panel.offset_top = -124.0
	bot_panel.offset_bottom = -14.0
	bot_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.05, 0.07, 0.11, 0.92), Color(0.28, 0.65, 0.98)))
	root.add_child(bot_panel)

	var bot_vbox := VBoxContainer.new()
	bot_panel.add_child(bot_vbox)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.96))
	_status_label.text = "Controls: Hold RIGHT-CLICK + WASD to Fly Camera  |  LEFT-CLICK on city to Place 3D Object  |  SCROLL WHEEL to Rotate"
	bot_vbox.add_child(_status_label)

	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	bot_vbox.add_child(grid)

	for idx: int in range(CATALOG.size()):
		var item: Dictionary = CATALOG[idx]
		var btn := Button.new()
		btn.text = "+ " + String(item["label"])
		btn.custom_minimum_size = Vector2(118.0, 36.0)
		var captured_idx: int = idx
		btn.pressed.connect(func() -> void:
			_selected_index = captured_idx
			_refresh_selected_text()
		)
		grid.add_child(btn)

	_refresh_selected_text()


func _refresh_selected_text() -> void:
	if _selected_label != null:
		var item: Dictionary = CATALOG[_selected_index]
		_selected_label.text = "Selected: " + String(item["label"]) + "  |  Rotation: " + str(int(_place_rot_deg)) + "°"


func _panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb
