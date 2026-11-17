#!/usr/bin/env python3
"""Static & data validation for Surwave repository (no Godot binary required)."""

from __future__ import annotations

import json
import os
import py_compile
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

FORBIDDEN_PATHS = [
    ".godot",
    "_t.gd",
]

RES_PATH_RE = re.compile(r'"(res://[^"]+)"')
CONFLICT_RE = re.compile(r"^(<{7} |={7}$|>{7} )", re.MULTILINE)


def fail(msg: str, errors: list[str]) -> None:
    print(f"[FAIL] {msg}")
    errors.append(msg)


def ok(msg: str) -> None:
    print(f"[OK]   {msg}")


def check_forbidden(errors: list[str]) -> None:
    for rel in FORBIDDEN_PATHS:
        p = ROOT / rel
        if p.exists():
            fail(f"Forbidden artifact present in repo: {rel}", errors)
    for p in ROOT.rglob("*.tmp"):
        if ".git" not in p.parts:
            fail(f"Temporary file present in repo: {p.relative_to(ROOT)}", errors)
    ok("No forbidden cache/temporary artifacts")


def check_json_files(errors: list[str]) -> dict[str, object]:
    loaded: dict[str, object] = {}
    json_files = sorted((ROOT / "data").glob("*.json"))
    manifest = ROOT / "assets" / "manifest.json"
    if manifest.exists():
        json_files.append(manifest)
    if not json_files:
        fail("No JSON files found in data/", errors)
        return loaded

    for jf in json_files:
        rel = jf.relative_to(ROOT).as_posix()
        try:
            text = jf.read_text(encoding="utf-8")
            loaded[rel] = json.loads(text)
        except Exception as exc:
            fail(f"Invalid JSON in {rel}: {exc}", errors)
    ok(f"Validated {len(loaded)} JSON files")
    return loaded


def check_text_and_res_paths(errors: list[str]) -> None:
    targets: list[Path] = [ROOT / "project.godot"]
    targets.extend(sorted((ROOT / "scenes").rglob("*.tscn")))
    targets.extend(sorted((ROOT / "scripts").rglob("*.gd")))

    checked_files = 0
    checked_refs = 0
    for path in targets:
        if not path.exists():
            fail(f"Missing required file: {path.relative_to(ROOT)}", errors)
            continue
        rel = path.relative_to(ROOT).as_posix()
        try:
            text = path.read_text(encoding="utf-8")
        except Exception as exc:
            fail(f"UTF-8 decode error in {rel}: {exc}", errors)
            continue
        checked_files += 1

        if CONFLICT_RE.search(text):
            fail(f"Git conflict marker detected in {rel}", errors)

        for m in RES_PATH_RE.finditer(text):
            res = m.group(1)
            # Strip optional autoload '*' prefix if regex ever sees it (regex starts at res://)
            sub = res[len("res://") :]
            if not sub or sub.endswith("/"):
                # Directory path constant (e.g. res://assets/sprites/)
                continue
            if "%" in sub or "{" in sub:
                continue
            target = ROOT / sub
            checked_refs += 1
            if not target.exists():
                fail(f"Broken res:// reference in {rel}: {res}", errors)

    ok(f"Checked {checked_files} Godot files and {checked_refs} res:// references")


def check_data_integrity(loaded: dict[str, object], errors: list[str]) -> None:
    perks_doc = loaded.get("data/perks.json")
    perk_ids: set[str] = set()
    if isinstance(perks_doc, dict):
        trees = perks_doc.get("trees", [])
        perks = perks_doc.get("perks", [])
        if len(trees) != 25:
            fail(f"Expected 25 perk trees, got {len(trees)}", errors)
        if len(perks) != 100:
            fail(f"Expected 100 perks, got {len(perks)}", errors)
        for p in perks:
            pid = str(p.get("id", ""))
            if not pid:
                fail("Perk entry missing id", errors)
            elif pid in perk_ids:
                fail(f"Duplicate perk id: {pid}", errors)
            perk_ids.add(pid)
        for p in perks:
            pid = str(p.get("id", ""))
            for field in ("req", "req_any"):
                for req_id in p.get(field, []):
                    if req_id not in perk_ids:
                        fail(f"Perk {pid} references unknown {field} '{req_id}'", errors)
        ok(f"Perks validated ({len(trees)} trees, {len(perks)} perks)")
    else:
        fail("data/perks.json is missing or invalid", errors)

    synergies = loaded.get("data/synergies.json")
    if isinstance(synergies, list):
        syn_ids: set[str] = set()
        for s in synergies:
            sid = str(s.get("id", ""))
            if not sid or sid in syn_ids:
                fail(f"Invalid or duplicate synergy id: {sid}", errors)
            syn_ids.add(sid)
            for req in s.get("requires", []):
                if req not in perk_ids:
                    fail(f"Synergy {sid} requires unknown perk '{req}'", errors)
        ok(f"Synergies validated ({len(synergies)} synergies)")
    else:
        fail("data/synergies.json is missing or invalid", errors)

    list_collections = [
        ("data/characters.json", "characters"),
        ("data/weapons.json", "weapons"),
        ("data/maps.json", None),
        ("data/enemies.json", None),
        ("data/seals.json", None),
    ]
    for path, key in list_collections:
        doc = loaded.get(path)
        items = doc.get(key, []) if (key and isinstance(doc, dict)) else doc
        if not isinstance(items, list) or not items:
            fail(f"{path} missing expected non-empty list", errors)
            continue
        ids: set[str] = set()
        for item in items:
            iid = str(item.get("id", ""))
            if not iid or iid in ids:
                fail(f"{path} has missing or duplicate id '{iid}'", errors)
            ids.add(iid)
        ok(f"{path} validated ({len(ids)} entries)")

    bosses_doc = loaded.get("data/bosses.json")
    if isinstance(bosses_doc, dict) and bosses_doc.get("bosses"):
        ok(f"data/bosses.json validated ({len(bosses_doc['bosses'])} bosses)")
    else:
        fail("data/bosses.json missing bosses", errors)

    amulets_doc = loaded.get("data/amulets.json")
    if isinstance(amulets_doc, dict) and amulets_doc.get("amulets"):
        ok(f"data/amulets.json validated ({len(amulets_doc['amulets'])} amulets)")
    else:
        fail("data/amulets.json missing amulets", errors)


def check_python_tools(errors: list[str]) -> None:
    py_files = sorted((ROOT / "tools").glob("*.py"))
    for pf in py_files:
        try:
            py_compile.compile(str(pf), doraise=True)
        except Exception as exc:
            fail(f"Python syntax error in {pf.relative_to(ROOT)}: {exc}", errors)
    ok(f"Compiled {len(py_files)} Python scripts in tools/")


def main() -> int:
    errors: list[str] = []
    check_forbidden(errors)
    loaded = check_json_files(errors)
    check_text_and_res_paths(errors)
    check_data_integrity(loaded, errors)
    check_python_tools(errors)

    if errors:
        print(f"\nValidation FAILED with {len(errors)} error(s).")
        return 1
    print("\nAll static repository validations PASSED.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
