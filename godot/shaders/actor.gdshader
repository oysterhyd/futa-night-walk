shader_type canvas_item;
render_mode unshaded;
instance uniform float age = 0.0;
instance uniform float flash = 0.0;
instance uniform float frozen = 0.0;
instance uniform float burning = 0.0;
instance uniform float dissolve = 0.0;
varying vec4 instance_modulate;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
void vertex() {
	instance_modulate = COLOR;
}
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 tint = mix(tex.rgb, vec3(0.22, 0.39, 0.46), frozen * 0.25);
	tint = mix(tint, tint + vec3(0.24, 0.06, 0.0), burning * (0.4 + 0.2 * sin(age * 18.0)));
	tint = mix(tint, vec3(1.0, 0.92, 0.72), flash);
	float noise = hash(floor(UV * 130.0));
	tex.a *= smoothstep(dissolve - 0.12, dissolve + 0.02, noise);
	COLOR = vec4(tint, tex.a) * instance_modulate;
}
