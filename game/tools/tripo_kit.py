#!/usr/bin/env python3
"""Tripo 에셋 툴킷: 그림 한 장이나 글 한 줄로 이 Godot 게임에 바로 넣을 3D 에셋을 만든다.

    python tools/tripo_kit.py car <그림 또는 네 방향 폴더> --name 이름 --length 미터
    python tools/tripo_kit.py quick "<설명>" --name 이름 --kind car|person|prop --size 미터 [--anims 걷기,화내기]
    python tools/tripo_kit.py batch <목록 파일>      # 한 줄에 "이름 | 설명 | 종류 | 크기"
    python tools/tripo_kit.py status

- 실제로 실행하는 tripo 명령을 "$ tripo ..." 한 줄로 먼저 보여 준다.
- 돈이 드는 단계는 --no-wait로 내고 task_id를 바로 .tripo-work/<이름>/state.json에 적은 뒤
  tripo task watch로 기다린다. 다시 돌리면 끝난 단계는 건너뛰고, 내다 끊긴 단계는 같은 작업을 다시 기다린다.
- 입력(그림·설명·옵션)이 바뀐 단계와 그 뒤 단계만 다시 한다. 일부러 다시 하려면 --redo <단계>.
- Blender 후작업(바퀴 떼어 내기, 크기·방향·바닥 맞추기)은 이 파일을 Blender로 다시 실행해서 한다.
- 결과: assets/models/<이름>/<이름>.glb 와 <이름>.json(크기·바퀴 위치, Godot 좌표: +Z 앞, +X 왼쪽, +Y 위)
"""
import argparse
import hashlib
import json
import math
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent  # godot-roadster/
WORK = ROOT / ".tripo-work"  # tripo 원본·상태(커밋 안 함, Godot도 안 읽음)
GAME = ROOT / "assets" / "models"

KINDS = ("car", "person", "prop")
FACES = {"car": 12000, "person": 20000, "prop": 5000}  # quick/batch 면 수 예산
RIG_V1 = "v1.0-20240301"  # 90개 넘는 사람 동작(화내기 등). v2.5는 기본 11개만
V2_ANIMS = {"idle", "walk", "run", "dive", "climb", "jump", "slash", "shoot", "hurt", "fall", "turn"}
ANIM_ALIASES = {
    "걷기": "walk", "달리기": "run", "대기": "idle", "서있기": "idle", "점프": "jump", "넘어지기": "fall",
    "화내기": "angry", "박수": "clap", "인사": "greet", "손흔들기": "wave", "환호": "cheer", "울기": "cry", "웃기": "laugh",
}
V1_NAMES = {"angry": "angry_01", "greet": "greet_01", "wave": "wave_goodbye_01", "laugh": "laugh_01", "scared": "scared_01"}


# --- 화면 출력 -------------------------------------------------------------------

def say(msg=""):
    print(msg, flush=True)


def die(msg, code=1):
    say(f"✗ {msg}")
    sys.exit(code)


def quote(a):
    a = str(a)
    return f'"{a}"' if (not a or re.search(r'[\s"\'&|<>^$;]', a)) else a


EXIT_HINTS = {
    2: "명령 인자가 잘못됐습니다",
    3: "로그인이 필요합니다: tripo doctor 로 확인하세요",
    4: "크레딧이 부족합니다: tripo topup",
    5: "콘텐츠 정책에 걸렸습니다. 그림·설명을 바꿔 보세요",
    6: "작업이 실패했습니다(크레딧은 자동 환불)",
    7: "네트워크 오류. tripo balance 로 이미 냈는지 확인한 뒤 다시 돌리세요",
    9: "요청이 너무 많습니다. 잠시 뒤 다시 돌리세요",
}


# --- tripo 실행 ------------------------------------------------------------------

def _tripo_base():
    exe = shutil.which("tripo")
    if not exe:
        die("tripo 가 없습니다: npm install -g tripo-cli")
    # Windows의 tripo.cmd를 거치면 JSON 인자 따옴표가 깨지므로 node로 바로 부른다
    cli = Path(exe).parent / "node_modules" / "tripo-cli" / "dist" / "cli.js"
    node = shutil.which("node")
    return [node, str(cli)] if (cli.exists() and node) else [exe]


_TRIPO = None


def tripo(args, stream=False):
    """tripo 명령을 화면에 한 줄로 보이고 실행한다. (종료 코드, 마지막 JSON 줄)."""
    global _TRIPO
    if _TRIPO is None:
        _TRIPO = _tripo_base()
    args = [rel(a) for a in args]  # 화면에 보인 그대로 실행한다(cwd = 게임 폴더)
    say("$ tripo " + " ".join(quote(a) for a in args))
    p = subprocess.Popen(_TRIPO + args, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                         text=True, encoding="utf-8", errors="replace", cwd=ROOT)
    last = None
    for line in p.stdout:
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            obj = json.loads(line)
        except ValueError:
            continue
        if stream and obj.get("event") == "progress":
            print(f"\r  … {obj.get('status')} {obj.get('progress')}%   ", end="", flush=True)
            continue
        last = obj
    code = p.wait()
    if stream:
        print("\r" + " " * 40 + "\r", end="", flush=True)
    return code, last


def rel(a):
    """게임 폴더 안의 경로는 상대 경로(/)로 줄인다."""
    if isinstance(a, Path) or (isinstance(a, str) and Path(a).is_absolute()):
        try:
            return Path(a).resolve().relative_to(ROOT).as_posix()
        except ValueError:
            return str(a)
    return str(a)


