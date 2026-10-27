// Procedural CRT feeds for the station screens (no textures): 0 county map with radar sweep and unit blips,
// 1 scrolling incident log with a radio waveform, 2 unit status table (row stripes and status chips; the text
// comes from Label3D on top), 3 idle CAD desktop, 4 TV news.
shader_type spatial;
render_mode unshaded, shadows_disabled, cull_back;

uniform int mode = 0;
uniform vec3 tint : source_color = vec3(0.35, 0.95, 0.75);
uniform float brightness = 1.0;
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float line_mask(float d, float width) {
	return smoothstep(width, 0.0, abs(d));
}

// Text-like dashes: rows of short blocks, as if the screen were full of small print.
float text_rows(vec2 uv, float rows, float cols, float row_offset) {
	float row = floor(uv.y * rows + row_offset);
	vec2 cell = vec2(floor(uv.x * cols), row);
	float in_row = step(0.25, fract(uv.y * rows + row_offset)) * step(fract(uv.y * rows + row_offset), 0.75);
	float length_cut = step(uv.x, 0.25 + 0.7 * hash(vec2(row, seed)));
	return in_row * step(0.3, hash(cell + seed)) * step(0.12, fract(uv.x * cols)) * length_cut;
}

vec3 map_feed(vec2 uv, float t) {
	vec3 col = vec3(0.015, 0.04, 0.05);
	vec2 grid = abs(fract(uv * vec2(18.0, 11.0)) - 0.5);
	col += tint * 0.05 * step(0.46, max(grid.x, grid.y));
	float terrain = noise(uv * vec2(5.0, 3.2) + seed);
	col += tint * 0.12 * line_mask(fract(terrain * 6.0) - 0.5, 0.03);
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		col += tint * 0.35 * line_mask(uv.y - (0.12 + 0.19 * fi + 0.05 * sin(uv.x * 6.0 + fi)), 0.004);
		col += tint * 0.28 * line_mask(uv.x - (0.08 + 0.21 * fi), 0.003);
	}
	vec2 d = (uv - vec2(0.5)) * vec2(1.7, 1.0);
	float ang = atan(d.y, d.x);
	float sweep = mod(t * 1.1, 6.2832);
	float trail = mod(sweep - ang + 6.2832, 6.2832);
	float inside = step(length(d), 0.47);
	col += tint * 0.45 * exp(-trail * 2.5) * inside;
	col += tint * 0.25 * line_mask(length(d) - 0.47, 0.004);
	col += tint * 0.12 * line_mask(length(d) - 0.24, 0.003);
	for (int i = 0; i < 7; i++) {
		vec2 p = vec2(hash(vec2(float(i), seed + 1.0)), hash(vec2(seed + 2.0, float(i)))) * 0.8 + 0.1;
		p += 0.02 * vec2(sin(t * 0.2 + float(i)), cos(t * 0.17 + float(i)));
		float blink = step(0.5, fract(t * 0.8 + hash(p)));
		vec3 dot_col = i < 2 ? vec3(1.0, 0.25, 0.15) : vec3(0.4, 0.75, 1.0);
		col += dot_col * smoothstep(0.014, 0.004, length((uv - p) * vec2(1.7, 1.0))) * (0.6 + blink);
	}
	return col;
}

vec3 log_feed(vec2 uv, float t) {
	vec3 col = vec3(0.01, 0.03, 0.03);
	col += tint * 0.85 * text_rows(uv * vec2(1.0, 0.8), 26.0, 34.0, t * 0.9) * step(uv.y, 0.78);
	col += tint * 0.18 * step(uv.y, 0.06);
	float band = step(0.82, uv.y);
	float wave = 0.91 + 0.06 * sin(uv.x * 40.0 + t * 9.0) * noise(vec2(uv.x * 8.0, t * 3.0));
	col += tint * band * line_mask(uv.y - wave, 0.006);
	col += tint * 0.15 * band * line_mask(uv.y - 0.82, 0.002);
	return col;
}

