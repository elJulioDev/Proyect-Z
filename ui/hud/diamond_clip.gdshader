shader_type canvas_item;

uniform sampler2D u_texture;
uniform vec2 u_texture_size = vec2(100.0, 100.0);
uniform vec2 u_node_size = vec2(100.0, 100.0);
uniform float u_border_width = 0.08;
uniform vec4 u_border_color : source_color = vec4(0, 0, 0, 1);
uniform vec4 u_fill_color : source_color = vec4(0.35, 0.2, 0.55, 1);
uniform bool u_has_texture = false;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float d = abs(p.x) + abs(p.y);
	if (d > 0.5) {
		discard;
	}
	vec4 col = u_fill_color;
	if (u_has_texture) {
		vec2 uv = UV;
		float rect_ratio = u_node_size.x / max(u_node_size.y, 0.001);
		float tex_ratio = u_texture_size.x / max(u_texture_size.y, 0.001);
		if (tex_ratio > rect_ratio) {
			uv.x = (UV.x - 0.5) * (rect_ratio / tex_ratio) + 0.5;
		} else {
			uv.y = (UV.y - 0.5) * (tex_ratio / rect_ratio) + 0.5;
		}
		col = texture(u_texture, uv);
	}
	if (d > 0.5 - u_border_width) {
		col = u_border_color;
	}
	COLOR = col;
}
