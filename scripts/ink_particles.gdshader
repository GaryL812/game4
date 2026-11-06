shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D paper_grain : repeat_enable, filter_linear;
uniform bool mist=false;
varying vec4 ink_state;
void vertex(){
	ink_state=INSTANCE_CUSTOM;
	vec3 sx=INV_VIEW_MATRIX[0].xyz*length(MODEL_MATRIX[0].xyz);
	vec3 sy=INV_VIEW_MATRIX[1].xyz*length(MODEL_MATRIX[1].xyz);
	vec3 sz=INV_VIEW_MATRIX[2].xyz*length(MODEL_MATRIX[2].xyz);
	VERTEX=vec3(VERTEX.x,VERTEX.z,0.);
	MODELVIEW_MATRIX=VIEW_MATRIX*mat4(vec4(sx,0.),vec4(sy,0.),vec4(sz,0.),MODEL_MATRIX[3]);
}
void fragment(){
	float grain=texture(paper_grain,UV*1.8+ink_state.z).r;
	vec2 q=UV-.5;
	float shape=1.-smoothstep(.23,.48,length(q)+grain*.10);
	if(mist){
		ALBEDO=vec3(.88,.86,.77);
		ALPHA=shape*(.25+grain*.15);
	}else{
		float fade=clamp(ink_state.y,0.,1.);
		ALBEDO=ink_state.x>1.5?vec3(.38,.43,.35):vec3(.075,.115,.095);
		ALPHA=shape*smoothstep(0.,.4,fade)*(ink_state.x>1.5?.27:.82);
	}
}
