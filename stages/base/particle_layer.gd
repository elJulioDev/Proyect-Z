extends CanvasLayer
## Capa de partículas ambientales del escenario: lluvia, nieve, ceniza, pétalos.
## Se instancia desde BaseStage según el StageFilter.

var _emitting: bool = false


func _init() -> void:
	layer = 0


func apply(filter_data: StageFilter) -> void:
	for child in get_children():
		if child is GPUParticles2D:
			child.queue_free()

	if filter_data == null or not filter_data.particles_enabled:
		_emitting = false
		return

	_emitting = true
	_create_particles(filter_data)


func _create_particles(filter_data: StageFilter) -> void:
	var particles := GPUParticles2D.new()
	particles.name = "AmbientParticles"
	particles.emitting = true

	# Textura procedural: círculo suave para cada partícula
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.0))
	gradient.set_color(1, Color(1, 1, 1, 1.0))
	gradient.add_point(0.5, Color(1, 1, 1, 1.0))
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = gradient
	grad_tex.width = 16
	grad_tex.height = 16
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(1.0, 0.5)
	particles.texture = grad_tex

	# Posición de emisión: centro de la pantalla
	particles.position = Vector2(640.0, 360.0)

	var mat := ParticleProcessMaterial.new()

	match filter_data.particle_type:
		StageFilter.ParticleType.RAIN:
			_configure_rain(mat, filter_data, particles)
		StageFilter.ParticleType.SNOW:
			_configure_snow(mat, filter_data, particles)
		StageFilter.ParticleType.ASH:
			_configure_ash(mat, filter_data, particles)
		StageFilter.ParticleType.PETALS:
			_configure_petals(mat, filter_data, particles)

	particles.process_material = mat
	add_child(particles)


func _configure_rain(mat: ParticleProcessMaterial, data: StageFilter, particles: GPUParticles2D) -> void:
	particles.amount = int(80 * data.particle_density)
	particles.lifetime = 1.2
	particles.speed_scale = 1.5
	particles.position = Vector2(640.0, -20.0)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(700.0, 0.0, 0.0)
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 5.0
	mat.initial_velocity_min = 400.0
	mat.initial_velocity_max = 500.0
	mat.gravity = Vector3(0.0, 300.0, 0.0)
	mat.scale_min = 0.3
	mat.scale_max = 0.6
	mat.color = data.particle_color


func _configure_snow(mat: ParticleProcessMaterial, data: StageFilter, particles: GPUParticles2D) -> void:
	particles.amount = int(60 * data.particle_density)
	particles.lifetime = 5.0
	particles.speed_scale = 0.8
	particles.position = Vector2(640.0, -20.0)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(700.0, 0.0, 0.0)
	mat.direction = Vector3(0.3, -1.0, 0.0)
	mat.spread = 25.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 60.0
	mat.gravity = Vector3(0.0, 40.0, 0.0)
	mat.scale_min = 0.5
	mat.scale_max = 1.2
	mat.angular_velocity_min = -30.0
	mat.angular_velocity_max = 30.0
	mat.color = data.particle_color


func _configure_ash(mat: ParticleProcessMaterial, data: StageFilter, particles: GPUParticles2D) -> void:
	particles.amount = int(40 * data.particle_density)
	particles.lifetime = 6.0
	particles.speed_scale = 0.6
	particles.position = Vector2(640.0, 360.0)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(700.0, 400.0, 0.0)
	mat.direction = Vector3(0.5, -0.5, 0.0)
	mat.spread = 40.0
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 50.0
	mat.gravity = Vector3(-30.0, -20.0, 0.0)
	mat.scale_min = 0.2
	mat.scale_max = 0.6
	mat.angular_velocity_min = -20.0
	mat.angular_velocity_max = 20.0
	mat.color = data.particle_color


func _configure_petals(mat: ParticleProcessMaterial, data: StageFilter, particles: GPUParticles2D) -> void:
	particles.amount = int(30 * data.particle_density)
	particles.lifetime = 7.0
	particles.speed_scale = 0.5
	particles.position = Vector2(640.0, 360.0)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(700.0, 400.0, 0.0)
	mat.direction = Vector3(1.0, -0.3, 0.0)
	mat.spread = 50.0
	mat.initial_velocity_min = 15.0
	mat.initial_velocity_max = 40.0
	mat.gravity = Vector3(20.0, 30.0, 0.0)
	mat.scale_min = 0.4
	mat.scale_max = 1.0
	mat.angular_velocity_min = -40.0
	mat.angular_velocity_max = 40.0
	mat.color = data.particle_color
