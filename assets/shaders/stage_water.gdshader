shader_type spatial;
uniform float cinematic_time = -1.0;
float scene_time() { return cinematic_time >= 0.0 ? cinematic_time : TIME; }
render_mode cull_disabled, depth_draw_opaque;
varying vec3 world;
uniform bool river = false;
void vertex() { world = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
	float ripple = sin(world.x*5.0+scene_time()*1.9)*sin(world.z*3.0-scene_time()*1.1);
	float rough_edge = sin(UV.y*1.8+UV.x*3.7)*.11+sin(UV.y*4.3)*.07;
	float edge = 1.0-smoothstep(2.05+rough_edge,2.65,abs(UV.x));
	float along = smoothstep(UV2.x,UV2.x+1.6,UV.y)*(1.0-smoothstep(UV2.y-1.6,UV2.y,UV.y));
	float foam = river ? pow(max(0.0,sin(world.x*.9+world.z*.3-scene_time()*2.3)),18.0)*.10 : 0.0;
	ALBEDO = mix(vec3(.09,.13,.10),vec3(.16,.35,.35),river ? .8 : edge)+vec3(foam);
	ROUGHNESS = .28+ripple*.035;
	SPECULAR = .4;
	NORMAL_MAP = vec3(.5+sin(world.x*3.0+scene_time()*2.0)*.035,.5+cos(world.z*5.0-scene_time()*1.8)*.025,1.0);
	ALPHA = river ? 1.0-smoothstep(108.0,120.0,abs(UV.x)) : edge*along*.82;
}
