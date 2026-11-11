extends Node
## GameManager (Autoload)
## Central orchestrator for GTA Studio Engine & Los Santos Open World:
## - App Modes: Main Menu, Playing, Pause Menu, Live 3D World Engine Builder
## - Full Mouse Capture management & Sensitivity
## - Graphics Quality Presets (Performance / High / Ultra Realism)
## - Cash ($), Wanted Stars (★), 3-Protagonist GTA 5 Sky-Zoom Switch

signal app_mode_changed(new_mode: int)
signal cash_changed(new_cash: int, delta_amount: int)
signal wanted_changed(new_stars: int)
signal prompt_changed(prompt_text: String)
signal active_target_changed(target_node: Node3D, in_vehicle: bool)
signal notification_pushed(title: String, subtitle: String, accent_color: Color)
signal protagonist_changed(slot_index: int, char_name: String)
signal aiming_changed(is_aiming: bool, weapon_name: String)
signal graphics_quality_changed(quality_level: int)

enum AppMode {
	MAIN_MENU = 0,
	PLAYING = 1,
	PAUSED = 2,
	WORLD_BUILDER = 3,
}

const MAX_WANTED_STARS: int = 5
const WANTED_DECAY_SECONDS: float = 22.0

var app_mode: int = AppMode.MAIN_MENU
var graphics_quality: int = 1 # 0=Performance, 1=High (Default), 2=Ultra Realism
var mouse_sensitivity: float = 0.0026

var cash: int = 5000
var wanted_level: int = 0
var _wanted_timer: float = 0.0

var active_character: Node3D = null
var active_vehicle: Node3D = null
var protagonists: Array[Node3D] = []
var active_protagonist_index: int = 0
var is_switching_character: bool = false

var _menu_orbit_cam: Camera3D = null
var _menu_orbit_angle: float = 0.35


func _ready() -> void:
	_setup_input_actions()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	call_deferred("_init_startup_mode")


func _init_startup_mode() -> void:
	_ensure_menu_camera()
	set_app_mode(AppMode.MAIN_MENU)


func _process(delta: float) -> void:
	if app_mode == AppMode.MAIN_MENU and is_instance_valid(_menu_orbit_cam):
		_menu_orbit_angle += delta * 0.11
		var radius: float = 68.0
		var cam_pos := Vector3(
			cos(_menu_orbit_angle) * radius,
			28.0 + sin(_menu_orbit_angle * 0.7) * 5.0,
			sin(_menu_orbit_angle) * radius
		)
		_menu_orbit_cam.global_position = cam_pos
		_menu_orbit_cam.look_at(Vector3(0.0, 9.0, 0.0), Vector3.UP)

	if app_mode == AppMode.PLAYING and wanted_level > 0:
		_wanted_timer -= delta
		if _wanted_timer <= 0.0:
			set_wanted_level(wanted_level - 1)
			if wanted_level == 0:
				push_banner("ESCAPED LSPD", "Wanted level cleared", Color(0.35, 0.95, 0.5))
			else:
				_wanted_timer = WANTED_DECAY_SECONDS


func _unhandled_input(event: InputEvent) -> void:
	if is_switching_character:
		return

	if event.is_action_pressed(&"pause_menu"):
		if app_mode == AppMode.PLAYING:
			set_app_mode(AppMode.PAUSED)
		elif app_mode == AppMode.PAUSED:
			set_app_mode(AppMode.PLAYING)
		elif app_mode == AppMode.WORLD_BUILDER:
			set_app_mode(AppMode.PAUSED)
		return

	if event.is_action_pressed(&"toggle_builder"):
		if app_mode == AppMode.PLAYING:
			set_app_mode(AppMode.WORLD_BUILDER)
		elif app_mode == AppMode.WORLD_BUILDER:
			set_app_mode(AppMode.PLAYING)
		return

	if app_mode != AppMode.PLAYING:
		return

	if event.is_action_pressed(&"switch_char_1"):
		switch_to_protagonist(0)
	elif event.is_action_pressed(&"switch_char_2"):
		switch_to_protagonist(1)
	elif event.is_action_pressed(&"switch_char_3"):
		switch_to_protagonist(2)
	elif event.is_action_pressed(&"cycle_time"):
		_cycle_world_time()


func set_app_mode(new_mode: int) -> void:
	app_mode = new_mode
	match app_mode:
		AppMode.MAIN_MENU:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			aiming_changed.emit(false, "")
			_ensure_menu_camera()
			if is_instance_valid(_menu_orbit_cam):
				_menu_orbit_cam.make_current()

		AppMode.PLAYING:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_activate_gameplay_camera()

		AppMode.PAUSED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			aiming_changed.emit(false, "")

		AppMode.WORLD_BUILDER:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			aiming_changed.emit(false, "")

	app_mode_changed.emit(app_mode)


func start_gameplay() -> void:
	set_app_mode(AppMode.PLAYING)
	push_banner("LOS SANTOS", "Welcome back — Press [TAB] anytime for 3D World Engine", Color(0.38, 0.95, 0.55))


