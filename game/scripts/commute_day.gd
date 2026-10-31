extends Node3D
## 출근길 주차 전쟁 — 요일 레벨 공통 진행.
## 요일 스크립트(day1.gd, day2.gd, …)가 상속해서 _configure()·_build_world()·_setup_rival()만 채운다.
## 진행: 소개 → 경주(목표 칸에 바퀴로 멈추면 성공) → 성공 연출(나는 출근, 상대는 씩씩) / 실패.
## 상대 역할(rival_role): "parker"(같은 칸을 노리는 앞차), "police"(쫓아오는 경찰차, DAY 8), "none"(DAY 6 배달).
## 실패: 앞차가 먼저 대거나 경찰에 잡히거나 마감 시각이 지나면 LOSE. 세게 박거나 뒤집히면 사고(FAIL) — 짧은 연출 뒤 저절로 다시 시작.
## 키: R 다시, 성공 뒤 Enter 다음 날, Esc 메뉴.

const GRID_SHADER := preload("res://shaders/grid.gdshader")
const BUILDING_SHADER := preload("res://shaders/building.gdshader")
const SURFACE_SHADER := preload("res://shaders/surface.gdshader")
## 바닥 겉면(shaders/surface.gdshader). 예전 격자(COLORS) 대신 쓴다. [바탕, 얼룩, 알갱이, 블록 크기, 거칠기]
const SURFACES := {
	"asphalt": [Color(0.16, 0.165, 0.18), Color(0.11, 0.115, 0.125), 0.07, 0.0, 0.88],
	"sidewalk": [Color(0.6, 0.58, 0.55), Color(0.5, 0.48, 0.45), 0.05, 1.2, 0.85],
	"concrete": [Color(0.58, 0.58, 0.57), Color(0.47, 0.47, 0.46), 0.05, 0.0, 0.9],
	"deck": [Color(0.5, 0.51, 0.53), Color(0.4, 0.41, 0.43), 0.05, 0.0, 0.88],
}
## 상자 건물 겉면(shaders/building.gdshader). [벽, 유리, 창틀, 층 높이, 칸 너비, 창 가로·세로 비율, 띠창]
## 맞은편·뒤 건물은 _skyline이 유리·콘크리트·벽돌·석재 가운데 골라 쓴다. hq는 DAY 1 본사(유리 커튼월)
const BUILDING_STYLES := {
	"glass": [Color(0.3, 0.33, 0.37), Color(0.2, 0.3, 0.38), Color(0.22, 0.24, 0.27), 3.6, 1.6, Vector2(0.9, 0.82), 0.0],
	"concrete": [Color(0.74, 0.72, 0.67), Color(0.18, 0.23, 0.29), Color(0.3, 0.3, 0.31), 3.5, 2.6, Vector2(1.0, 0.48), 1.0],
	"brick": [Color(0.52, 0.32, 0.26), Color(0.14, 0.17, 0.21), Color(0.24, 0.2, 0.19), 3.1, 2.2, Vector2(0.46, 0.56), 0.0],
	"stone": [Color(0.82, 0.79, 0.72), Color(0.2, 0.25, 0.3), Color(0.36, 0.34, 0.31), 3.0, 2.8, Vector2(0.56, 0.5), 0.0],
	"hq": [Color(0.34, 0.38, 0.43), Color(0.2, 0.31, 0.42), Color(0.2, 0.22, 0.25), 3.8, 1.8, Vector2(0.92, 0.84), 0.0],
}
const FONT := preload("res://fonts/Pretendard-Bold.otf")
const PARK_TIME := 0.8
const INTRO_TIME := 1.6
const RETRY_INTRO_TIME := 0.9 ## 사고 뒤 다시 할 때는 소개를 짧게
const FAIL_TIME := 2.4 ## 사고 연출 뒤 저절로 다시 시작
const PERSON_SCALE := 0.8
const DAYS := ["res://scenes/day1.tscn", "res://scenes/day2.tscn", "res://scenes/day3.tscn", "res://scenes/day4.tscn",
	"res://scenes/day5.tscn", "res://scenes/day6.tscn", "res://scenes/day7.tscn", "res://scenes/day8.tscn"]
const MENU := "res://scenes/menu.tscn"

