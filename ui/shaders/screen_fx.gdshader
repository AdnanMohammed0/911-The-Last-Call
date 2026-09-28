// Monitor / CCTV finish over a texture (or plain rect): scanlines, vignette, slight chromatic shift, noise.
shader_type canvas_item;

uniform float scanlines : hint_range(0.0, 1.0) = 0.18;
uniform float vignette : hint_range(0.0, 1.0) = 0.45;
uniform float noise_amount : hint_range(0.0, 0.3) = 0.05;
uniform float chroma : hint_range(0.0, 4.0) = 1.0;
uniform bool monochrome = false;
uniform vec4 mono_tint : source_color = vec4(0.75, 1.0, 0.8, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + TIME * 7.0) * 43758.5453);
}

void fragment() {
	vec2 shift = TEXTURE_PIXEL_SIZE * chroma;
	vec4 base = texture(TEXTURE, UV);
	float r = texture(TEXTURE, UV + shift).r;
	float b = texture(TEXTURE, UV - shift).b;
	vec3 colour = vec3(r, base.g, b) * COLOR.rgb;
	if (monochrome) {
		colour = vec3(dot(colour, vec3(0.3, 0.59, 0.11))) * mono_tint.rgb;
	}
	colour *= 1.0 - scanlines * (0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159));
	colour += (hash(FRAGCOORD.xy) - 0.5) * noise_amount;
	float v = smoothstep(0.85, 0.2, length(UV - vec2(0.5)));
	colour *= mix(1.0, v, vignette);
	COLOR = vec4(colour, base.a * COLOR.a);
}
