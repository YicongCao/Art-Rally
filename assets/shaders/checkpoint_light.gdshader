shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec4 light_color : source_color = vec4(.38,.91,1.0,1.0);
uniform float light_time = 0.0;
uniform int passed_gate = -1;
uniform float passed_time = -100.0;
varying vec3 state;
varying float footprint;

void vertex() {
	state = INSTANCE_CUSTOM.xyz;
	footprint = UV2.x;
	if (footprint < .5) {
		// Bases have an identity basis: use a horizontal camera right vector to
		// keep the beam vertical and readable from driving and replay cameras.
		vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x,0.0,INV_VIEW_MATRIX[0].z)+vec3(.00001,0.0,0.0));
		VERTEX = vec3(0.0,VERTEX.y,0.0)+right*VERTEX.x;
	}
}

void fragment() {
	float age = max(light_time-passed_time,0.0);
	float response = int(state.y+.5)==passed_gate ? exp(-age*3.5)*.32 : 0.0;
	float strength = state.x+response;
	float opacity;
	float white_core = 0.0;
	if (footprint > .5) {
		float radius = length((UV-.5)*2.0);
		opacity = pow(max(0.0,1.0-radius),2.5)*.48;
	} else {
		float x = abs(UV.x-.5)*2.0;
		float taper = 1.0-smoothstep(.65,1.0,UV.y);
		float core = exp(-x*x*360.0);
		float halo = exp(-x*x*14.0)*.26;
		float stream = .94+.06*sin(UV.y*32.0-light_time*2.8+state.z*6.28);
		vec2 cells = vec2(UV.x*19.0,UV.y*14.0-light_time*.55-state.z*8.0);
		vec2 local = fract(cells);
		float seed = fract(sin(dot(floor(cells),vec2(12.9898,78.233)))*43758.5453);
		float fleck = step(.88,seed)*(1.0-smoothstep(.06,.18,abs(local.x-.5)))*(1.0-smoothstep(.12,.4,abs(local.y-.5)));
		fleck *= smoothstep(.10,.25,x)*(1.0-smoothstep(.65,.95,x));
		opacity = (core+halo+fleck*.45)*taper*stream;
		white_core = core*.65;
	}
	ALBEDO = mix(light_color.rgb,vec3(1.0),white_core)*1.7;
	ALPHA = clamp(opacity*strength,0.0,1.0);
}
