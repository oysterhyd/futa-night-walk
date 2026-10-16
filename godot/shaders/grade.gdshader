shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float hurt = 0.0;
void fragment() {
	vec4 color = texture(screen_texture, SCREEN_UV);
	vec2 p = SCREEN_UV - vec2(0.5);
	float vignette = smoothstep(0.22,0.73,length(p * vec2(0.95,1.0)));
	color.rgb *= 1.0 - vignette * 0.07;
	color.rgb = mix(color.rgb, vec3(0.68,0.17,0.12),hurt * vignette * 0.28);
	COLOR = color;
}
