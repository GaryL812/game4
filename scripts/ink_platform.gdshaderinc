float platform_hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * .1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float platform_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 t = fract(p);
	t = t * t * (3.0 - 2.0 * t);
	float a = mix(platform_hash(cell), platform_hash(cell + vec2(1.0, 0.0)), t.x);
	float b = mix(platform_hash(cell + vec2(0.0, 1.0)), platform_hash(cell + 1.0), t.x);
	return mix(a, b, t.y);
}

float platform_joints(vec2 plane, float wash, float tooth, bool top, bool timber) {
	vec2 spacing = top ? vec2(3.65, 4.3) : vec2(4.2, 2.35);
	if (top && timber) {
		spacing.y = .92;
	}
	vec2 courses = plane / spacing;
	float pixel = max(fwidth(courses.x), fwidth(courses.y));
	courses.y += (wash - .5) * .092;
	float row = floor(courses.y);
	float offset = platform_hash(vec2(row, 9.0));
	courses.x = courses.x * mix(.84, 1.2, offset) + offset + (tooth - .5) * .087;
	vec2 distance_to_joint = abs(fract(courses + .5) - .5);
	float width = mix(.006, .024, tooth);
	vec2 joints = 1.0 - smoothstep(vec2(width * .30), vec2(width + min(pixel, .040) * .55), distance_to_joint);
	float strength = mix(.16, .74, smoothstep(.23, .72, tooth));
	float cross_joint = top && timber ? 0.0 : joints.x * .77;
	return max(joints.y, cross_joint) * strength * (1.0 - smoothstep(.045, .24, pixel));
}

vec3 painted_platform(vec3 p, vec3 normal, vec3 deck, float half_width, vec4 pattern, bool timber, vec3 texture_paper, float paper_tooth) {
	const vec3 WASH = vec3(.55, .58, .53);
	const vec3 INK = vec3(.26, .25, .21);
	const vec3 CHAR = vec3(.073, .065, .054);
	bool top = normal.y > .54;
	vec2 footprint = vec2(half_width, 12.0);
	vec2 inset = max(vec2(0.0), footprint - abs(deck.xz));
	float below_lip = max(0.0, -deck.y);
	float edge = top ? min(inset.x, inset.y) : below_lip;
	float along = p.x + p.z;
	float pressure = platform_noise(vec2(along * .44, (p.x - p.z) * .16) + 6.1);
	float tooth = platform_noise(vec2(along * 2.35, (p.x - p.z) * .46) + 17.8);
	vec2 plane = top ? p.xz : vec2(p.x + p.z, p.y);
	float wash = platform_noise(plane * .34 + pattern.zw * 13.0);

	float side = smoothstep(.31, .90, abs(deck.x) / half_width);
	vec3 paper = mix(vec3(.952, .936, .878), texture_paper, .32 + side * .42);
	if (timber) {
		paper = mix(paper, vec3(.78, .700, .559), .47);
	}
	vec3 color = top ? paper : mix(vec3(.885, .860, .788), WASH, .16 + wash * .29);
	float joint = platform_joints(plane, wash, tooth, top, timber);
	color = mix(color, INK, joint * (top ? mix(.11, .26, side) : .37));

	// A loaded corner and a smaller deposit across the platform.
	vec2 from_corner = footprint - deck.xz * pattern.xy;
	vec2 corner_scale = vec2(min(half_width * .75, 2.55), mix(3.25, 4.85, pattern.z));
	float corner_shape = length(max(vec2(0.0), from_corner) / corner_scale);
	vec2 second_sign = vec2(-pattern.x, pattern.y * (pattern.w < .48 ? 1.0 : -1.0));
	float second_shape = length(max(vec2(0.0), footprint - deck.xz * second_sign) / (corner_scale * .69));
	float texture_break = (wash - .5) * .49 + (tooth - .5) * .32 + (paper_tooth - .5) * .13;
	corner_shape += texture_break;
	second_shape -= texture_break;
	float corner_wash = max(1.0 - smoothstep(.29, 1.16, corner_shape), .73 * (1.0 - smoothstep(.23, 1.05, second_shape)));
	float corner_core = max(1.0 - smoothstep(.31, .86, corner_shape), .72 * (1.0 - smoothstep(.16, .74, second_shape)));
	float wall_fade = top ? 1.0 : 1.0 - smoothstep(.09, 1.95, below_lip);
	color = mix(color, WASH, corner_wash * wall_fade * .75);

	if (top) {
		// Each long edge gets its own brush direction, ink load and interruptions.
		float mark_seed = deck.x * pattern.x > 0.0 ? pattern.z : pattern.w;
		float mark_z = mix(-7.7, 7.7, mark_seed);
		vec2 patch = vec2(inset.x - min(half_width * .31, 1.0), deck.z - mark_z);
		float streak = smoothstep(.21, .58, mark_seed);
		patch.x += patch.y * mix(-.081, .071, pattern.w);
		vec2 mark_scale = mix(vec2(1.25, 1.47), vec2(2.1, .26), streak);
		float shape = platform_noise(patch * mark_scale + pattern.zw * 24.0 + mark_seed * 11.0);
		float envelope = 1.0 - smoothstep(.31, 1.0, length(patch / vec2(2.5, mix(5.8, 11.0, streak))));
		float wet_marks = smoothstep(.31, .76, shape) * envelope * side;
		float marks = smoothstep(.47, .78, shape + (paper_tooth - .5) * .13) * envelope * side;
		color = mix(color, WASH, wet_marks * .42);
		color = mix(color, mix(WASH, INK, .46 + streak * .40), marks * .88);
	}

	// Imperfect but recognisably straight brush lines, plus a softer wet fringe.
	float halo = 1.0 - smoothstep(.03, mix(.25, .68, pressure), edge);
	color = mix(color, WASH, halo * (.15 + pressure * .30));
	float wander = (pressure - .5) * .27 + (tooth - .5) * .103;
	float stroke_distance = abs(edge - (.13 + wander));
	float stroke_width = mix(.066, .24, pressure);
	float stroke = 1.0 - smoothstep(stroke_width * .23, stroke_width + .025, stroke_distance);
	float loaded = mix(.37, .94, smoothstep(.21, .81, pressure));
	float paper_gap = smoothstep(.55, .82, tooth * .82 + paper_tooth * .18) * (1.0 - corner_core);
	color = mix(color, mix(INK, CHAR, pressure * .50), stroke * loaded * (1.0 - paper_gap * .79));
	if (top) {
		float inner_offset = min(.63, half_width * .24) - wander * .50;
		float inner_width = mix(.062, .174, tooth);
		float inner = 1.0 - smoothstep(inner_width * .19, inner_width + .030, abs(edge - inner_offset));
		float inner_load = mix(.25, .81, smoothstep(.22, .77, wash + pressure * .22));
		color = mix(color, INK, inner * inner_load * (1.0 - paper_gap * .59));
	}
	return mix(color, CHAR, corner_core * wall_fade * (.90 + pressure * .10));
}
