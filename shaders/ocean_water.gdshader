shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 deep_water_color : source_color = vec3(0.03, 0.16, 0.28);
uniform vec3 shallow_water_color : source_color = vec3(0.08, 0.42, 0.54);
uniform vec3 foam_color : source_color = vec3(0.88, 0.94, 0.98);
uniform float wave_speed = 0.85;
uniform float wave_height = 0.22;

varying vec3 v_world_pos;

float wave_fn(vec2 p, float t) {
	float w1 = sin(p.x * 0.28 + t * 1.4) * cos(p.y * 0.22 + t * 1.1);
	float w2 = sin((p.x + p.y) * 0.52 - t * 1.9) * 0.5;
	float w3 = cos((p.x - p.y * 1.3) * 0.95 + t * 2.4) * 0.25;
	return (w1 + w2 + w3) / 1.75;
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	float h = wave_fn(wp.xz, t) * wave_height;
	VERTEX.y += h;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME * wave_speed;
	vec2 p = v_world_pos.xz;
	float eps = 0.25;
	float hc = wave_fn(p, t);
	float hx = wave_fn(p + vec2(eps, 0.0), t);
	float hz = wave_fn(p + vec2(0.0, eps), t);

	vec3 wave_normal = normalize(vec3((hc - hx) * 1.35, 1.0, (hc - hz) * 1.35));
	NORMAL = normalize((VIEW_MATRIX * vec4(wave_normal, 0.0)).xyz);

	float crest = smoothstep(0.45, 0.85, hc);
	vec3 water_col = mix(deep_water_color, shallow_water_color, clamp(hc * 0.5 + 0.5, 0.0, 1.0));
	water_col = mix(water_col, foam_color, crest * 0.28);

	ALBEDO = water_col;
	ROUGHNESS = mix(0.06, 0.28, crest * 0.5);
	METALLIC = 0.18;
	SPECULAR = 0.92;
}
