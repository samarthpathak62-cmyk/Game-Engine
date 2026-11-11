@tool
extends Node3D
class_name GTASkyEnvironment
## GTASkyEnvironment (Intel UHD Crash-Proof Optimized)
## GTA 5 Los Santos Atmosphere, Directional Shadows & GL Compatibility-safe
## Tone/Glow/Fog presets (no ReflectionProbe/SSAO/SSR GPU driver hangs).

enum WeatherPreset {
	LOS_SANTOS_GOLDEN_SUNSET = 0,
	SUNNY_CALI_NOON = 1,
	NEON_DOWNTOWN_NIGHT = 2,
}

@export var weather_preset: WeatherPreset = WeatherPreset.LOS_SANTOS_GOLDEN_SUNSET:
	set(value):
		weather_preset = value
		if is_node_ready():
			_rebuild_atmosphere()

@export_range(0, 2, 1) var graphics_quality_tier: int = 1:
	set(value):
		graphics_quality_tier = value
		if is_node_ready():
			_rebuild_atmosphere()

@export var auto_day_night_cycle: bool = false
@export_range(0.05, 2.0, 0.05) var cycle_speed: float = 0.25

var _world_env: WorldEnvironment = null
var _sun: DirectionalLight3D = null


func _ready() -> void:
	add_to_group(&"sky_environment")
	_rebuild_atmosphere()


func apply_quality_tier(tier: int) -> void:
	graphics_quality_tier = clampi(tier, 0, 2)


func set_weather(preset_idx: int) -> void:
	weather_preset = clampi(preset_idx, 0, 2) as WeatherPreset


func _process(delta: float) -> void:
	if auto_day_night_cycle and _sun != null and not Engine.is_editor_hint():
		_sun.rotation_degrees.x -= delta * cycle_speed * 6.0


func _rebuild_atmosphere() -> void:
	for child: Node in get_children(true):
		if child.get_meta("gta_internal", false):
			child.queue_free()

	_world_env = WorldEnvironment.new()
	_world_env.set_meta("gta_internal", true)

	var sky_mat := ProceduralSkyMaterial.new()
	var env := Environment.new()
	_sun = DirectionalLight3D.new()
	_sun.set_meta("gta_internal", true)
	_sun.shadow_enabled = (graphics_quality_tier >= 1)
	_sun.directional_shadow_max_distance = 135.0 if graphics_quality_tier == 1 else (180.0 if graphics_quality_tier >= 2 else 75.0)
	_sun.shadow_bias = 0.04

	match weather_preset:
		WeatherPreset.LOS_SANTOS_GOLDEN_SUNSET:
			sky_mat.sky_top_color = Color(0.16, 0.34, 0.68)
			sky_mat.sky_horizon_color = Color(0.96, 0.56, 0.30)
			sky_mat.ground_horizon_color = Color(0.75, 0.44, 0.28)
			sky_mat.ground_bottom_color = Color(0.16, 0.14, 0.16)
			sky_mat.sun_angle_max = 36.0
			_sun.rotation_degrees = Vector3(-25.0, -42.0, 0.0)
			_sun.light_color = Color(1.0, 0.80, 0.56)
			_sun.light_energy = 1.45
			env.ambient_light_color = Color(0.42, 0.36, 0.46)
			env.ambient_light_energy = 0.55
			env.fog_light_color = Color(0.92, 0.62, 0.42)
			env.fog_density = 0.0011

		WeatherPreset.SUNNY_CALI_NOON:
			sky_mat.sky_top_color = Color(0.14, 0.46, 0.88)
			sky_mat.sky_horizon_color = Color(0.64, 0.82, 0.96)
			sky_mat.ground_horizon_color = Color(0.56, 0.66, 0.74)
			sky_mat.ground_bottom_color = Color(0.18, 0.20, 0.22)
			_sun.rotation_degrees = Vector3(-56.0, -28.0, 0.0)
			_sun.light_color = Color(1.0, 0.97, 0.90)
			_sun.light_energy = 1.38
			env.ambient_light_color = Color(0.55, 0.65, 0.78)
			env.ambient_light_energy = 0.60
			env.fog_light_color = Color(0.72, 0.84, 0.95)
			env.fog_density = 0.0007

		WeatherPreset.NEON_DOWNTOWN_NIGHT:
			sky_mat.sky_top_color = Color(0.02, 0.04, 0.11)
			sky_mat.sky_horizon_color = Color(0.08, 0.13, 0.26)
			sky_mat.ground_horizon_color = Color(0.06, 0.09, 0.18)
			sky_mat.ground_bottom_color = Color(0.02, 0.02, 0.05)
			_sun.rotation_degrees = Vector3(-38.0, 135.0, 0.0)
			_sun.light_color = Color(0.48, 0.62, 0.95)
			_sun.light_energy = 0.55
			env.ambient_light_color = Color(0.20, 0.26, 0.42)
			env.ambient_light_energy = 0.65
			env.fog_light_color = Color(0.10, 0.15, 0.28)
			env.fog_density = 0.0016

	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.04

	# GL Compatibility-safe atmospheric fog + subtle bloom on High/Ultra
	env.fog_enabled = true
	env.fog_aerial_perspective = 0.35
	env.glow_enabled = (graphics_quality_tier >= 1)
	env.glow_intensity = 0.42 if graphics_quality_tier >= 2 else 0.28
	env.glow_bloom = 0.08
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.12

	_world_env.environment = env
	add_child(_world_env, false, Node.INTERNAL_MODE_BACK)
	add_child(_sun, false, Node.INTERNAL_MODE_BACK)
