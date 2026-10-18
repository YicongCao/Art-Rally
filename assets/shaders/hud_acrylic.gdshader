shader_type canvas_item;
render_mode unshaded;

uniform sampler2D scene_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float frost = 0.65;

void fragment() {
	vec4 tint = COLOR;
	vec3 sharp = textureLod(scene_texture, SCREEN_UV, 0.0).rgb;
	vec3 soft = textureLod(scene_texture, SCREEN_UV, 2.0).rgb;
	float grain = fract(sin(dot(floor(FRAGCOORD.xy),vec2(12.9898,78.233)))*43758.5453)-0.5;
	vec3 glass = mix(sharp,soft,frost);
	COLOR = vec4(mix(glass,tint.rgb,tint.a)+grain*0.009,1.0);
}
