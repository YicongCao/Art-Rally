shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

#include "res://assets/shaders/autumn_sky_palette.gdshaderinc"
uniform vec3 sun_direction = vec3(-0.6, 0.4, -0.6);
uniform float distant_layer : hint_range(0.0, 1.0) = 0.0;
uniform vec4 cloud_shadow : source_color = vec4(0.64, 0.49, 0.65, 1.0);
uniform vec4 cloud_light : source_color = vec4(1.0, 0.87, 0.68, 1.0);
varying vec3 world_normal;
varying vec3 world_position;

void vertex() {
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 direction = normalize(world_position - CAMERA_POSITION_WORLD);
	float n=dot(normalize(world_normal),sun_direction);
	float light=.16+.40*smoothstep(-.28,-.12,n)+.44*smoothstep(.40,.59,n);
	vec3 shade = mix(cloud_shadow.rgb, cloud_light.rgb, light);
	float distance_haze = smoothstep(800.0, 3600.0, distance(world_position, CAMERA_POSITION_WORLD));
	ALBEDO = mix(shade, autumn_sky(direction, sun_direction), 0.12 + distance_haze * 0.40 + distant_layer * 0.10);
}
