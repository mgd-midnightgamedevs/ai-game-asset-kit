"""Tripo 협찬 쇼츠용 게임 장면을 Godot 무비 메이커로 찍는다(60fps, 1080x1920 세로). 누구 PC에서나 같은 장면이 나온다.

  python tools/record_shot.py list
  python tools/record_shot.py <샷 이름> [<샷 이름> ...] [--godot <Godot 실행 파일>] [--out <폴더>]
  python tools/record_shot.py all

Godot 실행 파일은 --godot, 환경변수 GODOT, PATH의 godot 순서로 찾는다(4.7 이상). 결과는 rec/<샷>.avi와
ffmpeg가 있으면 rec/<샷>.mp4(H.264, 60fps). 장면은 자동 주행이 사람과 같은 입력으로 몬다.
녹화 중에는 창을 건드리지 않는다. 영상에는 DAY 1·2만 쓴다(10/23 사용자).
"""
import argparse
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 샷: (설명, 장면, 명령줄 값)
SHOTS = {
    "stage_kick": ("G1 훅: 시연장 장애물 차 셋·트럭 위로 옆으로 한 바퀴(고정 카메라, 깨끗한 화면)", "res://tests/autopilot_stage_kick.tscn", ["look=roadster", "cam=spot:kick", "clean=1", "quit=9"]),
    "stage_ramp": ("G2 시연장 램프: 천장에 매달렸다 옆으로 돌며 떨어져 착지(고정 카메라)", "res://tests/autopilot_stage.tscn", ["look=roadster", "cam=spot:ramp", "clean=1", "quit=17"]),
    "stage_lift": ("썸네일: 시연장 리프트로 첫 차 위에 뜬 순간(2.2초, 차가 화면 가운데인 낮은 고정 카메라)", "res://tests/autopilot_stage_kick.tscn", ["look=roadster", "cam=spot:lift", "clean=1", "quit=2.4"]),
    "stage_kick_chase": ("G1 예비: 같은 킥플립을 추적 카메라로", "res://tests/autopilot_stage_kick.tscn", ["look=roadster", "clean=1", "quit=9"]),
    "day1": ("G3 DAY 1 회사 앞 마지막 한 칸: 트럭 넘어 앞차보다 먼저 주차(추적 카메라)", "res://tests/autopilot_day1.tscn", ["look=roadster"]),
    "day2": ("DAY 2 주차 타워: 1층 통로 → 곡면 옹벽 흡착 → 거꾸로 날아 옥상 빈칸(추적 카메라)", "res://tests/autopilot_day2.tscn", ["look=roadster"]),
    "day3": ("DAY 3 옥상 주차장: 리프트로 9m 옥상에 솟구쳐 엘리베이터 앞 칸(추적 카메라)", "res://tests/autopilot_day3.tscn", ["look=roadster"]),
    "day4": ("DAY 4 길 건너 옥상: 벽 타고 올라가 Space로 차고 건너편 옥상에 착지(추적 카메라)", "res://tests/autopilot_day4.tscn", ["look=roadster"]),
    "day2_curl": ("DAY 2 옆에서: 곡면 옹벽을 타고 거꾸로 날아 옥상에 내림(고정 카메라, HUD 없음)", "res://tests/autopilot_day2.tscn", ["look=roadster", "cam=spot:curl", "clean=1", "quit=16"]),
    "day1_box": ("DAY 1 상자 차 버전(비교용)", "res://tests/autopilot_day1.tscn", ["look=box"]),
    "day1_compare": ("G5 DAY 1 날아오르는 순간 M으로 상자 → Tripo", "res://tests/autopilot_day1.tscn", ["look=box", "toggle_look=4.9", "quit=12"]),
    "day1_side": ("DAY 1 측면 카메라(트럭 넘는 높이가 보이게)", "res://tests/autopilot_day1.tscn", ["look=roadster", "cam=showcase", "quit=12"]),
    "wheels": ("G4 새 차가 처음 달리며 바퀴가 구르고 꺾이는 가까운 장면", "res://tests/autopilot_day1.tscn", ["look=roadster", "cam=wheel", "quit=9"]),
    "crash_parts": ("G6 앞차에 박으면 범퍼·미러가 떨어짐(측면)", "res://tests/fail_check.tscn", ["mode=crash", "hold=2.2", "cam=spot:crash", "clean=1", "look=roadster", "quit=7"]),
    "paint": ("G7 주차한 차 배색 바꾸기(P, 1.5초마다)", "res://tests/autopilot_day1.tscn", ["look=roadster", "cam=spot:paint", "clean=1", "palette_at=12,13.5,15,16.5", "quit=18.5"]),
}


def find_godot(arg: str | None) -> str:
    for c in [arg, os.environ.get("GODOT"), shutil.which("godot"), shutil.which("godot4"),
              "/Applications/Godot.app/Contents/MacOS/Godot"]:
        if c and os.path.exists(c):
            return c
    sys.exit("Godot 실행 파일을 찾지 못했다. --godot 경로를 주거나 GODOT 환경변수를 정한다.")


def record(name: str, godot: str, out_dir: str) -> None:
    desc, scene, vals = SHOTS[name]
    os.makedirs(out_dir, exist_ok=True)
    avi = os.path.join(out_dir, name + ".avi")
    if os.path.exists(avi):
        os.remove(avi)
    # project.godot의 mode.movie="viewport"로 화면 크기(1080x1920)가 곧 영상 크기다. 창은 작아도 된다
    cmd = [godot, "--path", ROOT, "--write-movie", avi, "--fixed-fps", "60", scene, "--", *vals]
    print(f"[{name}] {desc}\n  {' '.join(cmd)}", flush=True)
    subprocess.run(cmd, check=False)
    if not os.path.exists(avi):
        print("  녹화 파일이 없다(Godot 창이 떴는지 확인)")
        return
    ff = shutil.which("ffmpeg")
    if ff:
        mp4 = os.path.join(out_dir, name + ".mp4")
        subprocess.run([ff, "-nostdin", "-y", "-loglevel", "error", "-i", avi, "-c:v", "libx264", "-pix_fmt", "yuv420p",
                        "-crf", "18", "-preset", "medium", "-r", "60", "-c:a", "aac", "-b:a", "192k", mp4], check=False)
        print(f"  → {mp4}")


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    p = argparse.ArgumentParser(description="게임 장면을 무비 메이커로 찍는다")
    p.add_argument("shots", nargs="+", help="샷 이름, all, list")
    p.add_argument("--godot")
    p.add_argument("--out", default=os.path.join(ROOT, "rec"))
    a = p.parse_args()
    if a.shots == ["list"]:
        for k, (desc, _scene, _vals) in SHOTS.items():
            print(f"{k:<14} {desc}")
        return
    godot = find_godot(a.godot)
    names = list(SHOTS) if a.shots == ["all"] else a.shots
    for n in names:
        if n not in SHOTS:
            sys.exit(f"모르는 샷: {n} (list로 목록 보기)")
        record(n, godot, a.out)


if __name__ == "__main__":
    main()
