shader_type spatial;
uniform vec4 light_color : source_color = vec4(.38,.91,1.0,1.0);
varying float strength;
void vertex() { strength = INSTANCE_CUSTOM.x; }
void fragment() {
	ALBEDO = mix(vec3(.022,.032,.041),light_color.rgb*.5,UV2.x);
	ROUGHNESS = .7;
	SPECULAR = .25;
	EMISSION = light_color.rgb*UV2.x*strength*2.2;
}
