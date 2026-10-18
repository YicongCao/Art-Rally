shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, fog_disabled, cull_disabled;

uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec2 sun_uv = vec2(-2.0);
uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform float strength : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float clear_sky(vec2 at) {
	if (at.x < 0.0 || at.x > 1.0 || at.y < 0.0 || at.y > 1.0) return 0.0;
	// Godot Forward+/Metal uses reverse Z: an untouched sky pixel has zero depth.
	return 1.0 - step(0.000001, texture(scene_depth, at).r);
}

float ghost(vec2 uv, vec2 at, float radius, float aspect) {
	vec2 q = (uv - at) * vec2(aspect, 1.0);
	float angle = atan(q.y, q.x) + 0.16;
	float polygon = length(q) * cos(mod(angle, 1.04719755) - 0.52359877) / radius;
	float edge = exp(-pow((polygon - 0.94) * 16.0, 2.0));
	return (1.0 - smoothstep(0.93, 1.03, polygon)) * 0.26 + edge * 0.14;
}

void fragment() {
	vec3 effect = vec3(0.0);
	if (strength > 0.001) {
		vec2 pixel = 3.0 / viewport_size;
		float visibility = 0.0;
		for (int x = -1; x <= 1; x++) {
			for (int y = -1; y <= 1; y++) {
				visibility += clear_sky(sun_uv + vec2(float(x), float(y)) * pixel) / 9.0;
			}
		}
		float aspect = viewport_size.x / viewport_size.y;
		vec2 axis = vec2(0.5) - sun_uv;
		// Largest ghost is furthest from the source; smaller hexagons lead back to it.
		effect += ghost(SCREEN_UV, sun_uv + axis * 1.92, 0.087, aspect) * vec3(0.37,0.55,0.39);
		effect += ghost(SCREEN_UV, sun_uv + axis * 1.47, 0.056, aspect) * vec3(0.78,0.43,0.16);
		effect += ghost(SCREEN_UV, sun_uv + axis * 1.05, 0.032, aspect) * vec3(0.38,0.57,0.54);
		effect += ghost(SCREEN_UV, sun_uv + axis * 0.65, 0.021, aspect) * vec3(0.90,0.59,0.23);
		effect += ghost(SCREEN_UV, sun_uv + axis * 0.30, 0.011, aspect) * vec3(1.0,0.66,0.33);
		vec2 q = (SCREEN_UV - sun_uv) * vec2(aspect,1.0);
		effect += exp(-dot(q,q) / 0.007) * vec3(0.30,0.16,0.055);
		vec2 diagonal = vec2(q.x+q.y, q.y-q.x) * 0.70710678;
		effect += exp(-abs(diagonal.x)*14.0-abs(diagonal.y)*420.0) * vec3(0.46,0.29,0.10);
		effect *= visibility * strength * 0.24;
	}
	ALBEDO = effect;
	EMISSION = vec3(0.0);
	ALPHA = 1.0;
}
