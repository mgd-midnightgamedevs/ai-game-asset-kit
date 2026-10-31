extends Node
## 자동 주행 공통 도구: 사람과 같은 입력 액션만 눌러 차를 몬다(조향·멈추기·주차).
## tests/autopilot.gd(시연 코스), tests/autopilot_day1.gd(DAY 1)가 상속한다.

const ACTIONS := ["forward", "back", "left", "right", "rocket", "boost", "magnet", "air_forward", "air_back", "barrel_roll"]
const STOP_K := 0.8 ## 브레이크를 밟으면 대략 속도 x 0.8m 더 간다

var car: Roadster
var _reapproach := 0.0 ## > 0이면 목표 앞 이 거리까지 후진 중

func _release_all() -> void:
	for a in ACTIONS:
		Input.action_release(a)


func _press(action: String, strength := 1.0) -> void:
	Input.action_press(action, clampf(strength, 0.0, 1.0))


func _flat_fwd() -> Vector3:
	var z: Vector3 = car.vehicle_model.global_basis.z
	z.y = 0.0
	return z.normalized()


## 목표 방향으로 조향. keep_line이면 line_point를 지나는 직선(목표 방향과 평행)에 차를 붙인다.
## reverse: 후진 중(앞바퀴 조향이 차를 반대로 돌린다)
func _steer_heading(dir: Vector3, line_point := Vector3.ZERO, keep_line := false, reverse := false) -> float:
	var f := _flat_fwd()
	var target := dir.normalized()
	if keep_line:
		var side := Vector3.UP.cross(target) # 목표 방향 기준 왼쪽
		var lat := (line_point - car.get_vehicle_position()).dot(side)
		target = (target + side * clampf(lat * 0.15, -0.4, 0.4)).normalized()
	var err := atan2(f.cross(target).y, f.dot(target)) # + 이면 왼쪽으로 돌아야 함
	var s := clampf(err * 1.5, -1.0, 1.0) * (-1.0 if reverse else 1.0)
	if s > 0.03:
		_press("left", s)
	elif s < -0.03:
		_press("right", -s)
	return err


## 지점에서 멈춘다. dir은 차가 바라보는 방향. 멈추면 true. (중심선 위 5m 앞을 쫓는다)
## 멀리 있으면 지점을 향해 조향(추적)하고, 가까우면 dir 방향의 중심선에 붙인다.
## 옆으로 많이 어긋난 채 멈추면 room만큼 뒤로 뺐다가 다시 들어간다(실제 주차처럼).
func _stop_at(point: Vector3, dir: Vector3, room := 7.0, tol := 0.25, lat_tol := 0.8) -> bool:
	var p := car.get_vehicle_position()
	var along := (point - p).dot(dir)
	var lat := (point - p).dot(Vector3.UP.cross(dir))
	var v_along := car.linear_velocity.dot(dir)
	if _reapproach > 0.0:
		# 후진하며 차 뒤쪽을 중심선 쪽으로 붙인다(앞머리는 중심선 반대쪽을 보게)
		var side := Vector3.UP.cross(dir)
		_steer_heading((dir - side * clampf(lat * 0.35, -0.6, 0.6)).normalized(), Vector3.ZERO, false, true)
		_press("back", 0.7)
		if along >= _reapproach:
			_reapproach = 0.0
		return false
	var heading_off := absf(_flat_fwd().signed_angle_to(dir, Vector3.UP))
	if (absf(lat) > lat_tol or heading_off > 0.35) and absf(along) < 1.6 and car.get_speed() < 0.4 and room > 0.0:
		# 옆으로 어긋났거나 비스듬히 섰다: 제자리에서 돌 수 없으니 뒤로 뺐다가 다시 들어간다
		_reapproach = room
		return false
	var err := 0.0
	if along > 1.2:
		# 중심선 위, 차보다 5m 앞의 점을 쫓는다(순수 추적). 드리프트가 있는 아케이드 차라 짧게 보면 좌우로 흔들린다.
		var aim := point - dir * maxf(along - 5.0, 0.0)
		var to := aim - p
		to.y = 0.0
		err = _steer_heading(to.normalized())
	else:
		err = _steer_heading(dir, point, true)
	if along > tol:
		if v_along * STOP_K >= along - 0.1:
			if v_along > 0.15: _press("back")
		else:
			_press("forward", clampf(along / 6.0, 0.35, 0.75) * (1.0 - minf(absf(err), 1.0) * 0.5))
	elif along < -tol:
		if -v_along * STOP_K >= -along - 0.1:
			if v_along < -0.15: _press("forward")
		else:
			_press("back", clampf(-along / 3.0, 0.5, 1.0))
	else:
		if v_along > 0.15: _press("back")
		elif v_along < -0.15: _press("forward")
		elif car.get_speed() < 0.15 + tol * 0.4:
			return true
	return false


## 패드 중앙에 패드 방향으로 멈춰 주차 완료될 때까지. 완료되면 true.
func _park(pad: ParkingPad, room := 7.0) -> bool:
	if pad.state == ParkingPad.State.CHARGED and pad.latched:
		return true
	var d: Vector3 = pad.global_basis.z
	d.y = 0.0
	if _flat_fwd().dot(d) < 0.0:
		d = -d # 패드는 양방향 주차를 받으므로 차가 이미 보는 쪽으로 넣는다(유턴 방지)
	if _reapproach <= 0.0 and pad.car_inside(car) and car.get_speed() < 2.0:
		# 이미 칸 안이면 더 맞추지 않고 세워서 충전을 기다린다
		if car.linear_velocity.dot(_flat_fwd()) > 0.15:
			_press("back")
		elif car.linear_velocity.dot(_flat_fwd()) < -0.15:
			_press("forward")
		return false
	# 옆 허용 오차: 차 옆면이 칸 밖으로 나가지 않을 만큼(상자 차 0.6, 로드스터 0.35)
	_stop_at(pad.global_position, d.normalized(), room, 0.25, minf(0.8, pad.size.x * 0.5 - car.footprint.x - 0.12))
	return false


func _v(v: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [v.x, v.y, v.z]
