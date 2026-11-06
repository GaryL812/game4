shader_type spatial;
render_mode unshaded, cull_disabled, specular_disabled, shadows_disabled;
#include "res://samples/ink_study/brush.gdshaderinc"

uniform bool ground = false;
uniform vec3 ground_top_center = vec3(0.0);
uniform vec2 ground_half_size = vec2(3.4, 2.45);
varying vec3 brush_local;
varying vec3 world_position;
varying vec3 world_normal;

const vec3 PAPER = vec3(.947, .921, .855);
const vec3 WASH = vec3(.655, .668, .610);
const vec3 DRY_INK = vec3(.449, .467, .414);
const vec3 POOLED_INK = vec3(.285, .308, .271);
const vec3 CHAR_INK = vec3(.184, .170, .144);

void vertex() {
	brush_local = VERTEX;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = MODEL_NORMAL_MATRIX * NORMAL;
}

vec3 stone_pigment(vec3 normal) {
	vec3 relative = world_position - ground_top_center;
	vec2 inset = ground_half_size - abs(relative.xz);
	float lip_distance = max(0.0, -relative.y);
	float top = smoothstep(.20, .70, normal.y);
	float edge_distance = mix(min(lip_distance, max(inset.x, inset.y)), min(inset.x, inset.y), top);
	edge_distance = max(0.0, edge_distance);

	// All pigment fields share the same world-space phase across adjoining modules.
	vec2 plane = world_position.xz + world_position.y * vec2(.47, .81);
	float soak = ink_noise(plane * vec2(.69, .54) + vec2(12.7, 4.1));
	float pressure = ink_noise(plane * 3.2 + vec2(9.4, 17.3));
	float interior = smoothstep(.16, mix(.52, .98, soak), edge_distance);
	float corner = 1.0 - smoothstep(.02, .46, max(inset.x, inset.y));
	float pooling = 1.0 - smoothstep(.014, mix(.18, .46, soak), edge_distance);
	float wet_mask = smoothstep(.24, .83, soak);
	float bloom = wet_mask * mix(.77, .15, interior);
	bloom += (1.0 - top) * .28 * (1.0 - smoothstep(.03, .46, lip_distance));

	// Positive Z is the route direction. A small local drift keeps each cluster
	// close to that axis while the brush-load field starts and stops the marks.
	vec2 stroke_plane = vec2(plane.x + plane.y * .045 + (soak - .5) * .082, plane.y);
	float cluster = smoothstep(.43, .74, ink_noise(plane * vec2(2.2, 1.65) + 2.6));
	float fibre = ink_noise(stroke_plane * vec2(36.0, 3.4) + vec2(11.2, 1.1));
	float bristle = smoothstep(.48, .81, fibre);
	float dry = cluster * bristle * mix(.77, .030, interior);
	float paper_gap = smoothstep(.61, .82, fibre) * smoothstep(.44, .69, pressure);
	float rim = 1.0 - smoothstep(.002, mix(.028, .095, pressure), edge_distance);
	float char = rim * smoothstep(.32, .75, pressure + corner * .18) * (1.0 - paper_gap * .92);
	pooling *= mix(.14, .71, pressure) * (1.0 - paper_gap * .78);
	float wall_fade = 1.0 - smoothstep(.27, 1.11, lip_distance);
	char *= wall_fade;
	pooling *= wall_fade;
	dry *= wall_fade;

	vec3 paper = mix(PAPER, vec3(.954, .929, .873), (1.0 - top) * (1.0 - wall_fade));
	vec3 color = mix(paper, WASH, clamp(bloom * mix(wall_fade, 1.0, top), 0.0, 1.0));
	color = mix(color, DRY_INK, dry);
	color = mix(color, POOLED_INK, pooling);
	return mix(color, CHAR_INK, char * .76);
}

vec3 hero_pigment(vec3 normal, float facing, vec3 vertex_pigment) {
	vec2 plane = vec2(brush_local.x + brush_local.z * .68, brush_local.y);
	float soak = ink_noise(plane * 3.2 + vec2(4.4, 9.0));
	float pressure = ink_noise(plane * vec2(10.0, 6.5) + 7.3);
	float fibre = ink_noise(plane * vec2(49.0, 8.5) + 3.8);
	float broken = smoothstep(.57, .82, fibre) * smoothstep(.42, .69, pressure);
	float crease = (1.0 - smoothstep(.10, mix(.34, .65, pressure), facing)) * (.25 + pressure * .75);
	float lit = smoothstep(-.6, .94, dot(normal, vec3(-.40, .84, .37)));
	float light_source = smoothstep(.035, .60, sqrt(max(dot(vertex_pigment, vec3(.30, .49, .21)), 0.0)));
	float ochre = smoothstep(.075, .28, vertex_pigment.r - vertex_pigment.b) * smoothstep(.18, .44, vertex_pigment.g);
	float red = smoothstep(.065, .22, vertex_pigment.r - vertex_pigment.g) * (1.0 - smoothstep(.055, .19, vertex_pigment.g));
	float height = brush_local.y;
	float hem = smoothstep(.23, .36, height) * (1.0 - smoothstep(.39, .67, height));
	float cuff = smoothstep(.64, .73, height) * (1.0 - smoothstep(.75, .91, height));
	float hat = smoothstep(1.52, 1.64, height) * ochre;
	float crown = smoothstep(1.45, 1.85, height) * lit;
	float collection = clamp((hem * .72 + cuff * .38) * (1.0 - crown) + crease * .42, 0.0, 1.0);

	vec3 paper = mix(PAPER, vec3(.906, .814, .652), ochre * .78);
	vec3 wash = mix(WASH, vec3(.671, .539, .363), ochre);
	vec3 ink = mix(POOLED_INK, vec3(.397, .292, .192), ochre * .8);
	paper = mix(paper, vec3(.714, .366, .310), red * .86);
	wash = mix(wash, vec3(.495, .234, .198), red);
	ink = mix(ink, vec3(.310, .143, .124), red);
	float wet = (.20 + soak * .53) * (1.0 - crown * .53);
	float pigment = clamp(.82 - light_source * .82 - lit * .16 + collection * .59, 0.0, .94);
	pigment *= 1.0 - hat * .57;
	vec3 color = mix(mix(paper, wash, wet), ink, pigment);
	float char = crease * smoothstep(.29, .83, pressure + collection * .27);
	color = mix(color, mix(CHAR_INK, ink, max(red * .46, hat)), char * (1.0 - hat * .68) * (1.0 - broken * .91));
	return mix(color, paper, broken * (.09 + collection * .32));
}

void fragment() {
	vec3 normal = normalize(world_normal);
	ALBEDO = ground ? stone_pigment(normal) : hero_pigment(normal, abs(dot(normalize(NORMAL), normalize(VIEW))), COLOR.rgb);
}
