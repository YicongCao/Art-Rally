shader_type canvas_item;
uniform float strength=.035;
void fragment(){
 vec4 base=COLOR;
 vec2 p=FRAGCOORD.xy;
 float grain=fract(sin(dot(floor(p),vec2(12.9898,78.233)))*43758.5453);
 float dots=1.0-smoothstep(.65,.95,length(mod(p,vec2(7.0)) - vec2(3.5)));
 COLOR=vec4(base.rgb*(1.0-strength*(grain+dots)),base.a);
}
