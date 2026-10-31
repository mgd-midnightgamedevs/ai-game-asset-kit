extends "res://tests/pilot_base.gd"
## DAY 7 자동 주행: 리프트를 길게 눌러 고가도로(9m) 위로 → 차로를 건너 → 반대편 난간 앞에서 다시 리프트로 넘어
## 9m 아래 북쪽 길로 내려와 → 맛집 칸에 댄다. 사람과 같은 입력만 쓴다.
## 실행: Godot --headless --fixed-fps 60 --path . res://tests/autopilot_day7.tscn [-- lift1_t=0.8 hop_z=35 ...]

var p := {
	"throttle": 0.75,
	"run_x": -1.8, ## 이 줄을 따라 달린다(맛집 칸과 같은 줄)
	"lift1_z": 9.0, ## 길에서 고가도로로 뛰는 위치
	"lift1_t": 0.8,
	"main1_at": 0.5,
	"main1_t": 0.3,
	"hop_z": 34.5, ## 고가도로 위에서 반대편 난간을 넘으려고 리프트를 켜는 위치
	"lift2_t": 0.35,
}

enum S { WAIT, RUN, JUMP1, DECK, JUMP2, PARK, DONE }
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
	print("AUTOPILOT_DAY7 start ", p)


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
			_steer_heading(Vector3.BACK, Vector3(p.run_x, 0, 0), true)
			_press("forward", p.throttle)
			if pos.z >= p.lift1_z:
				_go(S.JUMP1)
		S.JUMP1:
			_steer_heading(Vector3.BACK)
			if st < p.lift1_t:
				_press("rocket")
			if st > p.main1_at and st < p.main1_at + p.main1_t:
				_press("boost")
			if st > 0.5 and car.is_grounded():
				_go(S.DECK if pos.y > game.DECK_Y - 1.0 else S.PARK)
		S.DECK:
			_steer_heading(Vector3.BACK)
			_press("forward")
			if pos.z >= p.hop_z:
				_go(S.JUMP2)
		S.JUMP2:
			_steer_heading(Vector3.BACK)
			if st < p.lift2_t:
				_press("rocket")
			if st > 0.5 and car.is_grounded():
				_go(S.PARK)
		S.PARK:
			_park(game.spot, 4.0)
		S.DONE:
			if st > 6.5 or game.phase == game.Phase.FAIL or game.phase == game.Phase.LOSE:
				print("AUTOPILOT_DAY7 done t=%.2f phase=%s clock=%s" % [t, game.Phase.keys()[game.phase], game._fmt_clock(game.clock)])
				get_tree().quit()

	if t > 60.0 or (state != S.WAIT and pos.y < -5.0):
		print("AUTOPILOT_DAY7 FAIL state=%s pos=%s" % [S.keys()[state], _v(pos)])
		get_tree().quit(1)

	_log_t += delta
	if _log_t >= 0.25:
		_log_t = 0.0
		print("t=%5.2f %-5s pos=%s spd=%5.2f air=%5.1f rival=%.2f" % [t, S.keys()[state], _v(pos), car.get_speed(), car.air, game.rival.progress])


func _go(next: S) -> void:
	print("STATE %s -> %s at t=%.2f" % [S.keys()[state], S.keys()[next], t])
	state = next
	st = 0.0
