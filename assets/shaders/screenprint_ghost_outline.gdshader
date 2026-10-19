shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled;
uniform vec4 ink : source_color = vec4(.075,.085,.10,1.0);
uniform float width_px=2.0;
uniform float opacity=1.0;
void vertex(){
 vec4 clip=PROJECTION_MATRIX*MODELVIEW_MATRIX*vec4(VERTEX,1.0);
 vec3 normal_view=normalize(MODELVIEW_NORMAL_MATRIX*NORMAL);
 vec2 direction=normal_view.xy;
 float distance_to_camera=length((MODELVIEW_MATRIX*vec4(VERTEX,1.0)).xyz);
 float fade=1.0-smoothstep(32.0,100.0,distance_to_camera);
 if(length(direction)>.001)clip.xy+=normalize(direction)*2.0*width_px/VIEWPORT_SIZE*clip.w*fade;
 POSITION=clip;
}
void fragment(){ALBEDO=ink.rgb;ALPHA=opacity;}
