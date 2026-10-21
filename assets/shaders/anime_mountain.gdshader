shader_type spatial;
render_mode unshaded,cull_disabled,fog_disabled;
#include "res://assets/shaders/painted_rock.gdshaderinc"
uniform vec3 sun_direction = vec3(-.6,.3,-.6);
uniform vec4 shade_color : source_color = vec4(.40,.42,.63,1.0);
uniform vec4 lit_color : source_color = vec4(.85,.73,.60,1.0);
uniform float layer = 0.0;
varying vec3 world_normal;
varying vec3 world;
void vertex(){world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float light=dot(normalize(world_normal),normalize(sun_direction));
 float planes=.08+.40*smoothstep(-.08,.12,light)+.52*smoothstep(.38,.60,light);
 vec3 paint=mix(shade_color.rgb,lit_color.rgb,planes);
 // Wide mineral bands stay attached to the mountain, never screen-space noise.
 float stratum=sin(world.y*.045+sin(world.x*.008+world.z*.011)*2.0);
 paint*=.90+.10*smoothstep(-.15,.2,stratum);
 float ridge=sin(world.y*.024+world.x*.012-world.z*.009);
 paint=mix(paint,lit_color.rgb,smoothstep(.85,.98,ridge)*max(light,0.0)*.22);
 // Pigment remains world-anchored and softens into the distant painted layers.
 paint=mix(paint,painted_rock(world,normalize(world_normal),paint),1.0-smoothstep(1600.0,6000.0,length(VERTEX)));
 paint=mix(paint,vec3(.17,.23,.40),layer*.18);
 ALBEDO=mix(paint,vec3(.20,.23,.40),clamp(length(VERTEX)/9500.0,.04,.36));
}
