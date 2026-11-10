@tool
extends WorldEnvironment
class_name GTASkyEnvironment
## GTASkyEnvironment
## 1-Click Open-World Sky, Sun Shadows & Bloom Preset Manager.
## Presets: Los Santos Sunset, Vice Sunny Noon, Neon Midnight.

enum MoodPreset {
	LOS_SANTOS_SUNSET = 0,
	VICE_SUNNY_NOON = 1,
	NEON_MIDNIGHT = 2,
}

@export var mood_preset: MoodPreset = MoodPreset.LOS_SANTOS_SUNSET:
	set(value):
		mood_preset = value
		_apply_mood()

var _sun_light: DirectionalLight3D = null


func _ready() -> void:
	_apply_mood()


func cycle_preset() -> String:
	var next_idx: int = (int(mood_preset) + 1) % 3
	mood_preset = next_idx as MoodPreset
	match mood_preset:
		MoodPreset.LOS_SANTOS_SUNSET:
			return "Los Santos Golden Sunset"
		MoodPreset.VICE_SUNNY_NOON:
			return "Sunny Clear Noon"
		_:
			return "Neon Midnight"


func _apply_mood() -> void:
	for child: Node in get_children(true):
		if child.get_meta("gta_internal", false):
			child.queue_free()

	_sun_light = DirectionalLight3D.new()
	_sun_light.set_meta("gta_internal", true)
	_sun_light.shadow_enabled = true
	_sun_light.directional_shadow_max_distance = 180.0
	add_child(_sun_light, false, Node.INTERNAL_MODE_BACK)

	var sky_mat := ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.12
	env.fog_enabled = true

	match mood_preset:
		MoodPreset.LOS_SANTOS_SUNSET:
			sky_mat.sky_top_color = Color(0.18, 0.24, 0.48)
			sky_mat.sky_horizon_color = Color(0.96, 0.52, 0.30)
			sky_mat.ground_horizon_color = Color(0.75, 0.42, 0.28)
			sky_mat.ground_bottom_color = Color(0.14, 0.12, 0.16)
			_sun_light.rotation_degrees = Vector3(-22.0, -38.0, 0.0)
			_sun_light.light_color = Color(1.0, 0.76, 0.52)
			_sun_light.light_energy = 1.45
			env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			env.ambient_light_sky_contribution = 0.65
			env.fog_light_color = Color(0.88, 0.55, 0.38)
			env.fog_density = 0.0022

		MoodPreset.VICE_SUNNY_NOON:
			sky_mat.sky_top_color = Color(0.16, 0.46, 0.88)
			sky_mat.sky_horizon_color = Color(0.62, 0.82, 0.96)
			sky_mat.ground_horizon_color = Color(0.55, 0.65, 0.72)
			sky_mat.ground_bottom_color = Color(0.20, 0.22, 0.24)
			_sun_light.rotation_degrees = Vector3(-58.0, -25.0, 0.0)
			_sun_light.light_color = Color(1.0, 0.98, 0.92)
			_sun_light.light_energy = 1.6
			env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			env.ambient_light_sky_contribution = 0.8
			env.fog_light_color = Color(0.70, 0.84, 0.95)
			env.fog_density = 0.0012

		MoodPreset.NEON_MIDNIGHT:
			sky_mat.sky_top_color = Color(0.03, 0.04, 0.10)
			sky_mat.sky_horizon_color = Color(0.09, 0.12, 0.24)
			sky_mat.ground_horizon_color = Color(0.06, 0.08, 0.16)
			sky_mat.ground_bottom_color = Color(0.02, 0.02, 0.05)
			_sun_light.rotation_degrees = Vector3(-38.0, 125.0, 0.0)
			_sun_light.light_color = Color(0.45, 0.58, 0.92)
			_sun_light.light_energy = 0.38
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.14, 0.18, 0.30)
			env.ambient_light_energy = 0.65
			env.glow_intensity = 0.95
			env.fog_light_color = Color(0.08, 0.10, 0.20)
			env.fog_density = 0.0030

	environment = env
