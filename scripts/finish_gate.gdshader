shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, specular_disabled;

uniform sampler2D gate_texture : source_color, filter_linear_mipmap, repeat_disable;

float stone_core(vec2 uv, vec4 bounds) {
	vec2 inside = smoothstep(bounds.xy,bounds.xy+vec2(.003),uv)
		*(1.0-smoothstep(bounds.zw-vec2(.003),bounds.zw,uv));
	return inside.x*inside.y;
}

void fragment() {
	vec4 ink = texture(gate_texture,UV);
	// Remove the baked neutral checkerboard in perceptual colour space.
	vec3 paper_colour = pow(max(ink.rgb,vec3(0.0)),vec3(1.0/2.2));
	float darkness = 1.0-dot(paper_colour,vec3(.299,.587,.114));
	float silhouette = smoothstep(.075,.24,darkness);
	// Preserve pale stone within the four posts instead of keying it into glass.
	float posts = stone_core(UV,vec4(.330,.450,.357,.720))
		+ stone_core(UV,vec4(.641,.450,.669,.720))
		+ stone_core(UV,vec4(.174,.540,.199,.720))
		+ stone_core(UV,vec4(.801,.540,.825,.720));
	silhouette = max(silhouette,min(1.0,posts)*.92);
	float ground_fade = 1.0-smoothstep(.78,.94,UV.y);
	ALBEDO = ink.rgb;
	ALPHA = silhouette*ground_fade*ink.a;
}
