shader_type spatial;
uniform float cinematic_time = -1.0;
float scene_time() { return cinematic_time >= 0.0 ? cinematic_time : TIME; }
render_mode cull_disabled;
void vertex() {
	float bend = smoothstep(0.0,5.5,VERTEX.y);
	VERTEX.z += sin(scene_time()*1.5+VERTEX.x*.5)*bend*.035;
}
void fragment() {
	float check = mod(floor(UV.x)+floor(UV.y*8.0),2.0);
	vec3 ivory = vec3(.88,.85,.73);
	vec3 charcoal = vec3(.055,.085,.085);
	float seam = smoothstep(.0,.025,fract(UV.x))*smoothstep(.0,.025,fract(UV.y*8.0));
	ALBEDO = mix(charcoal,ivory,check)*mix(.86,1.0,seam);
	ROUGHNESS = .82;
	SPECULAR = .28;
}
