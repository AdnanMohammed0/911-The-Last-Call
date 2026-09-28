// Worn stencil look for titles: erodes the glyphs with noise and adds a faint flicker.
shader_type canvas_item;

uniform float erosion : hint_range(0.0, 1.0) = 0.38;
uniform float scale = 0.05;
uniform float flicker : hint_range(0.0, 1.0) = 0.06;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec4 glyph = COLOR;
	vec2 p = FRAGCOORD.xy * scale;
	float n = noise(p) * 0.55 + noise(p * 3.7) * 0.3 + noise(p * 11.0) * 0.15;
	float keep = smoothstep(erosion - 0.08, erosion + 0.08, n + 0.35);
	float blink = 1.0 - flicker * step(0.93, fract(sin(floor(TIME * 12.0)) * 43758.5453));
	COLOR = vec4(glyph.rgb, glyph.a * keep * blink);
}
