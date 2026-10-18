shader_type sky;

uniform vec3 sun_direction = vec3(-0.6, 0.4, -0.6);

void sky() {
	float h = max(EYEDIR.y, 0.0);
	float alignment = max(dot(EYEDIR, normalize(sun_direction)), 0.0);
	vec3 horizon = mix(vec3(0.58, 0.30, 0.43), vec3(0.86, 0.46, 0.25), pow(alignment, 3.0));
	vec3 upper = vec3(0.36, 0.43, 0.64);
	COLOR = mix(horizon, upper, smoothstep(0.0, 0.85, h));
	COLOR += vec3(0.22, 0.17, 0.075) * pow(alignment, 16.0);
	float disc = smoothstep(cos(0.009), cos(0.0065), alignment);
	COLOR += vec3(3.3, 2.5, 1.6) * disc;
	COLOR = mix(vec3(0.42, 0.38, 0.48), COLOR, smoothstep(-0.12, 0.01, EYEDIR.y));
}
