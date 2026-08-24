shader_type canvas_item;

// Tinte de fighters para escenarios. Se aplica al Sprite2D de cada fighter.
// Mezcla el color original con un tinte basado en la atmósfera del stage.

uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 tinted = mix(tex.rgb, tint_color.rgb, tint_color.a);
	COLOR = vec4(tinted, tex.a);
}
