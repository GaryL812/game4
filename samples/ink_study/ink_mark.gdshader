shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
#include "res://samples/ink_study/brush.gdshaderinc"

uniform sampler2D paper_grain : repeat_enable, filter_linear_mipmap;
varying vec4 mark;

void vertex() {
	mark = INSTANCE_CUSTOM;
	// Only the thrown drops face the lens. Trails and rings lie on the stone.
	if (mark.x > .16 && mark.x < .50) {
		vec3 right = INV_VIEW_MATRIX[0].xyz * length(MODEL_MATRIX[0].xyz);
		vec3 up = INV_VIEW_MATRIX[1].xyz * length(MODEL_MATRIX[2].xyz);
		VERTEX = vec3(VERTEX.x, VERTEX.z, 0.0);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(up, 0.0), INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	}
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float wet = ink_noise(UV * vec2(4.8, 2.3) + mark.z * 23.0);
	float grain = texture(paper_grain, UV * vec2(3.8, .65) + mark.z).r;
	float shape;
	vec3 ink = mix(vec3(.128, .111, .093), vec3(.41, .384, .337), wet * .58);
	if (mark.x > .50) {
		float age = 1.0 - mark.y;
		float radius = length(p + vec2(wet - .5, grain - .5) * .16);
		float ring = abs(radius - .63);
		float fringe = 1.0 - smoothstep(0.0, mix(.11, .29, age), ring);
		float dry_arc = smoothstep(.16, .76, wet + (grain - .5) * .26);
		shape = fringe * mix(.57, .34, age) * mix(.23, 1.0, dry_arc);
		ink = mix(ink, vec3(.53, .484, .413), age * .60);
	} else if (mark.x > .16) {
		float feather = ink_noise(p * 3.1 + vec2(mark.z * 15.0, 2.8));
		float radius = length(p * vec2(1.02, mix(.93, 1.22, mark.z))) + (feather - .5) * .28;
		float pool = 1.0 - smoothstep(.045, .53, radius);
		float bloom = 1.0 - smoothstep(.12, .94, radius);
		float card_edge = 1.0 - smoothstep(.80, 1.0, max(abs(p.x), abs(p.y)));
		shape = (pool * .55 + bloom * .28) * card_edge;
		ink = mix(vec3(.51, .46, .39), ink, pool * .88);
	} else {
		float bristle = 1.0 - smoothstep(.37, .72, grain);
		float spread = mix(.23, .70, smoothstep(-1.0, .49, p.y));
		float strokes = 1.0 - smoothstep(spread * .32, spread, abs(p.x + (wet - .50) * .29));
		shape = strokes * (1.0 - smoothstep(.65, 1.0, abs(p.y)));
		shape *= mix(.28, 1.0, bristle) * (.55 + wet * .45);
	}
	ALBEDO = ink;
	ALPHA = shape * smoothstep(0.0, .75, mark.y) * mark.w;
}
