shader_type canvas_item;
render_mode unshaded;
#include "res://samples/ink_study/brush.gdshaderinc"

uniform sampler2D paper_grain : repeat_enable, filter_linear_mipmap;

float luma(vec3 color) {
	return dot(color, vec3(.30, .53, .17));
}

void fragment() {
	vec2 uv = UV;
	vec2 pixel = TEXTURE_PIXEL_SIZE;
	float fibers = texture(paper_grain, uv / pixel / 128.0 * vec2(.36, 1.67)).r;
	float tooth = texture(paper_grain, uv / pixel / 128.0).r;
	float stain = ink_noise(uv * vec2(8.2, 5.5) + vec2(6.0, 3.0));
	float wash = ink_noise(uv * vec2(5.6, 4.1) + vec2(stain, 0.0));
	float border = smoothstep(.30, .73, length((uv - .5) * vec2(1.08, .92)));
	vec3 paper = vec3(.956, .930, .872);
	paper -= vec3(.10, .093, .080) * smoothstep(.33, .82, wash) * (.10 + border * .60);
	paper += (tooth - .5) * .030 + (fibers - .5) * .012;

	float pressure = ink_noise(uv * vec2(83.0, 53.0) + 2.0);
	float tooth_shift = (fibers - .5) * 2.0;
	vec2 impression = uv + pixel * vec2(pressure - .5 + tooth_shift, stain - .5 - tooth_shift) * .82;
	vec4 paint = texture(TEXTURE, impression);
	float width = mix(.63, 2.55, pressure);
	vec2 stroke = pixel * width * vec2(1.0, .81);
	vec4 a = texture(TEXTURE, impression + vec2(stroke.x, 0.0));
	vec4 b = texture(TEXTURE, impression - vec2(stroke.x, 0.0));
	vec4 c = texture(TEXTURE, impression + vec2(0.0, stroke.y));
	vec4 d = texture(TEXTURE, impression - vec2(0.0, stroke.y));
	float outside = max(max(a.a, b.a), max(c.a, d.a));
	float inside = min(min(a.a, b.a), min(c.a, d.a));
	float opaque = smoothstep(.66, .97, outside);
	float silhouette = smoothstep(.19, .82, outside - inside) * opaque;
	float form = max(abs(luma(a.rgb - b.rgb)), abs(luma(c.rgb - d.rgb))) * smoothstep(.76, .98, inside);
	float form_stroke = smoothstep(.083, .31, form);
	float breakup = smoothstep(.19, .55, pressure);
	float dry = smoothstep(.42, .70, fibers) * smoothstep(.30, .66, pressure);
	float painted_value = luma(a.rgb + b.rgb + c.rgb + d.rgb + paint.rgb) /
		max(a.a + b.a + c.a + d.a + paint.a, .01);
	float ink_load = mix(1.0, .17, smoothstep(.66, .92, painted_value));
	float ink_line = max(silhouette * .78, form_stroke * .53);
	ink_line *= (.07 + breakup * .85) * (1.0 - dry * .96) * ink_load;

	// Sparse wider taps form the translucent wet fringe around the thin brush.
	vec2 seep = pixel * mix(4.1, 7.1, stain);
	float broad = (
		texture(TEXTURE, uv + seep).a + texture(TEXTURE, uv - seep).a +
		texture(TEXTURE, uv + vec2(-seep.x, seep.y)).a +
		texture(TEXTURE, uv + vec2(seep.x, -seep.y)).a
	) * .25;
	float bleed = smoothstep(.014, .54, max(broad - paint.a, 0.0)) * opaque * (.09 + stain * .24) * ink_load;
	float lift = (1.0 - inside) * paint.a * opaque * dry * (.12 + pressure * .37);
	vec3 color = paint.rgb + paper * (1.0 - paint.a);
	color = mix(color, paper, lift);
	color = mix(color, vec3(.185, .159, .134), clamp(ink_line + bleed, 0.0, .82));
	color += (tooth - .5) * .022;
	COLOR = vec4(color, 1.0);
}
