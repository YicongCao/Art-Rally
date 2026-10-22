shader_type spatial;
// High-fidelity vehicle paint for cars whose surfacing reads poorly as flat
// screenprint bands (the new P7). Smooth wrapped diffuse, a tight clear-coat
// highlight and engine sky reflections; the terminator uses the Brushline
// plum shadow ink so the car still sits inside the game's palette.
render_mode cull_back;
uniform vec4 paint : source_color = vec4(.73,.76,.77,1.0);
uniform vec3 shadow_ink : source_color = vec3(.29,.25,.34);
uniform float roughness_amount = .32;
uniform float gloss = .6;
uniform float glass = 0.0;
uniform float emissive = 0.0;
uniform vec3 sky_top : source_color = vec3(.62,.74,.88);
uniform vec3 sky_horizon : source_color = vec3(.95,.86,.74);
varying vec3 world_normal;
varying vec3 world_view;
void vertex(){
 world_normal=normalize((MODEL_MATRIX*vec4(NORMAL,0.0)).xyz);
 world_view=normalize((INV_VIEW_MATRIX*vec4(0,0,0,1)).xyz-(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz);
}
void fragment(){
 vec3 n=normalize(world_normal);
 vec3 v=normalize(world_view);
 float fresnel=pow(1.0-clamp(dot(n,v),0.0,1.0),4.0);
 vec3 r=reflect(-v,n);
 vec3 sky=mix(sky_horizon,sky_top,smoothstep(-.05,.6,r.y));
 // Warm ground bounce below the horizon keeps the lower body from going black.
 sky=mix(vec3(.50,.42,.34),sky,smoothstep(-.25,.02,r.y));
 if(glass>.5){
  ALBEDO=paint.rgb*.55;
  EMISSION=sky*(.08+.5*fresnel);
  ROUGHNESS=.05;
  SPECULAR=.75;
 } else {
  ALBEDO=paint.rgb;
  ROUGHNESS=roughness_amount;
  SPECULAR=.5*gloss+.15;
  // Painted horizon reflection band, strongest at grazing angles.
  EMISSION=sky*paint.rgb*fresnel*.45*gloss;
 }
 EMISSION+=paint.rgb*emissive;
}
void light(){
 float d=dot(NORMAL,LIGHT);
 float wrap=clamp((d+.35)/1.35,0.0,1.0);
 vec3 shade=mix(shadow_ink,vec3(1.0),smoothstep(0.0,1.0,wrap)*mix(.6,1.0,ATTENUATION));
 DIFFUSE_LIGHT+=ALBEDO*shade*LIGHT_COLOR/PI;
 vec3 h=normalize(LIGHT+VIEW);
 float spec=pow(max(dot(NORMAL,h),0.0),mix(24.0,220.0,1.0-roughness_amount));
 SPECULAR_LIGHT+=LIGHT_COLOR*spec*ATTENUATION*(glass>.5 ? 1.2 : .25+gloss*.75);
}
