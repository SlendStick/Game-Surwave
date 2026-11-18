#!/usr/bin/env python3
"""Headless Godot CI test runner for Surwave.

Suites:
  - core: Godot --import + all built-in SURW_* tests + quick smoke autoplay runs
  - matrix: 12 character/weapon/map autoplay runs (60s simulated time at 20x speed)
  - all: both suites
"""

from __future__ import annotations

import argparse
import codecs
import os
import re
import selectors
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

FATAL_PATTERNS = [
    re.compile(r"SCRIPT ERROR"),
    re.compile(r"Parse Error"),
    re.compile(r"Assertion failed"),
    re.compile(r"USER ERROR"),
    re.compile(r"ERROR:"),
    re.compile(r"\[SURWAVE\]\s+\w+_fail"),
    re.compile(r"\[SURWAVE\]\s+lifetime_bad"),
    re.compile(r"\bproblems=[1-9]\d*\b"),
    re.compile(r"\bout_of_bounds=[1-9]\d*\b"),
    re.compile(r"\blayout_problems=[1-9]\d*\b"),
]


@dataclass
class TestCase:
    name: str
    env: dict[str, str]
    args: list[str]
    expect_re: str
    timeout_s: float = 35.0
    wait_for_exit: bool = False


CORE_TESTS: list[TestCase] = [
    TestCase(
        name="perk_dependencies",
        env={"SURW_PERK_DEP_TEST": "1"},
        args=["--headless", "--audio-driver", "Dummy", "--path", ".", "--", "--autoplay", "--god"],
        expect_re=r"\[SURWAVE\] perk_dependencies OK:",
    ),
    TestCase(
        name="perk_effects",
        env={"SURW_PERK_EFFECT_TEST": "1"},
        args=["--headless", "--audio-driver", "Dummy", "--path", ".", "--", "--autoplay", "--god"],
        expect_re=r"\[SURWAVE\] perk_effects OK:",
    ),
    TestCase(
        name="hud_layout",
        env={"SURW_HUD_TEST": "1"},
        args=["--headless", "--audio-driver", "Dummy", "--path", ".", "--", "--autoplay", "--god"],
        expect_re=r"\[SURWAVE\] hud_test done .*problems=0",
    ),
    TestCase(
        name="pause_menu",
        env={"SURW_PAUSE_TEST": "1"},
        args=["--headless", "--audio-driver", "Dummy", "--path", ".", "--", "--autoplay", "--god"],
        expect_re=r"\[SURWAVE\] pause OK: .*layout_problems=0",
    ),
    TestCase(
        name="ui_screens",
        env={"SURW_UI_TEST": "1"},
        args=["--headless", "--audio-driver", "Dummy", "--path", ".", "--", "--autoplay", "--god"],
        expect_re=r"\[SURWAVE\] ui OK: .*out_of_bounds=0",
    ),
    TestCase(
        name="controls",
        env={"SURW_CONTROLS_TEST": "1"},
        args=["--headless", "--audio-driver", "Dummy", "--path", ".", "--", "--autoplay", "--god"],
        expect_re=r"\[SURWAVE\] controls OK:",
    ),
    TestCase(
        name="hazards_and_maps",
        env={"SURW_HAZARD_TEST": "1"},
        args=["--headless", "--audio-driver", "Dummy", "--path", ".", "--", "--autoplay", "--god"],
        expect_re=r"\[SURWAVE\] hazard OK: .*problems=0",
    ),
    TestCase(
        name="hazard_visuals",
        env={"SURW_VIS_TEST": "1"},
        args=["--headless", "--audio-driver", "Dummy", "--path", ".", "--", "--autoplay", "--god"],
        expect_re=r"\[SURWAVE\] vis OK: .*problems=0",
    ),
    TestCase(
        name="cheat_console",
        env={"SURW_CHEAT_TEST": "1"},
        args=["--headless", "--audio-driver", "Dummy", "--path", ".", "--", "--autoplay", "--god"],
        expect_re=r"\[SURWAVE\] cheat OK: .*problems=0",
    ),
    TestCase(
        name="network_layer",
        env={"SURW_NET_TEST": "1"},
        args=["--headless", "--audio-driver", "Dummy", "--path", ".", "--", "--autoplay", "--god"],
        expect_re=r"\[SURWAVE\] net OK:",
    ),
    TestCase(
        name="boomerang_perk",
        env={"SURW_BOOM_TEST": "1", "SURW_MAP": "forest"},
        args=["--headless", "--audio-driver", "Dummy", "--path", ".", "--", "--autoplay", "--god"],
        expect_re=r"\[SURWAVE\] boomerang OK:",
    ),
    TestCase(
        name="perk_clicks",
        env={"SURW_PERK_CLICK_TEST": "1", "SURW_MAP": "forest"},
        args=["--headless", "--audio-driver", "Dummy", "--path", ".", "--", "--autoplay", "--god"],
        expect_re=r"\[SURWAVE\] perk_click OK:",
        timeout_s=90.0,
    ),
    TestCase(
        name="avalanche_damage",
        env={"SURW_AVALANCHE_TEST": "1"},
        args=["--headless", "--audio-driver", "Dummy", "--path", ".", "--", "--autoplay", "--god"],
        expect_re=r"\[SURWAVE\] avalanche OK:",
    ),
    TestCase(
        name="coop_layer",
        env={"SURW_COOP_TEST": "1", "SURW_MAP": "forest"},
        args=["--headless", "--audio-driver", "Dummy", "--path", ".", "--", "--autoplay", "--god"],
        expect_re=r"\[SURWAVE\] coop OK:",
        timeout_s=90.0,
    ),
    TestCase(
        name="abilities",
        env={"SURW_ABILITY_TEST": "1"},
        args=["--headless", "--audio-driver", "Dummy", "--path", ".", "--", "--autoplay", "--god"],
        expect_re=r"\[SURWAVE\] abilities OK:",
    ),
    TestCase(
        name="boss_qte",
        env={"SURW_BOSS_TEST": "0.39", "SURW_DODGE_TEST": "1"},
        args=["--headless", "--audio-driver", "Dummy", "--path", ".", "--", "--autoplay", "--god"],
        expect_re=r"\[SURWAVE\] qte_dodge_counter test=ok",
    ),
    TestCase(
        name="lifetime_cleanup",
        env={"SURW_LIFETIME_TEST": "1"},
        args=["--headless", "--audio-driver", "Dummy", "--path", ".", "--", "--autoplay", "--god"],
        expect_re=r"\[SURWAVE\] lifetime OK:",
        timeout_s=30.0,
        wait_for_exit=True,
    ),
    TestCase(
        name="autoplay_smoke_void",
        env={"SURW_CHAR": "gavan", "SURW_WEAPON": "holy_spears", "SURW_MAP": "void", "SURW_LOG": "20"},
        args=["--headless", "--audio-driver", "Dummy", "--path", ".", "--", "--autoplay", "--god", "--fast"],
        expect_re=r"\[SURWAVE\] t=",
        timeout_s=30.0,
    ),
]

