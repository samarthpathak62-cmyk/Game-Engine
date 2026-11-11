extends CanvasLayer
class_name GTAHUD
## GTAHUD (Intel UHD Crash-Proof Optimized)
## Complete GTA V Main Menu + Pause Menu + Graphics/Mouse Settings + Gameplay HUD
## Uses a blazing-fast 2D Vector GPS Radar instead of a duplicate 3D SubViewport
## so Intel UHD Graphics renders the 3D world only ONCE per frame!


class GPSRadarControl extends Control:
	var focus_pos: Vector3 = Vector3.ZERO
	var focus_yaw: float = 0.0
	var meters_to_px: float = 1.35

	func _draw() -> void:
		var sz: Vector2 = size
		var center: Vector2 = sz * 0.5
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0.10, 0.12, 0.15, 0.96), true)

		# Ocean & Beach south of Z = 88
		var beach_y: float = center.y + (86.0 - focus_pos.z) * meters_to_px
		if beach_y < sz.y:
			var clamped_by: float = maxf(0.0, beach_y)
			draw_rect(Rect2(0.0, clamped_by, sz.x, sz.y - clamped_by), Color(0.76, 0.68, 0.46, 0.85), true)
		var ocean_y: float = center.y + (104.0 - focus_pos.z) * meters_to_px
		if ocean_y < sz.y:
			var clamped_oy: float = maxf(0.0, ocean_y)
			draw_rect(Rect2(0.0, clamped_oy, sz.x, sz.y - clamped_oy), Color(0.10, 0.34, 0.58, 0.95), true)

		# Los Santos Road Grid (X = -48, 0, 48 and Z = -48, 0, 48)
		var road_col := Color(0.28, 0.31, 0.36, 0.95)
		for rx: float in [-48.0, 0.0, 48.0]:
			var px: float = center.x + (rx - focus_pos.x) * meters_to_px
			if px >= -10.0 and px <= sz.x + 10.0:
				draw_rect(Rect2(px - 5.0, 0.0, 10.0, minf(sz.y, beach_y)), road_col, true)
		for rz: float in [-48.0, 0.0, 48.0]:
			var py: float = center.y + (rz - focus_pos.z) * meters_to_px
			if py >= -10.0 and py <= sz.y + 10.0:
				draw_rect(Rect2(0.0, py - 5.0, sz.x, 10.0), road_col, true)

		# Mission Yellow Blips
		for mnode: Node in get_tree().get_nodes_in_group(&"missions"):
			if mnode is Node3D:
				var mp: Vector2 = _world_to_map((mnode as Node3D).global_position, center, sz)
				draw_circle(mp, 5.5, Color(1.0, 0.84, 0.12))
				draw_circle(mp, 2.5, Color(0.12, 0.10, 0.02))

		# Vehicle Blips (Flashing Red/Blue for Police, Cyan for Cars)
		var flash_red: bool = int(Time.get_ticks_msec() / 220) % 2 == 0
		for vnode: Node in get_tree().get_nodes_in_group(&"vehicles"):
			if vnode is Node3D and not bool(vnode.get("_is_player_driving")):
				var vp: Vector2 = _world_to_map((vnode as Node3D).global_position, center, sz)
				if bool(vnode.get("is_police_unit")):
					draw_circle(vp, 4.2, Color(1.0, 0.22, 0.22) if flash_red else Color(0.25, 0.58, 1.0))
				else:
					draw_rect(Rect2(vp - Vector2(2.5, 2.5), Vector2(5.0, 5.0)), Color(0.68, 0.86, 0.96, 0.85), true)

		# Player White Directional Arrow in Center
		var fwd := Vector2(sin(focus_yaw), cos(focus_yaw)).normalized()
		var right := Vector2(fwd.y, -fwd.x)
		var pts := PackedVector2Array([
			center + fwd * 7.5,
			center - fwd * 5.0 + right * 5.0,
			center - fwd * 2.5,
			center - fwd * 5.0 - right * 5.0,
		])
		draw_colored_polygon(pts, Color(1.0, 1.0, 1.0))

	func _world_to_map(wpos: Vector3, center: Vector2, sz: Vector2) -> Vector2:
		var raw: Vector2 = center + Vector2((wpos.x - focus_pos.x) * meters_to_px, (wpos.z - focus_pos.z) * meters_to_px)
		return Vector2(clampf(raw.x, 6.0, sz.x - 6.0), clampf(raw.y, 6.0, sz.y - 6.0))


