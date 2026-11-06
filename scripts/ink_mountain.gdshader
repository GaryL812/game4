shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D paper_grain : repeat_enable, filter_linear;
varying vec2 wash_uv;
void vertex(){wash_uv=vec2(VERTEX.x/36.+.5,VERTEX.y/21.);}
void fragment(){
	float n=texture(paper_grain,wash_uv*vec2(3.,2.)).r;
	float wet=texture(paper_grain,wash_uv*vec2(.7,1.3)).r;
	float fade=smoothstep(.03,.55,wash_uv.y);
	ALBEDO=mix(vec3(.31,.38,.32),vec3(.52,.57,.46),n);
	ALPHA=fade*(.20+wet*.50)*( .65+n*.35);
}
