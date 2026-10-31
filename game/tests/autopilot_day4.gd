extends "res://tests/pilot_base.gd"
## DAY 4 자동 주행: 길을 달리다 오른쪽 벽 밑동 곡면으로 비스듬히 들어가 흡착 팬으로 벽을 타고 오르고
## → 정한 높이에서 리프트(Space)로 벽을 차고 길 건너 옥상으로 날아가며 공중에서 칸 방향으로 돌고 → 착지해 칸에 댄다.
## 사람과 같은 입력만 쓴다.
## 실행: Godot --headless --fixed-fps 60 --path . res://tests/autopilot_day4.tscn [-- in_deg=35 kick_y=10 ...]

var p := {
	"turn_z": 9.0, ## 이 z에서 벽 쪽으로 꺾는다
	"in_deg": 35.0, ## 벽 쪽으로 꺾는 각도(진행 방향 기준)
	"kick_y": 10.0, ## 이 높이에서 벽을 찬다
	"kick_t": 0.35, ## 리프트 누르는 시간
	"yaw_at": 0.3, ## 벽을 찬 뒤 이 시각부터 공중에서 칸 방향으로 돈다
}

enum S { WAIT, RUN, IN, CLIMB, KICK, PARK, DONE }
var state := S.WAIT
var t := 0.0
var st := 0.0
var game
var _log_t := 0.0
var _kick_dir := Vector3.ZERO


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2 and p.has(kv[0]):
			p[kv[0]] = float(kv[1])
	game = get_child(0)
	car = game.get_node("Roadster")
	car.debug_contacts = OS.get_cmdline_user_args().has("debug")
	car.landed.connect(func(up, air_t, spin): print("LANDED t=%.2f upright=%s air=%.2f spin=%.0f pos=%s" % [t, up, air_t, spin, _v(car.get_vehicle_position())]))
	car.crashed.connect(func(kind, impact): print("CRASHED %s impact=%.1f t=%.2f pos=%s" % [kind, impact, t, _v(car.get_vehicle_position())]))
	await get_tree().process_frame
	game.hud.toggle_help()
	print("AUTOPILOT_DAY4 start ", p)


func _physics_process(delta: float) -> void:
	t += delta
	st += delta
	_release_all()
	var pos := car.get_vehicle_position()
	match state:
		S.WAIT:
			if game.phase == game.Phase.PLAY:
				_go(S.RUN)
		S.RUN:
			_steer_heading(Vector3.BACK, Vector3(1.0, 0, 0), true)
			_press("forward")
			if pos.z >= p.turn_z:
				_go(S.IN)
		S.IN:
			var a := deg_to_rad(p.in_deg)
			if pos.y < 0.3:
				_steer_heading(Vector3(-sin(a), 0, cos(a)))
			_press("forward")
			_press("magnet")
			if car.attached and car.on_wall:
				_go(S.CLIMB)
		S.CLIMB:
			_press("forward")
			_press("magnet")
			if pos.y >= p.kick_y:
				print("KICK pos=%s vel=%s" % [_v(pos), _v(car.linear_velocity)])
				_go(S.KICK)
		S.KICK:
			if st < p.kick_t:
				_press("rocket")
			if _kick_dir == Vector3.ZERO:
				# 칸 방향 축 중 날아가는 쪽(길 건너)을 보게 한다. 공중에서 도는 중에 다시 고르면 반대쪽으로 돌 수 있다
				_kick_dir = game.spot.global_basis.z
				_kick_dir.y = 0.0
				if car.linear_velocity.dot(_kick_dir) < 0.0:
					_kick_dir = -_kick_dir
				_kick_dir = _kick_dir.normalized()
			if st > p.yaw_at and not car.is_grounded():
				_steer_heading(_kick_dir)
			if st > 0.4 and car.is_grounded():
				_go(S.PARK)
		S.PARK:
			if game.phase == game.Phase.WIN or game.phase == game.Phase.LOSE or game.phase == game.Phase.FAIL:
				_go(S.DONE)
			else:
				_park(game.spot, 3.0)
		S.DONE:
			if st > 6.5 or game.phase == game.Phase.FAIL:
				print("AUTOPILOT_DAY4 done t=%.2f phase=%s clock=%s" % [t, game.Phase.keys()[game.phase], game._fmt_clock(game.clock)])
				get_tree().quit()

	if t > 60.0 or (state != S.WAIT and pos.y < -5.0):
		print("AUTOPILOT_DAY4 FAIL state=%s pos=%s" % [S.keys()[state], _v(pos)])
		get_tree().quit(1)

	_log_t += delta
	if _log_t >= 0.25:
		_log_t = 0.0
		print("t=%5.2f %-5s pos=%s spd=%5.2f fwd=%s vfwd=%5.2f att=%s rival=%.2f%s" % [t, S.keys()[state], _v(pos), car.get_speed(),
			_v(car.get_forward()), car.forward_speed(), car.attached, game.rival.progress, " BLOCKED" if game.rival.blocked else ""])


func _go(next: S) -> void:
	print("STATE %s -> %s at t=%.2f" % [S.keys()[state], S.keys()[next], t])
	state = next
	st = 0.0
