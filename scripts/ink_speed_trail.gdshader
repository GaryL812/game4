shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D trail_texture : source_color, filter_linear_mipmap;
uniform vec4 live_roof;
uniform vec4 jump_roof;
varying vec4 ink_state;
varying vec3 world_position;

void vertex() {
	ink_state = INSTANCE_CUSTOM;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Source brush runs from its dense left tip to the fine right-hand tail.
	vec4 brush = texture(trail_texture, vec2(1.0 - UV.y, UV.x));
	float darkness = 1.0 - dot(brush.rgb, vec3(0.299, 0.587, 0.114));
	// Also remove the pale checkerboard baked into the supplied image.
	float coverage = brush.a * smoothstep(0.085, 0.85, darkness);
	coverage = pow(coverage, 1.0 / max(ink_state.g, 0.1));
	if (ink_state.b > 0.5) {
		vec4 roof = ink_state.b > 1.5 ? jump_roof : live_roof;
		if (world_position.x < roof.x || world_position.x > roof.y ||
			world_position.z < roof.z || world_position.z > roof.w) discard;
	}
	ALBEDO = vec3(0.025, 0.032, 0.027);
	ALPHA = coverage * ink_state.r;
}
