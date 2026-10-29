shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float film_strength : hint_range(0.0, 1.0) = 0.55;
uniform float sanity_strength : hint_range(0.0, 1.0) = 0.0;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.035;
uniform float scanline_strength : hint_range(0.0, 0.2) = 0.05;
uniform float aberration_px : hint_range(0.0, 4.0) = 1.1;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 pixel = SCREEN_PIXEL_SIZE;
	vec2 centred = uv * 2.0 - 1.0;
	float radial = clamp(length(centred * vec2(0.9, 1.0)), 0.0, 1.5);
	float distress = sanity_strength * sanity_strength;

	// Edge-only fringing keeps the centre and aiming point clear.
	float offset_px = (aberration_px * film_strength + distress * 2.0) * smoothstep(0.18, 1.15, radial);
	vec2 red_uv = clamp(uv + vec2(pixel.x * offset_px, 0.0), vec2(0.0), vec2(1.0));
	vec2 blue_uv = clamp(uv - vec2(pixel.x * offset_px, 0.0), vec2(0.0), vec2(1.0));
	vec3 image = vec3(
		texture(screen_texture, red_uv).r,
		texture(screen_texture, uv).g,
		texture(screen_texture, blue_uv).b
	);

	// Physical pixel coordinates avoid changing stripe density with UI scale.
	vec2 texel = floor(uv / pixel);
	float line = 0.5 + 0.5 * sin(texel.y * 1.5707963);
	float grain = hash21(floor(texel * 0.55) + floor(TIME * 16.0));
	float scan = scanline_strength * film_strength * (1.0 + distress * 0.8);
	float noise = grain_strength * film_strength * (1.0 + distress * 1.6);
	image *= 1.0 - line * scan;
	image += (grain - 0.5) * noise;
	image *= 1.0 - smoothstep(0.42, 1.3, radial) * (0.065 * film_strength + 0.09 * distress);
	COLOR = vec4(clamp(image, vec3(0.0), vec3(1.0)), 1.0);
}
