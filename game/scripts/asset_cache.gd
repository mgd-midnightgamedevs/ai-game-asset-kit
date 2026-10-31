extends Node
## 자동 로드 AssetCache. Tripo 모델·차 장면을 한 번 불러오면 붙잡아 둔다.
## 붙잡지 않으면 다음 날로 넘어가거나 다시 할 때마다 텍스처(WebP)를 다시 풀어서, 웹 판에서 DAY를 누를 때마다 몇 초씩 멈췄다(10/24).
## 메뉴가 떠 있는 동안 warm_step()을 매 프레임 불러 하나씩 미리 불러온다(웹 판은 스레드가 없어 한꺼번에 부르면 메뉴가 멈춘다).

const SCENES := ["res://scenes/roadster.tscn"]
const MODELS := ["sedan", "hatchback", "suv", "van", "pickup", "me", "karen", "walker_a", "walker_b", "semi_truck",
	"streetlight", "traffic_light", "tree", "bench", "hydrant", "cone", "bus_stop", "trash_bin", "bollard", "barrier_gate", "ev_charger"]

var _res := {}
var clicked_ms := -1 ## 메뉴에서 DAY를 누른 시각(첫 화면까지 걸린 시간 재기, 브라우저 콘솔에 찍는다)
var _queue: Array[String] = []


func _ready() -> void:
	_queue.append_array(SCENES)
	for m in MODELS:
		_queue.append(model_path(m))
		var hull := hull_path(m)
		if ResourceLoader.exists(hull):
			_queue.append(hull)


static func model_path(model_name: String) -> String:
	return "res://assets/models/%s/%s.glb" % [model_name, model_name]


## 세워 둔 차 충돌 모양(tests/bake_hulls.tscn이 미리 구워 둔 볼록 껍질). 없으면 빈 문자열이 아닌 경로를 그대로 돌려준다
static func hull_path(model_name: String) -> String:
	return "res://assets/models/%s/%s_hull.tres" % [model_name, model_name]


## 불러와서 붙잡아 둔다
func get_res(path: String) -> Resource:
	if not _res.has(path):
		_res[path] = load(path)
	return _res[path]


func model(model_name: String) -> PackedScene:
	return get_res(model_path(model_name)) as PackedScene


## 남은 것 하나를 불러온다. 다 끝났으면 false
func warm_step() -> bool:
	while not _queue.is_empty():
		var p: String = _queue.pop_front()
		if _res.has(p) or not ResourceLoader.exists(p):
			continue
		get_res(p)
		return true
	return false


func warm_left() -> int:
	return _queue.size()
