shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 asphalt_color : source_color = vec3(0.11, 0.115, 0.13);
uniform vec3 line_yellow : source_color = vec3(0.95, 0.74, 0.16);
uniform vec3 line_white : source_color = vec3(0.88, 0.90, 0.92);
uniform float road_width = 14.0;
uniform int is_intersection = 0;
uniform float wetness : hint_range(0.0, 1.0) = 0.25;

varying vec3 v_local_pos;
varying vec3 v_world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	v_local_pos = VERTEX;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float grain = value_noise(v_world_pos.xz * 18.0) * 0.5 + value_noise(v_world_pos.xz * 52.0) * 0.5;
	float puddle = smoothstep(0.56, 0.78, value_noise(v_world_pos.xz * 0.18)) * wetness;

	vec3 col = asphalt_color * (0.86 + grain * 0.28);
	float rough = mix(0.82 - grain * 0.12, 0.14, puddle);
	float spec = mix(0.35, 0.85, puddle);

	if (is_intersection == 0) {
		float abs_x = abs(v_local_pos.x);
		// Double yellow center line
		float center_line = step(0.10, abs_x) * (1.0 - step(0.24, abs_x));
		// White outer shoulder lines
		float edge_pos = road_width * 0.5 - 0.55;
		float outer_line = step(edge_pos - 0.10, abs_x) * (1.0 - step(edge_pos + 0.10, abs_x));
		// Dashed lane divider at quarter width
		float lane_pos = road_width * 0.25;
		float dash_z = step(0.45, fract(v_local_pos.z * 0.16));
		float lane_dash = step(lane_pos - 0.08, abs_x) * (1.0 - step(lane_pos + 0.08, abs_x)) * dash_z;

		// Subtle dark tire wear tracks
		float tire_wear = exp(-pow((abs_x - lane_pos * 0.55) * 1.4, 2.0)) * 0.14;
		col *= (1.0 - tire_wear);

		col = mix(col, line_yellow, center_line * 0.92);
		col = mix(col, line_white, clamp(outer_line + lane_dash, 0.0, 1.0) * 0.88);
		rough = mix(rough, 0.55, clamp(center_line + outer_line + lane_dash, 0.0, 1.0));
	} else {
		// Zebra crosswalk stripes on 4 sides of intersection
		float half_w = road_width * 0.5;
		float near_z = step(half_w - 2.3, abs(v_local_pos.z)) * (1.0 - step(half_w - 0.35, abs(v_local_pos.z)));
		float stripe_x = step(0.42, fract(v_local_pos.x * 0.75)) * (1.0 - step(half_w - 1.0, abs(v_local_pos.x)));

		float near_x = step(half_w - 2.3, abs(v_local_pos.x)) * (1.0 - step(half_w - 0.35, abs(v_local_pos.x)));
		float stripe_z = step(0.42, fract(v_local_pos.z * 0.75)) * (1.0 - step(half_w - 1.0, abs(v_local_pos.z)));

		float zebra = clamp(near_z * stripe_x + near_x * stripe_z, 0.0, 1.0);
		col = mix(col, line_white, zebra * 0.85);
	}

	ALBEDO = col;
	ROUGHNESS = clamp(rough, 0.1, 0.95);
	METALLIC = puddle * 0.25;
	SPECULAR = spec;
}
