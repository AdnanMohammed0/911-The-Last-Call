shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;

uniform vec4 deep_color : source_color = vec4(0.025, 0.105, 0.125, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.105, 0.22, 0.235, 1.0);
uniform float rise_fraction : hint_range(0.0, 1.0) = 0.0;
uniform float wave_strength : hint_range(0.0, 0.15) = 0.045;

varying vec2 water_uv;

void vertex() {
	water_uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz * 0.18;
	float wave = sin(water_uv.x * 2.8 + TIME * 0.8) * cos(water_uv.y * 2.2 - TIME * 0.6);
	VERTEX.y += wave * wave_strength;
}

void fragment() {
	float bands = sin(water_uv.x * 8.0 + TIME * 1.4) * sin(water_uv.y * 7.0 - TIME * 1.1);
	float ripples = sin(length(fract(water_uv * 0.7) - 0.5) * 28.0 - TIME * 2.0);
	float foam = smoothstep(0.60, 0.92, bands * 0.38 + ripples * 0.30 + 0.5);
	vec3 base = mix(shallow_color.rgb, deep_color.rgb, 0.32 + rise_fraction * 0.55);
	ALBEDO = base + vec3(0.075, 0.11, 0.105) * foam;
	ROUGHNESS = 0.13;
	METALLIC = 0.08;
	SPECULAR = 0.85;
	EMISSION = vec3(0.015, 0.04, 0.045) * foam;
	ALPHA = 0.68 + foam * 0.14;
}
