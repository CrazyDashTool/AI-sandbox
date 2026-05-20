shader_type sky;

uniform vec4 horizon_color : source_color = vec4(0.58, 0.82, 1.0, 1.0);
uniform vec4 zenith_color : source_color = vec4(0.03, 0.42, 0.82, 1.0);
uniform vec4 glow_color : source_color = vec4(0.9, 0.97, 1.0, 1.0);

void sky() {
	float h = clamp(EYEDIR.y * 0.5 + 0.5, 0.0, 1.0);
	float glow = pow(max(EYEDIR.y, 0.0), 10.0) * 0.08;
	float haze = pow(1.0 - h, 3.0) * 0.08;
	COLOR = mix(horizon_color.rgb, zenith_color.rgb, pow(h, 1.18)) + glow_color.rgb * (glow + haze);
}
