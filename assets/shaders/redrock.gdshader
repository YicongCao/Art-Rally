shader_type spatial;
render_mode diffuse_burley;
varying vec3 world;
void vertex(){ world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
 float band=sin(world.y*.63+sin(world.x*.13)*.8+sin(world.z*.09)*.6);
 vec3 base=mix(vec3(.36,.10,.045),vec3(.57,.22,.095),smoothstep(-.4,.4,band));
 float line=1.0-smoothstep(.04,.12,abs(sin(world.y*1.8+world.x*.025)));
 ALBEDO=base*(1.0-line*.13);
 ROUGHNESS=.96;
}
