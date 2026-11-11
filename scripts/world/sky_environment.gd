@tool
extends WorldEnvironment
class_name GTASkyEnvironment
## GTASkyEnvironment
## High-Quality Forward+ PBR Lighting, ReflectionProbe, SSAO, SSR & ACES Grading.
## Default: Crisp GTA 5 California Sunny Afternoon + Golden Sunset + Neon Midnight.

enum MoodPreset {
	CALIFORNIA_AFTERNOON = 0,
	LOS_SANTOS_SUNSET = 1,
	NEON_MIDNIGHT = 2,
}

@export var mood_preset: MoodPreset = MoodPreset.CALIFORNIA_AFTERNOON:
	set(value):
		mood_preset = value
		_apply_mood()

@export_range(0, 2, 1) var quality_tier: int = 1:
	set(value):
		quality_tier = value
		_apply_mood()

var _sun_light: DirectionalLight3D = null
var _refl_probe: ReflectionProbe = null


func _ready() -> void:
	_apply_mood()


func apply_quality_tier(tier: int) -> void:
	quality_tier = clampi(tier, 0, 2)


func cycle_preset() -> String:
	var next_idx: int = (int(mood_preset) + 1) % 3
	mood_preset = next_idx as MoodPreset
	match mood_preset:
		MoodPreset.CALIFORNIA_AFTERNOON:
			return "Los Santos California Afternoon"
		MoodPreset.LOS_SANTOS_SUNSET:
			return "Vinewood Golden Sunset"
		_:
			return "Downtown Neon Midnight"


func _apply_mood() -> void:
	for child: Node in get_children(true):
		if child.get_meta("gta_internal", false):
			child.queue_free()

	_sun_light = DirectionalLight3D.new()
	_sun_light.set_meta("gta_internal", true)
	_sun_light.shadow_enabled = true
	_sun_light.directional_shadow_max_distance = 240.0 if quality_tier >= 1 else 130.0
	_sun_light.shadow_bias = 0.04
	add_child(_sun_light, false, Node.INTERNAL_MODE_BACK)

	# Baked/Once ReflectionProbe so Clearcoat Cars & Wet Roads reflect real skyline at 60 FPS!
	_refl_probe = ReflectionProbe.new()
	_refl_probe.set_meta("gta_internal", true)
	_refl_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	_refl_probe.size = Vector3(380.0, 140.0, 380.0)
	_refl_probe.position = Vector3(0.0, 35.0, 0.0)
	_refl_probe.intensity = 0.85
	add_child(_refl_probe, false, Node.INTERNAL_MODE_BACK)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 28.0
	sky_mat.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05

	# Filmic GTA V Color Grading
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.07
	env.adjustment_saturation = 1.14

	# Quality Tier Effects (0 = Intel UHD Fast, 1 = High SSAO+Glow, 2 = Ultra SSR+SSAO+SSIL)
	env.ssao_enabled = quality_tier >= 1
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.65
	env.ssr_enabled = quality_tier >= 2
	env.ssil_enabled = quality_tier >= 2

	env.glow_enabled = quality_tier >= 1
	env.glow_intensity = 0.45
	env.glow_bloom = 0.08
	env.fog_enabled = true
	env.fog_sky_affect = 0.25

	match mood_preset:
		MoodPreset.CALIFORNIA_AFTERNOON:
			sky_mat.sky_top_color = Color(0.14, 0.42, 0.86)
			sky_mat.sky_horizon_color = Color(0.68, 0.84, 0.96)
			sky_mat.ground_horizon_color = Color(0.58, 0.66, 0.74)
			sky_mat.ground_bottom_color = Color(0.18, 0.20, 0.22)
			_sun_light.rotation_degrees = Vector3(-46.0, -35.0, 0.0)
			_sun_light.light_color = Color(1.0, 0.96, 0.88)
			_sun_light.light_energy = 1.55
			env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			env.ambient_light_sky_contribution = 0.85
			env.fog_light_color = Color(0.74, 0.85, 0.96)
			env.fog_density = 0.00075

		MoodPreset.LOS_SANTOS_SUNSET:
			sky_mat.sky_top_color = Color(0.16, 0.24, 0.52)
			sky_mat.sky_horizon_color = Color(0.98, 0.54, 0.30)
			sky_mat.ground_horizon_color = Color(0.76, 0.44, 0.30)
			sky_mat.ground_bottom_color = Color(0.14, 0.12, 0.16)
			_sun_light.rotation_degrees = Vector3(-19.0, -42.0, 0.0)
			_sun_light.light_color = Color(1.0, 0.74, 0.48)
			_sun_light.light_energy = 1.45
			env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			env.ambient_light_sky_contribution = 0.72
			env.fog_light_color = Color(0.92, 0.58, 0.40)
			env.fog_density = 0.0014

		MoodPreset.NEON_MIDNIGHT:
			sky_mat.sky_top_color = Color(0.02, 0.04, 0.10)
			sky_mat.sky_horizon_color = Color(0.08, 0.12, 0.24)
			sky_mat.ground_horizon_color = Color(0.05, 0.08, 0.16)
			sky_mat.ground_bottom_color = Color(0.02, 0.02, 0.05)
			_sun_light.rotation_degrees = Vector3(-42.0, 125.0, 0.0)
			_sun_light.light_color = Color(0.46, 0.60, 0.95)
			_sun_light.light_energy = 0.42
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.16, 0.20, 0.32)
			env.ambient_light_energy = 0.72
			env.glow_intensity = 0.85
			env.fog_light_color = Color(0.08, 0.10, 0.20)
			env.fog_density = 0.0020

	environment = env