MATRIX_COMBOS = [
    ("aldar", "fire_staff", "sands"),
    ("gavan", "holy_spears", "tundra"),
    ("morkana", "magic_books", "peak"),
    ("korgash", "shotgun", "abyss"),
    ("liel", "bow", "forest"),
    ("ten", "shadow_daggers", "rift"),
    ("voltra", "lightning_staff", "graveyard"),
    ("rain", "crossbow", "hive"),
    ("ignis", "fire_ring", "bloodmoon"),
    ("gavan", "ice_needles", "chaos"),
    ("morkana", "poison_clouds", "temple"),
    ("rain", "revolver", "throne"),
]

MATRIX_TESTS: list[TestCase] = [
    TestCase(
        name=f"matrix_{ch}_{wp}_{mp}",
        env={"SURW_CHAR": ch, "SURW_WEAPON": wp, "SURW_MAP": mp, "SURW_LOG": "20"},
        args=["--headless", "--audio-driver", "Dummy", "--path", ".", "--", "--autoplay", "--god", "--fast"],
        expect_re=r"\[SURWAVE\] t=",
        timeout_s=60.0,
    )
    for ch, wp, mp in MATRIX_COMBOS
]


def gh_error(title: str, msg: str) -> None:
    if os.environ.get("GITHUB_ACTIONS") == "true":
        safe_msg = msg.replace("\r", " ").replace("\n", " | ")[:400]
        print(f"::error title={title}::{safe_msg}")


