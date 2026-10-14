shader_type spatial;
render_mode cull_disabled, depth_draw_never;
void fragment() {
	float edge = smoothstep(0.0,0.14,UV.x)*(1.0-smoothstep(0.86,1.0,UV.x));
	float tread = mix(0.70,1.0,step(0.28,fract(UV.y*5.0+abs(UV.x-0.5)*2.0)));
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a*edge*tread;
	ROUGHNESS = 1.0;
}
