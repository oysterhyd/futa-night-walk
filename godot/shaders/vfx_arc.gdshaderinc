// Procedural sword arcs and shockwaves on a unit quad scaled to the radius.
// INSTANCE_CUSTOM: x = progress 0..1, y = half span (radians), z = thickness (of radius), w = style
//   0 blade glow   1 dry-brush ink arc   2 shock ring glow   3 ink ring
//   4 rune ring (dashed, rotating)        5 contracting ring (pull)
uniform sampler2D noise_tex : repeat_enable, filter_linear;
varying vec4 custom;
void vertex() { custom = INSTANCE_CUSTOM; }
float sweep_mask(float a, float prog, out float rel) {
	float head = clamp(prog * 2.6, 0.0, 1.0);
	float tail = clamp((prog - 0.18) * 1.55, 0.0, 1.0);
	rel = clamp((a - tail) / max(head - tail, 0.001), 0.0, 1.0);
	return smoothstep(tail - 0.02, tail + 0.12, a) * (1.0 - smoothstep(head - 0.03, head + 0.005, a));
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float prog = custom.x;
	float span = max(custom.y, 0.01);
	float th = custom.z;
	int style = int(custom.w + 0.5);
	float alpha = 0.0;
	vec3 rgb = COLOR.rgb;
	if (style <= 1) {
		float a = (ang + span) / (2.0 * span);
		if (a < 0.0 || a > 1.0) discard;
		float rel;
		float vis = sweep_mask(a, prog, rel);
		// crescent profile: pointed at both ends, fullest just behind the leading tip
		float prof = pow(clamp(sin(3.14159 * pow(rel, 0.62)), 0.0, 1.0), 0.75);
		float w = th * prof * (1.0 - 0.3 * smoothstep(0.45, 1.0, prog));
		float d = (1.0 - r) / max(w, 0.001);
		if (d < -0.15 || d > 1.0) discard;
		float fade = 1.0 - smoothstep(0.5, 1.0, prog);
		// streaks run along the stroke (low frequency along the arc, high across it)
		float streak = texture(noise_tex, vec2(a * 0.45 - prog * 0.9 + custom.y * 0.3, d * 1.6 + 0.37)).r;
		float fine = texture(noise_tex, vec2(a * 0.2 + 0.5, d * 4.0)).r;
		if (style == 0) {
			float edge = smoothstep(-0.12, 0.03, d);
			float body = edge * pow(clamp(1.0 - d, 0.0, 1.0), 1.4);
			float lines = mix(0.45, 1.25, smoothstep(0.3, 0.75, streak * 0.7 + fine * 0.5));
			float core = exp(-pow(max(d, 0.0) / 0.09, 2.0)) * edge;
			float tail = smoothstep(0.0, 0.45, rel);
			alpha = vis * fade * tail * max(body * lines, core);
			rgb = mix(rgb, vec3(1.0), clamp(core * 0.9 + smoothstep(0.85, 1.0, rel) * 0.4, 0.0, 1.0));
		} else {
			float body = smoothstep(-0.05, 0.04, d) * (1.0 - smoothstep(0.8, 1.0, d));
			float dry = smoothstep(0.38, 0.5, streak * 0.75 + fine * 0.35 + (1.0 - d) * 0.25 - (1.0 - rel) * 0.25);
			alpha = vis * fade * body * dry * (0.55 + 0.45 * rel);
		}
	} else if (style == 2 || style == 3 || style == 5) {
		float e = style == 5 ? 1.0 - prog : 1.0 - pow(1.0 - prog, 3.0);
		float rr = style == 5 ? mix(0.12, 1.0, e) : mix(0.06, 1.0, e);
		float band = th * (style == 5 ? 1.0 : (1.0 - prog * 0.65));
		float d = (r - rr) / max(band, 0.001);
		float fade = style == 5 ? smoothstep(0.0, 0.2, prog) * (1.0 - smoothstep(0.75, 1.0, prog)) : pow(1.0 - prog, 1.3);
		float n = texture(noise_tex, vec2(ang * 0.6366 + prog * 0.4, r * 0.8)).r;
		if (style == 3) {
			float body = 1.0 - smoothstep(0.55, 1.0, abs(d));
			alpha = body * smoothstep(0.32, 0.46, n + 0.25 - abs(d) * 0.3) * fade;
		} else {
			float body = exp(-d * d * 2.6);
			float lead = exp(-pow(max(d - 0.3, 0.0), 2.0) * 30.0) * step(0.0, d);
			alpha = (body * (0.6 + 0.6 * n) + lead * 0.4) * fade;
			rgb = mix(rgb, vec3(1.0), clamp(exp(-d * d * 14.0) * 0.6 * (1.0 - prog), 0.0, 1.0));
		}
	} else if (style == 4) {
		float d = (r - (1.0 - th)) / max(th, 0.001);
		float body = 1.0 - smoothstep(0.6, 1.0, abs(d));
		float dash = smoothstep(0.35, 0.5, fract(ang * 3.8197 + prog * 3.0)) * (1.0 - smoothstep(0.85, 1.0, fract(ang * 3.8197 + prog * 3.0)));
		alpha = body * mix(0.35, 1.0, dash);
	}
	COLOR = vec4(rgb, clamp(alpha, 0.0, 1.0) * COLOR.a);
}