def sha1(path):
    h = hashlib.sha1()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()[:12]


# --- 단계 상태(돈 낸 단계 건너뛰기) ---------------------------------------------------

class Job:
    def __init__(self, name, **meta):
        if not re.fullmatch(r"[A-Za-z0-9_\-]+", name):
            die(f"이름은 영문·숫자·_- 만 씁니다: {name}")
        self.name = name
        self.dir = WORK / name
        self.path = self.dir / "state.json"
        self.state = json.loads(self.path.read_text(encoding="utf-8")) if self.path.exists() else {"name": name, "steps": {}}
        self.state.update(meta)
        self.dir.mkdir(parents=True, exist_ok=True)
        (WORK / ".gdignore").touch()
        self.save()

    @property
    def steps(self):
        return self.state["steps"]

    def save(self):
        self.path.write_text(json.dumps(self.state, ensure_ascii=False, indent=2), encoding="utf-8")

    def drop_from(self, key):
        """key 단계와 그 뒤 단계를 지운다(파일·크레딧 기록 포함)."""
        keys = list(self.steps)
        if key not in keys:
            return
        for k in keys[keys.index(key):]:
            del self.steps[k]
        self.save()

    def _reuse(self, key, sig, label):
        s = self.steps.get(key)
        if s and s.get("sig") != sig:
            say(f"↻ {label}: 입력이 바뀌어서 이 단계부터 다시 합니다")
            self.drop_from(key)
            return None
        return s

    def step(self, key, label, args, files=()):
        """돈 드는 tripo 단계 하나. 끝난 단계는 건너뛰고, 내다 끊긴 단계는 같은 task를 다시 기다린다."""
        args = [str(x) for x in args]
        sig = json.dumps([args, [sha1(f) for f in files]], ensure_ascii=False)
        s = self._reuse(key, sig, label)
        out = self.dir / key
        if s and s.get("status") == "success" and out.exists():
            say(f"✓ {label}: 이미 끝남(task {s['task_id']}, {s.get('credits', 0)} 크레딧) → 건너뜀")
            return s
        say(f"▶ {label}")
        if not s or not s.get("task_id"):
            code, res = tripo(args + ["--no-wait", "--json", "--yes"])
            if code != 0 or not res or not res.get("task_id"):
                die(f"{label}: 작업을 내지 못했습니다. {EXIT_HINTS.get(code, '')}", code or 1)
            s = {"sig": sig, "task_id": res["task_id"], "type": res.get("type"), "status": "submitted"}
            self.steps[key] = s
            self.save()
        else:
            say(f"  이미 낸 작업 {s['task_id']} 를 이어서 기다립니다(다시 내지 않음)")
        if out.exists():
            shutil.rmtree(out)
        code, res = tripo(["task", "watch", s["task_id"], "--download", "-o", out, "--json"], stream=True)
        if code != 0 or not res or res.get("status") != "success":
            _, info = tripo(["task", "get", s["task_id"], "--json"])
            status = (info or {}).get("status", "unknown")
            if status in ("failed", "banned", "expired", "cancelled"):
                s.pop("task_id")
                s["status"] = status
                self.save()
                die(f"{label}: 작업이 {status} 되었습니다(크레딧 환불). 다시 돌리면 새로 냅니다", 6)
            die(f"{label}: 아직 끝나지 않았습니다(상태 {status}). 다시 돌리면 같은 작업을 이어서 기다립니다", code or 1)
        model = res.get("model_file")
        s.update(status="success", credits=res.get("credits_consumed", 0), output=res.get("output"),
                 model_file=str(Path(model).resolve()) if model else None, preview=res.get("preview"))
        self.save()
        say(f"✓ {label}: task {s['task_id']}, {s['credits']} 크레딧 → {out.relative_to(ROOT)}")
        return s

    def local(self, key, label, sig_obj, fn, outputs):
        """돈 안 드는 로컬 단계(Blender). 입력이 같고 결과 파일이 있으면 건너뛴다."""
        sig = json.dumps(sig_obj, ensure_ascii=False, default=str)
        s = self._reuse(key, sig, label)
        if s and s.get("status") == "success" and all(Path(o).exists() for o in outputs):
            say(f"✓ {label}: 이미 끝남 → 건너뜀")
            return s
        say(f"▶ {label}")
        fn()
        self.steps[key] = {"sig": sig, "status": "success", "outputs": [str(o) for o in outputs]}
        self.save()
        return self.steps[key]

    def redo(self, key):
        if key:
            if key not in self.steps:
                die(f"--redo {key}: 그런 단계가 없습니다. 있는 단계: {', '.join(self.steps) or '없음'}")
            say(f"↻ --redo {key}: 이 단계부터 다시 합니다")
            self.drop_from(key)


# --- Blender ---------------------------------------------------------------------

def find_blender():
    import os
    cands = [os.environ.get("BLENDER"), shutil.which("blender")]
    cands += sorted(Path("C:/Program Files/Blender Foundation").glob("*/blender.exe"), reverse=True)
    for c in cands:
        if c and Path(c).exists():
            return str(c)
    die("Blender를 찾지 못했습니다. BLENDER 환경 변수에 blender.exe 경로를 넣어 주세요")


