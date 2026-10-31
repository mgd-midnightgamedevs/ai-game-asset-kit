extends "res://tests/pilot_base.gd"
## DAY 8 자동 주행(경찰차 따돌리기): 곧장 회사 정면으로 전속력 → 흡착 팬을 켜고 밑동 곡면·벽·둥근 모서리를 타고
## 옥상으로 → 옥상 칸에 댄다. 사람과 같은 입력만 쓴다.
## 실행: Godot --headless --fixed-fps 60 --path . res://tests/autopilot_day8.tscn [-- fan_z=55 ...]

var p := {
	"fan_z": 50.0, ## 이 z부터 흡착 팬을 켠다
	"throttle": 1.0, ## 0.6처럼 낮추면 경찰에 잡혀야 한다
}

enum S { WAIT, RUN, CLIMB, PARK, DONE }
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
	print("AUTOPILOT_DAY8 start ", p)


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
			_press("forward", p.throttle)
			if pos.z >= p.fan_z:
				_go(S.CLIMB)
		S.CLIMB:
			if pos.y < 0.5:
				_steer_heading(Vector3.BACK, Vector3.ZERO, true)
			_press("forward")
			_press("magnet")
			if pos.y > game.ROOF_Y - 1.0 and car.is_grounded() and car.get_up().y > 0.9:
				_go(S.PARK)
		S.PARK:
			_park(game.spot, 3.0)
		S.DONE:
			if st > 6.5 or game.phase == game.Phase.FAIL or game.phase == game.Phase.LOSE:
				print("AUTOPILOT_DAY8 done t=%.2f phase=%s clock=%s" % [t, game.Phase.keys()[game.phase], game._fmt_clock(game.clock)])
				get_tree().quit()

	if t > 60.0 or (state != S.WAIT and pos.y < -5.0):
		print("AUTOPILOT_DAY8 FAIL state=%s pos=%s" % [S.keys()[state], _v(pos)])
		get_tree().quit(1)

	_log_t += delta
	if _log_t >= 0.25:
		_log_t = 0.0
		var cp: Vector3 = game.rival.global_position
		print("t=%5.2f %-5s pos=%s spd=%5.2f police_z=%.1f police_v=%.1f gap=%.1f" % [t, S.keys()[state], _v(pos), car.get_speed(), cp.z, game.rival.speed, pos.z - cp.z])


func _go(next: S) -> void:
	print("STATE %s -> %s at t=%.2f" % [S.keys()[state], S.keys()[next], t])
	state = next
	st = 0.0