def check_fatal(lines: list[str]) -> list[str]:
    hits: list[str] = []
    for line in lines:
        for pat in FATAL_PATTERNS:
            if pat.search(line):
                hits.append(line.rstrip())
                break
    return hits


def run_import(godot_bin: str, log_dir: Path) -> bool:
    print("=== Godot headless --import ===")
    cmd = [godot_bin, "--headless", "--audio-driver", "Dummy", "--path", ".", "--import"]
    proc = subprocess.run(
        cmd,
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        timeout=120,
    )
    (log_dir / "import.log").write_text(proc.stdout, encoding="utf-8")
    fatals = check_fatal(proc.stdout.splitlines())
    if proc.returncode != 0 or fatals:
        print(proc.stdout)
        msg = f"Godot import failed (rc={proc.returncode}, errors={len(fatals)}): {fatals[:2]}"
        gh_error("Godot Import Failed", msg)
        print(f"[FAIL] {msg}")
        return False
    print("[OK]   Godot --import succeeded cleanly")
    return True


def run_case(godot_bin: str, tc: TestCase, log_dir: Path) -> tuple[bool, str]:
    env = os.environ.copy()
    env.update(tc.env)
    cmd = [godot_bin, *tc.args]
    expect = re.compile(tc.expect_re)

    lines: list[str] = []
    buf = ""
    matched_line: str | None = None
    timed_out = False
    terminated_early = False

    proc = subprocess.Popen(
        cmd,
        cwd=ROOT,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    assert proc.stdout is not None
    fd = proc.stdout.fileno()
    decoder = codecs.getincrementaldecoder("utf-8")(errors="replace")
    sel = selectors.DefaultSelector()
    sel.register(fd, selectors.EVENT_READ)

    deadline = time.monotonic() + tc.timeout_s
    early_stop_at: float | None = None

    try:
        while True:
            now = time.monotonic()
            if early_stop_at is not None and now >= early_stop_at:
                proc.terminate()
                terminated_early = True
                break
            if now >= deadline:
                timed_out = True
                proc.terminate()
                break

            wait_for = 0.05
            if early_stop_at is not None:
                wait_for = min(wait_for, max(0.0, early_stop_at - now))

            events = sel.select(timeout=wait_for)
            if events:
                raw = os.read(fd, 8192)
                if not raw:
                    buf += decoder.decode(b"", final=True)
                    if buf:
                        lines.append(buf)
                        if matched_line is None and expect.search(buf):
                            matched_line = buf.strip()
                        buf = ""
                    break
                buf += decoder.decode(raw, final=False)
                while "\n" in buf:
                    ln, buf = buf.split("\n", 1)
                    ln_full = ln + "\n"
                    lines.append(ln_full)
                    if matched_line is None and expect.search(ln_full):
                        matched_line = ln.strip()
                        if not tc.wait_for_exit and early_stop_at is None:
                            early_stop_at = time.monotonic() + 0.25
            elif proc.poll() is not None:
                # Drain any remaining bytes on EOF
                while True:
                    raw = os.read(fd, 8192)
                    if not raw:
                        break
                    buf += decoder.decode(raw, final=False)
                buf += decoder.decode(b"", final=True)
                for ln in buf.splitlines(keepends=True):
                    lines.append(ln)
                    if matched_line is None and expect.search(ln):
                        matched_line = ln.strip()
                buf = ""
                break
    finally:
        sel.close()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=5)
        # Drain anything written during terminate()
        try:
            rem = proc.stdout.read()
            if rem:
                rem_txt = decoder.decode(rem, final=True)
                for ln in rem_txt.splitlines(keepends=True):
                    lines.append(ln)
                    if matched_line is None and expect.search(ln):
                        matched_line = ln.strip()
        except Exception:
            pass

    full_log = "".join(lines)
    (log_dir / f"{tc.name}.log").write_text(full_log, encoding="utf-8")

    fatals = check_fatal(lines)
    ok = (
        matched_line is not None
        and not timed_out
        and not fatals
        and (terminated_early or proc.returncode == 0)
    )

    if ok:
        assert matched_line is not None
        print(f"[OK]   {tc.name}: {matched_line}")
        return True, matched_line

    reason = f"timeout={timed_out}, rc={proc.returncode}, matched={matched_line is not None}"
    if fatals:
        reason += f", fatals={fatals[:2]}"
    gh_error(f"Test Failed: {tc.name}", reason)
    print(f"[FAIL] {tc.name} ({reason})")
    if fatals:
        print("  Matched fatal lines:")
        for f in fatals[:10]:
            print(f"    {f}")
        # по одной аннотации на каждую ошибку, чтобы причина читалась из API
        for f in fatals[:12]:
            context = f
            for i, ln in enumerate(lines):
                if ln.rstrip() == f:
                    context = " ".join(x.rstrip() for x in lines[i:i + 3])
                    break
            gh_error(f"{tc.name}: ошибка", context)
    print("  Tail of output:")
    for ln in lines[-60:]:
        print(f"    {ln.rstrip()}")
    return False, reason


