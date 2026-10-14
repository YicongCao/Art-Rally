shader_type spatial;
render_mode depth_draw_opaque;
varying vec3 world;
void vertex() { world = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float ripple = sin(world.x*6.0+TIME*1.3)*sin(world.z*5.0-TIME*0.9);
	float edge = 1.0-smoothstep(2.15,2.65,abs(UV.x));
	float along = max(smoothstep(1270.0,1272.0,UV.y)*(1.0-smoothstep(1288.0,1290.0,UV.y)),smoothstep(1480.0,1482.0,UV.y)*(1.0-smoothstep(1506.0,1508.0,UV.y)));
	ALBEDO = mix(vec3(0.10,0.105,0.065),vec3(0.12,0.23,0.25),edge);
	ROUGHNESS = 0.20+ripple*0.035;
	METALLIC = 0.1;
	NORMAL_MAP = vec3(0.5+sin(world.x*5.0+TIME)*0.05,0.5+cos(world.z*7.0-TIME)*0.04,1.0);
	ALPHA = edge*along*0.90;
}
