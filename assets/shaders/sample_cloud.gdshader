shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

uniform vec3 sun_direction = vec3(-0.6, 0.4, -0.6);
uniform float distant_layer : hint_range(0.0, 1.0) = 0.0;
varying vec3 face_normal;

void vertex() {
	face_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	float light = clamp(dot(normalize(face_normal), sun_direction) * 0.5 + 0.5, 0.0, 1.0);
	// Discrete values keep triangular planes readable instead of a soft noise cloud.
	light = floor(light * 4.0 + 0.5) / 4.0;
	vec3 shade = mix(vec3(0.48, 0.56, 0.66), vec3(1.0, 0.91, 0.75), light);
	ALBEDO = mix(shade, vec3(0.66, 0.76, 0.83), distant_layer * 0.28);
}
