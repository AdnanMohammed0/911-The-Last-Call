// Windows 11 "Bloom"-style wallpaper: soft layered petals of light over a deep gradient, drifting slowly.
shader_type canvas_item;

uniform vec4 deep : source_color = vec4(0.02, 0.05, 0.13, 1.0);
uniform vec4 mid : source_color = vec4(0.07, 0.24, 0.62, 1.0);
uniform vec4 glow : source_color = vec4(0.45, 0.72, 1.0, 1.0);
uniform float speed = 0.04;
uniform float aspect = 1.777;

float petal(vec2 uv, vec2 centre, float angle, float length_, float width, float soft) {
	vec2 d = uv - centre;
	float c = cos(angle);
	float s = sin(angle);
	d = vec2(c * d.x - s * d.y, s * d.x + c * d.y);
	d.x /= length_;
	d.y /= width;
	float r = length(d);
	return 1.0 - smoothstep(1.0 - soft, 1.0, r);
}

void fragment() {
	vec2 uv = UV;
	uv.x *= aspect;
	float t = TIME * speed;
	vec2 centre = vec2(aspect * 0.5, 0.58);
	vec3 colour = mix(deep.rgb, deep.rgb * 1.6, UV.y);
	float light = 0.0;
	for (int i = 0; i < 7; i++) {
		float fi = float(i);
		float angle = -1.2 + fi * 0.38 + sin(t + fi) * 0.05;
		vec2 offset = vec2(cos(angle), sin(angle)) * 0.22;
		float p = petal(uv, centre + offset, angle, 0.46 - fi * 0.02, 0.16 + 0.02 * sin(t * 1.3 + fi), 0.9);
		light += p * (0.32 - fi * 0.025);
	}
	float core = 1.0 - smoothstep(0.0, 0.45, length((uv - centre) * vec2(1.0, 1.3)));
	colour = mix(colour, mid.rgb, clamp(light * 1.4, 0.0, 1.0));
	colour = mix(colour, glow.rgb, clamp(light * light * 1.2 + core * 0.25, 0.0, 1.0));
	// Gentle vignette.
	float vignette = smoothstep(1.2, 0.3, length((UV - vec2(0.5)) * vec2(1.4, 1.0)));
	COLOR = vec4(colour * (0.75 + 0.25 * vignette), 1.0);
}