def run_blender(mode, spec, job):
    spec_path = job.dir / f"blender_{mode}.json"
    spec_path.write_text(json.dumps(spec, ensure_ascii=False, indent=2), encoding="utf-8")
    exe = find_blender()
    cmd = [exe, "-b", "--factory-startup", "--python", str(Path(__file__).resolve()), "--", mode, str(spec_path)]
    say("$ blender -b --python tools/tripo_kit.py -- " + mode + " " + quote(spec_path.relative_to(ROOT)))
    p = subprocess.run(cmd, stdin=subprocess.DEVNULL, capture_output=True, text=True, encoding="utf-8", errors="replace")
    lines = (p.stdout + p.stderr).splitlines()
    for line in lines:
        if line.startswith("[kit]"):
            say("  " + line[5:].strip())
    if p.returncode != 0 or not any(l.startswith("[kit] 저장") for l in lines):
        say("\n".join(lines[-30:]))
        die("Blender 후작업이 실패했습니다")


# --- 명령: car ---------------------------------------------------------------------

VIEW_RE = {
    "front": re.compile(r"front|정면|앞", re.I),
    "back": re.compile(r"back|rear|후면|뒤", re.I),
    "left": re.compile(r"left|왼", re.I),
    "right": re.compile(r"right|오른", re.I),
}
NOT_VIEW = re.compile(r"3q|3_4|three|sheet|reference|preview", re.I)


