class_name StageFilter extends Resource
## Filtro visual de escenario: define efectos shader (color grading, viñeta,
## distorsión) y partículas ambientales. Se aplica como overlay en FilterLayer.

## ── Color grading ──────────────────────────────────────────
@export_group("Color Grading")
@export var color_grading_enabled: bool = false
## Tinte aplicado al escenario completo y fighters.
@export var tint_color: Color = Color(1, 1, 1, 0.0)
## Saturación (1.0 = normal, 0.0 = gris, >1.0 = sobresaturado).
@export_range(0.0, 2.0, 0.01) var saturation: float = 1.0
## Brillo (-1.0 a 1.0, 0.0 = normal).
@export_range(-1.0, 1.0, 0.01) var brightness: float = 0.0
## Contraste (1.0 = normal, <1.0 = bajo, >1.0 = alto).
@export_range(0.0, 2.0, 0.01) var contrast: float = 1.0

## ── Viñeta ─────────────────────────────────────────────────
@export_group("Viñeta")
@export var vignette_enabled: bool = false
## Qué tanextendida está la viñeta (0.0 = solo esquinas, 1.0 = casi toda la pantalla).
@export_range(0.0, 1.0, 0.01) var vignette_intensity: float = 0.4
## Opacidad de la viñeta (0.0 = invisible, 1.0 = negro sólido).
@export_range(0.0, 1.0, 0.01) var vignette_opacity: float = 0.5

## ── Distorsión ─────────────────────────────────────────────
@export_group("Distorsión")
@export var distortion_enabled: bool = false
## Fuerza de la distorsión (0.0 = sin efecto, valores altos = mucho movimiento).
@export_range(0.0, 0.05, 0.001) var distortion_strength: float = 0.015
## Velocidad del patrón de distorsión.
@export_range(0.0, 10.0, 0.1) var distortion_speed: float = 1.0

## ── Partículas ambientales ─────────────────────────────────
@export_group("Partículas")
@export var particles_enabled: bool = false
@export var particle_type: ParticleType = ParticleType.NONE
## Cantidad relativa de partículas (1.0 = normal).
@export_range(0.1, 3.0, 0.1) var particle_density: float = 1.0
## Color base de las partículas.
@export var particle_color: Color = Color(1, 1, 1, 0.6)

enum ParticleType { NONE, RAIN, SNOW, ASH, PETALS }


## Devuelve true si algún efecto está habilitado.
func has_effects() -> bool:
	return color_grading_enabled or vignette_enabled or distortion_enabled or particles_enabled
