extends CanvasLayer
## 세로 화면 HUD. 기준 해상도 1080x1920(canvas_items 스트레치, expand).
## 위: 높이·기록·타이머, 가운데: 안내 문구와 주차 진행, 아래: 공기 탱크와 추진기·흡착 상태.

const FONT := preload("res://fonts/Pretendard-Bold.otf")
const COL_FUEL := Color(0.62, 0.88, 1.0) # 압축 공기: 연한 하늘색
const COL_FUEL_LOW := Color(1.0, 0.25, 0.2)
const COL_ON := Color(1, 1, 1, 1)
const COL_OFF := Color(1, 1, 1, 0.28)
const PARK_W := 520.0

var _root: Control
var _height: Label
var _best: Label
var _timer: Label
var _pads: Label
var _toast: Label
var _park_bg: ColorRect
var _park_fill: ColorRect
var _fuel_bg: ColorRect
var _fuel_fill: ColorRect
var _fuel_text: Label
var _chips := {}
var _help: Label
var _toast_left := 0.0
var _cap: Label
var _run: Label ## 이번 판 기록(웹 판 리더보드용, DAY 모드)


func _ready() -> void:
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var band := _place(_rect(Color(0.02, 0.03, 0.08, 0.55)), Control.PRESET_BOTTOM_WIDE, Rect2(0, -340, 0, 340))
	band.offset_right = 0
	_cap = _place(_label(40, "높이"), Control.PRESET_TOP_LEFT, Rect2(56, 52, 400, 50))
	_height = _place(_label(120), Control.PRESET_TOP_LEFT, Rect2(50, 92, 600, 140))
	_best = _place(_label(40), Control.PRESET_TOP_LEFT, Rect2(56, 240, 600, 50))

	_timer = _place(_label(76, "", HORIZONTAL_ALIGNMENT_RIGHT), Control.PRESET_TOP_RIGHT, Rect2(-476, 70, 420, 90))
	_pads = _place(_label(44, "", HORIZONTAL_ALIGNMENT_RIGHT), Control.PRESET_TOP_RIGHT, Rect2(-476, 170, 420, 56))

	_run = _place(_label(52, "", HORIZONTAL_ALIGNMENT_CENTER), Control.PRESET_CENTER_TOP, Rect2(-170, 300, 340, 70))
	_run.modulate = Color(1.0, 0.92, 0.55)

	_toast = _place(_label(60, "", HORIZONTAL_ALIGNMENT_CENTER), Control.PRESET_CENTER_TOP, Rect2(-480, 520, 960, 240))
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_park_bg = _place(_rect(Color(0, 0, 0, 0.45)), Control.PRESET_CENTER_TOP, Rect2(-PARK_W / 2, 790, PARK_W, 26))
	_park_fill = _place(_rect(Color(0.4, 1.0, 0.55)), Control.PRESET_CENTER_TOP, Rect2(-PARK_W / 2, 790, 0, 26))

	_fuel_bg = _place(_rect(Color(0, 0, 0, 0.5)), Control.PRESET_BOTTOM_WIDE, Rect2(60, -250, -120, 40))
	_fuel_fill = _place(_rect(COL_FUEL), Control.PRESET_BOTTOM_LEFT, Rect2(60, -250, 0, 40))
	_place(_label(40, "공기 탱크"), Control.PRESET_BOTTOM_LEFT, Rect2(62, -310, 300, 50))
	_fuel_text = _place(_label(40, "", HORIZONTAL_ALIGNMENT_RIGHT), Control.PRESET_BOTTOM_RIGHT, Rect2(-362, -310, 300, 50))

	var x := 62.0
	for key in ["리프트", "메인", "흡착 팬"]:
		_chips[key] = _place(_label(44, key), Control.PRESET_BOTTOM_LEFT, Rect2(x, -196, 320, 56))
		x += 200.0

	_help = _place(_label(30, "W/S 가속·후진  A/D 조향  ·  Space 리프트  Shift 메인 추진\n공중: W/S 기울기  A/D 수평 회전  F 옆으로 한 바퀴  ·  E 흡착 팬\nR 복귀  1~5 패드 이동(연습)  C 카메라  M 차 바꾸기  P 배색  Enter 재시작  H 숨김"),
		Control.PRESET_BOTTOM_LEFT, Rect2(62, -136, 1000, 130))
	_help.modulate = Color(1, 1, 1, 0.8)
	if DisplayServer.is_touchscreen_available():
		_help.visible = false # 휴대폰: 키 안내 대신 화면 버튼(touch_controls.gd)


