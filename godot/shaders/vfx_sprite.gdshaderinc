// Shared body for batched VFX sprites (MultiMesh). INSTANCE_CUSTOM:
//   x = atlas cell index, y = erosion 0..1, z = noise seed, w = hot core (whitens dense centres)
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float grid = 8.0;
varying vec4 custom;
varying vec2 local_uv;
varying vec4 instance_modulate;
void vertex() {
	custom = INSTANCE_CUSTOM;
	instance_modulate = COLOR;
	local_uv = UV;
	float cell = floor(custom.x + 0.5);
	vec2 origin = vec2(mod(cell, grid), floor(cell / grid));
	UV = (origin + mix(vec2(0.004), vec2(0.996), UV)) / grid;
}
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float alpha = tex.a;
	if (custom.y > 0.001) {
		float n = texture(noise_tex, local_uv * 0.85 + vec2(custom.z, custom.z * 1.7)).r;
		float field = n * 0.75 + tex.a * 0.35;
		alpha *= smoothstep(custom.y * 1.1 - 0.05, custom.y * 1.1 + 0.12, field);
	}
	vec3 rgb = tex.rgb * instance_modulate.rgb;
	rgb = mix(rgb, vec3(1.0), clamp(custom.w * tex.a * tex.a, 0.0, 1.0));
	COLOR = vec4(rgb, alpha * instance_modulate.a);
}
