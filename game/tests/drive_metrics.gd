extends Node
## 평지 주행 수치 측정. 차를 바꿀 때 전후를 같은 잣대로 비교한다(최고 속도, 가속, 제동, 선회, 리프트 점프).
## 실행: Godot --headless --fixed-fps 60 --path . res://tests/drive_metrics.tscn

const ACTIONS := ["forward", "back", "left", "right", "rocket", "boost", "magnet", "air_forward", "air_back"]

var car: Roadster


func _ready() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(800, 1, 800)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -0.5, 0)
	add_child(floor_body)
	car = preload("res://scenes/roadster.tscn").instantiate()
	add_child(car)
	car.landed.connect(func(up, air_t, spin): print("  LANDED upright=%s air=%.2f spin=%.0f" % [up, air_t, spin]))
	car.crashed.connect(func(kind, impact): print("  CRASHED %s impact=%.1f" % [kind, impact]))
	await get_tree().physics_frame
	await _run()
	get_tree().quit()


func _hold(actions: Dictionary) -> void:
	for a in ACTIONS:
		if actions.has(a):
			Input.action_press(a, actions[a])
		else:
			Input.action_release(a)


func _reset() -> void:
	_hold({})
	car.respawn_at(Transform3D.IDENTITY)
	for i in 30:
		await get_tree().physics_frame


func _frames(sec: float) -> int:
	return roundi(sec * 60.0)


func _fwd_speed() -> float:
	return car.get_planar_velocity().dot(car.get_forward())


func _run() -> void:
	# A. 풀 가속 → 제동
	await _reset()
	_hold({"forward": 1.0})
	var line := "A accel:"
	var t90 := -1.0
	for i in _frames(6.0):
		await get_tree().physics_frame
		if i % 30 == 29:
			line += " %.1f" % _fwd_speed()
	var top := _fwd_speed()
	print(line, "  top=%.2f" % top)
	_hold({"back": 1.0})
	var p0 := car.get_vehicle_position()
	var n := 0
	while _fwd_speed() > 0.2 and n < 600:
		await get_tree().physics_frame
		n += 1
	print("A brake: from %.2f stop %.2fm in %.2fs" % [top, car.get_vehicle_position().distance_to(p0), n / 60.0])

	# 0→90% 시간
	await _reset()
	_hold({"forward": 1.0})
	for i in _frames(6.0):
		await get_tree().physics_frame
		if t90 < 0.0 and _fwd_speed() >= top * 0.9:
			t90 = (i + 1) / 60.0
	print("A t90=%.2fs  t(5m/s)=?" % t90)

	# C. 0.62 가속
	await _reset()
	_hold({"forward": 0.62})
	for i in _frames(5.0):
		await get_tree().physics_frame
	print("C throttle0.62 speed=%.2f" % _fwd_speed())

	# D, E. 선회
	for thr: float in [1.0, 0.6, 0.35]:
		await _reset()
		_hold({"forward": thr})
		for i in _frames(3.0):
			await get_tree().physics_frame
		var v0 := _fwd_speed()
		_hold({"forward": thr, "left": 1.0})
		var yaw0 := car.get_forward()
		var t_quarter := -1.0
		for i in _frames(3.0):
			await get_tree().physics_frame
			if t_quarter < 0.0 and car.get_forward().angle_to(yaw0) >= PI * 0.5:
				t_quarter = (i + 1) / 60.0
		var v := car.get_planar_velocity()
		var slip := rad_to_deg(v.angle_to(car.get_forward())) if v.length() > 0.5 else 0.0
		var yaw_rate := rad_to_deg(absf(car.angular_velocity_y()))
		var radius := v.length() / maxf(deg_to_rad(yaw_rate), 0.01)
		print("D steer thr=%.2f v_in=%.2f -> v=%.2f yaw=%.0f°/s radius=%.1fm slip=%.0f° t90°=%.2fs" % [thr, v0, v.length(), yaw_rate, radius, slip, t_quarter])
		# 조향 반응: 손 떼고 직진으로 돌아오는 시간
		_hold({"forward": thr})
		var tr := 0.0
		for i in 120:
			await get_tree().physics_frame
			if absf(car.angular_velocity_y()) < deg_to_rad(5.0):
				tr = (i + 1) / 60.0
				break
		print("   release -> straight in %.2fs" % tr)

	# F. 리프트 0.5초 (정지 상태)
	await _reset()
	_hold({"rocket": 1.0})
	var max_y := 0.0
	var air_t := 0.0
	for i in _frames(3.0):
		await get_tree().physics_frame
		if i == _frames(0.5):
			_hold({})
		max_y = maxf(max_y, car.get_vehicle_position().y)
		if not car.is_grounded():
			air_t += 1.0 / 60.0
	print("F lift0.5 apex=%.2fm air=%.2fs" % [max_y, air_t])

	# G. 달리다 리프트 0.5초 + 공중 회전(A 길게)
	await _reset()
	_hold({"forward": 0.62})
	for i in _frames(3.0):
		await get_tree().physics_frame
	var vjump := _fwd_speed()
	var px := car.get_vehicle_position()
	_hold({"rocket": 1.0, "forward": 0.62})
	var landed_at := -1.0
	var left_ground := false
	for i in _frames(4.0):
		await get_tree().physics_frame
		if i == _frames(0.5):
			_hold({"left": 1.0})
		if i == _frames(1.0):
			_hold({})
		if not car.is_grounded():
			left_ground = true
		elif left_ground and landed_at < 0.0:
			landed_at = (i + 1) / 60.0
			print("G jump v=%.2f dist=%.2fm air=%.2fs upright=%.2f" % [vjump, car.get_vehicle_position().distance_to(px), landed_at, car.get_up().dot(Vector3.UP)])

	# H~K. 부딪힘 판정: 벽에 세게(crash), 천천히 닿기(아님), 바로 선 채 8m 낙하(아님), 지붕으로 떨어짐(flip)
	var wall := StaticBody3D.new()
	var ws := CollisionShape3D.new()
	var wb := BoxShape3D.new()
	wb.size = Vector3(8, 2, 1)
	ws.shape = wb
	wall.add_child(ws)
	wall.position = Vector3(0, 1, 30)
	add_child(wall)
	car.auto_recover = false
	print("H wall at full speed:")
	await _reset()
	car.debug_contacts = false
	_hold({"forward": 1.0})
	var v_hit := 0.0
	for i in _frames(4.0):
		await get_tree().physics_frame
		if car.get_vehicle_position().z < 27.0:
			v_hit = _fwd_speed()
	print("   speed before wall %.2f" % v_hit)
	car.debug_contacts = false
	print("I wall at walking pace:")
	car.respawn_at(Transform3D(Basis.IDENTITY, Vector3(0, 0, 25)))
	_hold({"forward": 0.25})
	for i in _frames(3.0):
		await get_tree().physics_frame
	print("J drop 8m upright:")
	car.respawn_at(Transform3D(Basis.IDENTITY, Vector3(10, 8, 0)))
	_hold({})
	for i in _frames(3.0):
		await get_tree().physics_frame
	print("K drop 1.5m upside down:")
	car.respawn_at(Transform3D(Basis(Vector3.BACK, PI), Vector3(20, 1.5, 0)))
	for i in _frames(3.0):
		await get_tree().physics_frame
	print("   up.y=%.2f" % car.get_up().y)
