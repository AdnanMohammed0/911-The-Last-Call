shader_type canvas_item;

void fragment() {
	float line = 0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159265);
	COLOR = vec4(0.0, 0.0, 0.0, line * 0.12);
}
