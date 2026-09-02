class_name Fx
extends Node2D

## Pooled CPUParticles2D one-shots (CPU: safe on gl_compatibility and
## the web export). Every gameplay moment that makes a sound can make
## a little weather too — burst() picks a preset and fires.

const GOLD := Color("e8c547")
const CONFETTI_RAMP := ["e8c547", "e05252", "52d67e", "9ec9d8", "b06fd8", "e8e0c8"]

var _pool: Array = []


func _emitter() -> CPUParticles2D:
	for p: CPUParticles2D in _pool:
		if not p.emitting:
			return p
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.z_index = 20
	add_child(p)
	_pool.append(p)
	return p


func burst(pos: Vector2, kind: String, tint := Color.WHITE, dir := Vector2.UP) -> void:
	if not is_inside_tree():
		return
	var p := _emitter()
	p.position = pos
	# Common baseline; presets override below.
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	p.amount = 12
	p.lifetime = 0.65
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2(0, 600)
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 260.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = tint
	p.color_initial_ramp = null
	p.damping_min = 0.0
	p.damping_max = 0.0
	match kind:
		"pop":
			p.amount = 10
			p.color = tint if tint != Color.WHITE else Color(0.93, 0.9, 0.8)
		"sparks":
			p.amount = 16
			p.gravity = Vector2(0, 300)
			p.initial_velocity_min = 70.0
			p.initial_velocity_max = 190.0
			p.lifetime = 0.8
			p.scale_amount_min = 2.0
			p.scale_amount_max = 4.0
			p.color = GOLD
		"gold":
			p.amount = 26
			p.direction = Vector2.UP
			p.spread = 50.0
			p.gravity = Vector2(0, 750)
			p.initial_velocity_min = 260.0
			p.initial_velocity_max = 430.0
			p.lifetime = 0.9
			p.color = GOLD
		"smoke":
			p.amount = 18
			p.gravity = Vector2(0, -90)
			p.initial_velocity_min = 40.0
			p.initial_velocity_max = 120.0
			p.lifetime = 1.3
			p.scale_amount_min = 7.0
			p.scale_amount_max = 14.0
			p.damping_min = 20.0
			p.damping_max = 40.0
			p.color = Color(0.35, 0.33, 0.3, 0.8) if tint == Color.WHITE else tint
		"embers":
			p.amount = 8
			p.direction = Vector2.UP
			p.spread = 35.0
			p.gravity = Vector2(0, -170)
			p.initial_velocity_min = 30.0
			p.initial_velocity_max = 90.0
			p.lifetime = 1.1
			p.scale_amount_min = 2.0
			p.scale_amount_max = 4.0
			p.color = Color("e07830")
		"splash":
			p.amount = 12
			p.direction = Vector2.UP
			p.spread = 65.0
			p.gravity = Vector2(0, 900)
			p.initial_velocity_min = 180.0
			p.initial_velocity_max = 320.0
			p.lifetime = 0.6
			p.scale_amount_min = 2.5
			p.scale_amount_max = 4.5
			p.color = Color("6fa8c9")
		"dust":
			p.amount = 14
			p.direction = dir
			p.spread = 16.0
			p.gravity = Vector2(0, 180)
			p.initial_velocity_min = 280.0
			p.initial_velocity_max = 520.0
			p.lifetime = 0.5
			p.scale_amount_min = 3.0
			p.scale_amount_max = 7.0
			p.color = Color(0.62, 0.54, 0.4, 0.8)
		"rock":
			p.amount = 10
			p.gravity = Vector2(0, 950)
			p.lifetime = 0.7
			p.color = Color(0.5, 0.5, 0.55)
		"confetti":
			p.amount = 70
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = Vector2(560, 12)
			p.direction = Vector2.DOWN
			p.spread = 40.0
			p.gravity = Vector2(0, 330)
			p.initial_velocity_min = 60.0
			p.initial_velocity_max = 160.0
			p.lifetime = 2.1
			p.scale_amount_min = 4.0
			p.scale_amount_max = 7.5
			var ramp := Gradient.new()
			var cols := PackedColorArray()
			var offs := PackedFloat32Array()
			for i in CONFETTI_RAMP.size():
				cols.append(Color(CONFETTI_RAMP[i]))
				offs.append(float(i) / (CONFETTI_RAMP.size() - 1))
			ramp.colors = cols
			ramp.offsets = offs
			p.color = Color.WHITE
			p.color_initial_ramp = ramp
	p.restart()
