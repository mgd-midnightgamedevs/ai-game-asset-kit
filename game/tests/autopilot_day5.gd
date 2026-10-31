extends "res://tests/pilot_base.gd"
## DAY 5 자동 주행: 왼쪽 빈 차선으로 빠져 달리다 리프트(Space)로 화물열차를 넘고 → 착지해 건널목 너머 칸에 댄다.
## 사람과 같은 입력만 쓴다.
## 실행: Godot --headless --fixed-fps 60 --path . res://tests/autopilot_day5.tscn [-- lift_z=10 lift_t=0.6 ...]

var p := {
	"lane_x": 1.8, ## 비어 있는 왼쪽 차선
	"throttle": 0.8,
	"lift_z": 10.5, ## 리프트를 켜는 위치
	"lift_t": 0.6,
}

enum S { WAIT, RUN, JUMP, PARK, DONE }
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
	print("AUTOPILOT_DAY5 start ", p)


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
			_steer_heading(Vector3.BACK, Vector3(p.lane_x, 0, 0), true)
			_press("forward", p.throttle)
			if pos.z >= p.lift_z:
				_go(S.JUMP)
		S.JUMP:
			if st < p.lift_t:
				_press("rocket")
			_steer_heading(Vector3.BACK)
			if st > 0.5 and car.is_grounded():
				_go(S.PARK)
		S.PARK:
			if game.phase != game.Phase.PLAY:
				_go(S.DONE)
			else:
				_park(game.spot, 4.0)
		S.DONE:
			if st > 6.5 or game.phase == game.Phase.FAIL:
				print("AUTOPILOT_DAY5 done t=%.2f phase=%s clock=%s" % [t, game.Phase.keys()[game.phase], game._fmt_clock(game.clock)])
				get_tree().quit()

	if t > 60.0 or (state != S.WAIT and pos.y < -5.0):
		print("AUTOPILOT_DAY5 FAIL state=%s pos=%s" % [S.keys()[state], _v(pos)])
		get_tree().quit(1)

	_log_t += delta
	if _log_t >= 0.25:
		_log_t = 0.0
		print("t=%5.2f %-5s pos=%s spd=%5.2f train_x=%.1f rival=%.2f hold=%s" % [t, S.keys()[state], _v(pos), car.get_speed(),
			game._train_x, game.rival.progress, game.rival.hold])


func _go(next: S) -> void:
	print("STATE %s -> %s at t=%.2f" % [S.keys()[state], S.keys()[next], t])
	state = next
	st = 0.0
