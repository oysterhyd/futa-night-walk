shader_type canvas_item;
render_mode unshaded;
// Night wash over backdrop art: a strong left gradient for the title menu,
// a uniform dim for other screens, and a soft bottom vignette.
uniform float base = 0.0;
uniform float left_strength = 0.9;
void fragment() {
	float left = left_strength * (1.0 - smoothstep(0.2, 0.62, UV.x));
	float bottom = smoothstep(0.62, 1.0, UV.y) * 0.55;
	float edge = smoothstep(0.35, 0.85, distance(UV, vec2(0.62, 0.45))) * 0.35;
	float a = clamp(base + left + bottom * (1.0 - base) + edge * (1.0 - base), 0.0, 0.97);
	COLOR = vec4(0.020, 0.040, 0.050, a);
}
