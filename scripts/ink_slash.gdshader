shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D slash_texture : source_color, filter_linear_mipmap;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float density = 1.0;

void vertex() {
	// Keep the ink facing the camera, including the Sprite3D's scale.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
}

void fragment() {
	vec4 ink = texture(slash_texture, UV);
	float darkness = 1.0 - dot(ink.rgb, vec3(0.299, 0.587, 0.114));
	ALBEDO = vec3(0.018, 0.024, 0.021);
	ALPHA = ink.a * smoothstep(0.035, 0.85, darkness * density) * opacity;
}
