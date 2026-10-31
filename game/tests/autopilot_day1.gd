extends "res://tests/pilot_base.gd"
## DAY 1 자동 주행(시연·촬영용). 사람과 같은 입력만 쓴다.
## 앞차 뒤에서 달려와 리프트로 넘고 → 공중에서 오른쪽으로 90도(D) → 메인 추진으로 칸 쪽으로 밀고 → 착지 → 칸 맞추기.
## 실행: Godot --headless --fixed-fps 60 --path . res://tests/autopilot_day1.tscn [-- lift_z=13 throttle=0.6 ...]

var p := {
	"throttle": 0.62, ## 달려오는 속도(전진 입력 세기)
	"lift_z": 16.8, ## 리프트를 켜는 위치
	"lift_t": 0.5, ## 리프트 누르는 시간
	"yaw_at": 0.18, ## 리프트 뒤 회전 시작
	"main_t": 0.1, ## 회전이 끝난 뒤 메인 추진 시간
}

enum S { WAIT, RUN, AIR, PARK, DONE }
var state := S.WAIT
var t := 0.0
var st := 0.0
var game
var _yawed_at := -1.0
var _log_t := 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2 and p.has(kv[0]):
			p[kv[0]] = float(kv[1])
	game = $Day1
	car = game.get_node("Roadster")
	car.landed.connect(func(up, air_t, spin): print("LANDED t=%.2f upright=%s air=%.2f spin=%.0f pos=%s" % [t, up, air_t, spin, _v(car.get_vehicle_position())]))
	await get_tree().process_frame
	game.hud.toggle_help()
	print("AUTOPILOT_DAY1 start ", p)


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
			_steer_heading(Vector3.BACK, Vector3(game.LANE_X, 0, 0), true)
			_press("forward", p.throttle)
			if pos.z >= p.lift_z:
				_go(S.AIR)
		S.AIR:
			if st < p.lift_t:
				_press("rocket")
			var heading_err := _flat_fwd().angle_to(Vector3.LEFT) # 칸(-X) 쪽을 보게
			if st > p.yaw_at and _yawed_at < 0.0:
				if heading_err > 0.12:
					_press("right")
				else:
					_yawed_at = st
			if _yawed_at > 0.0 and st < _yawed_at + p.main_t:
				_press("boost")
			if st > 0.4 and car.is_grounded():
				_go(S.PARK)
		S.PARK:
			if game.phase == game.Phase.WIN or game.phase == game.Phase.LOSE:
				_go(S.DONE)
			else:
				_park(game.spot, 3.0)
		S.DONE:
			if st > 6.5:
				print("AUTOPILOT_DAY1 done t=%.2f phase=%s clock=%s" % [t, game.Phase.keys()[game.phase], game._fmt_clock(game.clock)])
				get_tree().quit()

	if t > 40.0:
		print("AUTOPILOT_DAY1 FAIL timeout state=%s pos=%s" % [S.keys()[state], _v(pos)])
		get_tree().quit(1)

	_log_t += delta
	if _log_t >= 0.25:
		_log_t = 0.0
		print("t=%5.2f %-5s pos=%s spd=%5.2f rival=%.2f%s air=%5.1f" % [t, S.keys()[state], _v(pos), car.get_speed(),
			game.rival.progress, " BLOCKED" if game.rival.blocked else "", car.air])


func _go(next: S) -> void:
	print("STATE %s -> %s at t=%.2f" % [S.keys()[state], S.keys()[next], t])
	state = next
	st = 0.0
