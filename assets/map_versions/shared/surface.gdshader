shader_type canvas_item;
render_mode unshaded;

uniform sampler2D art_surface : source_color, filter_nearest, repeat_disable;
uniform vec4 map_colors[32] : source_color;
uniform vec4 fallback_color : source_color = vec4(0.34, 0.32, 0.29, 1.0);
uniform vec2 logical_canvas = vec2(48.0, 48.0);

void fragment() {
	vec2 pixel_uv = (floor(UV * logical_canvas) + vec2(0.5)) / logical_canvas;
	float geometry_alpha = texture(TEXTURE, pixel_uv).a;
	vec4 surface = texture(art_surface, pixel_uv);
	vec3 source_rgb = mix(fallback_color.rgb, surface.rgb, step(0.5, surface.a));
	vec3 selected = map_colors[0].rgb;
	float best = 1000.0;
	for (int i = 0; i < 32; i++) {
		vec3 delta = source_rgb - map_colors[i].rgb;
		float error = dot(delta, delta);
		if (error < best) {
			best = error;
			selected = map_colors[i].rgb;
		}
	}
	COLOR = vec4(selected, geometry_alpha);
}
