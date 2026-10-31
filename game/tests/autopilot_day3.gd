extends "res://tests/pilot_base.gd"
## DAY 3 자동 주행: 길을 따라가다 건물 쪽(-X)으로 꺾어 엘리베이터 옆에 서고
## → 리프트로 솟구쳐 메인을 짧게 뿜어 난간을 넘고 → 옥상 빈칸에 내려앉는다. 사람과 같은 입력만 쓴다.
## 실행: Godot --headless --fixed-fps 60 --path . res://tests/autopilot_day3.tscn [-- lift_t=0.75 main_at=0.5 ...]

var p := {
	"turn_z": 19.0, ## 이 z에서 건물 쪽으로 꺾는다
	"run_throttle": 0.6,
	"lift_t": 0.85,
	"main_at": 0.45,
	"main_t": 0.55,
	"aim_dz": -3.0, ## 겨누는 점을 칸 중심에서 z로 이만큼 옮긴다(2.75m 로드스터는 -3에서 바로 서서 칸에 내려앉는다, 10/24)
	"yaw_at": 1.25, ## 이륙 뒤 이 시각부터(메인 분사가 끝난 뒤) 공중에서 칸 방향으로 돈다(대각선으로 날아가도 칸과 나란히 착지)
}

enum S { WAIT, RUN, TURN, STOP, LIFT, PARK, DONE }
var state := S.WAIT
var t := 0.0
var st := 0.0
var game
var _log_t := 0.0
var _launch_dir := Vector3.ZERO


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2 and p.has(kv[0]):
			p[kv[0]] = float(kv[1])
	game = get_child(0)
	car = game.get_node("Roadster")
	car.landed.connect(func(up, air_t, spin): print("LANDED t=%.2f upright=%s air=%.2f spin=%.0f pos=%s" % [t, up, air_t, spin, _v(car.get_vehicle_position())]))
	await get_tree().process_frame
	game.hud.toggle_help()
	print("AUTOPILOT_DAY3 start ", p)


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
			_steer_heading(Vector3.BACK, Vector3(2.2, 0, 0), true)
			_press("forward", p.run_throttle)
			if pos.z >= p.turn_z:
				_go(S.TURN)
		S.TURN:
			# 엘리베이터 남쪽에서 칸을 바로 겨눈다(엘리베이터 통로 안에는 올라가는 앞차가 있다)
			if _launch_dir == Vector3.ZERO:
				var to: Vector3 = game.spot_center + Vector3(0, 0, p.aim_dz) - pos
				to.y = 0.0
				_launch_dir = to.normalized()
			var e := _steer_heading(_launch_dir)
			_press("forward", 0.35)
			if absf(e) < 0.1:
				_go(S.STOP)
		S.STOP:
			_steer_heading(_launch_dir)
			if car.linear_velocity.dot(_flat_fwd()) > 0.2:
				_press("back")
			if st > 0.3 and car.get_speed() < 0.35:
				print("TAKEOFF pos=%s dir=%s" % [_v(pos), _v(_flat_fwd())])
				_go(S.LIFT)
		S.LIFT:
			if st < p.lift_t:
				_press("rocket")
			if st > p.main_at and st < p.main_at + p.main_t:
				_press("boost")
			if st > p.yaw_at and not car.is_grounded():
				var d: Vector3 = game.spot.global_basis.z
				d.y = 0.0
				if _flat_fwd().dot(d) < 0.0:
					d = -d
				_steer_heading(d.normalized())
			if st > 0.5 and car.is_grounded():
				_go(S.PARK)
		S.PARK:
			if game.phase == game.Phase.WIN or game.phase == game.Phase.LOSE:
				_go(S.DONE)
			else:
				_park(game.spot, 2.0)
		S.DONE:
			if st > 6.5:
				print("AUTOPILOT_DAY3 done t=%.2f phase=%s clock=%s" % [t, game.Phase.keys()[game.phase], game._fmt_clock(game.clock)])
				get_tree().quit()

	if t > 60.0 or (state != S.WAIT and pos.y < -5.0):
		print("AUTOPILOT_DAY3 FAIL state=%s pos=%s" % [S.keys()[state], _v(pos)])
		get_tree().quit(1)

	_log_t += delta
	if _log_t >= 0.5:
		_log_t = 0.0
		print("t=%5.2f %-5s pos=%s spd=%5.2f rival=%.2f%s" % [t, S.keys()[state], _v(pos), car.get_speed(),
			game.rival.progress, " BLOCKED" if game.rival.blocked else ""])


func _go(next: S) -> void:
	print("STATE %s -> %s at t=%.2f" % [S.keys()[state], S.keys()[next], t])
	state = next
	st = 0.0
