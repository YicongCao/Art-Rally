shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;

uniform bool grass_blades = false;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float weight = grass_blades ? clamp(VERTEX.y / 0.65, 0.0, 1.0) : smoothstep(2.0, 8.0, VERTEX.y);
	float breeze = sin(world.x * 0.42 + world.z * 0.25 + TIME * 1.3);
	VERTEX.x += breeze * weight * (grass_blades ? 0.045 : 0.065);
	// Upward-biased blade normals keep a continuous golden carpet between tufts.
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
 float tone=.38+.32*smoothstep(-.12,.12,n)+.30*smoothstep(.52,.72,n);
 DIFFUSE_LIGHT+=ALBEDO*mix(vec3(.65,.62,.76),vec3(1.0),tone)*LIGHT_COLOR*ATTENUATION/PI;
}