var _hud_root: Control = null
var _main_menu_root: Control = null
var _pause_menu_root: Control = null
var _settings_panel: PanelContainer = null
var _crosshair: Control = null

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
var _quality_status_lbl: Label = null

var _gps_radar: GPSRadarControl = null
var _banner_timer: float = 0.0
var _wanted_flash_t: float = 0.0
var _current_stars: int = 0


func _ready() -> void:
	layer = 15
	_build_gameplay_hud()
	_build_main_menu()
	_build_pause_menu()
	_build_settings_modal()
	call_deferred("_connect_game_manager")


func _process(delta: float) -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm == null:
		return

	var target: Node3D = (gm.call("get_focus_target") as Node3D) if gm.has_method("get_focus_target") else null
	if is_instance_valid(target) and _gps_radar != null and _hud_root != null and _hud_root.visible:
		_gps_radar.focus_pos = target.global_position
		var fwd: Vector3 = target.global_transform.basis.z
		_gps_radar.focus_yaw = atan2(fwd.x, fwd.z)
		_gps_radar.queue_redraw()

	var active_car: Node3D = gm.get("active_vehicle") as Node3D
	if is_instance_valid(active_car):
		_speed_panel.visible = true
		var kmh: int = int(round(float(active_car.get("speed_kmh"))))
		_speed_label.text = str(kmh) + " KM/H"
		_car_name_label.text = String(active_car.get("vehicle_name")).to_upper()
		_nitro_bar.value = float(active_car.get("nitro_charge"))
	else:
		_speed_panel.visible = false

	if _current_stars > 0 and _wanted_label != null:
		_wanted_flash_t += delta * 6.5
		_wanted_label.modulate = Color(1.0, 0.30, 0.30) if sin(_wanted_flash_t) >= 0.0 else Color(0.45, 0.72, 1.0)

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
	gm.connect("app_mode_changed", _on_app_mode_changed)
	gm.connect("cash_changed", _on_cash_changed)
	gm.connect("wanted_changed", _on_wanted_changed)
	gm.connect("prompt_changed", _on_prompt_changed)
	gm.connect("notification_pushed", _on_notification_pushed)
	gm.connect("protagonist_changed", _on_protagonist_changed)
	gm.connect("aiming_changed", _on_aiming_changed)

	_on_cash_changed(int(gm.get("cash")), 0)
	_on_wanted_changed(int(gm.get("wanted_level")))
	_on_app_mode_changed(int(gm.get("app_mode")))


func _on_app_mode_changed(mode: int) -> void:
	if _main_menu_root != null:
		_main_menu_root.visible = (mode == 0)
	if _hud_root != null:
		_hud_root.visible = (mode == 1)
	if _pause_menu_root != null:
		_pause_menu_root.visible = (mode == 2)
	if mode != 0 and mode != 2 and _settings_panel != null:
		_settings_panel.visible = false
	if mode != 1 and _crosshair != null:
		_crosshair.visible = false


func _on_aiming_changed(is_aiming: bool, _wname: String) -> void:
	if _crosshair != null:
		_crosshair.visible = is_aiming


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
		_wanted_label.text = "★ ".repeat(stars).strip_edges() + " ☆".repeat(5 - stars)


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
	_banner_timer = 3.5


func _on_protagonist_changed(slot_idx: int, char_name: String) -> void:
	if _char_badge != null:
		_char_badge.text = "ACTIVE [" + str(slot_idx + 1) + "]: " + char_name.to_upper() + "   (1 / 2 / 3 Switch)"


