shader_type canvas_item;
uniform sampler2D paper_grain : repeat_enable, filter_linear;
void fragment(){
	vec2 uv=SCREEN_UV/SCREEN_PIXEL_SIZE/128.;
	float n=texture(paper_grain,uv).r;
	float fiber=texture(paper_grain,uv*vec2(.25,2.)).r;
	float edge=smoothstep(.24,.75,length(SCREEN_UV-.5));
	COLOR=vec4(vec3(.27,.29,.22),.012+(1.-n)*.025+fiber*.01+edge*.025);
}
