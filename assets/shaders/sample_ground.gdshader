shader_type spatial;
render_mode diffuse_burley;

varying vec3 world;
varying vec4 zone;
uniform bool road_mesh = false;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	zone = COLOR;
}
void fragment() {
	float large = noise(world.xz * 0.07);
	float grit = noise(world.xz * 24.0);
	float fleck = smoothstep(0.75, 0.93, noise(world.xz * 7.0));
	vec3 grass = mix(vec3(0.155, 0.205, 0.085), vec3(0.31, 0.34, 0.16), large);
	vec3 earth = mix(vec3(0.35, 0.30, 0.20), vec3(0.48, 0.42, 0.30), noise(world.xz * 0.31));
	vec3 color = mix(grass, earth, smoothstep(0.44, 0.8, noise(world.xz * 0.11)) * 0.7);
	if (road_mesh) {
		float on_road = 1.0 - smoothstep(2.6, 2.9, abs(UV.x));
		float shoulder = 1.0 - smoothstep(3.1, 4.2, abs(UV.x));
		vec3 gravel = mix(vec3(0.48, 0.40, 0.28), vec3(0.66, 0.57, 0.42), large * 0.45 + 0.35);
		float tracks = exp(-pow((abs(UV.x) - 0.80) * 3.3, 2.0));
		gravel *= 1.0 - tracks * (0.07 + noise(vec2(UV.y * 0.055, 0.0)) * 0.06);
		color = mix(color, earth * 1.09, shoulder);
		color = mix(color, gravel, on_road);
	}
	color *= 0.92 + grit * 0.14;
	color += vec3(fleck * 0.035);
	ALBEDO = color;
	ROUGHNESS = 0.96;
	NORMAL_MAP = vec3(0.5 + (grit - 0.5) * 0.13, 0.5 + (noise(world.zx * 19.0) - 0.5) * 0.13, 1.0);
	NORMAL_MAP_DEPTH = 0.2;
}
