// Colour-vision assist (daltonization): simulates the chosen deficiency in LMS space and shifts the lost
// contrast into channels that viewer can still tell apart. Drawn over the whole screen, UI included.
// mode: 1 protanopia, 2 deuteranopia, 3 tritanopia.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform int mode = 0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

const mat3 RGB_TO_LMS = mat3(
	vec3(17.8824, 3.45565, 0.0299566),
	vec3(43.5161, 27.1554, 0.184309),
	vec3(4.11935, 3.86714, 1.46709));
const mat3 LMS_TO_RGB = mat3(
	vec3(0.0809444479, -0.0102485335, -0.000365296938),
	vec3(-0.130504409, 0.0540193266, -0.00412161469),
	vec3(0.116721066, -0.113614708, 0.693511405));

vec3 simulate(vec3 rgb) {
	vec3 lms = RGB_TO_LMS * rgb;
	if (mode == 1) {
		lms.x = 2.02344 * lms.y - 2.52581 * lms.z;
	} else if (mode == 2) {
		lms.y = 0.494207 * lms.x + 1.24827 * lms.z;
	} else if (mode == 3) {
		lms.z = -0.395913 * lms.x + 0.801109 * lms.y;
	}
	return LMS_TO_RGB * lms;
}

void fragment() {
	vec3 colour = texture(screen_texture, SCREEN_UV).rgb;
	vec3 error = colour - simulate(colour);
	vec3 shift = vec3(0.0, 0.7 * error.r + error.g, 0.7 * error.r + error.b);
	COLOR = vec4(clamp(colour + shift * strength, 0.0, 1.0), 1.0);
}
