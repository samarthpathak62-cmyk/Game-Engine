@tool
extends EditorPlugin
## GTA Studio - No-Code Visual World Builder Plugin for Godot 4
## Adds a clean "GTA Studio" panel with 1-Click buttons to spawn Roads,
## Skyscrapers, Ramps, Sports/Police Cars, AI Pedestrians, and Missions.

const CityPropScript = preload("res://scripts/world/city_prop.gd")
const GTAVehicleScript = preload("res://scripts/vehicles/gta_vehicle.gd")
const GTACharacterScript = preload("res://scripts/player/gta_character.gd")
const GTANPCScript = preload("res://scripts/world/gta_npc.gd")
const MissionMarkerScript = preload("res://scripts/world/mission_marker.gd")
const GTASkyScript = preload("res://scripts/world/sky_environment.gd")

var _dock: Control = null


func _enter_tree() -> void:
	_dock = _create_studio_dock()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null


func _create_studio_dock() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "GTA Studio"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(main_vbox)

	# Header Title
	var title := Label.new()
	title.text = "GTA STUDIO (NO-CODE)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.38, 0.96, 0.55))
	main_vbox.add_child(title)

	var play_btn := Button.new()
	play_btn.text = "▶ PLAY OPEN WORLD (F5)"
	play_btn.custom_minimum_size = Vector2(0.0, 38.0)
	play_btn.pressed.connect(func() -> void:
		EditorInterface.play_main_scene()
	)
	main_vbox.add_child(play_btn)

	# Section 1: City & Roads
	_add_section_header(main_vbox, "1. CITY & ROADS")
	_add_spawn_btn(main_vbox, "+ Straight Road", func() -> Node3D:
		return _make_city_prop("RoadStraight", 1, Color(0.14, 0.15, 0.17), 1, Vector3(12.0, 1.0, 26.0))
	)
	_add_spawn_btn(main_vbox, "+ 4-Way Crossroads", func() -> Node3D:
		return _make_city_prop("Crossroads", 2, Color(0.14, 0.15, 0.17), 1, Vector3(15.6, 1.0, 15.6))
	)
	_add_spawn_btn(main_vbox, "+ Glass Skyscraper", func() -> Node3D:
		return _make_city_prop("Skyscraper", 3, Color(0.20, 0.27, 0.38), 10, Vector3(14.0, 1.0, 14.0))
	)
	_add_spawn_btn(main_vbox, "+ Neon Shop / Building", func() -> Node3D:
		return _make_city_prop("NeonShop", 4, Color(0.84, 0.68, 0.52), 3, Vector3(12.0, 1.0, 10.0))
	)
	_add_spawn_btn(main_vbox, "+ Stunt Jump Ramp", func() -> Node3D:
		return _make_city_prop("StuntRamp", 5, Color(0.95, 0.55, 0.12), 1, Vector3(5.4, 1.0, 9.5))
	)
	_add_spawn_btn(main_vbox, "+ Streetlight", func() -> Node3D:
		return _make_city_prop("Streetlight", 6, Color(0.25, 0.27, 0.30), 1, Vector3(1.0, 6.0, 1.0))
	)
	_add_spawn_btn(main_vbox, "+ Los Santos Palm Tree", func() -> Node3D:
		return _make_city_prop("PalmTree", 7, Color(0.46, 0.33, 0.22), 1, Vector3(1.0, 7.0, 1.0))
	)

	# Section 2: Vehicles
	_add_section_header(main_vbox, "2. VEHICLES (DRIVABLE)")
	_add_spawn_btn(main_vbox, "+ Sports Car (Infernus GT)", func() -> Node3D:
		return _make_vehicle("SportsCar", 0, false, false, Vector3(0.0, 0.3, 0.0))
	)
	_add_spawn_btn(main_vbox, "+ Police Cruiser (Pursuit AI)", func() -> Node3D:
		return _make_vehicle("PoliceCruiser", 1, false, true, Vector3(0.0, 0.3, 0.0))
	)
	_add_spawn_btn(main_vbox, "+ Offroad SUV (Goliath 4x4)", func() -> Node3D:
		return _make_vehicle("GoliathSUV", 2, false, false, Vector3(0.0, 0.35, 0.0))
	)
	_add_spawn_btn(main_vbox, "+ AI Traffic Taxi", func() -> Node3D:
		return _make_vehicle("TrafficTaxi", 3, true, false, Vector3(0.0, 0.3, 0.0))
	)

	# Section 3: NPCs, Missions & Player
	_add_section_header(main_vbox, "3. AI, MISSIONS & PLAYER")
	_add_spawn_btn(main_vbox, "+ Pedestrian NPC (AI)", func() -> Node3D:
		var npc := CharacterBody3D.new()
		npc.name = "PedestrianNPC"
		npc.set_script(GTANPCScript)
		npc.set("shirt_color", Color.from_hsv(randf(), 0.65, 0.90))
		return npc
	)
	_add_spawn_btn(main_vbox, "+ Mission Checkpoint ($)", func() -> Node3D:
		var m := Area3D.new()
		m.name = "MissionCheckpoint"
		m.set_script(MissionMarkerScript)
		return m
	)
	_add_spawn_btn(main_vbox, "+ Switchable Protagonist", func() -> Node3D:
		var p := CharacterBody3D.new()
		p.name = "Protagonist"
		p.set_script(GTACharacterScript)
		p.set("is_starting_player", false)
		return p
	)

	# Section 4: Sky & Mood Presets
	_add_section_header(main_vbox, "4. SKY & LIGHTING VIBE")
	var mood_hbox := HBoxContainer.new()
	main_vbox.add_child(mood_hbox)
	_add_mood_btn(mood_hbox, "Sunset", 0)
	_add_mood_btn(mood_hbox, "Noon", 1)
	_add_mood_btn(mood_hbox, "Night", 2)

	# Quick Help Box
	var tip := Label.new()
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size", 12)
	tip.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88))
	tip.text = "\nHOW TO USE (ZERO CODE):\n1. Click any button above to drop object in front of camera.\n2. Drag colored arrows in 3D view to place it.\n3. Use right-side Inspector sliders to edit Speed, Floors, Color, or drop your own .glb 3D model!"
	main_vbox.add_child(tip)

	return scroll


