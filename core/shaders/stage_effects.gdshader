shader_type canvas_item;

// Filtro combinado de escenario: color grading + viñeta + distorsión (calor).
// Se aplica en un ColorRect full-screen en layer 0 (detrás del HUD).

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

// Color grading
uniform bool color_grading_enabled = false;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform float brightness : hint_range(-1.0, 1.0) = 0.0;
uniform float contrast : hint_range(0.0, 2.0) = 1.0;

// Viñeta
uniform bool vignette_enabled = false;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.6;

// Distorsión (calor)
uniform bool distortion_enabled = false;
uniform float distortion_strength : hint_range(0.0, 0.05) = 0.015;
uniform float distortion_speed : hint_range(0.0, 5.0) = 0.8;

vec3 adjust_saturation(vec3 color, float sat) {
	float grey = dot(color, vec3(0.2126, 0.7152, 0.0722));
	return mix(vec3(grey), color, sat);
}

// Hash simple para ruido pseudo-aleatorio
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Ruido suave 2D (value noise)
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// Distorsión tipo calor: ondulación sutil vertical con ruido
	// Anclada al UV de pantalla, no se mueve con la cámara
	if (distortion_enabled) {
		float t = TIME * distortion_speed;
		// Dos capas de ruido a diferentes velocidades para efecto orgánico
		float n1 = noise(vec2(uv.x * 8.0, uv.y * 3.0 + t));
		float n2 = noise(vec2(uv.x * 12.0 + 5.0, uv.y * 5.0 + t * 0.6));
		float combined = (n1 + n2 * 0.5) * 0.667;
		// Offset sutil: más movimiento vertical que horizontal
		float offsetX = (combined - 0.5) * distortion_strength * 0.3;
		float offsetY = (combined - 0.5) * distortion_strength;
		uv += vec2(offsetX, offsetY);
		uv = clamp(uv, vec2(0.001), vec2(0.999));
	}

	vec4 screen = texture(screen_texture, uv);
	vec3 color = screen.rgb;

	// Color grading
	if (color_grading_enabled) {
		color += brightness;
		color = (color - 0.5) * contrast + 0.5;
		color = adjust_saturation(color, saturation);
		color = mix(color, tint_color.rgb, tint_color.a);
	}

	// Viñeta: oscurece bordes
	if (vignette_enabled) {
		// Corregir aspect ratio: SCREEN_UV es 0-1 en ambos ejes sin importar resolución
		// Aplicar corrección para que la viñeta sea circular en pantalla 16:9
		vec2 center = uv - 0.5;
		float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
		center.x *= aspect;
		float dist = length(center);
		float vig = smoothstep(0.3, 0.85, dist);
		color = mix(color, vec3(0.0), vig * vignette_opacity);
	}

	COLOR = vec4(color, screen.a);
}
