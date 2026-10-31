# AI에게 실제로 한 요청

영상에서 Claude Code에 입력한 요청을 그대로 옮겼다. 처음엔 상자 그래픽뿐인 게임(뼈대)이 있었고, Tripo CLI를 깔고 로그인만 해 둔 상태에서 시작했다. 한 번에 되지 않은 곳은 고쳐 달라고 몇 번 더 말했다.

## 1. Tripo CLI 위에 툴킷 만들기

```text
Tripo CLI(tripo)를 깔고 로그인해 뒀어. 먼저 tripo docs --llm 이랑 tripo docs --topic examples/game-asset 을 읽어 봐.
그다음 tripo 명령을 써서, 그림 한 장이나 글 한 줄로 이 Godot 게임에 바로 넣을 3D 에셋을 만드는 툴킷을 tools/tripo_kit.py 하나로 만들어 줘.

- car <그림> --name 이름 --length 미터: 우리가 운전할 차. 그림 → 네 방향 이미지 → 3D 모양 → 텍스처 입히기 → 부품 나누기 → Blender 후작업(바퀴 떼어 내기, 크기·방향·바닥 맞추기) → 게임 폴더
- quick "<설명>" --name 이름 --kind car|person|prop --size 미터 [--anims 동작들]: 주차된 차·사람·소품. 게임용 설정으로 3D를 한 번에. 사람이면 리깅하고 걷기·화내기 동작까지
- batch <목록 파일>: 한 줄에 "이름 | 설명 | 종류 | 크기". tripo batch run으로 한꺼번에
- status: 만든 에셋 목록과 남은 크레딧

단계마다 실제로 실행하는 tripo 명령을 화면에 한 줄씩 보여 주고, 결과를 저장해서 다시 돌리면 이미 끝난(돈 낸) 단계는 건너뛰게 해 줘. Blender는 <Blender 경로>에 있어.
다 만들면 status부터 돌려 봐.
```

## 2. 툴킷으로 우리 차 만들기(터미널)

```powershell
python tools/tripo_kit.py car assets/concept/roadster.png --name roadster --length 2.5
```

네 방향 그림 뒤쪽에 가짜 글자·번호판이 생겼을 때:

```text
네 방향 중 뒤쪽 두 장에 글자랑 번호판 자리가 생겼어. 그 두 장만 지우고 다시 이어서 돌려 줘.
```

## 3. 새 차를 게임에 넣기

```text
지금 게임의 상자 차를 방금 만든 roadster로 바꿔 줘.
- 바퀴 넷이 따로 굴러가고 앞바퀴는 꺾이게
- 노즐 분사랑 흡착 팬 표시는 새 차에서도 보이게
- 새 차가 2.5m라서 다른 차(3m) 옆에서 너무 작아 보이지 않는지, DAY 주차 칸에 들어가는지 보고 충돌 모양·바퀴 위치·칸 크기를 맞춰 줘
- 처음 상자 차는 지우지 말고, M 키로 상자 차 ↔ 새 차를 바꿔 볼 수 있게
다 하면 자동 주행 테스트(tests/autopilot*.tscn, tests/sim.tscn)가 다 통과하는지 돌려 줘.
```

## 4. 부품 나누기 결과 쓰기

```text
부품 나누기 결과를 게임에서 써 보자.
- 앞차나 벽에 세게 박으면 부딪힌 쪽 범퍼·사이드미러가 떨어져 튕겨 나가게. 다시 시작하면 제자리
- P 키를 누를 때마다 배색이 바뀌게. 차체 빨간 칠만 새 색으로 바꾸고 명암·광택은 그대로, 범퍼·미러·옆 치마는 다른 색으로도 칠할 수 있게
```

## 5. 다른 차·사람·소품(터미널)

```powershell
python tools/tripo_kit.py quick "plain silver four-door sedan, generic design, no logos, no badges, no license plate" --name sedan --kind car --size 3.0
python tools/tripo_kit.py quick "dark blue compact SUV, generic design, no logos, no license plate" --name suv --kind car --size 3.2
python tools/tripo_kit.py quick "small white hatchback, generic design, no logos, no license plate" --name hatchback --kind car --size 2.9
python tools/tripo_kit.py quick "white delivery van, generic design, no logos, no text" --name van --kind car --size 3.6
python tools/tripo_kit.py quick "office worker man in a navy suit holding a briefcase, stylized game character, T-pose" --name me --kind person --size 1.75 --anims walk,angry_01
python tools/tripo_kit.py quick "angry middle-aged woman with short blonde bob haircut, cardigan and handbag, stylized game character, T-pose" --name karen --kind person --size 1.65 --anims walk,angry_01,complain_01
python tools/tripo_kit.py batch props.txt
```

`props.txt`(소품 목록, 한 줄에 이름 | 설명 | 종류 | 크기):

```text
streetlight | modern street light pole, gray metal, no text | prop | 4.5
traffic_light | traffic light on a pole, generic, no text | prop | 4.0
tree | small street tree in a square planter | prop | 3.5
bench | wooden park bench with metal legs | prop | 1.8
cone | orange traffic cone with white stripes | prop | 0.7
hydrant | red fire hydrant | prop | 0.8
```

그다음:

```text
만든 주차 차 4종, 사람 둘(me, karen), 소품 6종을 DAY 1 거리에 넣어 줘.
- 주차된 상자 차들은 이 차들로, 원기둥 사람은 me·karen으로
- 주차에 성공하면 me는 서류 가방 들고 걸어서 출근, 자리 뺏긴 karen은 화내는 동작
- M 키를 누르면 이것들도 다 처음 상자 버전으로 같이 바뀌게
```

영상 뒤에 같은 방법으로 택배 트럭·픽업·버스 정류장·쓰레기통·볼라드·주차 차단기·충전기·걷는 사람 둘을 더 만들었다(`props_more.txt`).
