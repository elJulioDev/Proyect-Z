extends Node2D
## Capa de partículas ambientales del escenario: lluvia, nieve, ceniza, pétalos.
## Se instancia desde BaseStage según el StageFilter.
## Usa CPUParticles2D (compatible con renderer gl_compatibility).
## Ahora es hijo de Camera2D: sigue el viewport automáticamente.

var _emitting: bool = false
var _viewport_size: Vector2 = Vector2(1280, 720)


func apply(filter_data: StageFilter, viewport_size: Vector2 = Vector2(1280, 720)) -> void:
	_viewport_size = viewport_size
	for child in get_children():
		if child is CPUParticles2D:
			child.queue_free()

	if filter_data == null or not filter_data.particles_enabled:
		_emitting = false
		return

	_emitting = true
	_create_particles(filter_data)


func _create_particles(filter_data: StageFilter) -> void:
	var particles := CPUParticles2D.new()
	particles.name = "AmbientParticles"
	particles.emitting = true

	# Textura simple: 1x1 pixel blanco (se tiñe con particles.color)
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	var tex := ImageTexture.create_from_image(img)
	particles.texture = tex

	# Posición de emisión: centro del viewport (0,0 en espacio de cámara)
	particles.position = Vector2.ZERO

	match filter_data.particle_type:
		StageFilter.ParticleType.RAIN:
			_configure_rain(particles, filter_data)
		StageFilter.ParticleType.SNOW:
			_configure_snow(particles, filter_data)
		StageFilter.ParticleType.ASH:
			_configure_ash(particles, filter_data)
		StageFilter.ParticleType.PETALS:
			_configure_petals(particles, filter_data)

	add_child(particles)


func _configure_rain(particles: CPUParticles2D, data: StageFilter) -> void:
	particles.amount = int(80 * data.particle_density)
	particles.lifetime = 1.2
	particles.speed_scale = 1.5
	particles.position = Vector2(0.0, -_viewport_size.y / 2.0 - 20.0)
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(_viewport_size.x / 2.0 + 100.0, 0.0)
	particles.direction = Vector2(0.0, 1.0)
	particles.spread = 5.0
	particles.initial_velocity_min = 400.0
	particles.initial_velocity_max = 500.0
	particles.gravity = Vector2(0.0, 300.0)
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 6.0
	particles.color = data.particle_color


func _configure_snow(particles: CPUParticles2D, data: StageFilter) -> void:
	particles.amount = int(60 * data.particle_density)
	particles.lifetime = 5.0
	particles.speed_scale = 0.8
	particles.position = Vector2(0.0, -_viewport_size.y / 2.0 - 20.0)
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(_viewport_size.x / 2.0 + 100.0, 0.0)
	particles.direction = Vector2(0.3, -1.0)
	particles.spread = 25.0
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 60.0
	particles.gravity = Vector2(0.0, 40.0)
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 8.0
	particles.angular_velocity_min = -30.0
	particles.angular_velocity_max = 30.0
	particles.color = data.particle_color


func _configure_ash(particles: CPUParticles2D, data: StageFilter) -> void:
	particles.amount = int(40 * data.particle_density)
	particles.lifetime = 6.0
	particles.speed_scale = 0.6
	particles.position = Vector2.ZERO
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = _viewport_size / 2.0 + Vector2(100.0, 100.0)
	particles.direction = Vector2(0.5, -0.5)
	particles.spread = 40.0
	particles.initial_velocity_min = 20.0
	particles.initial_velocity_max = 50.0
	particles.gravity = Vector2(-30.0, -20.0)
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.angular_velocity_min = -20.0
	particles.angular_velocity_max = 20.0
	particles.color = data.particle_color


func _configure_petals(particles: CPUParticles2D, data: StageFilter) -> void:
	particles.amount = int(30 * data.particle_density)
	particles.lifetime = 7.0
	particles.speed_scale = 0.5
	particles.position = Vector2.ZERO
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = _viewport_size / 2.0 + Vector2(100.0, 100.0)
	particles.direction = Vector2(1.0, -0.3)
	particles.spread = 50.0
	particles.initial_velocity_min = 15.0
	particles.initial_velocity_max = 40.0
	particles.gravity = Vector2(20.0, 30.0)
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 8.0
	particles.angular_velocity_min = -40.0
	particles.angular_velocity_max = 40.0
	particles.color = data.particle_color