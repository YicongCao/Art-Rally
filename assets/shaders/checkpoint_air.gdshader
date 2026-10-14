shader_type spatial;
render_mode cull_disabled;
uniform float phase = 0.0;
uniform vec4 tint : source_color = vec4(0.93,0.63,0.25,1.0);
void vertex() {
	float bend = pow(clamp(VERTEX.y/4.5,0.0,1.0),1.8);
	VERTEX.x += sin(TIME*2.5+VERTEX.y*0.9+phase)*bend*0.38;
	VERTEX.z += cos(TIME*1.9+VERTEX.y*1.3+phase)*bend*0.22;
}
void fragment() {
	float band = step(0.70,fract(UV.y*4.0));
	ALBEDO = mix(tint.rgb,vec3(0.88,0.87,0.78),band);
	ROUGHNESS = 0.75;
}