def pick_views(folder):
    imgs = [p for p in sorted(Path(folder).iterdir()) if p.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp")]
    views = {}
    for view, rx in VIEW_RE.items():
        hits = [p for p in imgs if rx.search(p.stem) and not NOT_VIEW.search(p.stem)]
        if hits:
            views[view] = hits[0]
    if "front" not in views or len(views) < 2:
        die(f"{folder} 에서 앞(front)을 포함한 방향 이미지를 2장 이상 찾지 못했습니다: {[p.name for p in imgs]}")
    return views


def cmd_car(a):
    src = Path(a.image).resolve()
    if not src.exists():
        die(f"그림이 없습니다: {src}")
    job = Job(a.name, kind="car", size=a.length, source=str(src))
    job.redo(a.redo)
    say(f"■ 우리 차 '{a.name}' (길이 {a.length} m) — {src.name}")

    if src.is_dir():
        say("✓ 1/6 네 방향 이미지: 폴더에 이미 있음 → Tripo로 만들지 않음")
        views = pick_views(src)
    else:
        job.step("views", "1/6 그림 → 네 방향 이미지",
                     ["generate", "image-to-multiview", src, "--name", f"{a.name}-views"], files=[src])
        views = pick_views(job.dir / "views")
    # 업로드할 이름에 방향을 박아 둔다(tripo가 파일 이름으로 방향을 정한다)
    vdir = job.dir / "views_named"
    vdir.mkdir(exist_ok=True)
    named = []
    for view in ("front", "left", "back", "right"):
        if view in views:
            dst = vdir / f"{view}{views[view].suffix.lower()}"
            shutil.copyfile(views[view], dst)
            named.append(dst)
    say("  방향: " + ", ".join(f"{v}={views[v].name}" for v in views))

    shape = job.step("shape", "2/6 네 방향 → 3D 모양(텍스처 없이)",
                     ["generate", "multiview-to-model", *named, "--model", "tripo-v3.1",
                      "-p", "texture=false", "-p", "pbr=false", "-p", f"face_limit={a.faces}", "--name", f"{a.name}-shape"],
                     files=named)
    tex = job.step("texture", "3/6 텍스처 입히기",
                   ["model", "texture", shape["task_id"], "--texture-quality", a.texture_quality, "--name", f"{a.name}-tex"])
    seg = job.step("segment", "4/6 부품 나누기",
                   ["mesh", "segment", tex["task_id"], "--model", a.seg_model, "--name", f"{a.name}-parts"])

    out = GAME / a.name / f"{a.name}.glb"
    meta = out.with_suffix(".json")
    spec = {"name": a.name, "textured": str(glb_of(job, "texture")), "parts": str(glb_of(job, "segment")),
            "length": a.length, "yaw": a.yaw, "out": str(out), "meta": str(meta)}
    job.local("post", "5/6 Blender 후작업(바퀴 떼어 내기, 크기·방향·바닥)",
              [spec, tex["task_id"], seg["task_id"]], lambda: run_blender("car", spec, job), [out, meta])
    finish(job, out, meta, "6/6 게임 폴더")


def glb_of(job, key):
    s = job.steps[key]
    if s.get("model_file") and Path(s["model_file"]).exists() and s["model_file"].lower().endswith(".glb"):
        return Path(s["model_file"])
    glbs = sorted((job.dir / key).glob("*.glb"))
    if not glbs:
        die(f"{key} 단계 결과에 .glb가 없습니다: {job.dir / key}")
    return glbs[0]


def finish(job, out, meta, label):
    m = json.loads(Path(meta).read_text(encoding="utf-8"))
    spent = sum(s.get("credits") or 0 for s in job.steps.values())
    job.state["game_file"] = str(out.relative_to(ROOT)).replace("\\", "/")
    job.state["credits"] = spent
    job.save()
    say(f"✓ {label}: res://{job.state['game_file']}")
    sz = m.get("size_m")
    if sz:
        say(f"  크기(폭×높이×길이) {sz[0]:.2f} × {sz[1]:.2f} × {sz[2]:.2f} m")
    if m.get("wheels"):
        say(f"  바퀴: {m.get('wheel_method')} · 반지름 {m['wheel_radius']:.3f} m · wheel_x {m['wheel_x']:.3f} · "
            f"wheel_z 앞 {m['wheel_z_front']:.3f} / 뒤 {m['wheel_z_back']:.3f}")
    if m.get("animations"):
        say("  동작: " + ", ".join(m["animations"]))
    for w in m.get("warnings", []):
        say(f"  ! {w}")
    say(f"  이번 에셋에 쓴 크레딧 합계: {spent}")


# --- 명령: quick -------------------------------------------------------------------

def anim_plan(names):
    """사람 동작 이름 → (rig 모델, retarget preset 목록)."""
    names = [ANIM_ALIASES.get(n.strip(), n.strip().lower()) for n in names if n.strip()]
    if len(names) > 5:
        die("동작은 5개까지입니다")
    if all(n in V2_ANIMS for n in names):
        return None, [f"preset:{n}" for n in names]
    return RIG_V1, [f"preset:biped:{V1_NAMES.get(n, n)}" for n in names]


def cmd_quick(a):
    job = Job(a.name, kind=a.kind, size=a.size, desc=a.desc)
    job.redo(a.redo)
    say(f"■ {a.kind} '{a.name}' ({a.size} m) — {a.desc}")
    faces = a.faces or FACES[a.kind]
    if a.kind == "person":
        prompt = f"{a.desc}, T-pose, standing straight, full body"
        gen = ["make", prompt, "--for", "anim", "-p", f"face_limit={faces}", "--name", a.name]
    else:
        gen = ["make", a.desc, "--for", "game-mobile", "-p", f"face_limit={faces}", "--name", a.name]
    total = 5 if a.kind == "person" else 2
    say("  (계획표에 뒤 단계가 보여도 --no-wait라 생성만 내고, 이어지는 단계는 툴킷이 하나씩 냅니다)")
    model = job.step("model", f"1/{total} 게임용 설정으로 3D 만들기", gen)
    src_key, anims = "model", []

    if a.kind == "person":
        rig_model, presets = anim_plan(a.anims.split(","))
        check = job.step("check", f"2/{total} 리깅 가능한지 확인", ["anim", "check", model["task_id"], "--name", f"{a.name}-check"])
        out = check.get("output") or {}
        if out.get("riggable") is False:
            die("Tripo가 이 사람 모델은 리깅할 수 없다고 합니다. --redo model 로 다시 만들어 보세요")
        rig_type = out.get("rig_type") or "biped"
        if rig_model and rig_type != "biped":
            die(f"화내기 같은 동작은 두 발 사람(biped)만 됩니다. 이 모델은 {rig_type}")
        rig_args = ["anim", "rig", model["task_id"], "--rig-type", rig_type, "--out-format", "glb", "--name", f"{a.name}-rig"]
        if rig_model:
            rig_args += ["-p", f"model={rig_model}"]
        rig = job.step("rig", f"3/{total} 리깅(뼈대 넣기, {rig_type})", rig_args)
        job.step("anim", f"4/{total} 동작 입히기({', '.join(presets)})",
                 ["anim", "retarget", rig["task_id"], "--animation", *presets, "--out-format", "glb",
                  "--animate-in-place", "--name", f"{a.name}-anim"])
        src_key, anims = "anim", presets

    out = GAME / a.name / f"{a.name}.glb"
    meta = out.with_suffix(".json")
    spec = {"name": a.name, "src": str(glb_of(job, src_key)), "kind": a.kind, "size": a.size, "yaw": a.yaw,
            "out": str(out), "meta": str(meta), "anims": anims}
    job.local("post", f"{total}/{total} Blender 후작업(크기·방향·바닥)",
              [spec, job.steps[src_key]["task_id"]], lambda: run_blender("fit", spec, job), [out, meta])
    finish(job, out, meta, "게임 폴더")


# --- 명령: batch -------------------------------------------------------------------

def parse_list(path):
    jobs = []
    for n, raw in enumerate(Path(path).read_text(encoding="utf-8").splitlines(), 1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        cols = [c.strip() for c in line.split("|")]
        if len(cols) != 4:
            die(f"{path}:{n}: '이름 | 설명 | 종류 | 크기' 네 칸이어야 합니다: {raw}")
        name, desc, kind, size = cols
        if kind not in KINDS:
            die(f"{path}:{n}: 종류는 {'/'.join(KINDS)} 중 하나: {kind}")
        try:
            size = float(size)
        except ValueError:
            die(f"{path}:{n}: 크기는 미터 숫자: {size}")
        jobs.append({"name": name, "desc": desc, "kind": kind, "size": size})
    if not jobs:
        die(f"{path}: 만들 것이 없습니다")
    return jobs


def cmd_batch(a):
    items = parse_list(a.list)
    bdir = WORK / "_batch"
    bdir.mkdir(parents=True, exist_ok=True)
    (WORK / ".gdignore").touch()
    manifest = bdir / f"{Path(a.list).stem}.yaml"
    jobs = []
    for it in items:
        Job(it["name"], kind=it["kind"], size=it["size"], desc=it["desc"], batch=str(manifest.relative_to(ROOT)))
        out = str(WORK / it["name"] / "batch")
        if it["kind"] == "person":  # T자 사람 → 리깅 확인 → 리깅 → 대기·걷기
            jobs.append({"name": it["name"], "input": f"{it['desc']}, T-pose, standing straight, full body",
                         "for": "anim", "params": {"face_limit": FACES["person"]}, "out": out})
        else:  # game-mobile의 생성 설정 그대로, FBX 변환만 빼고 GLB로 받는다
            jobs.append({"name": it["name"], "input": it["desc"], "model": "tripo-p1",
                         "params": {"texture": True, "pbr": True, "texture_quality": "standard",
                                    "face_limit": FACES[it["kind"]]}, "out": out})
    # JSON은 YAML이기도 하다
    manifest.write_text(json.dumps({"concurrency": a.concurrency, "jobs": jobs}, ensure_ascii=False, indent=2), encoding="utf-8")
    say(f"■ 일괄 {len(jobs)}개 — 매니페스트 {manifest.relative_to(ROOT)} (끝난 줄은 tripo가 알아서 건너뜀)")
    code, res = tripo(["batch", "run", manifest, "--json", "--yes"])
    states = (res or {}).get("jobs") or {}
    if not states:
        die(f"tripo batch run 이 결과를 내지 않았습니다. {EXIT_HINTS.get(code, '')}", code or 1)

    done = 0
    for it in items:
        st = states.get(it["name"], {})
        job = Job(it["name"])
        if st.get("status") != "success":
            say(f"✗ {it['name']}: {st.get('status', '안 됨')} {st.get('error', '')}")
            continue
        odir = Path(st["output_dir"])
        glbs = sorted(odir.glob("*.glb"))
        if not glbs:
            say(f"✗ {it['name']}: {odir} 에 .glb가 없습니다")
            continue
        job.steps["batch"] = {"sig": "batch", "status": "success", "task_id": st.get("task_id"),
                              "credits": batch_credits(odir), "model_file": str(glbs[0])}
        job.save()
        out = GAME / it["name"] / f"{it['name']}.glb"
        meta = out.with_suffix(".json")
        spec = {"name": it["name"], "src": str(glbs[0]), "kind": it["kind"], "size": it["size"], "yaw": 0,
                "out": str(out), "meta": str(meta), "anims": ["preset:idle", "preset:walk"] if it["kind"] == "person" else []}
        job.local("post", f"{it['name']}: Blender 후작업", [spec, st.get("task_id")],
                  lambda spec=spec, job=job: run_blender("fit", spec, job), [out, meta])
        finish(job, out, meta, f"{it['name']}: 게임 폴더")
        done += 1
    say(f"■ 일괄 끝: {done}/{len(items)}")
    if done < len(items):
        sys.exit(6)


def batch_credits(odir):
    try:
        return json.loads((odir / "task.json").read_text(encoding="utf-8")).get("credits_consumed") or 0
    except (OSError, ValueError):
        return 0


# --- 명령: status ------------------------------------------------------------------

def cmd_status(a):
    say("■ 만든 에셋")
    states = sorted(WORK.glob("*/state.json")) if WORK.exists() else []
    if not states:
        say("  (아직 없음)")
    total = 0
    for p in states:
        st = json.loads(p.read_text(encoding="utf-8"))
        steps = st.get("steps", {})
        spent = sum(s.get("credits") or 0 for s in steps.values())
        total += spent
        marks = " ".join(f"{k}{'✓' if s.get('status') == 'success' else '…'}" for k, s in steps.items()) or "시작 전"
        game = st.get("game_file")
        where = f"res://{game}" if game and (ROOT / game).exists() else "게임 폴더에 아직 없음"
        say(f"  {st['name']:<16} {st.get('kind', '?'):<6} {st.get('size', '?')} m  {spent:>4} 크레딧  [{marks}]  {where}")
    extra = [g for g in sorted(GAME.glob("*/*.glb")) if not (WORK / g.parent.name / "state.json").exists()] if GAME.exists() else []
    for g in extra:
        say(f"  {g.parent.name:<16} (툴킷 기록 없음)  res://{g.relative_to(ROOT).as_posix()}")
    say(f"  툴킷으로 쓴 크레딧 합계: {total}")
    say("■ 남은 크레딧")
    code, res = tripo(["balance", "--json"])
    if code != 0 or not res:
        die(f"잔액을 읽지 못했습니다. {EXIT_HINTS.get(code, '')}", code or 1)
    say(f"  {res.get('balance')} 크레딧 (사용 중 묶인 것 {res.get('frozen', 0)})")


# --- Blender 안에서 도는 부분 ----------------------------------------------------------
# blender -b --python tripo_kit.py -- car|fit spec.json
# Blender 좌표(Z 위)로 정리한 뒤 glTF로 내보내면 Godot 좌표가 된다: Blender -Y = Godot +Z(앞), +X = 왼쪽, +Z = 위.

def kit(msg):
    print(f"[kit] {msg}", flush=True)


def blender_main(mode, spec_path):
    import bpy
    spec = json.loads(Path(spec_path).read_text(encoding="utf-8"))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    Path(spec["out"]).parent.mkdir(parents=True, exist_ok=True)
    meta = {"name": spec["name"], "warnings": []}
    if mode == "car":
        _bl_car(spec, meta)
    else:
        _bl_fit(spec, meta)
    Path(spec["meta"]).write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    kit(f"저장 {spec['out']}")


def _bl_import(path):
    import bpy
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    return [o for o in bpy.data.objects if o not in before]


def _bl_bake(objs, M):
    """메시 정점에 월드 변환과 M을 구워 넣고 오브젝트 변환을 0으로 둔다. 메시 아닌 것은 지운다."""
    import bpy
    from mathutils import Matrix
    meshes = []
    for o in objs:
        if o.type == "MESH":
            if o.data.users > 1:
                o.data = o.data.copy()
            mw = o.matrix_world.copy()
            o.parent = None
            o.data.transform(M @ mw)
            o.matrix_world = Matrix.Identity(4)
            meshes.append(o)
    for o in objs:
        if o.type != "MESH":
            bpy.data.objects.remove(o)
    return meshes


def _bl_bbox(objs):
    from mathutils import Vector
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        for v in o.data.vertices:
            c = o.matrix_world @ v.co
            for i in range(3):
                lo[i] = min(lo[i], c[i])
                hi[i] = max(hi[i], c[i])
    return lo, hi


def _bl_select(objs, active=None):
    import bpy
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]


def _bl_join(objs, name):
    import bpy
    if len(objs) > 1:
        _bl_select(objs)
        bpy.ops.object.join()
    objs[0].name = name
    objs[0].data.name = name
    return objs[0]


def _bl_split_loose(obj):
    import bpy
    _bl_select([obj])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=1e-5)  # glTF는 UV 경계·각진 모서리에서 정점을 쪼개 둔다
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    return list(bpy.context.selected_objects)


