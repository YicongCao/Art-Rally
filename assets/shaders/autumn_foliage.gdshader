shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;

uniform bool grass_blades = false;
varying float canopy;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	canopy = smoothstep(2.0,5.5,VERTEX.y);
	float weight = grass_blades ? clamp(VERTEX.y / 0.65, 0.0, 1.0) : smoothstep(2.0, 8.0, VERTEX.y);
	float breeze = sin(world.x * 0.42 + world.z * 0.25 + TIME * 1.3);
	VERTEX.x += breeze * weight * (grass_blades ? 0.045 : 0.065);
	// Upward-biased blade normals keep a continuous golden carpet between tufts.
	if (!grass_blades) NORMAL = normalize(mix(NORMAL,normalize(vec3(VERTEX.x,1.7,VERTEX.z)),.32*canopy));
	if (grass_blades) NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.82));
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	// A small leaf fill retains autumn color inside layered crowns.
	EMISSION = COLOR.rgb * (grass_blades ? 0.04 : 0.08);
}

void light() {
 float n=dot(NORMAL,LIGHT);
 float tone=.22+.40*smoothstep(-.15,.10,n)+.38*smoothstep(.48,.72,n);
 vec3 shadow=vec3(.35,.48,.68);
 DIFFUSE_LIGHT+=ALBEDO*mix(shadow,vec3(1.0),tone)*LIGHT_COLOR*ATTENUATION/PI;
 if (!grass_blades) {
  // Broad waxy leaf sheen and warm transmitted light, not PBR wet/plastic shine.
  float sheen=smoothstep(.68,.90,dot(normalize(LIGHT+VIEW),NORMAL));
  float back=pow(max(dot(-LIGHT,VIEW),0.0),4.0)*(1.0-max(n,0.0));
  DIFFUSE_LIGHT+=(ALBEDO*vec3(1.2,.78,.30)*back*.32+mix(ALBEDO,vec3(1.0),.32)*sheen*.20)*LIGHT_COLOR*ATTENUATION*canopy/PI;
 }
}