const COLORS := {
	"asphalt": [Color(0.14, 0.15, 0.17), Color(0.17, 0.18, 0.2)],
	"concrete": [Color(0.55, 0.55, 0.56), Color(0.42, 0.42, 0.44)],
	"deck": [Color(0.46, 0.48, 0.52), Color(0.35, 0.37, 0.41)],
	"sidewalk": [Color(0.5, 0.47, 0.44), Color(0.4, 0.38, 0.36)],
	"office": [Color(0.5, 0.56, 0.66), Color(0.36, 0.4, 0.5)],
	"building": [Color(0.62, 0.58, 0.54), Color(0.46, 0.43, 0.4)],
	"filler": [Color(0.24, 0.27, 0.36), Color(0.19, 0.21, 0.29)],
	"truck": [Color(0.88, 0.88, 0.86), Color(0.7, 0.7, 0.68)],
	"curl": [Color(0.86, 0.45, 0.16), Color(0.62, 0.3, 0.1)],
}
## Tripo 모델(assets/models/<이름>)로 꾸미는 날에 세워 둘 차
const PARKED_MODELS := ["hatchback", "sedan", "suv", "van"]
const PARKED_COLORS := [Color(0.85, 0.85, 0.87), Color(0.15, 0.16, 0.2), Color(0.55, 0.57, 0.6),
	Color(0.62, 0.1, 0.12), Color(0.2, 0.32, 0.55), Color(0.9, 0.9, 0.9), Color(0.3, 0.3, 0.32)]

enum Phase { INTRO, PLAY, WIN, LOSE, FAIL }

## 같은 날을 몇 번 다시 했는지(장면을 다시 불러와도 남는다)
static var retries := 0
static var _retry_day := -1

# --- 요일마다 _configure()에서 채운다 ---
var day_index := 0 ## DAYS 안의 위치(0 = DAY 1)
var day_name := ""
var intro_text := ""
var start_clock := 8 * 3600 + 59 * 60 + 38.0
var start_xform := Transform3D.IDENTITY
var spot_center := Vector3.ZERO
var spot_yaw_deg := 90.0 ## 칸 깊이 방향(+Z 기준)
var spot_size := Vector2(2.4, 4.2) ## 폭, 깊이. 로드스터(1.46 x 2.75)가 옆 0.47m·앞뒤 0.72m씩 남게 깊이를 3.6에서 늘렸다(폭을 늘리면 줄지은 칸이 다 밀린다)
var cut_cam_pos := Vector3.ZERO
var cut_cam_target := Vector3.ZERO
var win_lines := ["아니 깜빡이\n켰잖아요!!", "…부들부들"]
var lose_line := "먼저\n왔거든요~"
var rival_color := Color(0.55, 0.18, 0.45) ## 앞차 운전자 옷
var rival_paint := Color(0.86, 0.7, 0.32) ## 앞차 색
var rival_role := "parker" ## "parker" | "police" | "none"
var play_hint := "앞차보다 먼저 대면 내 자리"
var deadline := -1.0 ## 이 시각(초)이 지나면 실패. 음수면 없음
var deadline_label := "9시 출근"
var deadline_lose := "9시 넘었다… 지각 확정"
var win_toast := "주차 성공!"
var clear_line := "%s 출근 · 세이프"
var them_pos := Vector3.ZERO ## rival_role "none"일 때 성공 연출에서 말하는 사람 자리
## true면 세워 둔 차·사람·소품을 Tripo 모델로 만들고, 차의 겉모습(M 키)을 따라 처음 상자 버전과 함께 바꾼다.
## 로드스터면 모델(앞차는 노랗게 칠한 SUV), 상자 차면 상자 차·원기둥 사람(소품은 숨긴다). DAY 1~8이 다 쓴다.
var use_models := false

@onready var car: Roadster = $Roadster
@onready var cam = $Camera
@onready var hud = $HUD
var run_time := 0.0 ## 이번 판 기록: 출발(PLAY)부터 주차 완료까지(웹 판 리더보드)
var touch: TouchControls

var phase := Phase.INTRO
var phase_t := 0.0
var clock := 0.0
var spot: ParkingPad
var rival: RivalCar
var me: Commuter
var them: Commuter
var _materials := {}
var _look_box: Array[Node3D] = [] ## 상자 버전에서만 보이는 것(충돌 포함)
var _look_model: Array[Node3D] = [] ## 모델 버전에서만 보이는 것(충돌 포함)
static var _hull_cache := {} ## 모델 이름 → 충돌 모양(장면을 다시 불러와도 다시 만들지 않는다)
var _paint_rng := RandomNumberGenerator.new() ## 세워 둔 차 칠 고르기(요일마다 같은 배색)
var _last_paint := ""
var _walkers: Array = [] ## [사람, 길, 속도, 정방향] (_pedestrian)
var _paint_seeded := false
var _script_step := 0
var _intro_time := INTRO_TIME


# --- 요일 스크립트가 덮어쓴다 ---------------------------------------------
func _configure() -> void:
	pass


func _build_world() -> void:
	pass


func _setup_rival(_r: RivalCar) -> void:
	pass


## 목표가 여럿인 날(배달)은 여기서 칸을 더 만든다. spot은 지금 목표다.
func _setup_goal() -> void:
	pass


## 지금 목표 칸에 주차를 마쳤다. 기본은 성공. 배달처럼 여러 곳을 도는 날은 덮어써서 다음 칸으로 넘긴다.
func _on_spot_done() -> void:
	_win()


