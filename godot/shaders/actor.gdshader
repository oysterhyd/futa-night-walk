shader_type canvas_item;
render_mode unshaded;
instance uniform float age = 0.0;
instance uniform float flash = 0.0;
instance uniform float frozen = 0.0;
instance uniform float burning = 0.0;
instance uniform float dissolve = 0.0;
varying vec4 instance_modulate;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	instance_modulate = COLOR;
}
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 tint = mix(tex.rgb, vec3(0.22, 0.39, 0.46), frozen * 0.25);
	tint = mix(tint, tint + vec3(0.24, 0.06, 0.0), burning * (0.4 + 0.2 * sin(age * 18.0)));
	tint = mix(tint, vec3(1.0, 0.92, 0.72), flash);
	if (dissolve > 0.0) {
		// burning-paper dissolve: soft fbm front with a glowing ember rim and charred margin
		float field = 0.55 * vnoise(UV * 9.0) + 0.3 * vnoise(UV * 23.0 + 3.1) + 0.15 * vnoise(UV * 57.0 + 7.7);
		float front = dissolve * 1.15 - 0.05;
		float keep = smoothstep(front - 0.015, front + 0.015, field);
		float rim = 1.0 - smoothstep(0.0, 0.07, field - front);
		tint = mix(tint, vec3(0.12, 0.08, 0.06), clamp(rim * 1.6, 0.0, 1.0) * 0.8);
		tint = mix(tint, vec3(1.0, 0.62, 0.25), (1.0 - smoothstep(0.0, 0.025, field - front)) * keep);
		tex.a *= keep;
	}
	COLOR = vec4(tint, tex.a) * instance_modulate;
}