def _bl_has_texture(objs):
    for o in objs:
        for m in o.data.materials:
            if m and m.use_nodes and any(n.type == "TEX_IMAGE" and n.image for n in m.node_tree.nodes):
                return True
    return False


def _bl_transfer_texture(parts, src_objs):
    """부품 나누기 결과에 텍스처가 없으면 텍스처 입힌 모델에서 UV·재질을 옮긴다."""
    import bpy
    src = _bl_join(src_objs, "_textured")
    uv_name = src.data.uv_layers.active.name if src.data.uv_layers.active else "UVMap"
    for p in parts:
        while p.data.uv_layers:
            p.data.uv_layers.remove(p.data.uv_layers[0])
        p.data.uv_layers.new(name=uv_name)
        mod = p.modifiers.new("uv_from_textured", "DATA_TRANSFER")
        mod.object = src
        mod.use_loop_data = True
        mod.data_types_loops = {"UV"}
        mod.loop_mapping = "POLYINTERP_NEAREST"
        _bl_select([p])
        bpy.ops.object.modifier_apply(modifier=mod.name)
        p.data.materials.clear()
        for m in src.data.materials:
            p.data.materials.append(m)
    bpy.data.objects.remove(src)


def _bl_wheel_groups(parts, W, L, H):
    """부품 중에서 바퀴 넷을 고른다. 땅에 닿고, 옆에서 보면 둥글고, 네 귀퉁이에 있는 부품."""
    boxes = {o.name: _bl_bbox([o]) for o in parts}
    best = {}
    for o in parts:
        lo, hi = boxes[o.name]
        d = hi - lo
        c = (lo + hi) / 2
        if d.z < 0.2 * H or d.z > 0.8 * H or lo.z > 0.1 * H or c.z > 0.5 * H:
            continue
        if d.x > 0.5 * W or abs(c.y) < 0.15 * L or abs(c.x) < 0.1 * W:
            continue
        ratio = d.y / max(d.z, 1e-6)
        if not 0.6 < ratio < 1.6:
            continue
        q = ("front" if c.y < 0 else "back") + "-" + ("left" if c.x > 0 else "right")
        score = abs(math.log(ratio)) - 0.5 * d.z / H
        if q not in best or score < best[q][0]:
            best[q] = (score, o)
    if len(best) < 4:
        return None
    groups = {}
    taken = {o.name for _, o in best.values()}
    for q, (_, prim) in best.items():
        lo, hi = boxes[prim.name]
        pad = (hi - lo) * 0.15
        grp = [prim]
        for o in parts:  # 같은 바퀴의 림·브레이크 같은 조각도 같이
            if o.name in taken:
                continue
            olo, ohi = boxes[o.name]
            if all(olo[i] >= lo[i] - pad[i] and ohi[i] <= hi[i] + pad[i] for i in range(3)):
                grp.append(o)
                taken.add(o.name)
        groups[q] = grp
    return groups


