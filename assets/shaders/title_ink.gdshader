shader_type canvas_item;
uniform float mark_start = 430.0;
uniform float mark_end = 800.0;
uniform float baseline = 234.0;
varying vec2 local;
void vertex() { local = VERTEX; }
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
	vec4 ink = COLOR * texture(TEXTURE,UV);
	float x = local.x-mark_start;
	float y = local.y-(baseline-63.0);
	float along = x*.94-y*.34;
	float across = x*.34+y*.94-55.0;
	float tread = step(abs(across),22.0)*step(3.0,mod(along+abs(across)*.65,17.0))*(1.0-step(12.0,mod(along+abs(across)*.65,17.0)))*step(2.0,abs(across));
	vec2 cell = floor(vec2(along,across)/5.0);
	float fleck = step(.79,hash(cell))*step(length(fract(vec2(along,across)/5.0)-.5),.18+hash(cell+3.0)*.22);
	float dirt = fleck*(1.0-smoothstep(25.0,58.0,abs(across)));
	float mark = max(tread*.68,dirt*.8)*smoothstep(-8.0,18.0,x)*(1.0-smoothstep(mark_end-3.0,mark_end,local.x));
	ink.rgb = mix(ink.rgb,vec3(.23,.19,.12),mark);
	COLOR = ink;
}
