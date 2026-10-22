shader_type spatial;
render_mode cull_back, specular_disabled;
// Screenprint sandstone: world-anchored strata in a few flat inks, stepped
// light bands like the vehicles, warm plum shadows and sand on ledges.
uniform vec3 shadow_ink : source_color = vec3(0.47,0.25,0.31);
uniform vec3 shade_steps = vec3(.34,.66,1.0);
uniform vec3 deep_red : source_color = vec3(0.56,0.24,0.17);
uniform vec3 terracotta : source_color = vec3(0.72,0.36,0.22);
uniform vec3 orange_band : source_color = vec3(0.84,0.53,0.32);
uniform vec3 pale_band : source_color = vec3(0.91,0.75,0.56);
uniform vec3 ledge_sand : source_color = vec3(0.89,0.68,0.42);
varying vec3 world;
varying vec3 world_normal;

float rock_hash(float n) { return fract(sin(n*91.7)*43758.5453); }
float rock_noise(vec2 p) {
 vec2 i=floor(p), f=fract(p);
 f=f*f*(3.0-2.0*f);
 float a=fract(sin(dot(i,vec2(127.1,311.7)))*43758.55);
 float b=fract(sin(dot(i+vec2(1,0),vec2(127.1,311.7)))*43758.55);
 float c=fract(sin(dot(i+vec2(0,1),vec2(127.1,311.7)))*43758.55);
 float d=fract(sin(dot(i+vec2(1,1),vec2(127.1,311.7)))*43758.55);
 return mix(mix(a,b,f.x),mix(c,d,f.x),f.y);
}

void vertex() {
 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}

void fragment() {
 vec3 n=normalize(world_normal);
 float warp=sin(world.x*.019)*1.7+sin(world.z*.016+world.x*.007)*1.3;
 float y=world.y+warp;
 float index=floor(y/5.5);
 float pick=rock_hash(index);
 vec3 band=pick<.34 ? deep_red : (pick<.70 ? terracotta : (pick<.90 ? orange_band : pale_band));
 // A thin pale seam between strata keeps the layered read at distance.
 float seam=1.0-smoothstep(.0,.07,fract(y/5.5));
 band=mix(band,pale_band,seam*.55);
 // Desert varnish: vertical dark streaks only on near-vertical faces.
 float vertical=1.0-smoothstep(.35,.7,abs(n.y));
 float streak=smoothstep(.55,.85,rock_noise(vec2((world.x+world.z)*.45,world.y*.035)));
 band*=1.0-streak*vertical*.22;
 band=mix(band,ledge_sand,smoothstep(.62,.86,n.y));
 // Cheap pigment grain instead of triplanar texture fetches on screen-filling walls.
 float grain=rock_noise(world.xz*.9+world.y*.7)*.6+rock_noise(world.zy*2.3)*.4;
 ALBEDO=band*(.92+.16*grain);
 ROUGHNESS=.95;
}

void light() {
 float d=dot(NORMAL,LIGHT);
 float bands=shade_steps.x+(shade_steps.y-shade_steps.x)*smoothstep(.0,.08,d)+(shade_steps.z-shade_steps.y)*smoothstep(.45,.55,d);
 vec3 shade=mix(shadow_ink,vec3(1.0),bands*mix(.55,1.0,ATTENUATION));
 DIFFUSE_LIGHT+=ALBEDO*shade*LIGHT_COLOR/PI;
}
