// Strip of status LEDs (server racks, radios, generators). Each LED blinks at its own rate; the pattern is
// seeded by the node's world position so identical strips never blink in sync.
shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform vec3 color_a : source_color = vec3(0.2, 1.0, 0.4);
uniform vec3 color_b : source_color = vec3(1.0, 0.6, 0.1);
uniform float rate = 2.5;
uniform float columns = 8.0;
uniform float rows = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 grid = UV * vec2(columns, rows);
	vec2 cell = floor(grid);
	vec2 local = fract(grid);
	float h = hash(cell + NODE_POSITION_WORLD.xz * 17.0 + NODE_POSITION_WORLD.y);
	float on = step(0.4, fract(TIME * rate * (0.35 + h) + h * 7.0));
	float led = smoothstep(0.42, 0.28, length(local - vec2(0.5)));
	vec3 colour = mix(color_a, color_b, step(0.78, h));
	ALBEDO = mix(vec3(0.015), colour * (0.25 + on * 1.75), led);
}
