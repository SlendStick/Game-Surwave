#!/usr/bin/env python3
"""Headless Godot CI test runner for Surwave.

Suites:
  - core: Godot --import + all built-in SURW_* tests + quick smoke autoplay runs
  - matrix: 12 character/weapon/map autoplay runs (60s simulated time at 20x speed)
  - all: both suites
"""

from __future__ import annotations

import argparse
import os
import re
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
        args=["--headless", "--path", ".", "--", "--autoplay", "--god"],
        expect_re=r"\[SURWAVE\] perk_dependencies OK:",
    ),
    TestCase(
        name="perk_effects",
        env={"SURW_PERK_EFFECT_TEST": "1"},
        args=["--headless", "--path", ".", "--", "--autoplay", "--god"],
        expect_re=r"\[SURWAVE\] perk_effects OK:",
    ),
    TestCase(
        name="hud_layout",
        env={"SURW_HUD_TEST": "1"},
        args=["--headless", "--path", ".", "--", "--autoplay", "--god"],
        expect_re=r"\[SURWAVE\] hud_test done .*problems=0",
    ),
    TestCase(
        name="pause_menu",
        env={"SURW_PAUSE_TEST": "1"},
        args=["--headless", "--path", ".", "--", "--autoplay", "--god"],
        expect_re=r"\[SURWAVE\] pause OK: .*layout_problems=0",
    ),
    TestCase(
        name="ui_screens",
        env={"SURW_UI_TEST": "1"},
        args=["--headless", "--path", ".", "--", "--autoplay", "--god"],
        expect_re=r"\[SURWAVE\] ui OK: .*out_of_bounds=0",
    ),
    TestCase(
        name="controls",
        env={"SURW_CONTROLS_TEST": "1"},
        args=["--headless", "--path", ".", "--", "--autoplay", "--god"],
        expect_re=r"\[SURWAVE\] controls OK:",
    ),
    TestCase(
        name="hazards_and_maps",
        env={"SURW_HAZARD_TEST": "1"},
        args=["--headless", "--path", ".", "--", "--autoplay", "--god"],
        expect_re=r"\[SURWAVE\] hazard OK: .*problems=0",
    ),
    TestCase(
        name="hazard_visuals",
        env={"SURW_VIS_TEST": "1"},
        args=["--headless", "--path", ".", "--", "--autoplay", "--god"],
        expect_re=r"\[SURWAVE\] vis OK: .*problems=0",
    ),
    TestCase(
        name="cheat_console",
        env={"SURW_CHEAT_TEST": "1"},
        args=["--headless", "--path", ".", "--", "--autoplay", "--god"],
        expect_re=r"\[SURWAVE\] cheat OK: .*problems=0",
    ),
    TestCase(
        name="abilities",
        env={"SURW_ABILITY_TEST": "1"},
        args=["--headless", "--path", ".", "--", "--autoplay", "--god"],
        expect_re=r"\[SURWAVE\] abilities OK:",
    ),
    TestCase(
        name="boss_qte",
        env={"SURW_BOSS_TEST": "0.39", "SURW_DODGE_TEST": "1"},
        args=["--headless", "--path", ".", "--", "--autoplay", "--god"],
        expect_re=r"\[SURWAVE\] qte_dodge_counter test=ok",
    ),
    TestCase(
        name="lifetime_cleanup",
        env={"SURW_LIFETIME_TEST": "1"},
        args=["--headless", "--path", ".", "--", "--autoplay", "--god"],
        expect_re=r"\[SURWAVE\] lifetime OK:",
        timeout_s=30.0,
        wait_for_exit=True,
    ),
    TestCase(
        name="autoplay_smoke_void",
        env={"SURW_CHAR": "gavan", "SURW_WEAPON": "holy_spears", "SURW_MAP": "void", "SURW_LOG": "20"},
        args=["--headless", "--path", ".", "--", "--autoplay", "--god", "--fast"],
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
        env={"SURW_CHAR": ch, "SURW_WEAPON": wp, "SURW_MAP": mp, "SURW_LOG": "60"},
        args=["--headless", "--path", ".", "--", "--autoplay", "--god", "--fast"],
        expect_re=r"\[SURWAVE\] t=",
        timeout_s=35.0,
    )
    for ch, wp, mp in MATRIX_COMBOS
]


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
    cmd = [godot_bin, "--headless", "--path", ".", "--import"]
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
        print(f"[FAIL] Godot import failed (rc={proc.returncode}, errors={len(fatals)})")
        return False
    print("[OK]   Godot --import succeeded cleanly")
    return True


def run_case(godot_bin: str, tc: TestCase, log_dir: Path) -> bool:
    env = os.environ.copy()
    env.update(tc.env)
    cmd = [godot_bin, *tc.args]
    expect = re.compile(tc.expect_re)

    lines: list[str] = []
    matched_line: str | None = None
    timed_out = False
    terminated_early = False

    proc = subprocess.Popen(
        cmd,
        cwd=ROOT,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )

    assert proc.stdout is not None
    deadline = time.monotonic() + tc.timeout_s
    os.set_blocking(proc.stdout.fileno(), False)

    try:
        while True:
            chunk = proc.stdout.read()
            if chunk:
                for ln in chunk.splitlines(keepends=True):
                    lines.append(ln)
                    if matched_line is None and expect.search(ln):
                        matched_line = ln.strip()
                        if not tc.wait_for_exit:
                            time.sleep(0.25)
                            extra = proc.stdout.read()
                            if extra:
                                lines.extend(extra.splitlines(keepends=True))
                            proc.terminate()
                            terminated_early = True
                            break
                if terminated_early:
                    break

            ret = proc.poll()
            if ret is not None:
                rem = proc.stdout.read()
                if rem:
                    lines.extend(rem.splitlines(keepends=True))
                break

            if time.monotonic() >= deadline:
                timed_out = True
                proc.terminate()
                break

            time.sleep(0.05)
    finally:
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=5)

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
        print(f"[OK]   {tc.name}: {matched_line}")
        return True

    print(f"[FAIL] {tc.name} (timeout={timed_out}, rc={proc.returncode}, matched={matched_line is not None})")
    if fatals:
        print("  Matched fatal lines:")
        for f in fatals[:10]:
            print(f"    {f}")
    print("  Tail of output:")
    for ln in lines[-30:]:
        print(f"    {ln.rstrip()}")
    return False


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
    failures = 0
    for tc in tests:
        if not run_case(args.godot, tc, log_dir):
            failures += 1

    print(f"\nSummary: {len(tests) - failures}/{len(tests)} tests passed.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
