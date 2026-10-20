class_name DicePhysics
extends RefCounted
## Física simplificada dos dados (só apresentação): gravidade, quique, atrito no chão, paredes invisíveis
## e colisão entre os dados. Roda uma vez, antes da animação, e devolve a trajetória de cada dado.
## A orientação final (qual face fica para cima) NÃO vem daqui: o palco a ajusta ao resultado sorteado,
## porque a física não pode decidir o resultado do jogo.

const DT := 1.0 / 120.0
const SAMPLE_EVERY := 2              # amostra a cada 2 passos = 60 por segundo
const GRAVITY := 22.0
const RESTITUTION := 0.42            # quique no chão
const DIE_RESTITUTION := 0.6         # choque entre dados
const WALL_RESTITUTION := 0.5
const FRICTION := 6.0                # desaceleração horizontal enquanto desliza (unid/s²)
const DIE_RADIUS := 0.5              # esfera de colisão
const REST_SPEED := 0.06


## starts/vels: posição e velocidade inicial de cada dado. bounds: Rect2 no plano XZ (x, z).
## Retorna { "samples": [PackedVector3Array], "t_stop": [float], "events": [ {t, kind, power, pos, die} ], "duration": float }
static func simulate(starts: Array, vels: Array, rest_y: float, bounds: Rect2, max_t := 1.3) -> Dictionary:
	var n := starts.size()
	var pos: Array[Vector3] = []
	var vel: Array[Vector3] = []
	var samples: Array = []
	var last_move: Array[float] = []
	for i in n:
		pos.append(starts[i])
		vel.append(vels[i])
		var arr := PackedVector3Array()
		arr.append(starts[i])
		samples.append(arr)
		last_move.append(0.0)
	var events: Array = []
	var t := 0.0
	var step := 0
	var calm := 0.0
	var damp_from := max_t - 0.35
	while t < max_t:
		step += 1
		t += DT
		for i in n:
			var v := vel[i]
			var p := pos[i]
			v.y -= GRAVITY * DT
			p += v * DT
			var on_floor := false
			if p.y <= rest_y:
				p.y = rest_y
				if v.y < -0.9:
					events.append({ "t": t, "kind": "floor", "power": clampf(-v.y / 7.0, 0.0, 1.0), "pos": p, "die": i })
					v.y = -v.y * RESTITUTION
					v.x *= 0.88
					v.z *= 0.88
				else:
					v.y = 0.0
					on_floor = true
			if on_floor:
				var hs := Vector2(v.x, v.z)
				var sp := hs.length()
				if sp > 0.0:
					hs = hs * maxf(0.0, sp - FRICTION * DT) / sp
					v.x = hs.x
					v.z = hs.y
			# paredes invisíveis
			if p.x < bounds.position.x:
				p.x = bounds.position.x
				v.x = absf(v.x) * WALL_RESTITUTION
			elif p.x > bounds.end.x:
				p.x = bounds.end.x
				v.x = -absf(v.x) * WALL_RESTITUTION
			if p.z < bounds.position.y:
				p.z = bounds.position.y
				v.z = absf(v.z) * WALL_RESTITUTION
			elif p.z > bounds.end.y:
				p.z = bounds.end.y
				v.z = -absf(v.z) * WALL_RESTITUTION
			if t > damp_from:  # garante que tudo pare
				v.x *= 0.9
				v.z *= 0.9
			vel[i] = v
			pos[i] = p
		# choque entre dados
		for i in n:
			for j in range(i + 1, n):
				var d := pos[j] - pos[i]
				var dist := d.length()
				var min_d := DIE_RADIUS * 2.0
				if dist < min_d and dist > 0.0001:
					var nrm := d / dist
					var overlap := min_d - dist
					pos[i] -= nrm * overlap * 0.5
					pos[j] += nrm * overlap * 0.5
					var vn := (vel[i] - vel[j]).dot(nrm)
					if vn > 0.0:
						var jimp := (1.0 + DIE_RESTITUTION) * vn * 0.5
						vel[i] -= nrm * jimp
						vel[j] += nrm * jimp
						if vn > 0.7:
							events.append({ "t": t, "kind": "die", "power": clampf(vn / 5.0, 0.0, 1.0), "pos": (pos[i] + pos[j]) / 2.0, "die": i })
		if step % SAMPLE_EVERY == 0:
			for i in n:
				samples[i].append(pos[i])
		var moving := false
		for i in n:
			var speed := Vector3(vel[i].x, vel[i].y, vel[i].z).length()
			if speed > REST_SPEED or pos[i].y > rest_y + 0.01:
				last_move[i] = t
				moving = true
		calm = 0.0 if moving else calm + DT
		if calm > 0.12:
			break
	var t_stop: Array = []
	var duration := 0.0
	for i in n:
		t_stop.append(maxf(0.2, last_move[i]))
		duration = maxf(duration, t_stop[i])
	return { "samples": samples, "t_stop": t_stop, "events": events, "duration": duration }