def _bl_cut_wheels(body, W, L, H):
    """부품으로 못 찾았을 때: 땅에 닿은 점으로 바퀴 자리를 잡고 원기둥 안의 면을 잘라 낸다."""
    import bmesh
    import bpy
    from mathutils import Vector
    r = min(max(0.075 * L, 0.22 * H), 0.42 * H)
    verts = [body.matrix_world @ v.co for v in body.data.vertices]
    centers = {}
    for fb, ys in (("front", -1), ("back", 1)):
        for lr, xs in (("left", 1), ("right", -1)):
            low = [v for v in verts if v.z < 0.04 * H and v.y * ys > 0.15 * L and v.x * xs > 0]
            if not low:
                low = [v for v in verts if v.z < 0.12 * H and v.y * ys > 0.15 * L and v.x * xs > 0]
            if not low:
                return None
            yc = sum(v.y for v in low) / len(low)
            side = [abs(v.x) for v in verts if v.z < 2 * r and abs(v.y - yc) < r and v.x * xs > 0]
            x_out = max(side) if side else W / 2
            centers[f"{fb}-{lr}"] = (Vector((xs * (x_out - 0.035 * L), yc, r)), xs, x_out)
    wheels = {}
    for q, (c, xs, x_out) in centers.items():
        bm = bmesh.new()
        bm.from_mesh(body.data)
        for f in bm.faces:
            p = f.calc_center_median()
            f.select = (p.x * xs > x_out - 0.07 * L and math.hypot(p.y - c.y, p.z - c.z) < r * 1.02)
        bm.to_mesh(body.data)
        bm.free()
        _bl_select([body])
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.separate(type="SELECTED")
        bpy.ops.object.mode_set(mode="OBJECT")
        new = [o for o in bpy.context.selected_objects if o != body]
        if not new:
            return None
        wheels[q] = [new[0]]
    return wheels


