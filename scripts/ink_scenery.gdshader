shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D scenery_atlas : source_color, filter_linear_mipmap, repeat_disable;
varying float opacity;

void vertex() {
	float kind = INSTANCE_CUSTOM.r;
	opacity = INSTANCE_CUSTOM.g;
	// Tile coordinates are in 256 px units. Each tile has a transparent gutter.
	vec4 tile = vec4(0.0, 0.0, 4.0, 2.0);
	if (kind > 4.5) {
		tile = vec4(6.0, 2.0, 1.0, 2.0);
	} else if (kind > 3.5) {
		tile = vec4(6.0, 0.0, 2.0, 2.0);
	} else if (kind > 2.5) {
		tile = vec4(4.0, 2.0, 1.0, 2.0);
	} else if (kind > 1.5) {
		tile = vec4(4.0, 0.0, 2.0, 2.0);
	} else if (kind > .5) {
		tile = vec4(0.0, 2.0, 4.0, 2.0);
	}
	UV = (tile.xy + UV * tile.zw) / vec2(8.0, 4.0);

	// Instance transforms describe view-relative rectangles. Project them at
	// background depths so ordinary depth testing keeps the playable track in front.
	vec3 center = MODEL_MATRIX[3].xyz;
	vec2 extent = vec2(MODEL_MATRIX[0].x, MODEL_MATRIX[1].y);
	float narrow = 1.0 - smoothstep(.65, 1.55, VIEWPORT_SIZE.x / VIEWPORT_SIZE.y);
	if (kind < .5) {
		extent *= vec2(1.0 + narrow * .56, 1.0 - narrow * .12);
	} else if (kind > 1.5) {
		extent *= vec2(1.0 + narrow * .13, 1.0 - narrow * .26);
		center.x += sign(center.x) * narrow * .09;
	}
	vec2 screen = center.xy + VERTEX.xy * extent;
	vec2 view = screen * center.z / abs(vec2(PROJECTION_MATRIX[0][0], PROJECTION_MATRIX[1][1]));
	POSITION = PROJECTION_MATRIX * vec4(view, -center.z, 1.0);
}

void fragment() {
	vec4 ink = texture(scenery_atlas, UV);
	ALBEDO = ink.rgb;
	ALPHA = ink.a * opacity;
}