func _build_main_menu() -> void:
	_main_menu_root = Control.new()
	_main_menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_main_menu_root)

	var side_shade := ColorRect.new()
	side_shade.color = Color(0.03, 0.04, 0.07, 0.78)
	side_shade.anchor_bottom = 1.0
	side_shade.offset_right = 510.0
	_main_menu_root.add_child(side_shade)

	var menu_vbox := VBoxContainer.new()
	menu_vbox.offset_left = 54.0
	menu_vbox.offset_top = 80.0
	menu_vbox.offset_right = 460.0
	menu_vbox.offset_bottom = 640.0
	menu_vbox.add_theme_constant_override("separation", 14)
	_main_menu_root.add_child(menu_vbox)

	var tag_lbl := Label.new()
	tag_lbl.text = "GODOT 4 OPEN-WORLD ENGINE (INTEL UHD OPTIMIZED)"
	tag_lbl.add_theme_font_size_override("font_size", 13)
	tag_lbl.add_theme_color_override("font_color", Color(0.38, 0.96, 0.56))
	menu_vbox.add_child(tag_lbl)

	var logo_lbl := Label.new()
	logo_lbl.text = "LOS SANTOS V\nGTA STUDIO"
	logo_lbl.add_theme_font_size_override("font_size", 44)
	logo_lbl.add_theme_color_override("font_color", Color(1.0, 0.98, 0.94))
	logo_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	logo_lbl.add_theme_constant_override("outline_size", 10)
	menu_vbox.add_child(logo_lbl)

	var sub_lbl := Label.new()
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_lbl.text = "Real 3D Vehicles, Rigged Characters, Full Mouse Aim/Shoot & Live 3D World Engine Builder."
	sub_lbl.add_theme_font_size_override("font_size", 14)
	sub_lbl.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92))
	menu_vbox.add_child(sub_lbl)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 14.0)
	menu_vbox.add_child(spacer)

	_add_menu_button(menu_vbox, "▶  PLAY LOS SANTOS (FREE ROAM)", Color(0.22, 0.78, 0.42), func() -> void:
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm != null and gm.has_method("start_gameplay"):
			gm.call("start_gameplay")
	)

	_add_menu_button(menu_vbox, "🛠  3D WORLD ENGINE BUILDER (NO-CODE)", Color(0.20, 0.52, 0.90), func() -> void:
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm != null and gm.has_method("set_app_mode"):
			gm.call("set_app_mode", 3)
	)

	_add_menu_button(menu_vbox, "⚙  GRAPHICS & MOUSE SETTINGS", Color(0.24, 0.28, 0.36), func() -> void:
		_settings_panel.visible = not _settings_panel.visible
	)

	_add_menu_button(menu_vbox, "☀  CHANGE TIME OF DAY / WEATHER", Color(0.24, 0.28, 0.36), func() -> void:
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm != null and gm.has_method("_cycle_world_time"):
			gm.call("_cycle_world_time")
	)

	_add_menu_button(menu_vbox, "✕  EXIT TO DESKTOP", Color(0.42, 0.16, 0.18), func() -> void:
		get_tree().quit()
	)


func _build_pause_menu() -> void:
	_pause_menu_root = Control.new()
	_pause_menu_root.visible = false
	_pause_menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_pause_menu_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_menu_root.add_child(dim)

	var card := PanelContainer.new()
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -220.0
	card.offset_right = 220.0
	card.offset_top = -215.0
	card.offset_bottom = 215.0
	card.add_theme_stylebox_override("panel", _make_box_style(Color(0.06, 0.08, 0.12, 0.95), Color(0.35, 0.94, 0.55), 2))
	_pause_menu_root.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	card.add_child(vbox)

	var ptitle := Label.new()
	ptitle.text = "PAUSED — LOS SANTOS"
	ptitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ptitle.add_theme_font_size_override("font_size", 24)
	vbox.add_child(ptitle)

	_add_menu_button(vbox, "▶  RESUME GAME [ESC]", Color(0.22, 0.78, 0.42), func() -> void:
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm != null:
			gm.call("set_app_mode", 1)
	)

	_add_menu_button(vbox, "🛠  OPEN 3D WORLD ENGINE [TAB]", Color(0.20, 0.52, 0.90), func() -> void:
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm != null:
			gm.call("set_app_mode", 3)
	)

	_add_menu_button(vbox, "🏎  SPAWN PEGASSI ZENTORNO SUPERCAR", Color(0.65, 0.42, 0.14), func() -> void:
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm != null:
			gm.call("spawn_supercar_near_player")
			gm.call("set_app_mode", 1)
	)

	_add_menu_button(vbox, "⚙  GRAPHICS & MOUSE SETTINGS", Color(0.24, 0.28, 0.36), func() -> void:
		_settings_panel.visible = not _settings_panel.visible
	)

	_add_menu_button(vbox, "⌂  MAIN MENU", Color(0.42, 0.18, 0.20), func() -> void:
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm != null:
			gm.call("set_app_mode", 0)
	)


