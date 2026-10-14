shader_type sky;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
float fbm(vec2 p) {
	return noise(p)*0.55 + noise(p*2.03)*0.27 + noise(p*4.09)*0.13 + noise(p*8.17)*0.05;
}
void sky() {
	float h = max(EYEDIR.y, 0.0);
	vec3 blue = mix(vec3(0.68,0.77,0.79),vec3(0.18,0.40,0.59),pow(h,0.5));
	vec2 p = EYEDIR.xz / max(EYEDIR.y + 0.19, 0.08) * 1.5;
	float cloud = smoothstep(0.48,0.66,fbm(p)) * smoothstep(0.015,0.13,h);
	vec3 cloud_color = mix(vec3(0.64,0.70,0.71),vec3(0.97,0.93,0.83),fbm(p+vec2(0.3)));
	COLOR = mix(blue,cloud_color,cloud * 0.92);
	float sun_dot = dot(EYEDIR,normalize(vec3(-0.65,0.30,-0.5)));
	COLOR += vec3(1.0,0.73,0.40)*pow(max(sun_dot,0.0),160.0)*0.18;
	COLOR = mix(vec3(0.49,0.57,0.58),COLOR,smoothstep(-0.1,0.01,EYEDIR.y));
}