## 차에서 내린 사람이 회사(계단) 문까지 걷는 길
func _walk_points(_from: Vector3) -> Array[Vector3]:
	return []


func _day_process(_delta: float) -> void:
	pass


# --- 공통 진행 -------------------------------------------------------------
func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	_configure()
	clock = start_clock
	_build_world()
	touch = TouchControls.new()
	add_child(touch)
	spot = ParkingPad.new()
	spot.title = "마지막 한 칸"
	spot.size = spot_size
	spot.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(spot_yaw_deg)), spot_center)
	add_child(spot)
	spot.set_state(ParkingPad.State.NEXT)
	_setup_goal()

	if rival_role != "none":
		rival = RivalCar.new()
		rival.paint = rival_paint
		rival.police = rival_role == "police"
		if use_models and not rival.police:
			rival.model_name = "suv" # 앞차는 노랗게 칠한 SUV
		rival.player = car
		rival.position = Vector3(0, -30, 0) # 원점에서 시작 위치로 옮겨질 때 내 차를 쓸고 지나가지 않게 땅속에서 만든다
		add_child(rival)
		_setup_rival(rival)
		if rival.police:
			rival.caught.connect(_on_caught)
		else:
			rival.set_spot(spot_center, spot.global_basis.z, spot_size.x * 0.5, spot_size.y * 0.5)
			rival.parked.connect(_on_rival_parked)

	if use_models:
		car.style_changed.connect(_apply_look)
		_apply_look(car.style)
	car.respawn_at(start_xform)
	car.controls_enabled = false
	car.auto_recover = false # 뒤집히면 실패
	car.crashed.connect(_on_car_crashed)
	cam.snap()
	print("DAY %d 준비 %d ms" % [day_index + 1, Time.get_ticks_msec() - t0])
	_report_first_frame.call_deferred()
	if _retry_day != day_index:
		_retry_day = day_index
		retries = 0
	if retries > 0:
		_intro_time = RETRY_INTRO_TIME
		hud.toast("DAY %d · 다시 %d번째" % [day_index + 1, retries + 1], _intro_time + 0.3)
	else:
		hud.toast("DAY %d · %s" % [day_index + 1, intro_text], INTRO_TIME + 0.4)


## 메뉴에서 누른 뒤 첫 화면이 그려지기까지(셰이더 준비 포함)
func _report_first_frame() -> void:
	await RenderingServer.frame_post_draw
	if AssetCache.clicked_ms >= 0:
		print("DAY %d 첫 화면까지 %d ms" % [day_index + 1, Time.get_ticks_msec() - AssetCache.clicked_ms])
		AssetCache.clicked_ms = -1


func _unhandled_input(event: InputEvent) -> void:
	if WebBridge.overlay_open():
		return # 이름 입력·리더보드 창이 떠 있다
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(MENU)
	elif event.is_action_pressed("restart") and phase == Phase.WIN:
		hud.toast("불러오는 중…", 30.0)
		await RenderingServer.frame_post_draw
		get_tree().change_scene_to_file(_next_day_scene())
	elif event.is_action_pressed("respawn") or event.is_action_pressed("restart"):
		_retry()
	elif event.is_action_pressed("help"):
		hud.toggle_help()
	elif event.is_action_pressed("swap_car"):
		car.toggle_style()
		hud.toast("로드스터" if car.style == "roadster" else "상자 차", 1.0)
	elif event.is_action_pressed("paint"):
		hud.toast("배색: " + car.next_palette(), 1.0)


func _physics_process(delta: float) -> void:
	phase_t += delta
	_update_walkers()
	match phase:
		Phase.INTRO:
			if phase_t >= _intro_time:
				_set_phase(Phase.PLAY)
				car.controls_enabled = true
				run_time = 0.0
				WebBridge.start(day_index + 1)
				if rival:
					rival.go()
				hud.toast(play_hint, 1.4)
		Phase.PLAY:
			clock += delta
			run_time += delta
			_check_spot(delta)
			if phase == Phase.PLAY and deadline > 0.0 and clock >= deadline:
				_lose(deadline_lose + "\nR 다시")
		Phase.WIN:
			_win_script()
		Phase.LOSE:
			_lose_script()
		Phase.FAIL:
			if phase_t >= FAIL_TIME:
				_retry()
	_day_process(delta)

	hud.update_state({
		"top_left_cap": "지금",
		"top_left": _fmt_clock(clock),
		"top_left_sub": deadline_label,
		"top_right": "DAY %d" % (day_index + 1),
		"top_right_sub": day_name,
		"air_ratio": car.air / car.air_max,
		"lift": car.lift_firing,
		"main": car.main_firing,
		"fan": car.attached,
		"fan_g": car.fan_g(),
		"park": spot.charge if phase == Phase.PLAY else 0.0, # 주차가 끝나면 막대를 내린다(다 찬 채 화면에 남았다, 10/23)
		"run": run_time if phase != Phase.INTRO else 0.0,
	}, delta)


