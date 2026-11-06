shader_type spatial;
render_mode unshaded, cull_disabled, specular_disabled;
#include "res://scripts/ink_platform.gdshaderinc"
uniform sampler2D paper_grain : repeat_enable, filter_linear;
uniform sampler2D platform_stone : source_color, repeat_enable, filter_linear_mipmap;
uniform int surface_mode=0; // stone, timber, roof tile, prop, mountains, jump pad
uniform bool stretch_platform=false;
uniform float platform_span=8.2;
varying vec3 ink_world_position;
varying vec3 ink_world_normal;
varying vec3 deck_position;
varying flat float deck_half_width;
varying flat vec4 deck_layout;
void vertex(){
	if(stretch_platform){
		if(VERTEX.y<6.9) VERTEX.y*=max(0.1,platform_span-1.3)/6.9;
		else VERTEX.y+=platform_span-8.2;
		float scale_x = length(MODEL_MATRIX[0].xyz);
		deck_position = vec3(VERTEX.x * scale_x, VERTEX.y - platform_span, VERTEX.z);
		deck_half_width = 7.0 * scale_x;
		vec2 seed = MODEL_MATRIX[3].xz + vec2(17.0, 31.0);
		vec2 corner = vec2(platform_hash(seed), platform_hash(seed + 8.7));
		deck_layout = vec4(step(vec2(.5), corner) * 2.0 - 1.0, platform_hash(seed + 24.4), platform_hash(seed + 6.1));
	}
	ink_world_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
	ink_world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
	vec3 n=normalize(ink_world_normal);
	vec3 p=ink_world_position;
	vec2 plane=abs(n.y)>.6?p.xz:vec2(p.x+p.z,p.y);
	float fine=texture(paper_grain,plane*1.6).r;
	if (stretch_platform && deck_position.y < .22 && abs(deck_position.x) < deck_half_width + .19) {
		vec3 texture_paper = vec3(0.0);
		if (n.y > .54) {
			texture_paper = texture(platform_stone, p.xz * .081 + deck_layout.zw).rgb;
		}
		// Rails and eave tips above the deck keep their existing prop pigment.
		vec3 paint = painted_platform(p, n, deck_position, deck_half_width, deck_layout, surface_mode == 1, texture_paper, fine);
		ALBEDO = clamp(paint + (fine - .5) * .028, vec3(.025), vec3(.97));
	} else {
		float grain=texture(paper_grain,plane*.19).r;
		vec3 pigment=COLOR.rgb;
		if(dot(pigment,vec3(.3,.5,.2))>.14) pigment=pow(pigment,vec3(.65));
		vec3 c=mix(pigment,vec3(.91,.88,.77),.09);
		float lighting=mix(.82,1.,smoothstep(-.5,.75,dot(n,normalize(vec3(-.4,.85,-.25)))));
		c*=lighting;
		float seam=0.;
		if(surface_mode==0){
			vec2 tiles=plane*vec2(.47,.55);
			tiles.x+=mod(floor(tiles.y),2.)*.5;
			vec2 cell=fract(tiles);
			seam=1.-smoothstep(.014,.045,min(cell.x,cell.y));
			c=mix(c,vec3(.18,.22,.18),seam*(.15+grain*.12));
		}else if(surface_mode==1){
			float plank=fract(plane.y*1.2);
			seam=1.-smoothstep(.01,.04,plank);
			float wood=sin(plane.y*18.+grain*4.)*.02;
			c+=vec3(wood);
			c=mix(c,vec3(.14,.18,.14),seam*.55);
		}else if(surface_mode==2){
			float tile=1.-smoothstep(.03,.10,fract(plane.x*1.8));
			c=mix(c,vec3(.09,.14,.13),tile*.20);
		}else if(surface_mode==4){
			c=mix(c,vec3(.82,.83,.74),.35);
			c*=.86+grain*.27;
		}
		if(surface_mode==3)c=mix(c,vec3(dot(c,vec3(.30,.50,.20))),.26);
		float edge=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),4.);
		c=mix(c,vec3(.06,.105,.085),edge*(.36+grain*.20));
		c+=vec3((fine-.5)*.048+(grain-.5)*.06);
		ALBEDO=clamp(c,vec3(.025),vec3(.97));
	}
}