func _build_settings_modal() -> void:
	_settings_panel = PanelContainer.new()
	_settings_panel.visible = false
	_settings_panel.anchor_left = 0.5
	_settings_panel.anchor_right = 0.5
	_settings_panel.anchor_top = 0.5
	_settings_panel.anchor_bottom = 0.5
	_settings_panel.offset_left = 30.0
	_settings_panel.offset_right = 470.0
	_settings_panel.offset_top = -185.0
	_settings_panel.offset_bottom = 185.0
	_settings_panel.add_theme_stylebox_override("panel", _make_box_style(Color(0.05, 0.07, 0.11, 0.97), Color(0.38, 0.78, 1.0), 2))
	add_child(_settings_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_settings_panel.add_child(vbox)

	var stitle := Label.new()
	stitle.text = "GRAPHICS & CONTROLS"
	stitle.add_theme_font_size_override("font_size", 20)
	stitle.add_theme_color_override("font_color", Color(0.45, 0.84, 1.0))
	vbox.add_child(stitle)

	_quality_status_lbl = Label.new()
	_quality_status_lbl.text = "Graphics Quality: HIGH (Shadows + Bloom + MSAA 2x)"
	vbox.add_child(_quality_status_lbl)

	var q_hbox := HBoxContainer.new()
	q_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(q_hbox)

	_add_quality_btn(q_hbox, "Fast (60 FPS)", 0, "FAST (60 FPS Max Performance)")
	_add_quality_btn(q_hbox, "High (Default)", 1, "HIGH (Shadows + Bloom + MSAA 2x)")
	_add_quality_btn(q_hbox, "Ultra Crisp", 2, "ULTRA (Long Shadows + Vivid Glow + MSAA 4x)")

	var sens_lbl := Label.new()
	sens_lbl.text = "Mouse Camera Sensitivity:"
	vbox.add_child(sens_lbl)

	var sens_slider := HSlider.new()
	sens_slider.min_value = 0.0008
	sens_slider.max_value = 0.0065
	sens_slider.step = 0.0002
	sens_slider.value = 0.0026
	sens_slider.value_changed.connect(func(val: float) -> void:
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm != null:
			gm.set("mouse_sensitivity", val)
	)
	vbox.add_child(sens_slider)

	var fs_btn := Button.new()
	fs_btn.text = "Toggle Fullscreen Window"
	fs_btn.custom_minimum_size = Vector2(0.0, 36.0)
	fs_btn.pressed.connect(func() -> void:
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm != null and gm.has_method("toggle_fullscreen"):
			gm.call("toggle_fullscreen")
	)
	vbox.add_child(fs_btn)

	var close_btn := Button.new()
	close_btn.text = "Close Settings"
	close_btn.custom_minimum_size = Vector2(0.0, 36.0)
	close_btn.pressed.connect(func() -> void:
		_settings_panel.visible = false
	)
	vbox.add_child(close_btn)


func _add_quality_btn(parent_box: HBoxContainer, btn_txt: String, tier: int, desc: String) -> void:
	var b := Button.new()
	b.text = btn_txt
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void:
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm != null and gm.has_method("apply_graphics_quality"):
			gm.call("apply_graphics_quality", tier)
		if _quality_status_lbl != null:
			_quality_status_lbl.text = "Graphics Quality: " + desc
	)
	parent_box.add_child(b)


