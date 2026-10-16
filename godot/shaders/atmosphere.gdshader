shader_type canvas_item;
render_mode unshaded;
uniform float age = 0.0;
uniform float strength = 0.3;
uniform vec4 fog_color : source_color = vec4(0.23,0.42,0.42,1.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x), mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
	vec2 p = UV * vec2(7.0,4.0) + vec2(age*0.025, age*0.01);
	float n = noise(p)*0.6 + noise(p*2.1)*0.3 + noise(p*4.0)*0.1;
	float border = smoothstep(0.25, 0.65, distance(UV,vec2(0.5)));
	float mist = smoothstep(0.40,0.85,n) * strength * (0.35 + border);
	COLOR = vec4(fog_color.rgb,mist);
}
