extends Node
## 자동 로드 WebBridge. 웹 판(web-demo/)에서만 페이지 JS(window.mgd, web-demo/shell/mgd.js)와 주고받는다.
## - 판 시작: start(day) → 서버에서 시작 표(서명된 시각)를 받아 둔다(기록 위조 막기)
## - 주차 성공: finish(day, ms) → 페이지가 이름을 받고 리더보드에 올린다
## - 메뉴의 랭킹 버튼: show_board()
## 데스크톱·에디터에서는 아무것도 하지 않는다. 웹 판은 DAY 1~4만 연다(OS.has_feature("web_demo"), 내보내기 설정의 사용자 기능).

const DEMO_DAYS := 4

var enabled := OS.has_feature("web")
var demo := OS.has_feature("web_demo")
## 리더보드 페이지(window.mgd)가 붙은 웹 판에서만 랭킹 버튼을 보인다. GitHub Pages 판에는 없다
var has_board := enabled and bool(JavaScriptBridge.eval("!!window.mgd", true))


func _ready() -> void:
	if enabled:
		# 브라우저에서 Ctrl+W는 탭을 닫는다(막을 수 없다). 흡착 팬을 Ctrl로 누른 채 W로 가속하면 게임이 꺼지므로 웹에서는 E만 쓴다
		for ev in InputMap.action_get_events("magnet"):
			if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_CTRL:
				InputMap.action_erase_event("magnet", ev)


func start(day: int) -> void:
	_call("start(%d)" % day)


func finish(day: int, seconds: float) -> void:
	_call("finish(%d, %d)" % [day, roundi(seconds * 1000.0)])


func show_board(day := 0) -> void:
	_call("showBoard(%d)" % day)


## 이름 입력·리더보드 창이 떠 있으면 true(그동안 게임 키 입력을 무시한다)
func overlay_open() -> bool:
	if not enabled:
		return false
	return bool(JavaScriptBridge.eval("!!(window.mgd && window.mgd.isOpen())", true))


func _call(js: String) -> void:
	if enabled:
		JavaScriptBridge.eval("window.mgd && window.mgd." + js, true)
