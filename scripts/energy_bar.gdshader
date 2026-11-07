shader_type canvas_item;

uniform float density = 1.0;
uniform float opacity = .72;
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	// Discard the white background while retaining the brush's soft edge and dry fibres.
	vec2 sample_uv = vec2(mix(.33,.71,UV.x),mix(.065,.985,UV.y));
	vec4 brush = texture(TEXTURE,sample_uv);
	float ink = 1.0-dot(brush.rgb,vec3(.299,.587,.114));
	float alpha = smoothstep(.025,.92,ink*density)*brush.a*opacity;
	COLOR = vec4(.14,.155,.125,alpha)*vertex_tint;
}
