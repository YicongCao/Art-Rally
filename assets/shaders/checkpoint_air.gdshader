shader_type spatial;
render_mode cull_disabled;

uniform float air_time = 0.0;
uniform int flutter_gate = -1;
uniform float flutter_time = -100.0;
varying float gate_status;

void vertex() {
	// UV2.x: 0 = rigid blower/base, 1 = pressure cloth, 2 = loose streamer, 3 = blower rotor.
	// Vertex RGB retains Blender's authored panels; INSTANCE_CUSTOM is state only.
	gate_status = INSTANCE_CUSTOM.x;
	float phase = INSTANCE_CUSTOM.z * 6.283185;
	float distance_fade = 1.0-smoothstep(25.0,95.0,distance((MODEL_MATRIX*vec4(VERTEX,1.0)).xyz,CAMERA_POSITION_WORLD));
	float flex = pow(clamp((VERTEX.y-.55)/2.9,0.0,1.0),2.0);
	float wake = int(INSTANCE_CUSTOM.y+.5)==flutter_gate ? exp(-max(air_time-flutter_time,0.0)*3.0) : 0.0;
	if (UV2.x>.5 && UV2.x<2.5) {
		// Raise the pre-bent fabric into a pressurized stance. Pressure pulses
		// move the tip 30 cm, rather than the old barely visible 5 cm vibration.
		float pressure = .5+.5*sin(air_time*3.1+phase);
		VERTEX.x += (-.43+.30*pressure)*flex;
		VERTEX.y += .09*flex;
		VERTEX.z += sin(air_time*2.5+phase+VERTEX.y)*flex*(.10+wake*.12);
	}
	if (UV2.x>1.5 && UV2.x<2.5) {
		float free_tip = clamp((VERTEX.x-.55)/.85,0.0,1.0);
		VERTEX.z += sin(air_time*17.0-free_tip*10.0+phase)*free_tip*.16*distance_fade;
		VERTEX.y += sin(air_time*11.0-free_tip*8.0+phase)*free_tip*.075*distance_fade;
	}
	if (UV2.x>2.5) {
		float angle=air_time*21.0+phase;
		vec2 rotor=VERTEX.xy-vec2(0,.35);
		VERTEX.xy=vec2(cos(angle)*rotor.x-sin(angle)*rotor.y,sin(angle)*rotor.x+cos(angle)*rotor.y)+vec2(0,.35);
	}
}

void fragment() {
	// Preserve ivory, orange, checkers and machine finishes rather than recolor all faces.
	ALBEDO = COLOR.rgb * mix(.76,1.0,gate_status);
	ROUGHNESS = UV2.x>.5 ? .79 : .66;
	SPECULAR = .18;
}
