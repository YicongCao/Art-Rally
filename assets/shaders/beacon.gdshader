shader_type spatial;
render_mode unshaded,blend_mix,cull_disabled,depth_draw_never;
void fragment() {
	ALBEDO = vec3(1.0,.60,.06);
	ALPHA = .24*pow(1.0-UV.y,.85)*smoothstep(0.0,.04,UV.y);
}
