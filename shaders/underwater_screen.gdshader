shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(0.36, 0.78, 0.92, 1.0);
uniform vec4 deep_tint : source_color = vec4(0.02, 0.16, 0.28, 1.0);
uniform float wave_speed = 3.0;
uniform float wave_freq = 10.0;
uniform float wave_width = 1.0;
uniform float depth_fade = 0.0;
uniform float distortion_strength = 1.0;

void fragment() {
	vec2 wave_uv_offset = vec2(0.0);
	wave_uv_offset.x = cos((TIME * wave_speed) + UV.x + UV.y * wave_freq * 2.0) * wave_width * 0.01 * distortion_strength;
	wave_uv_offset.y = sin((TIME * wave_speed * 0.73) + UV.y * wave_freq + UV.x * 4.0) * wave_width * 0.0035 * distortion_strength;

	float depth = clamp(depth_fade, 0.0, 1.0);
	vec3 screen_color = texture(screen_texture, SCREEN_UV + wave_uv_offset).rgb;
	vec3 tinted = screen_color * tint.rgb;
	vec3 fogged = mix(tinted, deep_tint.rgb, depth * 0.82);
	fogged *= mix(1.0, 0.34, depth);

	COLOR = vec4(mix(screen_color, fogged, 0.18 + depth * 0.82), 1.0);
}
