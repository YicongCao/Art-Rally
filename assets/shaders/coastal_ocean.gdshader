shader_type spatial;
render_mode cull_disabled;
varying vec3 world;
uniform vec3 shallow : source_color = vec3(0.15,0.64,0.66);
uniform vec3 deep : source_color = vec3(0.06,0.31,0.46);
uniform vec3 sun_direction = vec3(-0.4,0.78,-0.48);
uniform float sparkle_strength = 1.9;
float hash21(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float twinkles(vec2 p,float phase){
 vec2 cell=floor(p);
 vec2 offset=fract(p)-.5;
 float seed=hash21(cell);
 float distance_to_center=length(offset);
 float aa=fwidth(distance_to_center);
 float spot=1.0-smoothstep(.035,.13+aa,distance_to_center);
 float pulse=smoothstep(.52,.94,.5+.5*sin(TIME*(.65+seed*.9)+seed*37.0+phase));
 float footprint=max(length(dFdx(p)),length(dFdy(p)));
 float resolved=1.0-smoothstep(.25,1.1,footprint);
 return spot*step(.68,seed)*pulse*resolved;
}
void vertex(){ world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
 float wave=sin(world.x*0.11+TIME*.65)*sin(world.z*.16-TIME*.35);
 vec3 to_camera=normalize(CAMERA_POSITION_WORLD-world);
 float sun_band=pow(max(0.0,dot(normalize(to_camera.xz),-normalize(sun_direction.xz))),5.0);
 vec2 drift=vec2(sin(TIME*.15),cos(TIME*.12))*.08;
 vec2 fine=world.xz*.55;
 float fine_footprint=max(length(dFdx(fine)),length(dFdy(fine)));
 float distant_scale=smoothstep(.03,.18,fine_footprint);
 float sparkle=(twinkles(fine+drift,0.0)+twinkles(world.xz*.075+drift,1.7)*.85*distant_scale)*(.5+sun_band*.5);
 float fresnel=pow(1.0-max(to_camera.y,0.0),3.0);
 ALBEDO=mix(deep,shallow,0.44+smoothstep(-.35,.45,wave)*.14)+vec3(.08,.11,.12)*fresnel;
 EMISSION=vec3(1.0,.93,.72)*sparkle*sparkle_strength;
 ROUGHNESS=.22+wave*.035; METALLIC=.10; SPECULAR=.65;
 NORMAL_MAP=vec3(.5+cos(world.x*.11+TIME*.65)*.055,.5+cos(world.z*.16-TIME*.35)*.055,1.0);
}
