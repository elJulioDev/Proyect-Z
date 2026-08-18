shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec2 node_resolution = vec2(1152, 648);
uniform float factor : hint_range(0.0, 1.0, 0.01) = 0.0;

uniform float spacing = 25.0;
uniform float dot_size : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	if (factor <= 0.0) {
		discard;
	}

	vec2 screen_size = node_resolution;
	vec2 pixel_pos = UV * screen_size;

	// Grid cell ID and center
	vec2 grid_id = floor(pixel_pos / spacing);
	vec2 grid_center = (grid_id + 0.5) * spacing;

	// Manhattan distance from diamond center (diamond shape)
	vec2 cell_local = abs(pixel_pos - grid_center);
	float diamond_dist = (cell_local.x + cell_local.y) / (spacing * 0.5);

	// Normalized grid position [0,1]
	vec2 grid_norm = grid_id * spacing / screen_size;
	// Diagonal wave delay: top-left = 0, bottom-right = 1
	float delay = (grid_norm.x + grid_norm.y) * 0.5;

	// Wave progress: each diamond scales based on where it sits on the diagonal
	float wave = factor * 1.4;
	float scale = smoothstep(delay - 0.25, delay + 0.15, wave);

	// Diamond shape via manhattan distance
	float diamond = 1.0 - smoothstep(scale * 0.9, scale * 0.95, diamond_dist);

	if (diamond < 0.01) {
		discard;
	}

	COLOR = vec4(base_color.rgb, diamond);
}
