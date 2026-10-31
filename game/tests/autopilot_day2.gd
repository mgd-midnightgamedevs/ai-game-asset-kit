extends "res://tests/pilot_base.gd"
## DAY 2 자동 주행: 1층 통로 → 흡착 팬으로 말린 램프 → 거꾸로 이탈(손 떼면 자동 자세 복원) → 옥상 착지
## → 통로를 따라 내려가다 왼쪽으로 꺾어 빈칸에 댄다. 사람과 같은 입력만 쓴다.
## 실행: Godot --headless --fixed-fps 60 --path . res://tests/autopilot_day2.tscn [-- turn_lead=3.7 ...]

var p := {
	"turn_lead": 3.7, ## 칸 중심보다 이만큼 앞(z)에서 왼쪽으로 꺾기 시작(로드스터 3.1~4.3, 상자 차 2.2~4.3 통과)
	"settle_fwd": 0.8, ## 착지 뒤 방향을 잡으며 굴러가는 힘(10/23 사용자: 올라간 다음 주차가 너무 느리다)
	"settle_max": 5.0, ## 이보다 빠르면 브레이크
	"settle_err": 0.3, ## 방향 오차(rad)가 이 안이면 통로를 따라간다
	"run_fwd": 0.6, ## 통로를 따라 내려가는 힘
	"turn_fwd": 0.45, ## 칸으로 꺾는 힘
	"run_x": 1.8, ## 1층 통로를 달리는 줄(x). 옆으로 떠서 내려앉는 만큼 미리 비켜 달린다
	"aisle_x": 1.0, ## 옥상 통로를 내려가는 줄(x). 칸 반대쪽으로 붙어 가면 꺾을 자리가 넓어 한 번에 들어간다
	"boost_run": 0.0, ## 1이면 1층 통로에서 Shift(메인 추진)도 누른다(램프 들머리 사고 확인용)
}

enum S { WAIT, RUN, AIR, SETTLE, TO_TURN, TURN, PARK, DONE }
var state := S.WAIT
var t := 0.0
var st := 0.0
var game
var _log_t := 0.0
var _stuck := 0.0
var _back_t := 0.0 ## > 0이면 막혀서 뒤로 빼는 중


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
	print("AUTOPILOT_DAY2 start ", p)


func _physics_process(delta: float) -> void:
	t += delta
	st += delta
	_release_all()
	var pos := car.get_vehicle_position()
	var spot: Vector3 = game.spot_center
	match state:
		S.WAIT:
			if game.phase == game.Phase.PLAY:
				_go(S.RUN)
		S.RUN:
			_steer_heading(Vector3.BACK, Vector3(p.run_x, 0, 0), true)
			_press("forward")
			_press("magnet")
			if p.boost_run > 0.0 and pos.z > 30.0:
				_press("boost")
			if pos.y > 3.0 and not car.attached:
				_go(S.AIR)
		S.AIR:
			if st > 0.3 and car.is_grounded() and pos.y > game.DECK_Y - 1.0:
				_go(S.SETTLE)
		S.SETTLE:
			if _back_t > 0.0:
				# 옆으로 내려앉아 코가 세워 둔 차에 닿았다: 곧게 조금 뒤로 뺀다
				# (꺾으면서 빼면 꼬리가 옥상 뒤 끝으로 돌아 떨어진다)
				_back_t -= delta
				_press("back", 0.6)
			else:
				var e := _steer_heading(Vector3.FORWARD, Vector3(p.aisle_x, 0, 0), true)
				if car.get_speed() > p.settle_max:
					_press("back", 0.6)
				else:
					_press("forward", p.settle_fwd) # 제자리에서는 돌 수 없으니 굴러가며 방향을 잡는다
					_stuck = _stuck + delta if st > 0.6 and car.get_speed() < 0.2 else 0.0
					if _stuck > 0.4:
						_stuck = 0.0
						_back_t = 0.6
				if st > 0.15 and absf(e) < p.settle_err:
					_go(S.TO_TURN)
		S.TO_TURN:
			_steer_heading(Vector3.FORWARD, Vector3(p.aisle_x, 0, 0), true)
			_press("forward", p.run_fwd)
			if pos.z <= spot.z + p.turn_lead:
				_go(S.TURN)
		S.TURN:
			var e2 := _steer_heading(Vector3.LEFT)
			_press("forward", p.turn_fwd)
			if absf(e2) < 0.15:
				_go(S.PARK)
		S.PARK:
			if game.phase == game.Phase.WIN or game.phase == game.Phase.LOSE:
				_go(S.DONE)
			else:
				_park(game.spot, 2.5)
		S.DONE:
			if st > 6.5:
				print("AUTOPILOT_DAY2 done t=%.2f phase=%s clock=%s" % [t, game.Phase.keys()[game.phase], game._fmt_clock(game.clock)])
				get_tree().quit()

	if t > 60.0 or (state != S.WAIT and pos.y < -5.0):
		print("AUTOPILOT_DAY2 FAIL state=%s pos=%s" % [S.keys()[state], _v(pos)])
		get_tree().quit(1)

	_log_t += delta
	if _log_t >= 0.5:
		_log_t = 0.0
		print("t=%5.2f %-7s pos=%s spd=%5.2f rival=%.2f%s" % [t, S.keys()[state], _v(pos), car.get_speed(),
			game.rival.progress, " BLOCKED" if game.rival.blocked else ""])


func _go(next: S) -> void:
	print("STATE %s -> %s at t=%.2f" % [S.keys()[state], S.keys()[next], t])
	state = next
	st = 0.0
