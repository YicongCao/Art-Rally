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
	vec3 shade = mix(vec3(0.56, 0.47, 0.61), vec3(1.0, 0.82, 0.63), light);
	ALBEDO = mix(shade, vec3(0.80, 0.65, 0.71), distant_layer * 0.38);
}