def _bl_car(spec, meta):
    import bpy
    from mathutils import Matrix, Vector
    R = Matrix.Rotation(math.radians(-90 + spec.get("yaw", 0)), 4, "Z")  # Tripo +X 앞 → Blender -Y 앞
    tex = _bl_bake(_bl_import(spec["textured"]), R)
    parts = _bl_bake(_bl_import(spec["parts"]), R) if spec.get("parts") else []
    kit(f"텍스처 모델 {len(tex)}개 메시, 부품 {len(parts)}개")
    if parts:
        tlo, thi = _bl_bbox(tex)
        plo, phi = _bl_bbox(parts)
        s = (thi - tlo).length / max((phi - plo).length, 1e-6)
        if abs(s - 1) > 0.02 or ((tlo + thi) / 2 - (plo + phi) / 2).length > 0.02 * (thi - tlo).length:
            M = Matrix.Translation((tlo + thi) / 2) @ Matrix.Scale(s, 4) @ Matrix.Translation(-(plo + phi) / 2)
            for o in parts:
                o.data.transform(M)
            kit("부품 모델 위치·크기를 텍스처 모델에 맞춤")
        if not _bl_has_texture(parts) and _bl_has_texture(tex):
            _bl_transfer_texture(parts, tex)
            kit("부품에 텍스처가 없어서 텍스처 모델에서 옮겨 입힘")
        else:
            for o in tex:
                bpy.data.objects.remove(o)
    else:
        parts = tex
    if len(parts) == 1:
        parts = _bl_split_loose(parts[0])

    lo, hi = _bl_bbox(parts)
    d = hi - lo
    if d.x > d.y * 1.15:
        meta["warnings"].append("차가 옆으로 누워 있어 90도 돌렸습니다. 앞뒤가 반대면 --yaw 180 으로 다시 돌리세요")
        M = Matrix.Rotation(math.radians(90), 4, "Z")
        for o in parts:
            o.data.transform(M)
        lo, hi = _bl_bbox(parts)
        d = hi - lo
    s = spec["length"] / d.y
    c = (lo + hi) / 2
    M = Matrix.Scale(s, 4) @ Matrix.Translation(Vector((-c.x, -c.y, -lo.z)))
    for o in parts:
        o.data.transform(M)
    lo, hi = _bl_bbox(parts)
    W, L, H = (hi - lo)
    kit(f"크기 맞춤: 길이 {L:.2f} m, 폭 {W:.2f} m, 높이 {H:.2f} m (x{s:.3f})")

    groups = _bl_wheel_groups(parts, W, L, H)
    if groups:
        meta["wheel_method"] = "부품 나누기 결과에서 바퀴 고름"
        rest = [o for o in parts if not any(o in g for g in groups.values())]
        body = _bl_join(rest, "body")
    else:
        body = _bl_join(parts, "body")
        groups = _bl_cut_wheels(body, W, L, H)
        meta["wheel_method"] = "땅 닿는 점으로 원기둥을 잘라 냄(거침)"
        meta["warnings"].append("부품에서 바퀴 넷을 못 찾아 원기둥으로 잘라 냈습니다. 바퀴 자리가 맞는지 Godot에서 확인하세요")
        if not groups:
            raise SystemExit("바퀴를 찾지 못했습니다")
    kit(f"바퀴: {meta['wheel_method']}")

    wheels = {}
    for q, grp in groups.items():
        w = _bl_join(grp, f"wheel-{q}")
        wlo, whi = _bl_bbox([w])
        center = (wlo + whi) / 2
        w.data.transform(Matrix.Translation(-center))
        w.location = center  # 바퀴 원점 = 바퀴 가운데(Godot에서 그 자리에서 돈다)
        wheels[q] = {"godot_pos": [round(center.x, 4), round(center.z, 4), round(-center.y, 4)],
                     "radius": round((whi.z - wlo.z) / 2, 4), "width": round(whi.x - wlo.x, 4)}

    meta.update(kind="car", size_m=[round(W, 3), round(H, 3), round(L, 3)], wheels=wheels,
                wheel_radius=sum(w["radius"] for w in wheels.values()) / 4,
                wheel_x=sum(abs(w["godot_pos"][0]) for w in wheels.values()) / 4,
                wheel_z_front=(wheels["front-left"]["godot_pos"][2] + wheels["front-right"]["godot_pos"][2]) / 2,
                wheel_z_back=(wheels["back-left"]["godot_pos"][2] + wheels["back-right"]["godot_pos"][2]) / 2,
                wheel_center_y=sum(w["godot_pos"][1] for w in wheels.values()) / 4,
                nodes=["body"] + [f"wheel-{q}" for q in wheels])
    bpy.ops.export_scene.gltf(filepath=spec["out"], export_format="GLB", export_yup=True, export_apply=False)


