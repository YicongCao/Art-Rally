uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float rock_scale = .08;
uniform float rock_strength = .68;

vec3 painted_rock(vec3 position, vec3 normal, vec3 tint) {
 vec3 weights=pow(abs(normal),vec3(4.0));
 weights/=max(weights.x+weights.y+weights.z,.001);
 vec3 paint=texture(rock_albedo,position.zy*rock_scale).rgb*weights.x;
 paint+=texture(rock_albedo,position.xz*rock_scale).rgb*weights.y;
 paint+=texture(rock_albedo,position.xy*rock_scale).rgb*weights.z;
 // Keep biome tint/light hierarchy; pigment detail belongs to the surface.
 float value=dot(paint,vec3(.2126,.7152,.0722));
 vec3 pigment=tint*clamp(value/ .23,.48,1.55);
 pigment=mix(pigment,pigment*(paint/max(value,.035)),.16);
 return mix(tint,pigment,rock_strength);
}