## 웹 판은 DAY 1~4만(WebBridge.DEMO_DAYS). 마지막 날 다음은 메뉴
func _day_count() -> int:
	return WebBridge.DEMO_DAYS if WebBridge.demo else DAYS.size()


func _next_day_scene() -> String:
	return DAYS[day_index + 1] if day_index + 1 < _day_count() else MENU


func _set_phase(p: Phase) -> void:
	phase = p
	phase_t = 0.0
	_script_step = 0


func _check_spot(delta: float) -> void:
	var inside := spot.car_inside(car)
	if inside and car.is_grounded() and not Input.is_action_pressed("forward"):
		car.settle(delta)
	var ok := car.is_grounded() and car.get_speed() < 0.9 and inside
	if ok:
		spot.charge = minf(spot.charge + delta / PARK_TIME, 1.0)
		if spot.charge >= 1.0:
			_on_spot_done()
	else:
		spot.charge = maxf(spot.charge - delta * 3.0, 0.0)
	spot.update_fill()


func _person(color: Color, briefcase: bool, model := "") -> Commuter:
	var c := Commuter.new()
	c.body_color = color
	c.has_briefcase = briefcase
	if use_models:
		c.model_name = model
		c.show_model = car.style == "roadster"
	c.scale = Vector3.ONE * PERSON_SCALE
	add_child(c)
	return c


func _flat_left(b: Basis) -> Vector3:
	return Vector3.UP.cross(Vector3(b.z.x, 0, b.z.z).normalized())


func _win() -> void:
	_set_phase(Phase.WIN)
	car.controls_enabled = false
	WebBridge.finish(day_index + 1, run_time)
	touch.show_next(true)
	spot.set_state(ParkingPad.State.CHARGED)
	spot.update_fill()
	if rival:
		rival.honk_forever = true
	hud.toast(win_toast, 1.6)

	# 나: 차에서 내려 서류 가방 들고 회사로
	me = _person(Color(0.16, 0.2, 0.32), true, "me")
	me.global_position = car.get_vehicle_position() + _flat_left(car.vehicle_model.global_basis) * 0.9 + Vector3.UP * 0.15
	me.walk_to(_walk_points(me.global_position), 1.6)

	# 앞차 운전자(경찰): 내려서 발 구르며 씩씩. 상대가 없는 날은 정해 둔 자리의 사람이 말한다
	them = _person(rival_color, false, "karen")
	them.global_position = rival.global_position + _flat_left(rival.global_basis) * 1.1 if rival else them_pos
	var look := car.get_vehicle_position()
	look.y = them.global_position.y
	if look.distance_to(them.global_position) > 0.1:
		them.look_at(look, Vector3.UP)
		them.rotate_y(PI) # +Z가 앞

	cam.set_physics_process(false)
	cam.global_position = cut_cam_pos
	cam.look_at(cut_cam_target, Vector3.UP)


func _win_script() -> void:
	if _script_step == 0 and phase_t > 0.6:
		_script_step = 1
		them.stomp(true)
	if _script_step == 1 and phase_t > 1.1:
		_script_step = 2
		them.say(win_lines[0], 2.6)
	if _script_step == 2 and phase_t > 3.9:
		_script_step = 3
		them.say(win_lines[1], 3.0)
		var key := "다음 날 버튼" if DisplayServer.is_touchscreen_available() else "Enter"
		var next_hint := ("%s 다음 날" % key) if day_index < _day_count() - 1 else ("%s 처음으로" % key)
		hud.toast("DAY %d 클리어 · 기록 %s\n%s\n%s" % [day_index + 1, hud.fmt_run(run_time), clear_line % _fmt_clock(clock), next_hint], 600.0)
	if me and not me.is_walking() and me.visible and phase_t > 1.0:
		me.visible = false # 문으로 들어갔다


func _on_rival_parked() -> void:
	if phase != Phase.PLAY:
		return
	_lose("자리 뺏김… 지각 확정\nR 다시")
	them = _person(rival_color, false, "karen")
	them.global_position = rival.global_position + _flat_left(rival.global_basis) * 1.1 + Vector3.UP * 0.15
	them.walk_to(_walk_points(them.global_position), 1.2)


## 경찰차가 따라붙었다
func _on_caught() -> void:
	if phase != Phase.PLAY:
		return
	_lose("잡혔다… 출근 대신 경찰서\nR 다시")
	car.linear_velocity = Vector3.ZERO
	them = _person(rival_color, false)
	them.global_position = rival.global_position + _flat_left(rival.global_basis) * 1.1 + Vector3.UP * 0.15


func _lose(text: String) -> void:
	_set_phase(Phase.LOSE)
	car.controls_enabled = false
	spot.set_state(ParkingPad.State.IDLE)
	hud.toast(text, 600.0)


