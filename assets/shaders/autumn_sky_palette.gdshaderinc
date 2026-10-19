// Artist-facing colors are sRGB; Godot converts source_color uniforms to linear
// before ACES. Sharing this palette also lets distant clouds merge into the sky.
uniform vec4 horizon_sun : source_color = vec4(1.0, 0.68, 0.32, 1.0);
uniform vec4 horizon_away : source_color = vec4(0.94, 0.38, 0.53, 1.0);
uniform vec4 zenith_color : source_color = vec4(0.40, 0.48, 0.72, 1.0);

vec3 autumn_sky(vec3 direction, vec3 sun) {
	float azimuth = dot(normalize(direction.xz + vec2(0.00001)), normalize(sun.xz));
	float warm_side = pow(max(azimuth, 0.0), 1.6);
	vec3 horizon = mix(horizon_away.rgb, horizon_sun.rgb, warm_side);
	float height = pow(clamp(direction.y / 0.85, 0.0, 1.0), 0.40);
	vec3 sky_color = mix(horizon, zenith_color.rgb, height);
	float alignment = max(dot(direction, normalize(sun)), 0.0);
	// Local solar scattering, not a white wash across the entire upper frame.
	sky_color += vec3(0.14, 0.085, 0.025) * pow(alignment, 48.0);
	return sky_color;
}