func _label(font_size: int, text := "", align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font = FONT
	ls.font_size = font_size
	ls.outline_size = maxi(roundi(font_size / 7.0), 4)
	ls.outline_color = Color(0, 0, 0, 0.85)
	l.label_settings = ls
	l.horizontal_alignment = align
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _rect(col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## r.position은 앵커 기준 오프셋, r.size.x가 음수면 오른쪽 오프셋(넓게 펼치는 프리셋용)
func _place(c: Control, preset: Control.LayoutPreset, r: Rect2) -> Control:
	_root.add_child(c)
	c.set_anchors_preset(preset)
	c.offset_left = r.position.x
	c.offset_top = r.position.y
	c.offset_right = r.size.x if r.size.x < 0.0 else r.position.x + r.size.x
	c.offset_bottom = r.position.y + r.size.y
	return c


func toast(text: String, seconds := 2.0) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_left = seconds


func toggle_help() -> void:
	_help.visible = not _help.visible


## 위쪽 네 칸은 기본이 시연 코스(높이·기록·타이머·패드)다.
## 다른 모드(DAY 1 등)는 top_left_cap / top_left / top_left_sub / top_right / top_right_sub 문자열을 넘긴다.
func update_state(s: Dictionary, delta: float) -> void:
	if s.has("top_left"):
		_cap.text = s.get("top_left_cap", "")
		_height.text = s.top_left
		_best.text = s.get("top_left_sub", "")
		_timer.text = s.get("top_right", "")
		_pads.text = s.get("top_right_sub", "")
	else:
		_height.text = "%d m" % int(round(maxf(s.height, 0.0)))
		_best.text = "최고 %d m" % int(round(s.best_height))
		_timer.text = _fmt_time(s.time)
		_pads.text = "패드 %d / %d" % [s.pads_done, s.pads_total]

	var run: float = s.get("run", -1.0)
	_run.visible = run >= 0.0
	if run >= 0.0:
		_run.text = "기록 " + fmt_run(run)

	var ratio: float = s.air_ratio
	_fuel_fill.offset_right = _fuel_fill.offset_left + _fuel_bg.size.x * ratio
	_fuel_fill.color = COL_FUEL if ratio > 0.25 else COL_FUEL_LOW
	_fuel_text.text = "%d%%" % int(ceil(ratio * 100.0))

	_chips["리프트"].modulate = COL_ON if s.lift else COL_OFF
	_chips["메인"].modulate = COL_ON if s.main else COL_OFF
	_chips["흡착 팬"].text = ("흡착 %.1fG" % s.fan_g) if s.fan else "흡착 팬"
	_chips["흡착 팬"].modulate = Color(0.6, 0.9, 1.0) if s.fan else COL_OFF

	var park: float = s.park
	_park_bg.visible = park > 0.01
	_park_fill.visible = park > 0.01
	_park_fill.offset_right = _park_fill.offset_left + PARK_W * park

	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left < 0.4:
			_toast.modulate.a = maxf(_toast_left / 0.4, 0.0)


## 리더보드 기록 표기(분:초.백분의 일)
static func fmt_run(t: float) -> String:
	var m := floori(t / 60.0)
	return "%d:%05.2f" % [m, t - m * 60.0]


static func _fmt_time(t: float) -> String:
	var m := floori(t / 60.0)
	var sec := fmod(t, 60.0)
	return "%d:%04.1f" % [m, sec]
