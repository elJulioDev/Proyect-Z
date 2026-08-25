shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_size : hint_range(0.0, 20.0) = 3.0;
uniform float dark_amount : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec4 color = vec4(0.0);
	float total = 0.0;
	vec2 ps = SCREEN_PIXEL_SIZE;

	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float w = 1.0 / (1.0 + float(x * x + y * y));
			color += texture(screen_texture, SCREEN_UV + vec2(float(x), float(y)) * ps * blur_size) * w;
			total += w;
		}
	}

	COLOR = mix(color / total, vec4(0.0, 0.0, 0.0, 1.0), dark_amount);
}