def _bl_fit(spec, meta):
    import bpy
    from mathutils import Vector
    # 뼈 모양용 구(Icosphere)처럼 장면에 안 놓인 오브젝트는 빼고 잰다
    objs = [o for o in _bl_import(spec["src"])
            if not any(c.name.startswith("glTF_not_exported") for c in o.users_collection)]
    root = bpy.data.objects.new(spec["name"], None)
    bpy.context.scene.collection.objects.link(root)
    for o in objs:
        if o.parent is None:
            o.parent = root
    root.rotation_euler = (0, 0, math.radians(-90 + spec.get("yaw", 0)))  # Tripo +X 앞 → Godot +Z 앞
    bpy.context.view_layer.update()

    def world_box():
        dg = bpy.context.evaluated_depsgraph_get()
        lo = Vector((1e9, 1e9, 1e9))
        hi = Vector((-1e9, -1e9, -1e9))
        for o in objs:
            if o.type != "MESH":
                continue
            ev = o.evaluated_get(dg)
            for v in ev.to_mesh().vertices:
                c = ev.matrix_world @ v.co
                for i in range(3):
                    lo[i] = min(lo[i], c[i])
                    hi[i] = max(hi[i], c[i])
            ev.to_mesh_clear()
        return lo, hi

    lo, hi = world_box()
    d = hi - lo
    if spec["kind"] == "car" and d.x > d.y * 1.15:
        root.rotation_euler.z += math.radians(90)
        meta["warnings"].append("차가 옆으로 누워 있어 90도 돌렸습니다. 앞뒤가 반대면 --yaw 180 으로 다시 돌리세요")
        bpy.context.view_layer.update()
        lo, hi = world_box()
        d = hi - lo
    measure = {"car": d.y, "person": d.z}.get(spec["kind"], max(d))
    s = spec["size"] / measure
    root.scale = (s, s, s)
    bpy.context.view_layer.update()
    lo, hi = world_box()
    c = (lo + hi) / 2
    root.location = Vector((-c.x, -c.y, -lo.z))
    bpy.context.view_layer.update()
    lo, hi = world_box()
    W, L, H = hi - lo
    kit(f"크기 맞춤({ {'car': '길이', 'person': '키'}.get(spec['kind'], '가장 긴 변') } {spec['size']} m, x{s:.3f})")
    actions = [a.name for a in bpy.data.actions]
    meta.update(kind=spec["kind"], size_m=[round(W, 3), round(H, 3), round(L, 3)], animations=actions,
                requested_animations=spec.get("anims", []))
    has_anim = bool(actions)
    bpy.ops.export_scene.gltf(filepath=spec["out"], export_format="GLB", export_yup=True,
                              export_animations=has_anim, **({"export_animation_mode": "ACTIONS"} if has_anim else {}))


# --- 진입점 -----------------------------------------------------------------------

def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(prog="tripo_kit", description="그림 한 장·글 한 줄 → Godot에 바로 넣는 3D 에셋 (Tripo CLI)")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("car", help="우리가 운전할 차: 그림 → 네 방향 → 3D → 텍스처 → 부품 → Blender → 게임 폴더")
    p.add_argument("image", help="차 그림 한 장, 또는 front/back(rear)/left/right 이미지가 든 폴더")
    p.add_argument("--name", required=True)
    p.add_argument("--length", type=float, required=True, help="차 길이(미터)")
    p.add_argument("--faces", type=int, default=30000, help="3D 모양 면 수 상한")
    p.add_argument("--texture-quality", default="detailed", choices=["standard", "detailed", "extreme"])
    p.add_argument("--seg-model", default="v2.0-20260430", help="부품 나누기 모델(v2는 의미 단위, v1.0-20250506은 형상 단위)")
    p.add_argument("--yaw", type=float, default=0, help="앞뒤가 틀리면 180 등으로 더 돌린다(돈 안 드는 후작업만 다시 함)")
    p.add_argument("--redo", help="이 단계부터 다시: views shape texture segment post")
    p.set_defaults(fn=cmd_car)

    p = sub.add_parser("quick", help="주차된 차·사람·소품: 게임용 설정으로 한 번에")
    p.add_argument("desc", help="설명 한 줄")
    p.add_argument("--name", required=True)
    p.add_argument("--kind", required=True, choices=KINDS)
    p.add_argument("--size", type=float, required=True, help="차는 길이, 사람은 키, 소품은 가장 긴 변(미터)")
    p.add_argument("--anims", default="walk,angry", help="사람 동작, 쉼표로(걷기·화내기·달리기·대기…, 5개까지)")
    p.add_argument("--faces", type=int, help="면 수 상한(기본: 차 12000, 사람 20000, 소품 5000)")
    p.add_argument("--yaw", type=float, default=0)
    p.add_argument("--redo", help="이 단계부터 다시: model check rig anim post")
    p.set_defaults(fn=cmd_quick)

    p = sub.add_parser("batch", help='목록 파일로 한꺼번에(한 줄: "이름 | 설명 | 종류 | 크기")')
    p.add_argument("list")
    p.add_argument("--concurrency", type=int, default=2)
    p.set_defaults(fn=cmd_batch)

    p = sub.add_parser("status", help="만든 에셋 목록과 남은 크레딧")
    p.set_defaults(fn=cmd_status)

    a = ap.parse_args()
    a.fn(a)


if __name__ == "__main__":
    if "--" in sys.argv and sys.argv[sys.argv.index("--") + 1:][:1] in (["car"], ["fit"]):
        rest = sys.argv[sys.argv.index("--") + 1:]
        blender_main(rest[0], rest[1])
    else:
        main()
