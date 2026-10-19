// Original direction-space cloud painting. Broad lobes are smoothly joined;
// the lighting field is sampled independently so overlapping puffs have no seams.
uniform vec4 cloud_light : source_color = vec4(1.0, .86, .58, 1.0);
uniform vec4 cloud_shadow : source_color = vec4(.56, .43, .67, 1.0);
uniform vec4 cloud_mid : source_color = vec4(.91, .62, .64, 1.0);
uniform float cloud_drift = 0.0;
float cloud_hash(float p) { return fract(sin(p * 127.1 + 311.7) * 43758.5453); }
float cloud_field(vec2 uv) {
 float field=-10.0;
 for(int bank=0;bank<7;bank++) {
  float b=float(bank);
  float angle=b*.897598+sin(b*4.0)*.12;
  float dx=atan(sin(uv.x-angle),cos(uv.x-angle));
  float base=.09+cloud_hash(b+9.0)*.13;
  vec2 q=vec2(dx,uv.y-base);
  float scale=.55+cloud_hash(b+4.0)*.65;
  float bank_field=-10.0;
  for(int lobe=0;lobe<7;lobe++) {
   float id=b*19.0+float(lobe);
   float x=(float(lobe)-3.0)*.09*scale;
   float radius=(.036+cloud_hash(id+3.0)*.047)*scale;
   vec2 center=vec2(x,.015+cloud_hash(id+32.0)*.065*scale);
   vec2 d=(q-center)/vec2(radius*1.7,radius);
   float theta=atan(d.y,d.x);
   float edge=1.0-length(d)+.065*sin(theta*7.0+id)+.025*sin(theta*13.0-id);
   // Smooth max joins lobe boundaries rather than shading each sphere separately.
   float h=clamp(.5+.5*(edge-bank_field)/.35,0.0,1.0);
   bank_field=mix(bank_field,edge,h)+.35*h*(1.0-h);
  }
  bank_field=min(bank_field,(q.y+.045)*14.0);
  field=max(field,bank_field);
 }
 return field;
}
vec4 painted_clouds(vec3 ray,vec3 sun) {
 vec2 uv=vec2(atan(ray.z,ray.x)+cloud_drift,asin(clamp(ray.y,-1.0,1.0)));
 float density=cloud_field(uv);
 float cover=smoothstep(-.022,.022,density)*smoothstep(.04,.09,uv.y);
 // Light arrives from upper left; exposed scallops are warm, deep masses violet.
 float solar_az=atan(sun.z,sun.x);
 float upper=cloud_field(uv+vec2(sin(solar_az-uv.x)*.025,.025));
 float exposed=1.0-smoothstep(-.05,.60,upper);
 float body=.5+.5*sin(uv.x*23.0+sin(uv.y*38.0))*sin(uv.y*19.0+uv.x*4.0);
 vec3 paint=mix(cloud_shadow.rgb,cloud_mid.rgb,smoothstep(.30,.75,body)*.60);
 paint=mix(paint,cloud_light.rgb,smoothstep(.28,.82,exposed));
 return vec4(paint,cover);
}
