shader_type spatial;
render_mode unshaded,cull_disabled,fog_disabled;
uniform vec3 sun_direction = vec3(-.6,.3,-.6);
uniform vec4 shade_color : source_color = vec4(.40,.42,.63,1.0);
uniform vec4 lit_color : source_color = vec4(.85,.73,.60,1.0);
uniform float layer = 0.0;
varying vec3 world_normal;
varying vec3 world;
void vertex(){world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float light=dot(normalize(world_normal),normalize(sun_direction));
 float planes=.08+.40*smoothstep(-.10,.20,light)+.52*smoothstep(.55,.78,light);
 vec3 paint=mix(shade_color.rgb,lit_color.rgb,planes);
 // Wide mineral bands stay attached to the mountain, never screen-space noise.
 float stratum=sin(world.y*.045+sin(world.x*.008+world.z*.011)*2.0);
 paint*=.94+.06*smoothstep(-.2,.4,stratum);
 paint=mix(paint,vec3(.17,.23,.40),layer*.18);
 ALBEDO=mix(paint,vec3(.20,.23,.40),clamp(length(VERTEX)/9500.0,.04,.36));
}
