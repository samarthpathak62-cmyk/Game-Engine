@tool
extends EditorPlugin
## GTA Studio - No-Code Visual World Builder Plugin for Godot 4
## Adds BOTH a Top 3D Viewport Quick-Toolbar AND a Right-Side Studio Dock
## for 1-Click spawning of Real 3D .glb Buildings, Supercars, NPCs & Missions!

const CityPropScript = preload("res://scripts/world/city_prop.gd")
const GTAVehicleScript = preload("res://scripts/vehicles/gta_vehicle.gd")
const GTACharacterScript = preload("res://scripts/player/gta_character.gd")
const GTANPCScript = preload("res://scripts/world/gta_npc.gd")
const MissionMarkerScript = preload("res://scripts/world/mission_marker.gd")
const GTASkyScript = preload("res://scripts/world/sky_environment.gd")

var _dock: Control = null
var _top_bar: HBoxContainer = null


func _enter_tree() -> void:
	_dock = _create_studio_dock()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)

	_top_bar = _create_viewport_topbar()
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _top_bar)


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
	if _top_bar != null:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _top_bar)
		_top_bar.queue_free()
		_top_bar = null


func _create_viewport_topbar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)

	var badge := Label.new()
	badge.text = " GTA STUDIO: "
	badge.add_theme_color_override("font_color", Color(0.38, 0.96, 0.56))
	bar.add_child(badge)

	_add_quick_top_btn(bar, "+ Skyscraper", func() -> Node3D:
		return _make_city_prop("Skyscraper", 3, randi() % 6, Vector3(14.0, 1.0, 14.0))
	)
	_add_quick_top_btn(bar, "+ Shop/Hotel", func() -> Node3D:
		return _make_city_prop("DowntownBlock", 4, randi() % 5, Vector3(14.0, 1.0, 14.0))
	)
	_add_quick_top_btn(bar, "+ Road", func() -> Node3D:
		return _make_city_prop("RoadSegment", 1, 0, Vector3(14.0, 1.0, 42.0))
	)
	_add_quick_top_btn(bar, "+ SU7 Supercar", func() -> Node3D:
		return _make_vehicle("PegassiSU7", 0, false, false)
	)
	_add_quick_top_btn(bar, "+ G63 SUV", func() -> Node3D:
		return _make_vehicle("BenefactorG63", 2, false, false)
	)
	_add_quick_top_btn(bar, "+ Police", func() -> Node3D:
		return _make_vehicle("LSPDCruiser", 1, false, true)
	)
	_add_quick_top_btn(bar, "+ 3D NPC", func() -> Node3D:
		return _make_npc()
	)
	return bar


func _add_quick_top_btn(bar: HBoxContainer, txt: String, factory: Callable) -> void:
	var b := Button.new()
	b.text = txt
	b.flat = true
	b.pressed.connect(func() -> void:
		var inst: Node3D = factory.call() as Node3D
		_spawn_into_edited_scene(inst)
	)
	bar.add_child(b)


