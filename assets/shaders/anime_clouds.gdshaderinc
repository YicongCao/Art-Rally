// Painted banks live in sky direction, not on the camera or a full-screen overlay.
// Ten texture samples replace 126 procedural lobe evaluations per half-res pixel.
uniform sampler2D cloud_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 cloud_light : source_color = vec4(1.0,.86,.58,1.0);
uniform vec4 cloud_shadow : source_color = vec4(.56,.43,.67,1.0);
uniform vec4 cloud_mid : source_color = vec4(.91,.62,.64,1.0);
uniform float cloud_atlas_warmth = 1.0;
uniform float cloud_drift = 0.0;
float cloud_hash(float p) { return fract(sin(p*127.1+311.7)*43758.5453); }
vec4 painted_clouds(vec3 ray,vec3 sun) {
 vec2 direction=vec2(atan(ray.z,ray.x)+cloud_drift,asin(clamp(ray.y,-1.0,1.0)));
 vec4 cloud=vec4(0.0);
 for(int bank=0;bank<10;bank++) {
  float b=float(bank);
  float yaw=b*.628318+sin(b*4.0)*.15;
  float dx=atan(sin(direction.x-yaw),cos(direction.x-yaw));
  float height=.10+cloud_hash(b+9.0)*.26;
  float width=.8+cloud_hash(b+4.0)*.65;
  float thickness=width*.18;
  vec2 uv=vec2(dx/width+.5,.5-(direction.y-height)/thickness);
  if(uv.x>0.0 && uv.x<1.0 && uv.y>0.0 && uv.y<1.0) {
   int row=bank%4;
   vec2 strip=vec2(.0,.31);
   if(row==1)strip=vec2(.312,.218);
   if(row==2)strip=vec2(.535,.255);
   if(row==3)strip=vec2(.79,.21);
   vec4 paint=texture(cloud_atlas,vec2(uv.x,strip.x+uv.y*strip.y));
   float edge=smoothstep(0.0,.018,uv.x)*smoothstep(0.0,.018,1.0-uv.x)*smoothstep(0.0,.025,uv.y)*smoothstep(0.0,.025,1.0-uv.y);
   float alpha=smoothstep(.04,.86,paint.a)*edge;
   float tone=dot(paint.rgb,vec3(.2126,.7152,.0722));
   vec3 neutral=mix(cloud_shadow.rgb,cloud_light.rgb,smoothstep(.13,.80,tone));
   vec3 color=mix(neutral,paint.rgb,cloud_atlas_warmth);
   // Premultiplied accumulation avoids dark halos at transparent atlas edges.
   cloud.rgb=color*alpha+cloud.rgb*(1.0-alpha);
   cloud.a=alpha+cloud.a*(1.0-alpha);
  }
 }
 cloud.rgb/=max(cloud.a,.0001);
 cloud.a*=smoothstep(.035,.075,direction.y);
 return cloud;
}
