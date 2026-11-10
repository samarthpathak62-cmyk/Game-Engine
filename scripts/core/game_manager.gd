extends Node
## GameManager (Autoload)
## Central brain for GTA Studio: manages Input bindings, Cash ($), Wanted Stars,
## 3-Protagonist GTA 5 Sky-Zoom Character Switching, and HUD notifications.

signal cash_changed(new_cash: int, delta_amount: int)
signal wanted_changed(new_stars: int)
signal prompt_changed(prompt_text: String)
signal active_target_changed(target_node: Node3D, in_vehicle: bool)
signal notification_pushed(title: String, subtitle: String, accent_color: Color)
signal protagonist_changed(slot_index: int, char_name: String)

const MAX_WANTED_STARS: int = 5
const WANTED_DECAY_SECONDS: float = 20.0

var cash: int = 2500
var wanted_level: int = 0
var _wanted_timer: float = 0.0

var active_character: Node3D = null
var active_vehicle: Node3D = null
var protagonists: Array[Node3D] = []
var active_protagonist_index: int = 0
var is_switching_character: bool = false


func _ready() -> void:
	_setup_input_actions()


func _process(delta: float) -> void:
	if wanted_level > 0:
		_wanted_timer -= delta
		if _wanted_timer <= 0.0:
			set_wanted_level(wanted_level - 1)
			if wanted_level == 0:
				push_banner("ESCAPED POLICE", "Wanted level cleared", Color(0.35, 0.95, 0.5))
			else:
				_wanted_timer = WANTED_DECAY_SECONDS


func _unhandled_input(event: InputEvent) -> void:
	if is_switching_character:
		return
	if event.is_action_pressed(&"switch_char_1"):
		switch_to_protagonist(0)
	elif event.is_action_pressed(&"switch_char_2"):
		switch_to_protagonist(1)
	elif event.is_action_pressed(&"switch_char_3"):
		switch_to_protagonist(2)
	elif event.is_action_pressed(&"cycle_time"):
		_cycle_world_time()


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
	active_target_changed.emit(vehicle, true)


func notify_exited_vehicle(character: Node3D) -> void:
	active_vehicle = null
	active_character = character
	active_target_changed.emit(character, false)


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
		push_banner("WANTED ★".repeat(1), reason + " (" + str(wanted_level) + " Stars)", Color(1.0, 0.32, 0.32))


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
	# Clean invalid references first
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

	# If currently driving a vehicle, exit cleanly before switching
	if is_instance_valid(active_vehicle) and active_vehicle.has_method("exit_driver"):
		active_vehicle.call("exit_driver")

	if is_instance_valid(active_character) and active_character.has_method("set_player_controlled"):
		active_character.call("set_player_controlled", false)

	var scene_root: Node = get_tree().current_scene
	var sky_cam := Camera3D.new()
	sky_cam.fov = 68.0
	scene_root.add_child(sky_cam)

	var start_pos: Vector3 = from_node.global_position
	var end_pos: Vector3 = target_char.global_position

	sky_cam.global_position = start_pos + Vector3(0.0, 8.0, -6.0)
	sky_cam.look_at(start_pos, Vector3.UP)
	sky_cam.make_current()

	var high_from: Vector3 = start_pos + Vector3(0.0, 58.0, -8.0)
	var high_to: Vector3 = end_pos + Vector3(0.0, 58.0, -8.0)
	var land_to: Vector3 = end_pos + Vector3(0.0, 3.2, -5.0)

	var tween: Tween = create_tween()
	tween.tween_property(sky_cam, "global_position", high_from, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(sky_cam, "global_position", high_to, 0.36).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
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
			push_banner("SWITCHED TO " + cname.to_upper(), "GTA 5 Character Wheel", Color(0.4, 0.78, 1.0))
		is_switching_character = false
	)


func _cycle_world_time() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	for child: Node in scene_root.find_children("*", "WorldEnvironment", true, false):
		if child.has_method("cycle_preset"):
			var preset_label: String = String(child.call("cycle_preset"))
			push_banner("WEATHER / TIME", preset_label, Color(1.0, 0.72, 0.35))
			return


func _setup_input_actions() -> void:
	_bind_keys(&"move_forward", [KEY_W, KEY_UP])
	_bind_keys(&"move_back", [KEY_S, KEY_DOWN])
	_bind_keys(&"move_left", [KEY_A, KEY_LEFT])
	_bind_keys(&"move_right", [KEY_D, KEY_RIGHT])
	_bind_keys(&"jump_handbrake", [KEY_SPACE])
	_bind_keys(&"sprint_boost", [KEY_SHIFT])
	_bind_keys(&"interact_vehicle", [KEY_F, KEY_E])
	_bind_keys(&"horn_siren", [KEY_H])
	_bind_keys(&"headlights", [KEY_L])
	_bind_keys(&"switch_char_1", [KEY_1])
	_bind_keys(&"switch_char_2", [KEY_2])
	_bind_keys(&"switch_char_3", [KEY_3])
	_bind_keys(&"cycle_time", [KEY_T])
	_bind_keys(&"toggle_help", [KEY_F1])
	_bind_keys(&"toggle_mouse", [KEY_ESCAPE])


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
