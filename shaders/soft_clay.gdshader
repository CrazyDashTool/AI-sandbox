shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.75, 0.85, 0.95, 1.0);
uniform vec4 top_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float roughness = 0.82;
uniform float rim_strength = 0.08;
uniform float shade_softness = 0.35;

void fragment() {
	float vertical = clamp((VERTEX.y + 1.5) / 3.0, 0.0, 1.0);
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.2);
	ALBEDO = mix(base_color.rgb, top_tint.rgb, vertical * shade_softness);
	ROUGHNESS = roughness;
	METALLIC = 0.0;
	EMISSION = top_tint.rgb * rim * rim_strength;
	ALPHA = base_color.a;
}
