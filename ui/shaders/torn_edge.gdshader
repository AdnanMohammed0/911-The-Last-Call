// Dark ink panel with a ragged, brushed right edge (main menu sidebar) — fades into the scene behind it.
shader_type canvas_item;

uniform vec4 ink : source_color = vec4(0.02, 0.024, 0.03, 1.0);
uniform float edge : hint_range(0.0, 1.0) = 0.72;
uniform float softness : hint_range(0.0, 0.5) = 0.18;
uniform float roughness : hint_range(0.0, 0.3) = 0.09;
uniform float time_scale = 0.03;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		value += noise(p) * amp;
		p *= 2.1;
		amp *= 0.5;
	}
	return value;
}

void fragment() {
	float t = TIME * time_scale;
	// Streaky brush fibres run horizontally, so vary mostly along y.
	float fibres = fbm(vec2(UV.x * 3.0, UV.y * 38.0) + t) * 0.6 + fbm(vec2(UV.x * 9.0, UV.y * 90.0)) * 0.4;
	float boundary = edge + (fibres - 0.5) * roughness * 2.0;
	float mask = 1.0 - smoothstep(boundary - softness, boundary + 0.01, UV.x);
	// Specks of ink past the edge.
	float specks = step(0.82, noise(UV * vec2(60.0, 120.0))) * (1.0 - smoothstep(boundary, boundary + 0.08, UV.x)) * 0.5;
	float alpha = clamp(mask + specks, 0.0, 1.0);
	COLOR = vec4(ink.rgb + (fibres - 0.5) * 0.02, ink.a * alpha);
}
