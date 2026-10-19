shader_type spatial;
render_mode cull_disabled,specular_disabled;
void fragment(){ALBEDO=COLOR.rgb;ROUGHNESS=.96;}
void light(){
 float n=dot(NORMAL,LIGHT);
 float value=.40+.28*smoothstep(-.05,.12,n)+.32*smoothstep(.52,.76,n);
 DIFFUSE_LIGHT+=ALBEDO*mix(vec3(.64,.65,.80),vec3(1.0),value)*LIGHT_COLOR*ATTENUATION/PI;
}
