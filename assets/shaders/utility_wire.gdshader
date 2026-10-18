shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec4 cable_color : source_color = vec4(0.22, 0.29, 0.285, 1.0);

// View-facing ribbons keep distant wires continuous at about one pixel, instead
// of turning thin polygon cylinders into a dotted line under FXAA.
void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 tangent = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec2 across = normalize(vec2(-tangent.y, tangent.x) + vec2(0.00001));
	vec4 clip = PROJECTION_MATRIX * view;
	float pixels = max(2.0, 0.065 * VIEWPORT_SIZE.y * PROJECTION_MATRIX[1][1] / max(-view.z, 1.0));
	clip.xy += across * UV.x * pixels / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}
void fragment() {
	ALBEDO = cable_color.rgb;
	ALPHA = 1.0 - smoothstep(0.25, 1.0, abs(UV.x));
}
