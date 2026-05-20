shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, specular_schlick_ggx;

uniform vec4 glass_color : source_color = vec4(0.7, 0.92, 1.0, 0.42);
uniform float rim_power = 2.4;
uniform float glow = 0.22;

void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
	ALBEDO = glass_color.rgb;
	ALPHA = glass_color.a + rim * 0.22;
	ROUGHNESS = 0.04;
	METALLIC = 0.0;
	EMISSION = glass_color.rgb * rim * glow;
}
