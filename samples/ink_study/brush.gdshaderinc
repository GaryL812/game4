// Smooth value noise shared by the wet wash, dry brush, and paper.
float ink_hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * .1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float ink_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(ink_hash(cell), ink_hash(cell + vec2(1.0, 0.0)), f.x),
		mix(ink_hash(cell + vec2(0.0, 1.0)), ink_hash(cell + 1.0), f.x), f.y
	);
}