def write_summary(suite: str, results: list[tuple[str, bool, str]]) -> None:
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not summary_path:
        return
    passed = sum(1 for _, ok, _ in results if ok)
    lines = [
        f"### Surwave Godot Tests (`{suite}`): {passed}/{len(results)} passed",
        "",
        "| Test | Status | Output |",
        "| --- | --- | --- |",
    ]
    for name, ok, detail in results:
        icon = "PASS" if ok else "FAIL"
        safe = detail.replace("|", "\\|")[:140]
        lines.append(f"| `{name}` | {icon} | `{safe}` |")
    with open(summary_path, "a", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--godot",
        default=os.environ.get("GODOT", "godot"),
        help="Path to Godot headless binary",
    )
    parser.add_argument(
        "--suite",
        choices=["core", "matrix", "all"],
        default="core",
        help="Which test suite to run",
    )
    parser.add_argument(
        "--log-dir",
        default="/tmp/surwave-ci-logs",
        help="Directory to store individual test logs",
    )
    args = parser.parse_args()

    log_dir = Path(args.log_dir)
    log_dir.mkdir(parents=True, exist_ok=True)

    if not run_import(args.godot, log_dir):
        return 1

    tests: list[TestCase] = []
    if args.suite in ("core", "all"):
        tests.extend(CORE_TESTS)
    if args.suite in ("matrix", "all"):
        tests.extend(MATRIX_TESTS)

    print(f"\n=== Running {len(tests)} Surwave tests (suite={args.suite}) ===")
    results: list[tuple[str, bool, str]] = []
    failures = 0
    for tc in tests:
        ok, detail = run_case(args.godot, tc, log_dir)
        results.append((tc.name, ok, detail))
        if not ok:
            failures += 1

    write_summary(args.suite, results)
    print(f"\nSummary: {len(tests) - failures}/{len(tests)} tests passed.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