vec3 status_feed(vec2 uv, float t) {
	vec3 col = vec3(0.012, 0.025, 0.035);
	float rows = 9.0;
	float row = floor(uv.y * rows);
	float in_row = step(0.12, fract(uv.y * rows)) * step(fract(uv.y * rows), 0.88);
	col += tint * 0.08 * in_row * step(0.5, mod(row, 2.0));
	float pick = hash(vec2(row, floor(t * 0.25 + hash(vec2(row, seed)) * 4.0)));
	vec3 chip = pick < 0.55 ? vec3(0.25, 0.9, 0.4) : (pick < 0.85 ? vec3(1.0, 0.7, 0.15) : vec3(1.0, 0.2, 0.15));
	col += chip * in_row * step(0.86, uv.x) * step(uv.x, 0.96) * (row > 0.0 ? 1.0 : 0.0);
	return col;
}

vec3 cad_feed(vec2 uv, float t) {
	vec3 col = vec3(0.02, 0.05, 0.09);
	col += vec3(0.1, 0.25, 0.45) * step(uv.y, 0.07);
	col += vec3(0.05, 0.1, 0.16) * step(uv.x, 0.3) * step(0.07, uv.y);
	col += tint * 0.6 * text_rows(vec2(uv.x * 3.3, uv.y), 22.0, 14.0, 0.0) * step(uv.x, 0.28) * step(0.1, uv.y);
	vec2 m = (uv - vec2(0.65, 0.5)) * vec2(1.6, 1.0);
	col += tint * 0.18 * line_mask(fract(noise(uv * 4.0 + seed) * 5.0) - 0.5, 0.03) * step(0.32, uv.x) * step(0.1, uv.y);
	float cursor = step(0.5, fract(t * 1.2));
	col += vec3(0.8) * cursor * step(0.34, uv.x) * step(uv.x, 0.345) * step(0.88, uv.y) * step(uv.y, 0.93);
	col += vec3(1.0, 0.3, 0.2) * smoothstep(0.02, 0.01, length(m - vec2(0.05 * sin(t * 0.3), 0.0))) * step(0.5, fract(t * 0.9));
	return col;
}

vec3 news_feed(vec2 uv, float t) {
	vec3 col = mix(vec3(0.08, 0.1, 0.2), vec3(0.25, 0.18, 0.12), noise(uv * 3.0 + vec2(t * 0.15, 0.0)));
	col += vec3(0.25) * smoothstep(0.25, 0.0, length((uv - vec2(0.38, 0.42)) * vec2(1.0, 0.8)));
	float lower = step(0.74, uv.y) * step(uv.y, 0.86);
	col = mix(col, vec3(0.65, 0.06, 0.05), lower);
	float ticker = step(0.86, uv.y);
	col = mix(col, vec3(0.04), ticker);
	col += vec3(0.9) * ticker * text_rows(vec2(fract(uv.x + t * 0.08), (uv.y - 0.86) / 0.14), 1.0, 30.0, 0.0);
	col += vec3(0.95) * lower * text_rows(vec2(uv.x * 1.4, (uv.y - 0.74) / 0.12), 1.0, 20.0, 0.0) * step(uv.x, 0.6);
	return col;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME + seed * 13.0;
	vec3 col;
	if (mode == 0) {
		col = map_feed(uv, t);
	} else if (mode == 1) {
		col = log_feed(uv, t);
	} else if (mode == 2) {
		col = status_feed(uv, t);
	} else if (mode == 3) {
		col = cad_feed(uv, t);
	} else {
		col = news_feed(uv, t);
	}
	col *= 0.86 + 0.14 * sin(uv.y * 700.0);
	col *= 1.0 - 0.35 * pow(length(uv - vec2(0.5)) * 1.3, 3.0);
	col *= 0.97 + 0.03 * sin(t * 50.0);
	ALBEDO = col * brightness;
}
