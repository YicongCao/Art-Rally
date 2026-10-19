shader_type canvas_item;
render_mode unshaded;

uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform float phase = 0.0;
uniform float wind_time = 0.0;
uniform sampler2D wordmark : filter_linear;
varying vec2 pixel;
void vertex() { pixel = VERTEX; }

void fragment() {
	// Travel along a screen diagonal; oversized fabric fully covers every corner at phase 1.
	vec2 center = viewport_size * (vec2(0.5) + vec2(2.1, 2.1) * (phase - 1.0));
	vec2 relative = pixel - center;
	float angle = -0.12;
	vec2 p = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle))) * relative;
	vec2 extent = viewport_size * vec2(1.5, 1.7);
	vec2 cloth = p / extent;
	float a = cloth.x * 12.0 + cloth.y * 5.0 - wind_time * 5.0;
	float b = cloth.x * 24.0 - cloth.y * 8.0 - wind_time * 6.5;
	float fold = sin(a) * 0.022 + sin(b) * 0.006;
	cloth.y += fold;
	cloth.x += sin(cloth.y * 13.0 - wind_time * 3.8) * 0.009;
	float edge = max(abs(cloth.x), abs(cloth.y));
	float alpha = 1.0 - smoothstep(0.499, 0.501, edge);
	float square = extent.y / 8.0;
	vec2 grid = floor((cloth + 0.5) * extent / square);
	float checker = mod(grid.x + grid.y, 2.0);
	// Ink is deep blue-green, with warm ivory squares and a broad woven center ribbon.
	vec3 dark = vec3(0.125,0.145,0.17);
	vec3 ivory = vec3(.933,.886,.773);
	vec3 color = mix(ivory, dark, checker);
	float ribbon = 1.0 - smoothstep(0.145, 0.148, abs(cloth.y));
	color = mix(color, dark, ribbon);
	float piping = (1.0 - smoothstep(0.002, 0.004, abs(abs(cloth.y) - 0.14)));
	color = mix(color, vec3(.839,.659,.235), piping);
	float logo_width = min(viewport_size.x * 0.94, viewport_size.y * 1.8);
	vec2 logo_uv = cloth * extent / vec2(logo_width, logo_width / 6.0) + 0.5;
	float inside_logo = step(0.0, logo_uv.x) * step(logo_uv.x, 1.0) * step(0.0, logo_uv.y) * step(logo_uv.y, 1.0);
	float logo = texture(wordmark, clamp(logo_uv, vec2(0.0), vec2(1.0))).a * inside_logo;
	color = mix(color, ivory, logo);
	// Broad diffuse folds rather than glossy highlights. Fine weave stays deliberately subtle.
	float slope = cos(a) * 0.264 + cos(b) * 0.144;
	float light = 0.89 + slope * 0.34 + sin(a - 0.8) * 0.065;
	float weave = sin(cloth.x * extent.x * 2.2) * sin(cloth.y * extent.y * 2.2) * 0.008;
	color *= light + weave;
	color += vec3(0.105, 0.067, 0.024) * (0.5 + 0.5 * sin(a - 0.5));
	color += vec3(0.015, 0.025, 0.04) * (1.0 - light);
	COLOR = vec4(color, alpha);
}
