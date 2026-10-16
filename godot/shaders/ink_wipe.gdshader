shader_type canvas_item;
render_mode unshaded;
// Screen transition: black ink dissolves away in noisy brush-like tendrils.
uniform float progress = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x), mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
	vec2 p = UV * vec2(9.0, 5.0);
	float n = noise(p) * 0.55 + noise(p * 2.7) * 0.3 + noise(p * 7.0) * 0.15;
	float sweep = UV.x * 0.55 + n * 0.45;
	float t = progress * 1.25 - 0.1;
	float a = smoothstep(t - 0.06, t + 0.01, sweep);
	float rim = smoothstep(0.0, 0.05, abs(sweep - t)) ;
	vec3 ink = mix(vec3(0.45, 0.16, 0.08), vec3(0.015, 0.03, 0.04), rim);
	COLOR = vec4(ink, a * (1.0 - smoothstep(0.92, 1.0, progress)));
}
