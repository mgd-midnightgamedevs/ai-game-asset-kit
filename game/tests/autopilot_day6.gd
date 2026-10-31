extends "res://tests/pilot_base.gd"
## DAY 6 자동 주행(배달 세 곳): 길에서 리프트로 6m 테라스 → 배달 → 조금 달려 리프트+메인으로 12m 테라스 → 배달
## → 타워 밑동 곡면으로 흡착 팬을 켜고 벽을 타 둥근 모서리를 넘어 30m 옥상 → 배달. 사람과 같은 입력만 쓴다.
## 실행: Godot --headless --fixed-fps 60 --path . res://tests/autopilot_day6.tscn [-- lift1_z=8 ...]

var p := {
	"throttle1": 0.8,
	"lift1_z": 8.0, ## 길에서 1층 테라스로 뛰는 위치(9.0이면 로드스터의 긴 코가 테라스 벽에 걸린다. 7.5~8.5 둘 다 통과)
	"lift1_t": 0.55,
	"run2_t": 0.45, ## 1번 칸에서 2층으로 뛰기 전에 달리는 시간
	"lift2_t": 0.6,
	"main2_t": 0.25,
}

enum S { WAIT, RUN, JUMP1, PARK1, RUN2, JUMP2, PARK2, CLIMB, PARK3, DONE }
var state := S.WAIT
var t := 0.0
var st := 0.0
var game
var _log_t := 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2 and p.has(kv[0]):
			p[kv[0]] = float(kv[1])
	game = get_child(0)
	car = game.get_node("Roadster")
	car.landed.connect(func(up, air_t, spin): print("LANDED t=%.2f upright=%s air=%.2f spin=%.0f pos=%s" % [t, up, air_t, spin, _v(car.get_vehicle_position())]))
	car.crashed.connect(func(kind, impact): print("CRASHED %s impact=%.1f t=%.2f pos=%s" % [kind, impact, t, _v(car.get_vehicle_position())]))
	await get_tree().process_frame
	game.hud.toggle_help()
	print("AUTOPILOT_DAY6 start ", p)


func _physics_process(delta: float) -> void:
	t += delta
	st += delta
	_release_all()
	var pos := car.get_vehicle_position()
	if game.phase != game.Phase.PLAY and state != S.WAIT and state != S.DONE:
		_go(S.DONE)
	match state:
		S.WAIT:
			if game.phase == game.Phase.PLAY:
				_go(S.RUN)
		S.RUN:
			_steer_heading(Vector3.BACK, Vector3.ZERO, true)
			_press("forward", p.throttle1)
			if pos.z >= p.lift1_z:
				_go(S.JUMP1)
		S.JUMP1:
			if st < p.lift1_t:
				_press("rocket")
			if st > 0.5 and car.is_grounded():
				_go(S.PARK1)
		S.PARK1:
			_park(game.stops[0], 3.0)
			if game.delivered >= 1:
				_go(S.RUN2)
		S.RUN2:
			_steer_heading(Vector3.BACK, Vector3.ZERO, true)
			_press("forward")
			if st >= p.run2_t:
				_go(S.JUMP2)
		S.JUMP2:
			_steer_heading(Vector3.BACK)
			if st < p.lift2_t:
				_press("rocket")
			if st > 0.2 and st < 0.2 + p.main2_t:
				_press("boost")
			if st > 0.5 and car.is_grounded():
				_go(S.PARK2)
		S.PARK2:
			_park(game.stops[1], 2.0)
			if game.delivered >= 2:
				_go(S.CLIMB)
		S.CLIMB:
			if pos.y < game.T2_Y + 0.5:
				_steer_heading(Vector3.BACK, Vector3.ZERO, true)
			_press("forward")
			_press("magnet")
			if pos.y > game.ROOF_Y - 1.0 and car.is_grounded() and car.get_up().y > 0.9:
				_go(S.PARK3)
		S.PARK3:
			_park(game.stops[2], 3.0)
		S.DONE:
			if st > 6.5 or game.phase == game.Phase.FAIL or game.phase == game.Phase.LOSE:
				print("AUTOPILOT_DAY6 done t=%.2f phase=%s clock=%s delivered=%d" % [t, game.Phase.keys()[game.phase], game._fmt_clock(game.clock), game.delivered])
				get_tree().quit()

	if t > 90.0 or (state != S.WAIT and pos.y < -5.0):
		print("AUTOPILOT_DAY6 FAIL state=%s pos=%s" % [S.keys()[state], _v(pos)])
		get_tree().quit(1)

	_log_t += delta
	if _log_t >= 0.25:
		_log_t = 0.0
		print("t=%5.2f %-6s pos=%s spd=%5.2f air=%5.1f att=%s up=%s delivered=%d" % [t, S.keys()[state], _v(pos), car.get_speed(), car.air, car.attached, _v(car.up_dir), game.delivered])


func _go(next: S) -> void:
	print("STATE %s -> %s at t=%.2f" % [S.keys()[state], S.keys()[next], t])
	state = next
	st = 0.0
