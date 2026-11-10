extends CanvasLayer
class_name GTAHUD
## GTAHUD
## Complete GTA 5 Style In-Game Interface:
## - Bottom-Left Live 3D Minimap Radar + Health/Armor Strip
## - Top-Right Cash ($), Wanted Stars (★), and 3-Character Switch Indicator
## - Bottom-Right Digital Speedometer & Nitro Gauge (when driving)
## - Center Mission Passed Banner & Vehicle Enter Prompt
## - Optional On-Screen Touch Controls for Android / Mobile exports

var _cash_label: Label = null
var _wanted_label: Label = null
var _char_badge: Label = null
var _prompt_panel: PanelContainer = null
var _prompt_label: Label = null
var _banner_box: VBoxContainer = null
var _banner_title: Label = null
var _banner_sub: Label = null
var _speed_panel: PanelContainer = null
var _speed_label: Label = null
var _car_name_label: Label = null
var _nitro_bar: ProgressBar = null
var _help_panel: PanelContainer = null

var _radar_subviewport: SubViewport = null
var _radar_camera: Camera3D = null
var _banner_timer: float = 0.0
var _wanted_flash_t: float = 0.0
var _current_stars: int = 0


func _ready() -> void:
	layer = 10
	_build_ui()
	call_deferred("_connect_game_manager")
	call_deferred("_link_minimap_world")


func _process(delta: float) -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm == null:
		return

	# Follow active character or driven car on Minimap Radar
	var target: Node3D = (gm.call("get_focus_target") as Node3D) if gm.has_method("get_focus_target") else null
	if is_instance_valid(target) and _radar_camera != null:
		_radar_camera.global_position = Vector3(target.global_position.x, 90.0, target.global_position.z)

	# Speedometer update when driving
	var active_car: Node3D = gm.get("active_vehicle") as Node3D
	if is_instance_valid(active_car):
		_speed_panel.visible = true
		var kmh: int = int(round(float(active_car.get("speed_kmh"))))
		_speed_label.text = str(kmh) + " KM/H"
		_car_name_label.text = String(active_car.get("vehicle_name")).to_upper()
		_nitro_bar.value = float(active_car.get("nitro_charge"))
	else:
		_speed_panel.visible = false

	# Flash Wanted Stars red/blue like police sirens
	if _current_stars > 0 and _wanted_label != null:
		_wanted_flash_t += delta * 6.5
		_wanted_label.modulate = Color(1.0, 0.30, 0.30) if sin(_wanted_flash_t) >= 0.0 else Color(0.45, 0.72, 1.0)

	# Fade Mission / Event Banner
	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0 and _banner_box != null:
			_banner_box.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_help") and _help_panel != null:
		_help_panel.visible = not _help_panel.visible


func _connect_game_manager() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm == null:
		return
	gm.connect("cash_changed", _on_cash_changed)
	gm.connect("wanted_changed", _on_wanted_changed)
	gm.connect("prompt_changed", _on_prompt_changed)
	gm.connect("notification_pushed", _on_notification_pushed)
	gm.connect("protagonist_changed", _on_protagonist_changed)

	_on_cash_changed(int(gm.get("cash")), 0)
	_on_wanted_changed(int(gm.get("wanted_level")))


func _link_minimap_world() -> void:
	if _radar_subviewport != null and get_viewport() != null:
		_radar_subviewport.world_3d = get_viewport().world_3d


func _on_cash_changed(new_cash: int, _delta_amt: int) -> void:
	if _cash_label != null:
		_cash_label.text = "$" + _format_commas(new_cash)


func _on_wanted_changed(stars: int) -> void:
	_current_stars = stars
	if _wanted_label == null:
		return
	if stars <= 0:
		_wanted_label.text = "☆ ☆ ☆ ☆ ☆"
		_wanted_label.modulate = Color(1.0, 1.0, 1.0, 0.25)
	else:
		var filled: String = "★ ".repeat(stars).strip_edges()
		var empty: String = " ☆".repeat(5 - stars)
		_wanted_label.text = filled + empty


func _on_prompt_changed(text: String) -> void:
	if _prompt_panel != null and _prompt_label != null:
		_prompt_panel.visible = text != ""
		_prompt_label.text = text


func _on_notification_pushed(title: String, subtitle: String, accent: Color) -> void:
	if _banner_box == null:
		return
	_banner_title.text = title
	_banner_title.modulate = accent
	_banner_sub.text = subtitle
	_banner_box.visible = true
	_banner_timer = 3.4


