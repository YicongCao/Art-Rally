shader_type sky;

uniform vec3 sun_direction = vec3(-0.6, 0.4, -0.6);

void sky() {
	float h = max(EYEDIR.y, 0.0);
	vec3 blue = mix(vec3(0.66,0.75,0.80),vec3(0.12,0.32,0.53),pow(h,0.48));
	float alignment = max(dot(EYEDIR, normalize(sun_direction)), 0.0);
	COLOR = blue + vec3(0.25,0.13,0.045) * pow(alignment, 32.0);
	float disc = smoothstep(cos(0.0085), cos(0.0065), alignment);
	COLOR += vec3(4.0, 2.7, 1.4) * disc;
	COLOR = mix(vec3(0.49,0.57,0.58),COLOR,smoothstep(-0.1,0.01,EYEDIR.y));
}
