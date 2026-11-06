shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D scenery_atlas : source_color, filter_linear_mipmap, repeat_disable;
varying float opacity;

void vertex() {
	float kind = INSTANCE_CUSTOM.r;
	opacity = INSTANCE_CUSTOM.g;
	// Tile coordinates are in 256 px units. Each tile has a transparent gutter.
	vec4 tile = vec4(0.0, 0.0, 4.0, 2.0);
	if (kind < .5) {
		// Pin the distant painting to the view and project it beyond the track.
		float aspect = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
		float wide = smoothstep(.65, 1.55, aspect);
		vec2 extent = vec2(max(2.10, 1.86 / aspect), mix(.93, 1.20, wide));
		vec2 screen = VERTEX.xy * extent + vec2(0.0, mix(.57, .48, wide));
		float distance_to_camera = 190.0;
		vec2 view = screen * distance_to_camera / abs(vec2(PROJECTION_MATRIX[0][0], PROJECTION_MATRIX[1][1]));
		POSITION = PROJECTION_MATRIX * vec4(view, -distance_to_camera, 1.0);
	} else {
		POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
		UV.x = 1.0 - UV.x;
		if (kind < 1.5) {
			tile = vec4(0.0, 2.0, 4.0, 2.0);
		} else if (kind < 2.5) {
			tile = vec4(4.0, 0.0, 2.0, 2.0);
		} else {
			tile = vec4(kind + 1.0, 2.0, 1.0, 2.0);
		}
	}
	UV = (tile.xy + UV * tile.zw) / vec2(6.0, 4.0);
}

void fragment() {
	vec4 ink = texture(scenery_atlas, UV);
	ALBEDO = ink.rgb;
	ALPHA = ink.a * opacity;
}