func _create_studio_dock() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "GTA Studio"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(main_vbox)

	var title := Label.new()
	title.text = "GTA STUDIO (REAL 3D)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.38, 0.96, 0.55))
	main_vbox.add_child(title)

	var play_btn := Button.new()
	play_btn.text = "▶ LAUNCH LOS SANTOS (F5)"
	play_btn.custom_minimum_size = Vector2(0.0, 38.0)
	play_btn.pressed.connect(func() -> void:
		EditorInterface.play_main_scene()
	)
	main_vbox.add_child(play_btn)

	_add_section_header(main_vbox, "1. REAL 3D ARCHITECTURE")
	_add_spawn_btn(main_vbox, "+ 6-Story Skyscraper", func() -> Node3D:
		return _make_city_prop("Skyscraper", 3, 0, Vector3(14.0, 1.0, 14.0))
	)
	_add_spawn_btn(main_vbox, "+ Modern Glass Tower", func() -> Node3D:
		return _make_city_prop("GlassTower", 3, 1, Vector3(14.0, 1.0, 14.0))
	)
	_add_spawn_btn(main_vbox, "+ Downtown Commercial Block", func() -> Node3D:
		return _make_city_prop("CommercialBlock", 4, 0, Vector3(14.0, 1.0, 14.0))
	)
	_add_spawn_btn(main_vbox, "+ Vinewood Hills Mansion", func() -> Node3D:
		return _make_city_prop("VinewoodMansion", 4, 5, Vector3(14.0, 1.0, 14.0))
	)
	_add_spawn_btn(main_vbox, "+ PBR Asphalt Road", func() -> Node3D:
		return _make_city_prop("AsphaltRoad", 1, 0, Vector3(14.0, 1.0, 42.0))
	)
	_add_spawn_btn(main_vbox, "+ 4-Way Zebra Intersection", func() -> Node3D:
		return _make_city_prop("Intersection", 2, 0, Vector3(14.0, 1.0, 14.0))
	)
	_add_spawn_btn(main_vbox, "+ Bridge Stunt Ramp", func() -> Node3D:
		return _make_city_prop("BridgeRamp", 5, 0, Vector3(6.0, 1.0, 10.0))
	)
	_add_spawn_btn(main_vbox, "+ Double Highway Streetlight", func() -> Node3D:
		return _make_city_prop("Streetlight", 6, 0, Vector3(1.0, 6.0, 1.0))
	)
	_add_spawn_btn(main_vbox, "+ Lush City Tree", func() -> Node3D:
		return _make_city_prop("CityTree", 7, randi() % 3, Vector3(1.0, 6.0, 1.0))
	)

	_add_section_header(main_vbox, "2. REAL 3D VEHICLES (.GLB)")
	_add_spawn_btn(main_vbox, "+ Pegassi SU7 PBR Supercar", func() -> Node3D:
		return _make_vehicle("PegassiSU7", 0, false, false)
	)
	_add_spawn_btn(main_vbox, "+ Benefactor G63 AMG SUV", func() -> Node3D:
		return _make_vehicle("BenefactorG63", 2, false, false)
	)
	_add_spawn_btn(main_vbox, "+ LSPD Police Cruiser (AI)", func() -> Node3D:
		return _make_vehicle("LSPDCruiser", 1, false, true)
	)
	_add_spawn_btn(main_vbox, "+ Bravado Muscle Coupe", func() -> Node3D:
		return _make_vehicle("MuscleCoupe", 4, false, false)
	)
	_add_spawn_btn(main_vbox, "+ AI Traffic Taxi", func() -> Node3D:
		return _make_vehicle("TrafficTaxi", 3, true, false)
	)

	_add_section_header(main_vbox, "3. RIGGED 3D HUMANS & MISSIONS")
	_add_spawn_btn(main_vbox, "+ Animated 3D Civilian NPC", func() -> Node3D:
		return _make_npc()
	)
	_add_spawn_btn(main_vbox, "+ Mission Checkpoint ($)", func() -> Node3D:
		var m := Area3D.new()
		m.name = "MissionCheckpoint"
		m.set_script(MissionMarkerScript)
		return m
	)

	_add_section_header(main_vbox, "4. TIME & GRAPHICS PRESET")
	var mood_hbox := HBoxContainer.new()
	main_vbox.add_child(mood_hbox)
	_add_mood_btn(mood_hbox, "Sunny Day", 0)
	_add_mood_btn(mood_hbox, "Sunset", 1)
	_add_mood_btn(mood_hbox, "Night", 2)

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
		var root: Node = EditorInterface.get_edited_scene_root()
		if root == null:
			return
		for child: Node in root.find_children("*", "WorldEnvironment", true, false):
			if child.get_script() == GTASkyScript:
				child.set("mood_preset", preset_id)
				return
	)
	hbox.add_child(btn)


func _make_city_prop(base_name: String, ptype: int, var_idx: int, psize: Vector3) -> Node3D:
	var prop := StaticBody3D.new()
	prop.name = base_name
	prop.set_script(CityPropScript)
	prop.set("prop_type", ptype)
	prop.set("variant_index", var_idx)
	prop.set("prop_size", psize)
	return prop


func _make_vehicle(base_name: String, preset: int, traffic_ai: bool, cop_ai: bool) -> Node3D:
	var car := VehicleBody3D.new()
	car.name = base_name
	car.set_script(GTAVehicleScript)
	car.set("vehicle_preset", preset)
	car.set("ai_traffic_mode", traffic_ai)
	car.set("police_pursuit_ai", cop_ai)
	car.position = Vector3(0.0, 0.35, 0.0)
	return car


func _make_npc() -> Node3D:
	var npc := CharacterBody3D.new()
	npc.name = "PedestrianNPC"
	npc.set_script(GTANPCScript)
	npc.set("npc_skin", randi() % 4)
	return npc


func _spawn_into_edited_scene(node: Node3D) -> void:
	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null:
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


func _compute_editor_camera_ground_point() -> Vector3:
	var vp: SubViewport = EditorInterface.get_editor_viewport_3d(0)
	if vp == null:
		return Vector3.ZERO
	var cam: Camera3D = vp.get_camera_3d()
	if cam == null:
		return Vector3.ZERO

	var cam_pos: Vector3 = cam.global_position
	var cam_dir: Vector3 = -cam.global_transform.basis.z.normalized()
	var hit_pos: Vector3 = cam_pos + cam_dir * 20.0
	if cam_dir.y < -0.08 and cam_pos.y > 0.0:
		var t: float = clampf(-cam_pos.y / cam_dir.y, 6.0, 48.0)
		hit_pos = cam_pos + cam_dir * t

	return Vector3(snappedf(hit_pos.x, 1.0), 0.0, snappedf(hit_pos.z, 1.0))
