shader_type spatial;
render_mode cull_disabled;
varying vec3 instance_tint;
void vertex() {
	float phase = floor(float(INSTANCE_ID)/2.0)*0.83;
	instance_tint = COLOR.rgb;
	float bend = pow(clamp(VERTEX.y/4.5,0.0,1.0),1.8);
	VERTEX.x += sin(TIME*2.5+VERTEX.y*0.9+phase)*bend*0.38;
	VERTEX.z += cos(TIME*1.9+VERTEX.y*1.3+phase)*bend*0.22;
}
void fragment() {
	float band = step(0.70,fract(UV.y*4.0));
	ALBEDO = mix(instance_tint,vec3(0.88,0.87,0.78),band);
	ROUGHNESS = 0.75;
}