func _add_section_header(vbox: VBoxContainer, text_str: String) -> void:
	var sep := HSeparator.new()
	vbox.add_child(sep)
	var lbl := Label.new()
	lbl.text = text_str
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.28))
	vbox.add_child(lbl)


func _add_spawn_btn(vbox: VBoxContainer, label_txt: String, factory: Callable) -> void:
	var btn := Button.new()
	btn.text = label_txt
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(func() -> void:
		var inst: Node3D = factory.call() as Node3D
		_spawn_into_edited_scene(inst)
	)
	vbox.add_child(btn)


func _add_mood_btn(hbox: HBoxContainer, label_txt: String, preset_id: int) -> void:
	var btn := Button.new()
	btn.text = label_txt
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(func() -> void:
		_apply_sky_preset_in_scene(preset_id)
	)
	hbox.add_child(btn)


func _make_city_prop(base_name: String, ptype: int, col: Color, flrs: int, psize: Vector3) -> Node3D:
	var prop := StaticBody3D.new()
	prop.name = base_name
	prop.set_script(CityPropScript)
	prop.set("prop_type", ptype)
	prop.set("primary_color", col)
	prop.set("floors", flrs)
	prop.set("prop_size", psize)
	return prop


func _make_vehicle(base_name: String, preset: int, traffic_ai: bool, cop_ai: bool, y_off: Vector3) -> Node3D:
	var car := VehicleBody3D.new()
	car.name = base_name
	car.set_script(GTAVehicleScript)
	car.set("vehicle_preset", preset)
	car.set("ai_traffic_mode", traffic_ai)
	car.set("police_pursuit_ai", cop_ai)
	car.position = y_off
	return car


func _spawn_into_edited_scene(node: Node3D) -> void:
	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null:
		push_warning("GTA Studio: Please open a 3D scene (e.g. scenes/main_city.tscn) first!")
		node.queue_free()
		return

	var spawn_pos: Vector3 = _compute_editor_camera_ground_point() + node.position
	node.position = spawn_pos

	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	undo_redo.create_action("GTA Studio Spawn " + node.name)
	undo_redo.add_do_method(root, "add_child", node, true)
	undo_redo.add_do_property(node, "owner", root)
	undo_redo.add_do_reference(node)
	undo_redo.add_undo_method(root, "remove_child", node)
	undo_redo.commit_action()

	var sel: EditorSelection = EditorInterface.get_selection()
	sel.clear()
	sel.add_node(node)


func _apply_sky_preset_in_scene(preset_id: int) -> void:
	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null:
		return
	for child: Node in root.find_children("*", "WorldEnvironment", true, false):
		if child.get_script() == GTASkyScript:
			child.set("mood_preset", preset_id)
			return

	var sky_node := WorldEnvironment.new()
	sky_node.name = "GTASkyEnvironment"
	sky_node.set_script(GTASkyScript)
	root.add_child(sky_node, true)
	sky_node.owner = root
	sky_node.set("mood_preset", preset_id)


func _compute_editor_camera_ground_point() -> Vector3:
	var vp: SubViewport = EditorInterface.get_editor_viewport_3d(0)
	if vp == null:
		return Vector3.ZERO
	var cam: Camera3D = vp.get_camera_3d()
	if cam == null:
		return Vector3.ZERO

	var cam_pos: Vector3 = cam.global_position
	var cam_dir: Vector3 = -cam.global_transform.basis.z.normalized()
	var hit_pos: Vector3 = cam_pos + cam_dir * 18.0
	if cam_dir.y < -0.08 and cam_pos.y > 0.0:
		var t: float = clampf(-cam_pos.y / cam_dir.y, 6.0, 42.0)
		hit_pos = cam_pos + cam_dir * t

	return Vector3(snappedf(hit_pos.x, 1.0), 0.0, snappedf(hit_pos.z, 1.0))