func _on_protagonist_changed(slot_idx: int, char_name: String) -> void:
	if _char_badge != null:
		_char_badge.text = "ACTIVE [" + str(slot_idx + 1) + "]: " + char_name.to_upper() + "   (Switch: 1 / 2 / 3)"


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# 1. TOP-RIGHT: Cash, Wanted Stars & Character Switcher Badge
	var top_right := VBoxContainer.new()
	top_right.anchor_left = 1.0
	top_right.anchor_right = 1.0
	top_right.offset_left = -360.0
	top_right.offset_right = -22.0
	top_right.offset_top = 18.0
	top_right.offset_bottom = 130.0
	top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_right)

	_wanted_label = Label.new()
	_wanted_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wanted_label.add_theme_font_size_override("font_size", 26)
	_wanted_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_wanted_label.add_theme_constant_override("outline_size", 6)
	_wanted_label.text = "☆ ☆ ☆ ☆ ☆"
	_wanted_label.modulate = Color(1.0, 1.0, 1.0, 0.25)
	top_right.add_child(_wanted_label)

	_cash_label = Label.new()
	_cash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cash_label.add_theme_font_size_override("font_size", 30)
	_cash_label.add_theme_color_override("font_color", Color(0.35, 0.94, 0.46))
	_cash_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_cash_label.add_theme_constant_override("outline_size", 7)
	_cash_label.text = "$2,500"
	top_right.add_child(_cash_label)

	_char_badge = Label.new()
	_char_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_char_badge.add_theme_font_size_override("font_size", 14)
	_char_badge.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0))
	_char_badge.add_theme_color_override("font_outline_color", Color.BLACK)
	_char_badge.add_theme_constant_override("outline_size", 4)
	_char_badge.text = "ACTIVE [1]: FRANKLIN   (Switch: 1 / 2 / 3)"
	top_right.add_child(_char_badge)

	# 2. BOTTOM-LEFT: GTA 5 Rectangular Minimap Radar + Health/Armor Bars
	var radar_frame := PanelContainer.new()
	radar_frame.anchor_top = 1.0
	radar_frame.anchor_bottom = 1.0
	radar_frame.offset_left = 20.0
	radar_frame.offset_right = 252.0
	radar_frame.offset_top = -190.0
	radar_frame.offset_bottom = -20.0
	radar_frame.add_theme_stylebox_override("panel", _make_box_style(Color(0.05, 0.06, 0.08, 0.88), Color(0.28, 0.32, 0.38), 2))
	root.add_child(radar_frame)

	var radar_vbox := VBoxContainer.new()
	radar_vbox.add_theme_constant_override("separation", 4)
	radar_frame.add_child(radar_vbox)

	var sub_container := SubViewportContainer.new()
	sub_container.stretch = true
	sub_container.custom_minimum_size = Vector2(220.0, 146.0)
	radar_vbox.add_child(sub_container)

	_radar_subviewport = SubViewport.new()
	_radar_subviewport.size = Vector2i(220, 146)
	_radar_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub_container.add_child(_radar_subviewport)

	_radar_camera = Camera3D.new()
	_radar_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_radar_camera.size = 78.0
	_radar_camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_radar_camera.position = Vector3(0.0, 90.0, 0.0)
	_radar_subviewport.add_child(_radar_camera)

	# Center player blip overlay on radar
	var blip := ColorRect.new()
	blip.color = Color(0.25, 0.95, 1.0)
	blip.custom_minimum_size = Vector2(8.0, 8.0)
	blip.position = Vector2(106.0, 69.0)
	sub_container.add_child(blip)

	# GTA 5 Health (Green) + Armor (Blue) Strip under radar
	var bars_hbox := HBoxContainer.new()
	bars_hbox.add_theme_constant_override("separation", 4)
	radar_vbox.add_child(bars_hbox)

	var hp_strip := ColorRect.new()
	hp_strip.color = Color(0.28, 0.86, 0.42)
	hp_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_strip.custom_minimum_size = Vector2(0.0, 7.0)
	bars_hbox.add_child(hp_strip)

	var armor_strip := ColorRect.new()
	armor_strip.color = Color(0.25, 0.65, 0.98)
	armor_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	armor_strip.custom_minimum_size = Vector2(0.0, 7.0)
	bars_hbox.add_child(armor_strip)

	# 3. BOTTOM-RIGHT: Vehicle Speedometer & Nitro Gauge
	_speed_panel = PanelContainer.new()
	_speed_panel.visible = false
	_speed_panel.anchor_left = 1.0
	_speed_panel.anchor_right = 1.0
	_speed_panel.anchor_top = 1.0
	_speed_panel.anchor_bottom = 1.0
	_speed_panel.offset_left = -245.0
	_speed_panel.offset_right = -20.0
	_speed_panel.offset_top = -126.0
	_speed_panel.offset_bottom = -20.0
	_speed_panel.add_theme_stylebox_override("panel", _make_box_style(Color(0.06, 0.07, 0.10, 0.84), Color(0.95, 0.62, 0.18), 2))
	root.add_child(_speed_panel)

	var sp_vbox := VBoxContainer.new()
	_speed_panel.add_child(sp_vbox)

	_car_name_label = Label.new()
	_car_name_label.add_theme_font_size_override("font_size", 13)
	_car_name_label.add_theme_color_override("font_color", Color(1.0, 0.76, 0.28))
	_car_name_label.text = "INFERNUS GT"
	sp_vbox.add_child(_car_name_label)

	_speed_label = Label.new()
	_speed_label.add_theme_font_size_override("font_size", 28)
	_speed_label.text = "0 KM/H"
	sp_vbox.add_child(_speed_label)

	_nitro_bar = ProgressBar.new()
	_nitro_bar.min_value = 0.0
	_nitro_bar.max_value = 100.0
	_nitro_bar.value = 100.0
	_nitro_bar.show_percentage = false
	_nitro_bar.custom_minimum_size = Vector2(180.0, 10.0)
	sp_vbox.add_child(_nitro_bar)

	# 4. CENTER BANNER (MISSION PASSED / CHARACTER SWITCH)
	_banner_box = VBoxContainer.new()
	_banner_box.visible = false
	_banner_box.anchor_left = 0.5
	_banner_box.anchor_right = 0.5
	_banner_box.offset_left = -280.0
	_banner_box.offset_right = 280.0
	_banner_box.offset_top = 86.0
	_banner_box.offset_bottom = 180.0
	_banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_banner_box)

	_banner_title = Label.new()
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_title.add_theme_font_size_override("font_size", 32)
	_banner_title.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner_title.add_theme_constant_override("outline_size", 8)
	_banner_box.add_child(_banner_title)

	_banner_sub = Label.new()
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.add_theme_font_size_override("font_size", 18)
	_banner_sub.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner_sub.add_theme_constant_override("outline_size", 5)
	_banner_box.add_child(_banner_sub)

	# 5. BOTTOM-CENTER INTERACTION PROMPT ("Press [F] to Drive...")
	_prompt_panel = PanelContainer.new()
	_prompt_panel.visible = false
	_prompt_panel.anchor_left = 0.5
	_prompt_panel.anchor_right = 0.5
	_prompt_panel.anchor_top = 1.0
	_prompt_panel.anchor_bottom = 1.0
	_prompt_panel.offset_left = -190.0
	_prompt_panel.offset_right = 190.0
	_prompt_panel.offset_top = -76.0
	_prompt_panel.offset_bottom = -32.0
	_prompt_panel.add_theme_stylebox_override("panel", _make_box_style(Color(0.05, 0.06, 0.09, 0.88), Color(0.35, 0.95, 0.55), 2))
	root.add_child(_prompt_panel)

	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 17)
	_prompt_panel.add_child(_prompt_label)

	# 6. TOP-LEFT CONTROLS CHEAT SHEET (Toggle with F1)
	_help_panel = PanelContainer.new()
	_help_panel.offset_left = 20.0
	_help_panel.offset_top = 18.0
	_help_panel.offset_right = 318.0
	_help_panel.offset_bottom = 186.0
	_help_panel.add_theme_stylebox_override("panel", _make_box_style(Color(0.06, 0.08, 0.12, 0.76), Color(0.26, 0.32, 0.44), 1))
	root.add_child(_help_panel)

	var help_lbl := Label.new()
	help_lbl.add_theme_font_size_override("font_size", 13)
	help_lbl.text = "GTA STUDIO CONTROLS [F1 Hide]\n• WASD / Arrows : Walk & Drive\n• Shift : Sprint / Car Nitro Boost\n• Space : Jump / Handbrake Drift\n• [F] or [E] : Enter / Exit Any Car\n• [1] [2] [3] : GTA 5 Sky Character Switch\n• [L] Headlights | [H] Siren | [T] Time of Day"
	_help_panel.add_child(help_lbl)

	# 7. MOBILE / TOUCHSCREEN BUTTONS (Auto-shown on Android/Tablets)
	if DisplayServer.is_touchscreen_available():
		_build_touch_controls(root)


