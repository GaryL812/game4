shader_type spatial;
render_mode unshaded, cull_disabled, specular_disabled;

uniform sampler2D ink_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 accent_color : source_color = vec4(0.0);

void fragment() {
	vec3 ink = texture(ink_atlas, UV).rgb;
	vec3 colored_ink = mix(ink, accent_color.rgb, .72);
	ALBEDO = mix(ink, colored_ink, COLOR.r * accent_color.a);
}
