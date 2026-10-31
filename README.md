# AI로 만든 게임 + 3D 에셋 툴킷

> **English summary.** A small Godot 4.7 game ("Commute Parking War": fly a rocket-thruster roadster into the last parking spot before the car in front) built with an AI coding agent (Claude Code), plus the toolkit the agent wrote on top of the official **Tripo CLI** to turn one picture or one line of text into game-ready 3D assets (car with separate wheels and breakable parts, parked cars, rigged people with walk/angry animations, batched props). Everything here is shared as-is from an M.G.D YouTube episode. Docs are in Korean; code comments too.

M.G.D(퇴근 후 게임 만드는 두 아빠) 유튜브 영상에서 만든 것을 그대로 공유합니다. AI(Claude Code)에게 Tripo CLI 문서를 읽혀 **3D 에셋 툴킷**을 만들게 하고, 그 툴킷으로 뽑은 차·사람·소품을 **Godot 게임**에 넣었습니다.

- 영상: https://youtu.be/rhIkJIXx7Gs
- 게임: `game/` — Godot 4.7 프로젝트. 출근길 마지막 한 칸을 앞차보다 먼저, 날아서 차지하는 게임(DAY 1~8 + 스턴트 코스 + 시연장)
- 툴킷: `game/tools/tripo_kit.py` — Tripo CLI 위에서 그림 한 장·글 한 줄 → 게임에 바로 넣는 3D 에셋
- AI에게 실제로 한 요청: [`docs/prompts.md`](docs/prompts.md)
- AI 에이전트용 안내: [`AGENTS.md`](AGENTS.md)
- 게임 규칙·구조·운전 물리: [`docs/game.md`](docs/game.md)

있는 그대로(as-is) 공유합니다. 프로토타입이라 다듬지 않은 곳이 많습니다.

## 게임 해 보기

PC에서 키보드로 한다(휴대폰은 안 된다).

- **브라우저에서 바로:** https://mgd-midnightgamedevs.github.io/ai-game-asset-kit/ — 설치 없이 실행. 웹 판은 DAY 1~4까지다(전부 하려면 윈도우 판이나 Godot). 처음 로딩이 약 90MB다. 용량을 줄이려고 모델 텍스처 해상도를 낮췄다.
- **윈도우:** [Releases](https://github.com/mgd-midnightgamedevs/ai-game-asset-kit/releases/latest)에서 `commute-parking-war-windows.zip`을 받아 풀고 `commute-parking-war.exe`를 실행한다. 서명하지 않은 파일이라 "Windows의 PC 보호" 창이 뜨면 추가 정보 → 실행.

Godot에서 직접 열기:

1. [Godot 4.7](https://godotengine.org/download)(4.7.2에서 확인)을 받는다.
2. Godot에서 `game/project.godot`를 연다(처음 열 때 모델·텍스처를 불러오느라 몇 분 걸린다).
3. F5로 실행 → 메뉴에서 DAY를 고른다.

| 키 | 동작 |
| --- | --- |
| W/S, 방향키 | 가속·후진(공중에서는 기수 숙이기·들기) |
| A/D | 조향(공중에서는 수평 회전) |
| Space | 리프트: 아래 노즐 4개. 땅에서 켜면 튀어 오른다 |
| Shift | 메인 추진(부스트) |
| E (길게) | 흡착 팬: 곡면 램프·벽을 타고 오른다 |
| F | 공중에서 옆으로 한 바퀴(뒤집혀 있으면 반 바퀴) |
| M | Tripo 모델 ↔ 처음 만든 상자 그래픽 |
| P | 배색 바꾸기 |
| C | 측면 카메라 |
| R / Esc / Enter | 다시 / 메뉴 / 성공 뒤 다음 날 |

## 툴킷 써 보기(Tripo 계정 필요)

1. [Node.js 20+](https://nodejs.org)와 Tripo CLI: `npm install -g tripo-cli`
2. [Tripo 개발자 페이지](https://developers.tripo3d.ai)에서 API 키를 만들어 환경 변수 `TRIPO_API_KEY`에 넣는다(또는 `tripo login`). **키를 파일·Git에 넣지 않는다.** `tripo doctor`로 확인.
3. 우리 차(`car`) 후작업에는 [Blender](https://www.blender.org)가 필요하다(바퀴 떼어 내기·크기·방향). 다른 경로면 환경 변수 `BLENDER`.

```powershell
cd game
python tools/tripo_kit.py --help
python tools/tripo_kit.py car assets/concept/roadster.png --name roadster --length 2.5
python tools/tripo_kit.py quick "plain silver four-door sedan, generic design, no logos" --name sedan --kind car --size 3.0
python tools/tripo_kit.py quick "office worker in a navy suit holding a briefcase, stylized" --name me --kind person --size 1.75 --anims walk,angry
python tools/tripo_kit.py batch props.txt
python tools/tripo_kit.py status
```

- 단계마다 실제로 실행하는 `tripo` 명령을 한 줄씩 보여 준다.
- 돈(크레딧)이 드는 단계는 결과를 `.tripo-work/`에 저장해 두고, 다시 돌리면 끝난 단계는 건너뛴다. 끊긴 단계는 같은 작업을 이어서 기다린다.
- 결과: `assets/models/<이름>/<이름>.glb`와 `<이름>.json`(크기·바퀴 위치, Godot 좌표).
- 크레딧은 에셋마다 다르다(이 저장소의 에셋 전부 합쳐 약 1,200크레딧). `status`가 쓴 양과 남은 양을 보여 준다.

## 폴더

```text
README.md, AGENTS.md, CLAUDE.md
docs/          AI에게 한 요청, 게임 규칙·구조
game/          Godot 4.7 프로젝트
  scripts/     차(roadster.gd), 요일(day1~8.gd), 공통 진행(commute_day.gd) …
  scenes/      DAY 1~8, 스턴트 코스, 시연장, 메뉴
  assets/      Tripo로 만든 모델(models/), 효과음(sfx/), 툴킷 입력 그림(concept/)
  tests/       헤드리스 자동 주행·검사(사람과 같은 키 입력만 쓴다)
  tools/       tripo_kit.py(툴킷), record_shot.py(영상용 녹화)
```

## 라이선스

- 코드(`game/scripts`, `game/tests`, `game/tools`, `game/shaders`): MIT — [`LICENSE`](LICENSE)
- Tripo로 만든 3D 모델(`game/assets/models`): Tripo와의 계약에 따라 이 저장소에 포함했다. MIT·CC BY 4.0 대상이 아니다. 다른 프로젝트에 쓰려면 툴킷으로 직접 다시 만든다.
- 우리가 만든 컨셉 그림(`game/assets/concept`)과 효과음(`game/assets/sfx`): [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) — 출처(M.G.D)를 밝히면 자유롭게 써도 된다.
- 폰트 `game/fonts/Pretendard-Bold.otf`: [Pretendard](https://github.com/orioncactus/pretendard), SIL Open Font License 1.1(`game/fonts/OFL.txt`)
- 소리 일부 `game/vendor/kenney_starter_kit_racing`: Kenney [Starter Kit Racing](https://github.com/KenneyNL/Starter-Kit-Racing), CC0 / MIT(`LICENSE`)

실제 자동차 회사와 관계없는 팬 프로젝트입니다. 게임 속 차·간판에 실제 회사 이름·로고를 쓰지 않았습니다.
3D 에셋은 [Tripo](https://www.tripo3d.ai)로 만들었습니다(영상은 Tripo 제작 지원).