## 사고: 세게 박음("crash") 또는 뒤집힘("flip"). 앞차는 그 틈에 서둘러 칸으로 간다.
func _on_car_crashed(kind: String, _impact: float) -> void:
	if phase != Phase.PLAY:
		return
	_set_phase(Phase.FAIL)
	car.controls_enabled = false
	spot.charge = 0.0
	spot.update_fill()
	spot.set_state(ParkingPad.State.IDLE)
	if rival and not rival.police:
		rival.speed *= 1.8
	if kind == "flip":
		hud.toast("뒤집혔다…\n견인차 부르는 중", FAIL_TIME)
	else:
		hud.toast("쾅!\n사고 처리하다 지각", FAIL_TIME)


func _retry() -> void:
	if phase != Phase.WIN:
		retries += 1
	get_tree().reload_current_scene()


func _lose_script() -> void:
	if _script_step == 0 and phase_t > 0.5 and them:
		_script_step = 1
		them.say(lose_line, 2.5)


@warning_ignore("integer_division")
func _fmt_clock(sec: float) -> String:
	var s := int(sec)
	return "%02d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]


# --- 거리 만들기 도구 -------------------------------------------------------
func _material(key: String) -> ShaderMaterial:
	if not _materials.has(key) and SURFACES.has(key):
		var sf: Array = SURFACES[key]
		var sm := ShaderMaterial.new()
		sm.shader = SURFACE_SHADER
		sm.set_shader_parameter("base_color", sf[0])
		sm.set_shader_parameter("stain_color", sf[1])
		sm.set_shader_parameter("grain", sf[2])
		sm.set_shader_parameter("tile", sf[3])
		sm.set_shader_parameter("roughness", sf[4])
		_materials[key] = sm
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = GRID_SHADER
		m.set_shader_parameter("base_color", COLORS[key][0])
		m.set_shader_parameter("line_color", COLORS[key][1])
		_materials[key] = m
	return _materials[key]


func _building_material(style: String) -> ShaderMaterial:
	var key := "building:" + style
	if not _materials.has(key):
		var st: Array = BUILDING_STYLES[style]
		var m := ShaderMaterial.new()
		m.shader = BUILDING_SHADER
		m.set_shader_parameter("wall_color", st[0])
		m.set_shader_parameter("glass_color", st[1])
		m.set_shader_parameter("frame_color", st[2])
		m.set_shader_parameter("floor_h", st[3])
		m.set_shader_parameter("bay_w", st[4])
		m.set_shader_parameter("window_frac", st[5])
		m.set_shader_parameter("ribbon", st[6])
		m.set_shader_parameter("seed", float(BUILDING_STYLES.keys().find(style)) * 7.3)
		_materials[key] = m
	return _materials[key]


## 상자 건물 하나: 겉면(style이 비면 자리로 정한 무작위), 옥상 테두리 턱, 옥상 기계실·실외기. 크기·자리는 a, b 그대로다.
## roof_clutter가 false면 옥상 턱·기계실을 두지 않는다(옥상 주차장 건물: 칸과 겹치지 않게)
func _building(a: Vector3, b: Vector3, style := "", roof_clutter := true) -> void:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	var r := RandomNumberGenerator.new() # 장식은 따로 뽑아 건물 배치(부른 쪽 rng)는 예전 그대로 둔다
	r.seed = hash(Vector3i(roundi(lo.x * 10.0), roundi(lo.z * 10.0), roundi(hi.y * 10.0)))
	if style == "":
		style = ["glass", "concrete", "brick", "stone"][r.randi() % 4]
	_block(lo, hi, _building_material(style))
	if not roof_clutter:
		return
	var trim := _plain(Color(BUILDING_STYLES[style][2]).lerp(Color(0.5, 0.5, 0.5), 0.3))
	_block(Vector3(lo.x - 0.15, hi.y, lo.z - 0.15), Vector3(hi.x + 0.15, hi.y + 0.5, hi.z + 0.15), trim, false)
	var roof := _plain(Color(0.46, 0.47, 0.48))
	for i in r.randi_range(1, 3):
		var w := Vector3(r.randf_range(1.5, 4.0), r.randf_range(1.0, 2.8), r.randf_range(1.5, 4.0))
		var cx := r.randf_range(lo.x + w.x * 0.5 + 0.6, maxf(lo.x + w.x * 0.5 + 0.6, hi.x - w.x * 0.5 - 0.6))
		var cz := r.randf_range(lo.z + w.z * 0.5 + 0.6, maxf(lo.z + w.z * 0.5 + 0.6, hi.z - w.z * 0.5 - 0.6))
		_block(Vector3(cx - w.x * 0.5, hi.y, cz - w.z * 0.5), Vector3(cx + w.x * 0.5, hi.y + w.y, cz + w.z * 0.5), roof, false)


