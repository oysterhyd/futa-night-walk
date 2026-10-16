shader_type canvas_item;
render_mode unshaded;
void fragment() {
	float fade = 0.96 * (1.0-smoothstep(0.28,0.56,UV.x));
	COLOR = vec4(0.91,0.87,0.76,fade);
}