func apply_graphics_quality(level: int) -> void:
	graphics_quality = clampi(level, 0, 2)
	var vp: Viewport = get_viewport()
	if vp != null:
		match graphics_quality:
			0:
				vp.msaa_3d = Viewport.MSAA_DISABLED
				vp.scaling_3d_scale = 0.85
			1:
				vp.msaa_3d = Viewport.MSAA_2X
				vp.scaling_3d_scale = 1.0
			2:
				vp.msaa_3d = Viewport.MSAA_4X
				vp.scaling_3d_scale = 1.0

	var scene_root: Node = get_tree().current_scene
	if scene_root != null:
		for child: Node in scene_root.find_children("*", "WorldEnvironment", true, false):
			if child.has_method("apply_quality_tier"):
				child.call("apply_quality_tier", graphics_quality)
	graphics_quality_changed.emit(graphics_quality)


func toggle_fullscreen() -> void:
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func spawn_supercar_near_player() -> void:
	var target: Node3D = get_focus_target()
	var scene_root: Node = get_tree().current_scene
	if not is_instance_valid(target) or scene_root == null:
		return
	var veh_scene: PackedScene = load("res://scenes/prefabs/sports_car.tscn") as PackedScene
	if veh_scene == null:
		return
	var inst: Node3D = veh_scene.instantiate() as Node3D
	scene_root.add_child(inst)
	var fwd: Vector3 = target.global_transform.basis.z.normalized()
	inst.global_position = target.global_position + fwd * 4.5 + Vector3(0.0, 0.4, 0.0)
	push_banner("PEGASSI SU7 DELIVERED", "Personal Supercar spawned nearby", Color(0.35, 0.85, 1.0))


func _ensure_menu_camera() -> void:
	if is_instance_valid(_menu_orbit_cam):
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	_menu_orbit_cam = Camera3D.new()
	_menu_orbit_cam.name = "MainMenuOrbitCamera"
	_menu_orbit_cam.fov = 62.0
	_menu_orbit_cam.far = 900.0
	scene_root.add_child(_menu_orbit_cam)


func _activate_gameplay_camera() -> void:
	if is_instance_valid(active_vehicle) and active_vehicle.has_method("activate_vehicle_camera"):
		active_vehicle.call("activate_vehicle_camera")
	elif is_instance_valid(active_character) and active_character.has_method("set_player_controlled"):
		active_character.call("set_player_controlled", true)


func register_protagonist(character: Node3D, slot_index: int, make_active: bool) -> void:
	if not protagonists.has(character):
		protagonists.append(character)
		protagonists.sort_custom(func(a: Node3D, b: Node3D) -> bool:
			return int(a.get("protagonist_slot")) < int(b.get("protagonist_slot"))
		)
	if make_active or active_character == null:
		active_character = character
		active_protagonist_index = slot_index
		active_target_changed.emit(character, false)
		protagonist_changed.emit(slot_index, String(character.get("character_name")))
		if app_mode == AppMode.MAIN_MENU and is_instance_valid(_menu_orbit_cam):
			_menu_orbit_cam.make_current()


func get_focus_target() -> Node3D:
	if is_instance_valid(active_vehicle):
		return active_vehicle
	if is_instance_valid(active_character):
		return active_character
	return null


func notify_entered_vehicle(character: Node3D, vehicle: Node3D) -> void:
	active_character = character
	active_vehicle = vehicle
	set_interaction_prompt("")
	aiming_changed.emit(false, "")
	active_target_changed.emit(vehicle, true)


func notify_exited_vehicle(character: Node3D) -> void:
	active_vehicle = null
	active_character = character
	active_target_changed.emit(character, false)


func notify_aiming(is_aiming: bool, weapon_label: String) -> void:
	aiming_changed.emit(is_aiming, weapon_label)


func add_cash(amount: int, reason: String = "") -> void:
	cash = max(0, cash + amount)
	cash_changed.emit(cash, amount)
	if reason != "":
		push_banner(reason, "+$" + str(amount) + " RESPECT +", Color(0.32, 0.96, 0.48))


func report_crime(stars_added: int = 1, reason: String = "CRIME REPORTED") -> void:
	var target_stars: int = mini(MAX_WANTED_STARS, maxi(wanted_level + stars_added, 1))
	_wanted_timer = WANTED_DECAY_SECONDS
	if target_stars != wanted_level:
		wanted_level = target_stars
		wanted_changed.emit(wanted_level)
		push_banner("WANTED LEVEL INCREASED", reason + " (" + str(wanted_level) + " ★)", Color(1.0, 0.32, 0.32))


func set_wanted_level(new_stars: int) -> void:
	wanted_level = clampi(new_stars, 0, MAX_WANTED_STARS)
	if wanted_level > 0:
		_wanted_timer = WANTED_DECAY_SECONDS
	wanted_changed.emit(wanted_level)


func set_interaction_prompt(text: String) -> void:
	prompt_changed.emit(text)


