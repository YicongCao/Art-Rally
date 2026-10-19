shader_type canvas_item;
render_mode unshaded;
uniform sampler2D scene_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
void fragment() {
 vec4 paint=COLOR;
 vec3 scene=textureLod(scene_texture,SCREEN_UV,2.2).rgb;
 float light=dot(paint.rgb,vec3(.2126,.7152,.0722));
 // Dense neutral charcoal with restrained frosted transmission. Keep the
 // generated orange rim and ivory ticks crisp; blur only the world beneath.
 vec3 glass=mix(scene,paint.rgb,mix(.84,1.0,smoothstep(.12,.42,light)));
 COLOR=vec4(glass,smoothstep(.06,.50,paint.a));
}
