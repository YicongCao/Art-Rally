shader_type canvas_item;
uniform vec2 extent = vec2(1100.0,24.0);
uniform float completion : hint_range(0.0,1.0) = 0.0;
uniform vec4 charcoal : source_color = vec4(.15,.21,.21,1.0);
uniform vec4 linen : source_color = vec4(.91,.88,.80,1.0);
void fragment() {
	vec2 at=UV*extent;
	float cell=max(8.0,extent.y*.5);
	float checker=mod(floor(at.x/cell)+floor(at.y/cell),2.0);
	float end=completion*extent.x;
	float fade=1.0-smoothstep(max(0.0,end-26.0),end,at.x);
	if(completion>=.999) fade=1.0;
	if(completion<=.0001) fade=0.0;
	COLOR=vec4(mix(charcoal.rgb,linen.rgb,checker),fade);
}