func push_banner(title: String, subtitle: String, color: Color = Color(1.0, 0.82, 0.2)) -> void:
	notification_pushed.emit(title, subtitle, color)


func switch_to_protagonist(slot_index: int) -> void:
	var valid_list: Array[Node3D] = []
	for p: Node3D in protagonists:
		if is_instance_valid(p):
			valid_list.append(p)
	protagonists = valid_list

	if slot_index < 0 or slot_index >= protagonists.size():
		return

	var target_char: Node3D = protagonists[slot_index]
	if target_char == active_character and active_vehicle == null:
		return

	var from_node: Node3D = get_focus_target()
	if not is_instance_valid(from_node):
		return

	is_switching_character = true

	if is_instance_valid(active_vehicle) and active_vehicle.has_method("exit_driver"):
		active_vehicle.call("exit_driver")

	if is_instance_valid(active_character) and active_character.has_method("set_player_controlled"):
		active_character.call("set_player_controlled", false)

	var scene_root: Node = get_tree().current_scene
	var sky_cam := Camera3D.new()
	sky_cam.fov = 68.0
	sky_cam.far = 900.0
	scene_root.add_child(sky_cam)

	var start_pos: Vector3 = from_node.global_position
	var end_pos: Vector3 = target_char.global_position

	sky_cam.global_position = start_pos + Vector3(0.0, 9.0, -7.0)
	sky_cam.look_at(start_pos, Vector3.UP)
	sky_cam.make_current()

	var high_from: Vector3 = start_pos + Vector3(0.0, 72.0, -10.0)
	var high_to: Vector3 = end_pos + Vector3(0.0, 72.0, -10.0)
	var land_to: Vector3 = end_pos + Vector3(0.0, 3.4, -5.0)

	var tween: Tween = create_tween()
	tween.tween_property(sky_cam, "global_position", high_from, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(sky_cam, "global_position", high_to, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sky_cam, "global_position", land_to, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		if is_instance_valid(sky_cam):
			sky_cam.queue_free()
		if is_instance_valid(target_char):
			active_character = target_char
			active_protagonist_index = slot_index
			if target_char.has_method("set_player_controlled"):
				target_char.call("set_player_controlled", true)
			var cname: String = String(target_char.get("character_name"))
			active_target_changed.emit(target_char, false)
			protagonist_changed.emit(slot_index, cname)
			push_banner("SWITCHED TO " + cname.to_upper(), "GTA V Character Switch", Color(0.4, 0.78, 1.0))
		is_switching_character = false
	)


func _cycle_world_time() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	for child: Node in scene_root.find_children("*", "WorldEnvironment", true, false):
		if child.has_method("cycle_preset"):
			var preset_label: String = String(child.call("cycle_preset"))
			push_banner("LOS SANTOS WEATHER", preset_label, Color(1.0, 0.72, 0.35))
			return


func _setup_input_actions() -> void:
	_bind_keys(&"move_forward", [KEY_W, KEY_UP])
	_bind_keys(&"move_back", [KEY_S, KEY_DOWN])
	_bind_keys(&"move_left", [KEY_A, KEY_LEFT])
	_bind_keys(&"move_right", [KEY_D, KEY_RIGHT])
	_bind_keys(&"jump_handbrake", [KEY_SPACE])
	_bind_keys(&"sprint_boost", [KEY_SHIFT])
	_bind_keys(&"interact_vehicle", [KEY_F, KEY_E])
	_bind_keys(&"toggle_weapon", [KEY_Q])
	_bind_keys(&"dodge_roll", [KEY_C, KEY_CTRL])
	_bind_keys(&"horn_siren", [KEY_H])
	_bind_keys(&"headlights", [KEY_L])
	_bind_keys(&"switch_char_1", [KEY_1])
	_bind_keys(&"switch_char_2", [KEY_2])
	_bind_keys(&"switch_char_3", [KEY_3])
	_bind_keys(&"cycle_time", [KEY_T])
	_bind_keys(&"toggle_help", [KEY_F1])
	_bind_keys(&"toggle_builder", [KEY_TAB])
	_bind_keys(&"pause_menu", [KEY_ESCAPE])
	_bind_mouse_button(&"aim_weapon", MOUSE_BUTTON_RIGHT)
	_bind_mouse_button(&"fire_weapon", MOUSE_BUTTON_LEFT)


func _bind_keys(action_name: StringName, keycodes: Array[Key]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.2)
	for code: Key in keycodes:
		var already_bound: bool = false
		for existing: InputEvent in InputMap.action_get_events(action_name):
			if existing is InputEventKey and (existing.physical_keycode == code or existing.keycode == code):
				already_bound = true
				break
		if not already_bound:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action_name, ev)


func _bind_mouse_button(action_name: StringName, button_idx: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.2)
	for existing: InputEvent in InputMap.action_get_events(action_name):
		if existing is InputEventMouseButton and existing.button_index == button_idx:
			return
	var ev := InputEventMouseButton.new()
	ev.button_index = button_idx
	InputMap.action_add_event(action_name, ev)
