shader_type canvas_item;

uniform vec4 source_region = vec4(.149, 0.0, .714, 1.0);
uniform bool wooden_roller = false;
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec2 sample_uv = source_region.xy + UV * source_region.zw;
	if (!wooden_roller) {
		// Give the parchment a gentle hanging curve with both ends attached.
		sample_uv.y -= .095 * sin(UV.x * 3.14159265)
			- .025 * sin(UV.x * 6.28318530);
		// Follow the tilted paper-to-roller seam in the source image.
		float attached_edge = .871 + .072 * sample_uv.y;
		sample_uv.x = mix(source_region.x,attached_edge,UV.x);
	} else {
		// Straighten the source cylinder before applying the UI's gentle tilt.
		float roller_axis = .890 + .072 * sample_uv.y;
		sample_uv.x = roller_axis + (UV.x-.5)*.050*sign(source_region.z);
	}
	vec4 ink = texture(TEXTURE, sample_uv);
	float warmth = smoothstep(.004, .024, ink.r - ink.b);
	float dark_ink = 1.0-smoothstep(.60,.86,dot(ink.rgb,vec3(.299,.587,.114)));
	float silhouette = max(warmth,dark_ink);
	float mask;
	if (wooden_roller) {
		// Keep the new wood grain and dark end caps. The pale neutral
		// checkerboard is baked into the supplied image.
		mask = silhouette;
	} else {
		// Key only the outer margins, retaining the texture's own irregular
		// curled edges and all neutral-grey mountains inside the paper.
		float margin = clamp(1.0-smoothstep(.29,.34,sample_uv.y)
			+ smoothstep(.70,.76,sample_uv.y),0.0,1.0);
		mask = mix(1.0,silhouette,margin);
	}
	mask *= step(0.0,sample_uv.y)*step(sample_uv.y,1.0);
	COLOR = vec4(ink.rgb, ink.a * mask) * vertex_tint;
}
