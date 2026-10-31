extends "res://tests/pilot_base.gd"
## DAY 실패 규칙 확인: crash(앞차에 전속력으로 박기) 또는 flip(지붕으로 떨어뜨리기) 뒤 FAIL이 되는지.
## 실행: Godot --headless --fixed-fps 60 --path . res://tests/fail_check.tscn -- mode=crash|flip|slow [hold=초]
## hold: FAIL 뒤 끝내기까지 기다리는 시간. DAY는 2.4초 뒤 저절로 다시 시작하니 그보다 짧게(녹화는 2.2)

var mode := "crash"
var hold := 1.0
var t := 0.0
var game
var _done := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("mode="):
			mode = a.split("=")[1]
		elif a.begins_with("hold="):
			hold = float(a.split("=")[1])
	game = get_child(0)
	car = game.get_node("Roadster")
	car.crashed.connect(func(kind, impact): print("CRASHED %s impact=%.1f t=%.2f pos=%s" % [kind, impact, t, _v(car.get_vehicle_position())]))
	print("FAIL_CHECK ", mode)


func _physics_process(delta: float) -> void:
	t += delta
	_release_all()
	if game.phase == game.Phase.PLAY:
		match mode:
			"crash":
				_steer_heading(Vector3.BACK, Vector3(game.LANE_X, 0, 0), true)
				_press("forward")
			"slow":
				_steer_heading(Vector3.BACK, Vector3(game.LANE_X, 0, 0), true)
				_press("forward", 0.22)
			"flip":
				if not _done:
					_done = true
					car.respawn_at(Transform3D(Basis(Vector3.BACK, PI), Vector3(game.LANE_X, 1.5, 4.0)))
	if game.phase == game.Phase.FAIL and game.phase_t > hold:
		print("PHASE FAIL ok t=%.2f retries(before reload)=%d" % [t, game.retries])
		get_tree().quit()
	if t > 14.0:
		print("END phase=%s t=%.2f pos=%s rival=%.2f" % [game.Phase.keys()[game.phase], t, _v(car.get_vehicle_position()), game.rival.progress])
		get_tree().quit()
