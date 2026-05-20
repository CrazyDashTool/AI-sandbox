shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 near_color : source_color = vec4(0.22, 0.5, 0.17, 1.0);
uniform vec4 far_color : source_color = vec4(0.48, 0.76, 0.32, 1.0);
uniform float softness = 0.42;

void fragment() {
	float blades = sin(UV.x * 130.0) * sin(UV.y * 97.0) * 0.025;
	float meadow = sin((UV.x + UV.y) * 18.0) * 0.035;
	float fade = clamp(UV.y * softness + 0.42 + meadow, 0.0, 1.0);
	ALBEDO = mix(near_color.rgb, far_color.rgb, fade) + vec3(blades);
	ROUGHNESS = 0.95;
	SPECULAR = 0.12;
}