func _build_touch_controls(root: Control) -> void:
	var pad_left := HBoxContainer.new()
	pad_left.anchor_top = 1.0
	pad_left.anchor_bottom = 1.0
	pad_left.offset_left = 270.0
	pad_left.offset_right = 450.0
	pad_left.offset_top = -95.0
	pad_left.offset_bottom = -25.0
	root.add_child(pad_left)
	_add_touch_btn(pad_left, "◀", &"move_left")
	_add_touch_btn(pad_left, "▶", &"move_right")

	var pad_right := HBoxContainer.new()
	pad_right.anchor_left = 1.0
	pad_right.anchor_right = 1.0
	pad_right.anchor_top = 1.0
	pad_right.anchor_bottom = 1.0
	pad_right.offset_left = -520.0
	pad_right.offset_right = -260.0
	pad_right.offset_top = -95.0
	pad_right.offset_bottom = -25.0
	root.add_child(pad_right)
	_add_touch_btn(pad_right, "CAR [F]", &"interact_vehicle")
	_add_touch_btn(pad_right, "BRAKE", &"move_back")
	_add_touch_btn(pad_right, "GAS ▲", &"move_forward")


func _add_touch_btn(parent_box: Container, label_txt: String, action_name: StringName) -> void:
	var btn := Button.new()
	btn.text = label_txt
	btn.custom_minimum_size = Vector2(76.0, 58.0)
	btn.button_down.connect(func() -> void: Input.action_press(action_name))
	btn.button_up.connect(func() -> void: Input.action_release(action_name))
	parent_box.add_child(btn)


func _make_box_style(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	return sb


func _format_commas(val: int) -> String:
	var s: String = str(absi(val))
	var out: String = ""
	var count: int = 0
	for i: int in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = s[i] + out
		count += 1
	return ("-" + out) if val < 0 else out
