extends Node3D
## 모델 확인용 한 장: 이름 목록의 Tripo 모델을 한 줄로 세우고(앞 +Z가 카메라 쪽 비스듬히) DAY 1과 같은 하늘·해 아래에서 찍는다.
## 창이 있는 실행에서만 찍힌다.
##   Godot --path . res://tests/model_lab.tscn -- models=semi_truck,pickup out=C:/경로/models.png [yaw=200] [dist=3] [camh=0.9]

var out := "user://model_lab.png"
var models: Array = []
var yaw := 200.0
var dist := -1.0 ## 주면 카메라 거리(m)를 이 값으로(가까이 보기)
var cam_h := -1.0 ## 주면 카메라 높이(m)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("models="):
			models = a.substr(7).split(",")
		elif a.begins_with("yaw="):
			yaw = float(a.substr(4))
		elif a.begins_with("dist="):
			dist = float(a.substr(5))
		elif a.begins_with("camh="):
			cam_h = float(a.substr(5))
	_world()
	var x := 0.0
	var tallest := 0.0
	for m: String in models:
		var n: Node3D = (load("res://assets/models/%s/%s.glb" % [m, m]) as PackedScene).instantiate()
		add_child(n)
		var aabb := _aabb(n)
		x += aabb.size.x * 0.5 + 0.8
		n.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), Vector3(x, 0, 0))
		var l := Label3D.new()
		l.text = "%s %.1fx%.1fx%.1f" % [m, aabb.size.x, aabb.size.y, aabb.size.z]
		l.font_size = 48
		l.pixel_size = 0.004 * maxf(1.0, aabb.size.x * 0.5)
		l.outline_size = 10
		l.position = Vector3(x, -0.05, -maxf(aabb.size.z, aabb.size.x) * 0.6 - 0.4)
		l.rotation = Vector3(-PI * 0.5, PI, 0)
		add_child(l)
		x += aabb.size.x * 0.5 + 0.8
		tallest = maxf(tallest, aabb.size.y)
	var vp := SubViewport.new()
	vp.size = Vector2i(2400, 1200)
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 35.0
	vp.add_child(cam)
	var d := dist if dist > 0.0 else maxf(x * 1.35, tallest * 3.0) + 2.0
	cam.global_position = Vector3(x * 0.5, cam_h if cam_h >= 0.0 else d * 0.35, -d)
	cam.look_at(Vector3(x * 0.5, tallest * 0.35, 0), Vector3.UP)
	cam.current = true
	for i in 20:
		await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out)
	print("MODEL_LAB saved ", out)
	get_tree().quit()


func _aabb(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _world() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.2, 0.36, 0.62)
	sky_mat.sky_horizon_color = Color(0.86, 0.74, 0.62)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D(Basis(Vector3(0.866025, 0, -0.5), Vector3(-0.321394, 0.766044, -0.55667), Vector3(0.383022, 0.642788, 0.663414)), Vector3.ZERO)
	sun.light_color = Color(1, 0.93, 0.82)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.3, 0.31, 0.33)
	ground.material_override = gm
	add_child(ground)
