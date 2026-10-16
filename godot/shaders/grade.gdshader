shader_type canvas_item;
render_mode unshaded;
// Night grade for the arena. The world is graded towards moonlit blue-grey and
// re-lit by up to 32 point lights (player lantern, fire, hostile warnings...).
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float hurt = 0.0;
uniform float night = 0.0;          // 0 = daylight print, 1 = full night
uniform float desaturate = 0.0;     // slow-motion / perfect dodge
uniform float flash = 0.0;          // ignite flash
uniform vec4 flash_color : source_color = vec4(1.0, 0.82, 0.5, 1.0);
uniform int light_count = 0;
uniform vec4 lights[32];            // xy = screen px (1600x900), z = radius, w = intensity
uniform vec4 light_colors[32];
uniform float age = 0.0;
void fragment() {
	vec4 color = texture(screen_texture, SCREEN_UV);
	vec2 px = UV * vec2(1600.0, 900.0);
	vec3 lit = vec3(0.0);
	for (int i = 0; i < 32; i++) {
		if (i >= light_count) break;
		vec4 l = lights[i];
		float d = distance(px, l.xy) / max(l.z, 1.0);
		float fall = clamp(1.0 - d, 0.0, 1.0);
		fall = fall * fall * (3.0 - 2.0 * fall);
		lit += light_colors[i].rgb * fall * l.w;
	}
	vec3 moon = vec3(0.34, 0.41, 0.53);
	float luma = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	vec3 night_col = mix(vec3(luma), color.rgb, 0.55) * moon;
	vec3 graded = mix(color.rgb, night_col, night);
	// lights restore the print's true colour and add warmth
	vec3 relit = color.rgb * (vec3(1.0) + lit * 0.35);
	vec3 amount = clamp(lit, 0.0, 1.0);
	graded = mix(graded, relit, amount * night) + lit * 0.06 * night;
	graded = mix(graded, color.rgb, 1.0 - night);
	vec2 p = SCREEN_UV - vec2(0.5);
	float vignette = smoothstep(0.22, 0.75, length(p * vec2(0.95, 1.0)));
	graded *= 1.0 - vignette * (0.07 + 0.30 * night);
	float g = dot(graded, vec3(0.299, 0.587, 0.114));
	graded = mix(graded, vec3(g) * vec3(0.85, 0.95, 1.05), desaturate * 0.75);
	graded = mix(graded, vec3(0.68, 0.17, 0.12), hurt * vignette * 0.32);
	graded = mix(graded, flash_color.rgb, flash * 0.55);
	float grain = fract(sin(dot(px + age * 37.0, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	graded += grain * 0.025 * night;
	COLOR = vec4(graded, color.a);
}
