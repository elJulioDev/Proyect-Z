shader_type canvas_item;

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.6);
uniform float blur_amount : hint_range(0.0, 5.0) = 1.5;

void fragment() {
    // Tamaño del píxel multiplicado por la intensidad del desenfoque
    vec2 ps = TEXTURE_PIXEL_SIZE * blur_amount;
    float alpha_sum = 0.0;

    // Muestreo manual de 9 puntos para un desenfoque suave compatible con pixel art
    alpha_sum += texture(TEXTURE, UV + vec2(-ps.x, -ps.y)).a;
    alpha_sum += texture(TEXTURE, UV + vec2( 0.0,  -ps.y)).a;
    alpha_sum += texture(TEXTURE, UV + vec2( ps.x, -ps.y)).a;
    alpha_sum += texture(TEXTURE, UV + vec2(-ps.x,  0.0)).a;
    alpha_sum += texture(TEXTURE, UV).a;
    alpha_sum += texture(TEXTURE, UV + vec2( ps.x,  0.0)).a;
    alpha_sum += texture(TEXTURE, UV + vec2(-ps.x,  ps.y)).a;
    alpha_sum += texture(TEXTURE, UV + vec2( 0.0,   ps.y)).a;
    alpha_sum += texture(TEXTURE, UV + vec2( ps.x,  ps.y)).a;

    alpha_sum /= 9.0;

    // Pintar de color sólido (negro) y aplicar la transparencia promediada
    COLOR = vec4(shadow_color.rgb, alpha_sum * shadow_color.a);
}