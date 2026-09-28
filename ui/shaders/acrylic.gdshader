// Acrylic / Mica glass for panels: the panel's own StyleBox gives the shape (rounded corners, AA edges);
// this replaces its fill with a blurred copy of what is behind it, tinted, lifted and with a little grain.
// Give the StyleBox an opaque bg_color (the tint) — its alpha channel is only used as the shape mask.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur_lod : hint_range(0.0, 6.0) = 3.2;
uniform float tint_amount : hint_range(0.0, 1.0) = 0.62;
uniform float luminosity : hint_range(0.0, 1.0) = 0.12;
uniform float grain : hint_range(0.0, 0.2) = 0.025;
uniform float saturation : hint_range(0.0, 2.0) = 1.25;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 shape = COLOR;
	vec2 px = SCREEN_PIXEL_SIZE * exp2(blur_lod) * 0.9;
	vec3 blur = vec3(0.0);
	float total = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float weight = 1.0 / (1.0 + float(x * x + y * y));
			blur += textureLod(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * px, blur_lod).rgb * weight;
			total += weight;
		}
	}
	blur /= total;
	float grey = dot(blur, vec3(0.299, 0.587, 0.114));
	blur = mix(vec3(grey), blur, saturation);
	blur = mix(blur, vec3(1.0), luminosity * 0.25);
	vec3 colour = mix(blur, shape.rgb, tint_amount);
	colour += (hash(FRAGCOORD.xy) - 0.5) * grain;
	COLOR = vec4(colour, shape.a);
}
