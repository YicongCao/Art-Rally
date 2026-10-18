shader_type sky;

#include "res://assets/shaders/autumn_sky_palette.gdshaderinc"
uniform vec3 sun_direction = vec3(-0.6, 0.4, -0.6);

void sky() {
	float alignment = max(dot(EYEDIR, normalize(sun_direction)), 0.0);
	COLOR = autumn_sky(EYEDIR, sun_direction);
	float disc = smoothstep(cos(0.009), cos(0.0065), alignment);
	COLOR += vec3(2.5, 1.8, 0.8) * disc;
	COLOR = mix(vec3(0.24, 0.18, 0.29), COLOR, smoothstep(-0.12, 0.01, EYEDIR.y));
}
