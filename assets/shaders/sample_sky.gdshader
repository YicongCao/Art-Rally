shader_type sky;
render_mode use_half_res_pass;

#include "res://assets/shaders/autumn_sky_palette.gdshaderinc"
#include "res://assets/shaders/anime_clouds.gdshaderinc"
uniform bool painted_banks = false;
uniform vec3 sun_direction = vec3(-0.6, 0.4, -0.6);

void sky() {
	if (AT_HALF_RES_PASS) {
		vec4 cloud=vec4(0.0);
		if(painted_banks) cloud=painted_clouds(EYEDIR,sun_direction);
		COLOR=cloud.rgb;
		ALPHA=cloud.a;
	} else {
		float alignment = max(dot(EYEDIR, normalize(sun_direction)), 0.0);
		COLOR = autumn_sky(EYEDIR, sun_direction);
		float disc = smoothstep(cos(0.009), cos(0.0065), alignment);
		COLOR += vec3(2.5, 1.8, 0.8) * disc;
		// Reflection radiance uses the stable broad sky illumination. Cloud edges
		// are a background painting, not ninety lobe evaluations per cube texel.
		if (painted_banks && !AT_CUBEMAP_PASS) COLOR = mix(COLOR,HALF_RES_COLOR.rgb,HALF_RES_COLOR.a);
		COLOR = mix(vec3(0.24, 0.18, 0.29), COLOR, smoothstep(-0.12, 0.01, EYEDIR.y));
	}
}
