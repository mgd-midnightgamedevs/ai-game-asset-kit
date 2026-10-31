# AI 에이전트 안내(AGENTS.md)

이 저장소에서 일하는 코딩 에이전트(Claude Code, Codex 등)가 먼저 읽는 파일. 사람에게도 같은 내용이 쓸모 있다.

## 무엇인가

- `game/`: Godot 4.7(GDScript, OpenGL 호환 렌더러, Jolt Physics) 세로 화면 게임. 직접 만든 레이캐스트 서스펜션 차(`scripts/roadster.gd`)에 냉가스 추진기 10개·흡착 팬을 달았다.
- `game/tools/tripo_kit.py`: Tripo CLI(`tripo`)를 부르는 에셋 툴킷. 같은 파일을 Blender로 다시 실행해 후작업을 한다(`blender -b --python tools/tripo_kit.py -- car|fit <spec.json>`).
- 규칙·구조·물리 설명은 `docs/game.md`.

## 실행·검사

Godot 실행 파일은 환경 변수 `GODOT`에 두고 쓴다(아래는 PowerShell).

```powershell
cd game
& $env:GODOT --headless --path . --import                                   # 처음 한 번(모델·텍스처 불러오기)
& $env:GODOT --headless --fixed-fps 60 --path . res://tests/autopilot_day1.tscn   # DAY 1 자동 주행 → "AUTOPILOT_DAY1 done … phase=WIN"
```

- 물리·레벨·앞차 경로를 바꾸면 **자동 주행을 돌려 확인한다**: `tests/autopilot_day1.tscn`~`autopilot_day8.tscn`, `tests/autopilot.tscn`(스턴트 코스), `tests/autopilot_stage.tscn`·`autopilot_stage_kick.tscn`(시연장). 자동 주행은 사람과 같은 입력 액션만 누른다(차를 직접 옮기지 않는다). 값은 명령줄로 바꿔 시험한다: `-- lift_z=16.8 main_t=0.1`.
- 실패 규칙: `tests/fail_check.tscn -- mode=crash|flip|slow`(세게 박기·뒤집힘은 사고, 천천히 닿기는 사고가 아니어야 한다).
- 앞차 경로가 세워 둔 차·벽을 뚫는지: `tests/rival_path_check.tscn -- day=1`.
- 평지 주행 수치: `tests/drive_metrics.tscn`.
- 헤드리스 실행은 그림을 그리지 않는다. 화면 확인·녹화는 창이 뜨는 실행(`tools/record_shot.py <샷>`, Godot 무비 메이커 60fps 1080x1920)으로 한다.

## 바꿀 때 지킬 것

- **API 키**: Tripo 키는 환경 변수 `TRIPO_API_KEY`(또는 `tripo login`)에만 둔다. 코드·문서·Git·로그에 남기지 않는다. `.tripo-work/`(생성 원본·상태)는 Git에 넣지 않는다.
- **크레딧**: 툴킷의 Tripo 단계는 크레딧을 쓴다. 새로 생성하기 전에 사람에게 묻는다. 다시 돌리면 끝난 단계는 건너뛰므로 같은 명령을 다시 쳐도 돈이 두 번 들지 않는다.
- **상표**: 실제 자동차 회사 이름·로고를 게임·텍스처·설명에 넣지 않는다. Tripo 설명에 `generic design, no logos, no badges, no license plate`를 붙인다. 생성된 텍스처에 엠블럼이 생기면 지운다(로드스터 뒤 엠블럼을 텍스처와 GLB 안 사본 모두에서 지운 적이 있다).
- **차 좌표**: 앞 +Z, 왼쪽 +X, 위 +Y. 모델 안 `wheel-front-left` 등 바퀴 노드가 있으면 서스펜션·회전·조향 표시가 붙는다(`roadster.gd`의 `STYLES`).
- **사고 판정**: 차체(바닥 아닌 쪽)로 받은 충격량이 `crash_speed`를 넘으면 사고. 경사로·곡면 조각은 `set_meta("ramp", true)`를 달아 사고로 치지 않는다(빠르게 들이받아도 코가 닿는다). 새 경사로를 만들면 같은 meta를 단다.
- **세워 둔 차**: 충돌은 미리 구운 볼록 껍질(`assets/models/<이름>/<이름>_hull.tres`, `tests/bake_hulls.tscn`). 차 모델을 새로 만들면 다시 굽는다.
- **모델 불러오기**: `AssetCache.model(이름)`으로 부른다(한 번 불러 붙잡아 둔다. 다시 할 때마다 텍스처를 다시 풀지 않게).
- **소리**: 버스(`default_bus_layout.tres`: Motor·Jet·Fan·Hit·World·UI, Master 압축기·리미터)로 크기를 맞춘다. 녹화 실행에 `meter=1`을 주면 버스별 피크가 찍힌다.
- **글**: 코드 주석과 문서는 한국어, `##` 문서 주석. 왜 그렇게 했는지(무엇이 문제였는지)를 한 줄로 남긴다.

## Tripo CLI를 처음 쓸 때

`tripo docs --llm`과 `tripo docs --topic examples/game-asset`을 먼저 읽는다. 툴킷이 쓰는 흐름:

- 우리 차: `generate image-to-multiview`(그림 → 네 방향) → `generate multiview-to-model`(텍스처 없이) → `model texture` → `mesh segment`(부품 나누기) → Blender 후작업
- 주차된 차·소품: `make "<설명>" --for game-mobile` 한 번
- 사람: `make … --for anim` → `anim check` → `anim rig` → `anim retarget`(걷기·화내기). 화내기 같은 동작은 biped 리깅(v1 모델)에서만 된다. 걷기 동작 단계가 가끔 실패하면 다시 돌린다(실패한 작업은 크레딧이 돌아온다).
- 소품 여러 개: `batch run <매니페스트>`