func _plain(col: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.45
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _block(a: Vector3, b: Vector3, mat: Material, collide := true) -> void:
	var size := (b - a).abs()
	var center := (a + b) * 0.5
	_box(Transform3D(Basis.IDENTITY, center), size, mat, collide)


func _box(xform: Transform3D, size: Vector3, mat: Material, collide := true) -> Node3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	if not collide:
		mi.transform = xform
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.transform = xform
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.add_child(mi)
	add_child(body)
	return body


## z 방향 경사로: 윗면이 from에서 to까지(폭 width, x 중심 x)
func _ramp(x: float, width: float, from: Vector3, to: Vector3, mat: Material) -> void:
	var d := to - from
	var angle := atan2(d.y, d.z)
	var b := Basis(Vector3.RIGHT, -angle)
	var center := (from + to) * 0.5 - b.y * 0.2
	center.x = x
	_box(Transform3D(b, center), Vector3(width, 0.4, d.length() + 0.1), mat).set_meta("ramp", true)


## 경사로·곡면 조각은 meta "ramp"를 단다: 차가 빠르게 들이받아도 사고·부품 떨어짐으로 치지 않는다(roadster.gd _read_contacts)
## 원호 곡면(달리는 면은 원의 안쪽). plane "z"는 z-y 평면, 진행 +Z, 0도 = 바닥, 90도 = 벽, 180도 = 천장.
func _arc(center_zy: Vector2, radius: float, from_deg: float, to_deg: float, segments: int, width: float, x: float, mat: Material) -> void:
	var thickness := 0.4
	var step := deg_to_rad(to_deg - from_deg) / segments
	var length := 2.0 * radius * sin(step * 0.5) * 1.08
	for i in segments:
		var th := deg_to_rad(from_deg) + step * (i + 0.5)
		var n3 := Vector3(0, cos(th), -sin(th))
		var t3 := Vector3(0, sin(th), cos(th))
		var p3 := Vector3(x, center_zy.y - radius * cos(th), center_zy.x + radius * sin(th))
		_box(Transform3D(Basis(n3.cross(t3), n3, t3), p3 - n3 * (thickness * 0.5)), Vector3(width, thickness, length), mat).set_meta("ramp", true)


## 원호 곡면(x-y 평면, z0~z1로 길게 늘인 쿼터파이프). dir = -1이면 -X 쪽으로 달려 올라간다
## (벽이 차의 오른쪽에 있을 때). 0도 = 바닥, 90도 = 수직 벽.
func _arc_x(center_xy: Vector2, radius: float, from_deg: float, to_deg: float, segments: int, z0: float, z1: float, mat: Material, dir := 1.0) -> void:
	var thickness := 0.4
	var step := deg_to_rad(to_deg - from_deg) / segments
	var length := 2.0 * radius * sin(step * 0.5) * 1.08
	for i in segments:
		var th := deg_to_rad(from_deg) + step * (i + 0.5)
		var n3 := Vector3(-dir * sin(th), cos(th), 0)
		var t3 := Vector3(dir * cos(th), sin(th), 0)
		var p3 := Vector3(center_xy.x + dir * radius * sin(th), center_xy.y - radius * cos(th), (z0 + z1) * 0.5)
		_box(Transform3D(Basis(n3.cross(t3), n3, t3), p3 - n3 * (thickness * 0.5)), Vector3(z1 - z0, thickness, length), mat).set_meta("ramp", true)


## 볼록한 원호 곡면(z-y 평면): 달리는 면은 원의 바깥. 0도 = 수직 벽(원 중심의 -Z 쪽), 90도 = 수평 옥상.
## 흡착 팬이 원 중심 쪽으로 당기므로, 속도가 sqrt(팬 가속도 x 반지름)보다 느리면 모서리를 따라 넘어간다.
func _arc_convex(center_zy: Vector2, radius: float, from_deg: float, to_deg: float, segments: int, width: float, x: float, mat: Material) -> void:
	var thickness := 0.4
	var step := deg_to_rad(to_deg - from_deg) / segments
	var length := 2.0 * radius * sin(step * 0.5) * 1.08
	for i in segments:
		var th := deg_to_rad(from_deg) + step * (i + 0.5)
		var n3 := Vector3(0, sin(th), -cos(th))
		var t3 := Vector3(0, cos(th), sin(th))
		var p3 := Vector3(x, center_zy.y + radius * sin(th), center_zy.x - radius * cos(th))
		_box(Transform3D(Basis(n3.cross(t3), n3, t3), p3 - n3 * (thickness * 0.5)), Vector3(width, thickness, length), mat).set_meta("ramp", true)

## 길이 3m, 폭 1.35m 상자 차. yaw 0이면 길이가 z, 90이면 x 방향.
## use_models면 PARKED_MODELS 가운데 하나(pick)도 같은 자리에 세우고, 둘 중 하나만 보인다.
func _parked_car(center: Vector3, yaw_deg: float, col: Color, height_scale := 1.0, pick := -1, models: Array = []) -> void:
	var b := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var body_h := 0.6 * height_scale
	var parts: Array[Node3D] = [
		_box(Transform3D(b, center + Vector3.UP * (0.2 + body_h * 0.5)), Vector3(1.35, body_h, 3.0), _plain(col)),
		_box(Transform3D(b, center + Vector3.UP * (0.2 + body_h + 0.2) + b.z * -0.3), Vector3(1.15, 0.4, 1.4), _plain(Color(0.08, 0.1, 0.14))),
		_box(Transform3D(b, center + Vector3.UP * 0.1), Vector3(1.19, 0.2, 2.4), _plain(Color(0.05, 0.05, 0.06)), false),
	]
	if use_models and pick >= 0:
		var pool: Array = models if not models.is_empty() else PARKED_MODELS
		var model_name: String = pool[pick % pool.size()]
		_look_box.append_array(parts)
		var car := _model(model_name, Transform3D(b, center), _hull(model_name))
		if not _paint_seeded:
			_paint_seeded = true
			_paint_rng.seed = 1000 + day_index
		_last_paint = CarPaint.pick(_paint_rng, _last_paint)
		CarPaint.paint(car, model_name, _last_paint)


## Tripo 모델 하나를 세운다(모델 버전에서만 보인다). shape가 있으면 그 모양으로 부딪힌다(모델 원점 기준 shape_xf).
func _model(model_name: String, xform: Transform3D, shape: Shape3D = null, shape_xf := Transform3D.IDENTITY) -> Node3D:
	var node: Node3D = AssetCache.model(model_name).instantiate()
	var root: Node3D = node
	if shape != null:
		root = StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.transform = shape_xf
		root.add_child(cs)
		root.add_child(node)
	root.transform = xform
	add_child(root)
	_look_model.append(root)
	return root


## Tripo 모델 파일이 있고 모델 버전인 날인지(새로 구운 에셋은 파일이 있을 때만 놓는다)
func _has_model(model_name: String) -> bool:
	return use_models and ResourceLoader.exists("res://assets/models/%s/%s.glb" % [model_name, model_name])


## 보이지 않는 충돌 상자(겉모습이 상자 ↔ 모델로 바뀌어도 늘 부딪힌다)
func _solid(a: Vector3, b: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = (b - a).abs()
	shape.shape = box
	body.position = (a + b) * 0.5
	body.add_child(shape)
	add_child(body)


## 상자 버전에서만 보이는 상자(부딪히지 않는다)
func _box_look(a: Vector3, b: Vector3, mat: Material) -> void:
	var n := _box(Transform3D(Basis.IDENTITY, (a + b) * 0.5), (b - a).abs(), mat, false)
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_look_box.append(n)


## 길을 오가는 사람(모델 버전에서만). points를 따라 걷고 끝에 닿으면 거꾸로 돌아온다. 처음 자리는 offset(0~1)
func _pedestrian(model_name: String, points: Array[Vector3], speed := 1.1, offset := 0.0) -> void:
	var c := Commuter.new()
	c.model_name = model_name
	c.show_model = true
	c.scale = Vector3.ONE * PERSON_SCALE
	add_child(c)
	var i := clampi(int(offset * (points.size() - 1)), 0, points.size() - 2)
	c.global_position = points[i].lerp(points[i + 1], fmod(offset * (points.size() - 1), 1.0))
	var rest: Array[Vector3] = points.slice(i + 1)
	c.walk_to(rest, speed)
	_walkers.append([c, points, speed, true])
	_look_model.append(c)


func _update_walkers() -> void:
	for w in _walkers:
		var c: Commuter = w[0]
		if not c.is_walking():
			w[3] = not w[3]
			var pts: Array[Vector3] = (w[1] as Array[Vector3]).duplicate()
			if not w[3]:
				pts.reverse()
			c.walk_to(pts, w[2])


## 소품: 모델 원점 기준 상자(가운데 box_center, 크기 box_size)로 부딪힌다. 크기가 0이면 부딪히지 않는다.
func _prop(model_name: String, pos: Vector3, yaw_deg: float, box_center := Vector3.ZERO, box_size := Vector3.ZERO) -> Node3D:
	var shape: BoxShape3D = null
	if box_size != Vector3.ZERO:
		shape = BoxShape3D.new()
		shape.size = box_size
	return _model(model_name, Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos), shape, Transform3D(Basis.IDENTITY, box_center))


## 모델 메시의 볼록 껍질(단순화)을 모델 원점 좌표로 옮긴 충돌 모양. 세워 둔 차에 쓴다.
func _hull(model_name: String) -> Shape3D:
	if not _hull_cache.has(model_name) and ResourceLoader.exists(AssetCache.hull_path(model_name)):
		_hull_cache[model_name] = AssetCache.get_res(AssetCache.hull_path(model_name)) # 미리 구운 것(tests/bake_hulls.tscn)
	if not _hull_cache.has(model_name):
		var node: Node3D = AssetCache.model(model_name).instantiate()
		var points := PackedVector3Array()
		for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			var xf := Transform3D.IDENTITY
			var n: Node = mi
			while n != node:
				xf = (n as Node3D).transform * xf
				n = n.get_parent()
			var hull := mi.mesh.create_convex_shape(true, true) as ConvexPolygonShape3D
			for p in hull.points:
				points.append(xf * p)
		node.free()
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		_hull_cache[model_name] = shape
	return _hull_cache[model_name]


## 차의 겉모습(style)을 따라 상자 버전 ↔ 모델 버전을 바꾼다. 숨긴 쪽은 충돌도 끈다.
func _apply_look(style: String) -> void:
	var models := style == "roadster"
	for n in _look_box:
		_set_shown(n, not models)
	for n in _look_model:
		_set_shown(n, models)
	for p: Commuter in [me, them]:
		if p:
			p.set_look(models)
	if rival:
		rival.set_look(models)


func _set_shown(n: Node3D, on: bool) -> void:
	n.visible = on
	if n is CollisionObject3D:
		n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


## 주차칸 한 줄: center_x 중심, depth 방향 x, z에 SPOT_W 간격. skip_z의 칸은 비운다.
## models: 이 줄에서 고를 모델(비우면 PARKED_MODELS). 자동 주행이 스쳐 가는 줄은 기본 그대로 둔다(충돌 모양이 바뀌면 길이 달라진다)
func _parking_row(center: Vector3, count_before: int, count_after: int, skip_center: bool, rng: RandomNumberGenerator, lines := true, models: Array = []) -> void:
	var white := _plain(Color(0.9, 0.9, 0.86), true)
	var pick := RandomNumberGenerator.new() # 모델 고르기는 따로 뽑아 상자 차 색·방향은 예전 그대로 둔다
	pick.seed = rng.seed + 1
	for k in range(-count_before, count_after + 1):
		var z := center.z + k * spot_size.x
		if lines:
			_block(Vector3(center.x - spot_size.y * 0.5, center.y, z + spot_size.x * 0.5 - 0.05),
				Vector3(center.x + spot_size.y * 0.5, center.y + 0.02, z + spot_size.x * 0.5 + 0.05), white, false)
		if k == 0 and skip_center:
			continue
		var col: Color = PARKED_COLORS[rng.randi() % PARKED_COLORS.size()]
		_parked_car(Vector3(center.x, center.y, z), 90.0 if rng.randf() < 0.5 else -90.0, col, rng.randf_range(0.85, 1.2), pick.randi(), models)
	if lines:
		_block(Vector3(center.x - spot_size.y * 0.5, center.y, center.z - count_before * spot_size.x - spot_size.x * 0.5 - 0.05),
			Vector3(center.x + spot_size.y * 0.5, center.y + 0.02, center.z - count_before * spot_size.x - spot_size.x * 0.5 + 0.05), white, false)


## 주차칸 한 줄(x 방향으로 늘어선 칸, 차는 z 방향으로 선다). 칸 방향(spot_yaw_deg)이 0일 때 쓴다.
func _parking_row_x(center: Vector3, count_before: int, count_after: int, skip_center: bool, rng: RandomNumberGenerator) -> void:
	var white := _plain(Color(0.9, 0.9, 0.86), true)
	var pick := RandomNumberGenerator.new()
	pick.seed = rng.seed + 1
	for k in range(-count_before, count_after + 2):
		var x := center.x + (k - 0.5) * spot_size.x
		_block(Vector3(x - 0.05, center.y, center.z - spot_size.y * 0.5), Vector3(x + 0.05, center.y + 0.02, center.z + spot_size.y * 0.5), white, false)
	for k in range(-count_before, count_after + 1):
		if k == 0 and skip_center:
			continue
		var col: Color = PARKED_COLORS[rng.randi() % PARKED_COLORS.size()]
		_parked_car(Vector3(center.x + k * spot_size.x, center.y, center.z), 0.0 if rng.randf() < 0.5 else 180.0, col, rng.randf_range(0.85, 1.2), pick.randi())


func _sign(text: String, pos: Vector3, yaw_deg: float, size := 110, col := Color.WHITE) -> void:
	var l := Label3D.new()
	l.font = FONT
	l.font_size = size
	l.pixel_size = 0.008
	l.outline_size = 14
	l.modulate = col
	l.text = text
	l.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos)
	add_child(l)


func _skyline(rng: RandomNumberGenerator, x0: float, z0: float, z1: float) -> void:
	var z := z0
	while z < z1:
		var d := rng.randf_range(8.0, 16.0)
		_building(Vector3(x0, 0, z), Vector3(x0 + rng.randf_range(10.0, 18.0), rng.randf_range(8.0, 34.0), z + d))
		z += d + rng.randf_range(3.0, 8.0)
