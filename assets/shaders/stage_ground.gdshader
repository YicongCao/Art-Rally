shader_type spatial;
render_mode diffuse_burley;

varying vec3 world;
varying vec4 zone;
uniform bool road_mesh = false;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
vec2 cell_point(vec2 id) { return vec2(hash(id),hash(id+vec2(51.3,9.2))); }

vec3 aggregate(vec2 p) {
	vec2 id = floor(p), f = fract(p);
	float first = 8.0, second = 8.0, shade = 0.5;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x),float(y));
			float distance = length(offset+cell_point(id+offset)-f);
			if (distance < first) { second=first; first=distance; shade=hash(id+offset+12.0); }
			else { second=min(second,distance); }
		}
	}
	return vec3(first,second-first,shade);
}
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	zone = COLOR;
}
void fragment() {
	float large = noise(world.xz * 0.07);
	float grit = mix(noise(world.xz * 16.0),0.5,clamp(length(fwidth(world.xz))*12.0,0.0,1.0));
	float fleck = smoothstep(0.75, 0.93, noise(world.xz * 7.0));
	vec3 grass = mix(vec3(0.32, 0.21, 0.055), vec3(0.62, 0.43, 0.13), large);
	vec3 earth = mix(vec3(0.26, 0.22, 0.14), vec3(0.39, 0.33, 0.21), noise(world.xz * 0.31));
	vec3 color = mix(grass, earth, smoothstep(0.44, 0.8, noise(world.xz * 0.11)) * 0.25);
	float road_bump = 0.0;
	float stone_speckle = 1.0;
	if (road_mesh) {
		float half_width = 2.8 - 0.25*smoothstep(1130.0,1170.0,UV.y)*(1.0-smoothstep(1620.0,1660.0,UV.y));
		float on_road = 1.0 - smoothstep(half_width-0.15, half_width+0.1, abs(UV.x));
		float shoulder = 1.0 - smoothstep(3.1, 4.2, abs(UV.x));
		vec3 gravel = mix(vec3(0.27, 0.26, 0.21), vec3(0.44, 0.40, 0.30), large * 0.45 + 0.35);
		float tracks = exp(-pow((abs(UV.x) - 0.80) * 3.3, 2.0));
		gravel *= 1.0 - tracks * (0.09 + noise(vec2(UV.y * 0.055, 0.0)) * 0.07);
		vec3 stones = aggregate(world.xz*13.0);
		float near_detail = 1.0-smoothstep(0.15,1.1,length(fwidth(world.xz))*13.0);
		float crown = smoothstep(0.018,0.15,stones.y)*(1.0-smoothstep(0.12,0.55,stones.x));
		float grain_shade = mix(0.83,1.12,stones.z);
		gravel *= mix(1.0,grain_shade,near_detail*0.48);
		gravel *= 1.0-(1.0-smoothstep(0.012,0.055,stones.y))*near_detail*0.10;
		road_bump = crown*near_detail*on_road;
		color = mix(color, earth * 1.09, shoulder);
		// Irregular, compacted edges and dragged material break up the straight join.
		float worn_s = UV.y+(noise(vec2(UV.x*1.8,UV.y*0.35))-0.5)*4.5+sin(UV.x*3.1)*0.8;
		float mud = smoothstep(1147.0,1153.0,worn_s)*(1.0-smoothstep(1647.0,1653.0,worn_s));
		float asphalt = smoothstep(1647.0,1653.0,worn_s)*(1.0-smoothstep(2097.0,2103.0,worn_s));
		stone_speckle = mix(1.0,mix(0.15,0.07,asphalt),max(mud,asphalt)*on_road);
		vec3 mud_color = mix(vec3(0.075,0.044,0.021),vec3(0.17,0.10,0.045),noise(world.xz*0.4));
		mud_color *= 1.0-tracks*0.25;
		vec3 tarmac = vec3(0.042,0.047,0.051)*(0.9+grit*0.2);
		float edge_mark = smoothstep(half_width-0.32,half_width-0.25,abs(UV.x))*(1.0-smoothstep(half_width-0.17,half_width-0.10,abs(UV.x)));
		tarmac = mix(tarmac,vec3(0.56,0.53,0.43),edge_mark);
		gravel = mix(mix(gravel,mud_color,mud),tarmac,asphalt);
		road_bump *= 1.0-asphalt*0.93;
		color = mix(color, gravel, on_road);
	}
	color *= 0.92 + grit * 0.14;
	color += vec3(fleck * 0.012 * stone_speckle);
	ALBEDO = color;
	bool muddy_lane = road_mesh && UV.y>=1150.0 && UV.y<1650.0 && abs(UV.x)<2.55;
	ROUGHNESS = muddy_lane ? 0.76 : 0.96;
	SPECULAR = muddy_lane ? 0.12 : 0.08;
	vec2 bumps = vec2(dFdx(road_bump),dFdy(road_bump));
	NORMAL_MAP = vec3(vec2(0.5)+clamp(-bumps*0.55,vec2(-0.20),vec2(0.20)) + vec2(grit-0.5)*0.08,1.0);
	NORMAL_MAP_DEPTH = 0.4;
}
