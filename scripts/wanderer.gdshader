shader_type spatial;
render_mode unshaded, cull_disabled, specular_disabled;
uniform vec4 accent_color : source_color = vec4(0.67,0.18,0.18,1.0);
uniform vec4 body_tint : source_color = vec4(.4,.44,.38,1.);
uniform bool reference_palette=true;
uniform sampler2D paper_grain : repeat_enable, filter_linear;
varying vec3 brush_position;
void vertex(){ brush_position=VERTEX; }
void fragment() {
	vec3 base=COLOR.rgb;
	float ribbon=step(base.g*3.0+0.005,base.r)*step(base.b*3.0+0.005,base.r);
	base=reference_palette?mix(base,accent_color.rgb,ribbon):base*body_tint.rgb;
	float noise=texture(paper_grain,brush_position.xy*vec2(2.,10.)).r;
	float edge=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),3.);
	base=mix(base,vec3(.025,.055,.04),edge*.85);
	float scratch=smoothstep(.65,.86,noise)*.15;
	base=mix(base,vec3(.80,.79,.67),scratch);
	ALBEDO=base*(.83+noise*.25);
	ROUGHNESS=0.95;
}