func _add_menu_button(vbox: VBoxContainer, txt: String, accent: Color, cb: Callable) -> void:
	var btn := Button.new()
	btn.text = txt
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0.0, 44.0)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_stylebox_override("normal", _make_box_style(Color(accent.r * 0.35, accent.g * 0.35, accent.b * 0.35, 0.90), accent, 2))
	btn.add_theme_stylebox_override("hover", _make_box_style(Color(accent.r * 0.65, accent.g * 0.65, accent.b * 0.65, 0.96), Color.WHITE, 2))
	btn.pressed.connect(cb)
	vbox.add_child(btn)


func _build_gameplay_hud() -> void:
	_hud_root = Control.new()
	_hud_root.visible = false
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud_root)

	# Center GTA 5 White Aim Reticle Dot + Crosshair
	_crosshair = Control.new()
	_crosshair.visible = false
	_crosshair.anchor_left = 0.5
	_crosshair.anchor_right = 0.5
	_crosshair.anchor_top = 0.5
	_crosshair.anchor_bottom = 0.5
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_crosshair)

	var dot := ColorRect.new()
	dot.color = Color(1.0, 1.0, 1.0, 0.95)
	dot.position = Vector2(-3.0, -3.0)
	dot.size = Vector2(6.0, 6.0)
	_crosshair.add_child(dot)

	for offset_rect: Rect2 in [
		Rect2(-16.0, -1.0, 8.0, 2.0),
		Rect2(8.0, -1.0, 8.0, 2.0),
		Rect2(-1.0, -16.0, 2.0, 8.0),
		Rect2(-1.0, 8.0, 2.0, 8.0),
	]:
		var tick := ColorRect.new()
		tick.color = Color(1.0, 1.0, 1.0, 0.80)
		tick.position = offset_rect.position
		tick.size = offset_rect.size
		_crosshair.add_child(tick)

	# 1. TOP-RIGHT: Cash, Wanted Stars & Character Badge
	var top_right := VBoxContainer.new()
	top_right.anchor_left = 1.0
	top_right.anchor_right = 1.0
	top_right.offset_left = -380.0
	top_right.offset_right = -22.0
	top_right.offset_top = 18.0
	top_right.offset_bottom = 132.0
	top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(top_right)

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
	_cash_label.text = "$5,000"
	top_right.add_child(_cash_label)

	_char_badge = Label.new()
	_char_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_char_badge.add_theme_font_size_override("font_size", 14)
	_char_badge.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	_char_badge.add_theme_color_override("font_outline_color", Color.BLACK)
	_char_badge.add_theme_constant_override("outline_size", 4)
	_char_badge.text = "ACTIVE [1]: FRANKLIN   (1 / 2 / 3 Switch)"
	top_right.add_child(_char_badge)

	# 2. BOTTOM-LEFT: GTA 5 Rectangular 2D Vector GPS Minimap + Health/Armor Bars
	var radar_frame := PanelContainer.new()
	radar_frame.anchor_top = 1.0
	radar_frame.anchor_bottom = 1.0
	radar_frame.offset_left = 20.0
	radar_frame.offset_right = 256.0
	radar_frame.offset_top = -194.0
	radar_frame.offset_bottom = -20.0
	radar_frame.add_theme_stylebox_override("panel", _make_box_style(Color(0.05, 0.06, 0.08, 0.90), Color(0.32, 0.36, 0.42), 2))
	_hud_root.add_child(radar_frame)

	var radar_vbox := VBoxContainer.new()
	radar_vbox.add_theme_constant_override("separation", 4)
	radar_frame.add_child(radar_vbox)

	_gps_radar = GPSRadarControl.new()
	_gps_radar.clip_contents = true
	_gps_radar.custom_minimum_size = Vector2(212.0, 142.0)
	radar_vbox.add_child(_gps_radar)

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

	# 3. BOTTOM-RIGHT: Speedometer
	_speed_panel = PanelContainer.new()
	_speed_panel.visible = false
	_speed_panel.anchor_left = 1.0
	_speed_panel.anchor_right = 1.0
	_speed_panel.anchor_top = 1.0
	_speed_panel.anchor_bottom = 1.0
	_speed_panel.offset_left = -252.0
	_speed_panel.offset_right = -20.0
	_speed_panel.offset_top = -128.0
	_speed_panel.offset_bottom = -20.0
	_speed_panel.add_theme_stylebox_override("panel", _make_box_style(Color(0.06, 0.07, 0.10, 0.86), Color(0.95, 0.62, 0.18), 2))
	_hud_root.add_child(_speed_panel)

	var sp_vbox := VBoxContainer.new()
	_speed_panel.add_child(sp_vbox)

	_car_name_label = Label.new()
	_car_name_label.add_theme_font_size_override("font_size", 13)
	_car_name_label.add_theme_color_override("font_color", Color(1.0, 0.76, 0.28))
	sp_vbox.add_child(_car_name_label)

	_speed_label = Label.new()
	_speed_label.add_theme_font_size_override("font_size", 28)
	sp_vbox.add_child(_speed_label)

	_nitro_bar = ProgressBar.new()
	_nitro_bar.min_value = 0.0
	_nitro_bar.max_value = 100.0
	_nitro_bar.value = 100.0
	_nitro_bar.show_percentage = false
	_nitro_bar.custom_minimum_size = Vector2(185.0, 10.0)
	sp_vbox.add_child(_nitro_bar)

	# 4. CENTER BANNER
	_banner_box = VBoxContainer.new()
	_banner_box.visible = false
	_banner_box.anchor_left = 0.5
	_banner_box.anchor_right = 0.5
	_banner_box.offset_left = -290.0
	_banner_box.offset_right = 290.0
	_banner_box.offset_top = 80.0
	_banner_box.offset_bottom = 175.0
	_banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_banner_box)

	_banner_title = Label.new()
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_title.add_theme_font_size_override("font_size", 30)
	_banner_title.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner_title.add_theme_constant_override("outline_size", 8)
	_banner_box.add_child(_banner_title)

	_banner_sub = Label.new()
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.add_theme_font_size_override("font_size", 17)
	_banner_sub.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner_sub.add_theme_constant_override("outline_size", 5)
	_banner_box.add_child(_banner_sub)

	# 5. INTERACTION PROMPT
	_prompt_panel = PanelContainer.new()
	_prompt_panel.visible = false
	_prompt_panel.anchor_left = 0.5
	_prompt_panel.anchor_right = 0.5
	_prompt_panel.anchor_top = 1.0
	_prompt_panel.anchor_bottom = 1.0
	_prompt_panel.offset_left = -205.0
	_prompt_panel.offset_right = 205.0
	_prompt_panel.offset_top = -76.0
	_prompt_panel.offset_bottom = -32.0
	_prompt_panel.add_theme_stylebox_override("panel", _make_box_style(Color(0.05, 0.06, 0.09, 0.90), Color(0.35, 0.95, 0.55), 2))
	_hud_root.add_child(_prompt_panel)

	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 17)
	_prompt_panel.add_child(_prompt_label)

	# 6. TOP-LEFT CONTROLS CHEAT SHEET [F1]
	_help_panel = PanelContainer.new()
	_help_panel.offset_left = 20.0
	_help_panel.offset_top = 18.0
	_help_panel.offset_right = 345.0
	_help_panel.offset_bottom = 208.0
	_help_panel.add_theme_stylebox_override("panel", _make_box_style(Color(0.05, 0.07, 0.11, 0.78), Color(0.28, 0.35, 0.48), 1))
	_hud_root.add_child(_help_panel)

	var help_lbl := Label.new()
	help_lbl.add_theme_font_size_override("font_size", 13)
	help_lbl.text = "LOS SANTOS CONTROLS [F1 Hide]\n• Mouse Move : 360° 3D Camera Look\n• Right-Click + Left-Click : Aim & Shoot Rifle\n• WASD : Walk & Drive  |  Shift : Sprint / Nitro\n• [F] : Enter / Hijack Car  |  Space : Jump / Drift\n• [TAB] : Live 3D World Engine Builder!\n• [1][2][3] : GTA 5 Sky Switch  |  [ESC] : Pause Menu"
	_help_panel.add_child(help_lbl)


func _make_box_style(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 7.0
	sb.content_margin_bottom = 7.0
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
