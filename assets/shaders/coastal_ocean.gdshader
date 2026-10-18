shader_type spatial;
render_mode cull_disabled;
varying vec3 world;
uniform vec3 shallow : source_color = vec3(0.15,0.64,0.66);
uniform vec3 deep : source_color = vec3(0.06,0.31,0.46);
void vertex(){ world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
 float wave=sin(world.x*0.11+TIME*.65)*sin(world.z*.16-TIME*.35);
 float glint=pow(max(0.0,sin(world.x*.48+world.z*.37+TIME)),24.0)*.09;
 ALBEDO=mix(deep,shallow,0.45+wave*.14)+glint;
 ROUGHNESS=.36; METALLIC=.18;
 NORMAL_MAP=vec3(.5+cos(world.x*.11+TIME*.65)*.035,.5+cos(world.z*.16-TIME*.35)*.035,1.0);
}
