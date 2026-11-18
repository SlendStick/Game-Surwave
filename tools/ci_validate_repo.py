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


def check_sprites(loaded: dict[str, object], errors: list[str]) -> None:
    sdir = ROOT / "assets" / "sprites"
    if not sdir.is_dir():
        fail("Missing assets/sprites directory", errors)
        return
    required: set[str] = {
        "ring.png", "elite.png", "fx_burst.png", "fx_ring.png",
        "ui_heart_full.png", "ui_heart_empty.png", "ui_ammo.png",
        "ui_skill_ready.png", "ui_crest.png", "ui_title_bg.png",
        "boss_satan.png", "boss_champion.png", "mb.png",
        "pickup_xp.png", "pickup_xp_big.png", "pickup_gold.png",
        "pickup_soul.png", "pickup_heart.png", "pickup_chest.png", "pickup_item.png",
        "projectile_bullet.png", "projectile_pellet.png", "projectile_arrow.png",
        "projectile_bolt.png", "projectile_fire.png", "projectile_ice.png",
        "projectile_lightning.png", "projectile_orb.png", "projectile_gas.png",
        "projectile_spear.png", "projectile_dagger.png", "projectile_enemy.png", "projectile_boss.png",
        "mover_tumbleweed.png", "mover_wisp.png", "mover_insects.png", "mover_shard.png",
        "event_meteor_0.png", "event_meteor_3.png", "event_crater.png", "event_boulder_0.png",
        "event_stalactite.png", "event_ice_spike_0.png", "event_avalanche_wave.png",
        "event_geyser_0.png", "event_ghost_hand_0.png",
        "vfx_lightning_0.png", "vfx_fireball_0.png", "vfx_smite_0.png", "vfx_frost_0.png",
        "illus_evolution.png", "illus_specialization.png",
    }
    chars = loaded.get("data/characters.json")
    if isinstance(chars, list):
        for ch in chars:
            cls = str(ch.get("cls", ""))
            if cls:
                required.add(f"{cls}.png")
                required.add(f"{cls}_idle_0.png")
                required.add(f"{cls}_walk_0.png")
                required.add(f"portrait_{cls}.png")
            for u in ch.get("upgrades", []):
                required.add(f"illus_{u['id']}.png")
    weaps = loaded.get("data/weapons.json")
    if isinstance(weaps, list):
        for w in weaps:
            wid = str(w.get("id", ""))
            if wid:
                required.add(f"weapon_{wid}.png")
                required.add(f"icon_weapon_{wid}.png")
    enems = loaded.get("data/enemies.json")
    if isinstance(enems, list):
        for e in enems:
            eid = str(e.get("id", ""))
            if eid:
                required.add(f"{eid}.png")
                required.add(f"portrait_{eid}.png")
    bosses_doc = loaded.get("data/bosses.json")
    if isinstance(bosses_doc, dict):
        for mk, bd in bosses_doc.get("bosses", {}).items():
            bid = str(bd.get("id", ""))
            if bid:
                required.add(f"portrait_{bid}.png")
            required.add(f"portrait_boss_{mk}.png")
        for bname in ("boss_shemhaz", "boss_satanail", "boss_satan"):
            for st_name, cnt in (("idle", 4), ("walk", 4), ("attack", 4), ("hurt", 3), ("death", 5)):
                for fi in range(cnt):
                    required.add(f"{bname}_{st_name}_{fi}.png")
    maps = loaded.get("data/maps.json")
    if isinstance(maps, list):
        for m in maps:
            mid = str(m.get("id", ""))
            if mid:
                required.add(f"tile_{mid}.png")
            for o in m.get("obstacles", []):
                sh = str(o.get("shape", ""))
                if sh:
                    required.add(f"obs_{sh}.png")
    perks = loaded.get("data/perks.json")
    if isinstance(perks, dict):
        for t in perks.get("trees", []):
            required.add(f"icon_tree_{t['id']}.png")
        for p in perks.get("perks", []):
            required.add(f"illus_{p['id']}.png")
    for s in (loaded.get("data/synergies.json") or []):
        required.add(f"icon_{s['id']}.png")
        required.add(f"illus_{s['id']}.png")
    for s in (loaded.get("data/seals.json") or []):
        required.add(f"icon_{s['id']}.png")
        required.add(f"illus_{s['id']}.png")
    amulets = loaded.get("data/amulets.json")
    if isinstance(amulets, dict):
        for a in amulets.get("amulets", []):
            required.add(f"icon_{a['id']}.png")

    checked = 0
    for fn in sorted(required):
        p = sdir / fn
        if not p.exists():
            fail(f"Missing required sprite asset: assets/sprites/{fn}", errors)
            continue
        hdr = p.read_bytes()[:8]
        if hdr != b"\x89PNG\r\n\x1a\n":
            fail(f"Invalid PNG header in assets/sprites/{fn}", errors)
            continue
        checked += 1
    ok(f"Validated {checked} required pixel-art PNG assets in assets/sprites/")


BALANCE_LIMITS = {
    # ключ -> (минимум, максимум)
    "xp_gain_mult": (0.2, 0.7),
    "heart_chance": (0.0, 0.003),
    "enemy_proj_speed": (0.4, 1.0),
}
SETTINGS_KEYS = [
    "window_mode", "camera_shake", "vignette", "crosshair", "aim_line",
    "hit_stop", "combo_fx", "screen_flash", "camera_distance", "net_name", "net_port",
]


def check_balance_and_net(errors: list[str]) -> None:
    balance = json.loads((ROOT / "data" / "balance.json").read_text(encoding="utf-8"))
    run = balance.get("run", {})
    for key, (lo, hi) in BALANCE_LIMITS.items():
        if key not in run:
            fail(f"balance.run.{key} отсутствует (настройка баланса потеряна)", errors)
            continue
        value = float(run[key])
        if not (lo <= value <= hi):
            fail(f"balance.run.{key}={value} вне диапазона {lo}..{hi}", errors)
    pickups = run.get("pickup_xp", {})
    for role in ("fodder", "shooter", "elite", "miniboss", "boss"):
        if role not in pickups:
            fail(f"balance.run.pickup_xp.{role} отсутствует", errors)
    ok(f"Баланс: xp×{run.get('xp_gain_mult')} hearts {run.get('heart_chance')} "
       f"снаряды ×{run.get('enemy_proj_speed')} (pickup_xp: {len(pickups)} ролей)")

    # сеть: файлы и публичный API
    net = ROOT / "scripts" / "autoload" / "net_manager.gd"
    net_player = ROOT / "scripts" / "game" / "net_player.gd"
    for path in (net, net_player):
        if not path.exists():
            fail(f"нет файла сетевого кооп:{path.relative_to(ROOT)}", errors)
    net_src = net.read_text(encoding="utf-8") if net.exists() else ""
    for fn in ("host_game", "join_game", "start_lan_listen", "lan_list", "send_player_state",
               "request_damage", "start_session", "max_players", "broadcast_snapshot"):
        if f"func {fn}()" not in net_src and f"func {fn}(" not in net_src:
            fail(f"net_manager.gd: нет функции {fn}()", errors)

    menu = (ROOT / "scripts" / "ui" / "main_menu.gd").read_text(encoding="utf-8")
    if "СЕТЕВАЯ ИГРА" not in menu:
        fail("main_menu.gd: нет кнопки «СЕТЕВАЯ ИГРА»", errors)
    for mode in ("windowed", "borderless", "fullscreen"):
        if mode not in menu:
            fail(f"main_menu.gd: режим окна {mode} не предлагается", errors)
    game_manager = (ROOT / "scripts" / "autoload" / "game_manager.gd").read_text(encoding="utf-8")
    if "WINDOW_MODES" not in game_manager:
        fail("game_manager.gd: нет WINDOW_MODES", errors)

    save = (ROOT / "scripts" / "autoload" / "save_manager.gd").read_text(encoding="utf-8")
    missing = [k for k in SETTINGS_KEYS if f'"{k}"' not in save]
    if missing:
        fail("save_manager.gd: в default_data()[\"settings\"] нет ключей " + ", ".join(missing), errors)
    ok(f"Сеть и настройки: {len(SETTINGS_KEYS)} ключей, режимы окна, лобби")

    # бумеранг вместо копья в дереве перков
    perks = json.loads((ROOT / "data" / "perks.json").read_text(encoding="utf-8"))
    trees = perks.get("trees", []) if isinstance(perks, dict) else []
    all_perks = perks.get("perks", []) if isinstance(perks, dict) else perks
    tree_ids = [str(t.get("id", "")) for t in trees if isinstance(t, dict)]
    if "boomerang" not in tree_ids:
        fail("perks.json: нет дерева boomerang", errors)
    else:
        tree_perks = [p for p in all_perks if str(p.get("tree", "")) == "boomerang"]
        if len(tree_perks) < 4:
            fail(f"Дерево бумеранга подозрительно короткое: {len(tree_perks)} перков", errors)
        if not any(str(p.get("flags", {}).get("summon", "")) == "boomerang" for p in tree_perks):
            fail("Дерево бумеранга не призывает бумеранг (flags.summon)", errors)
        if any("копь" in str(p.get("name", "")).lower() for p in tree_perks):
            fail("В дереве бумеранга остались перки-копья", errors)
        ok(f"Бумеранг: {len(tree_perks)} перков в дереве")

    ally = (ROOT / "scripts" / "game" / "ally.gd").read_text(encoding="utf-8")
    for token in ("BOOMERANG_RANGE", "BOOMERANG_ORBIT", "boom_state"):
        if token not in ally:
            fail(f"ally.gd: нет механике бумеранга ({token})", errors)
    for spr in ("ally_boomerang.png", "icon_tree_boomerang.png", "vfx_boomerang_0.png",
                "illus_boomerang_t1.png", "illus_boomerang_t3.png"):
        if not (ROOT / "assets" / "sprites" / spr).exists():
            fail(f"нет спрайта бумеранга assets/sprites/{spr}", errors)

    # документация
    for doc in ("docs/СЕТЕВОЙ_КООП.md", "README.md"):
        if not (ROOT / doc).exists():
            fail(f"нет документа {doc}", errors)
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    if "1.5.0" not in readme:
        fail("README.md: версия не обновлена до 1.5.0", errors)


# Частые опечатки в свойствах узлов Godot: скрипт падает на этапе парсинга
# ("Identifier ... not declared"), а статически это видно сразу.
GD_KNOWN_PROPS = [
    "visible", "position", "global_position", "rotation", "scale", "modulate",
    "texture", "text", "size", "color", "mouse_filter", "z_index", "speed",
    "velocity", "direction", "offset", "pivot_offset", "self_modulate", "flip_h",
    "flip_v", "centered", "frame", "playing", "volume_db", "stream", "paused",
    "alignment", "autowrap_mode", "clip_text", "max_lines_visible",
]
GD_DECL_RE = re.compile(r"^\s*(?:@?onready\s+)?(?:var|const|signal|func|class_name)\s+([A-Za-z_][A-Za-z0-9_]*)")
GD_FOR_RE = re.compile(r"\bfor\s+([A-Za-z_][A-Za-z0-9_]*)\s+in\b")
GD_FUNC_RE = re.compile(r"^\s*(?:static\s+)?func\s+[A-Za-z_][A-Za-z0-9_]*\s*\(([^)]*)\)")
GD_ASSIGN_RE = re.compile(r"^\s{1,}([A-Za-z_][A-Za-z0-9_]*)\s*(?:\+|-|\*|/)?=(?!=)")


def _lev(a: str, b: str) -> int:
    if abs(len(a) - len(b)) > 2:
        return 9
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca != cb)))
        prev = cur
    return prev[-1]


def check_gdscript_typos(errors: list[str]) -> None:
    checked = 0
    for path in sorted((ROOT / "scripts").rglob("*.gd")):
        src = path.read_text(encoding="utf-8")
        declared: set[str] = set()
        for line in src.splitlines():
            m = GD_DECL_RE.match(line)
            if m:
                declared.add(m.group(1))
            for m in GD_FOR_RE.finditer(line):
                declared.add(m.group(1))
            m = GD_FUNC_RE.match(line)
            if m:
                for param in m.group(1).split(","):
                    name = param.strip().split(":")[0].split("=")[0].strip()
                    if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name):
                        declared.add(name)
        for idx, line in enumerate(src.splitlines(), 1):
            if line.lstrip().startswith("#"):
                continue
            m = GD_ASSIGN_RE.match(line)
            if not m:
                continue
            name = m.group(1)
            if name in declared or name in GD_KNOWN_PROPS:
                continue
            best = min(GD_KNOWN_PROPS, key=lambda prop: _lev(name, prop))
            if best != name and _lev(name, best) <= 3:
                fail(f"{path.relative_to(ROOT)}:{idx}: похоже на опечатку «{name}» "
                     f"вместо «{best}» (скрипт не скомпилируется)", errors)
        checked += 1
    ok(f"Проверено {checked} GDScript-файлов на опечатки в свойствах узлов")


GD_LOCAL_VAR_RE = re.compile(r"^(\t+)(?:var|const)\s+([A-Za-z_][A-Za-z0-9_]*)")
GD_FUNC_HEAD_RE = re.compile(r"^(?:static\s+)?func\s+[A-Za-z_][A-Za-z0-9_]*\s*\(")


def _indent_of(line: str) -> int:
    return len(line) - len(line.lstrip("\t"))


def _param_names(header: str) -> list[str]:
    names: list[str] = []
    start = header.find("(")
    if start < 0:
        return names
    depth = 0
    chunk = ""
    for ch in header[start:]:
        if ch == "(":
            depth += 1
            if depth == 1:
                continue
        elif ch == ")":
            depth -= 1
            if depth == 0:
                break
        if depth == 1:
            chunk += ch
    for part in chunk.split(","):
        name = part.strip().split(":")[0].split("=")[0].strip()
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name):
            names.append(name)
    return names


def check_gdscript_scopes(errors: list[str]) -> None:
    """Ловит локальные переменные, использованные вне своего блока.

    В GDScript переменная, объявленная в `if`/`for`/`match`, видна только внутри
    этого блока и вложенных в него. Использование в соседнем блоке или выше —
    ошибка компиляции, которую легко внести при правке кода.
    """
    checked = 0
    for path in sorted((ROOT / "scripts").rglob("*.gd")):
        lines = path.read_text(encoding="utf-8").splitlines()
        stack: list[tuple[int, int]] = []  # (отступ заголовка, id блока)
        decls: dict[str, list[tuple[tuple[int, ...], int]]] = {}
        next_id = 0
        skip_until = 0
        in_string = False
        for idx, raw in enumerate(lines, 1):
            if in_string:
                if raw.count('"""') % 2 == 1:
                    in_string = False
                continue
            if idx <= skip_until or not raw.strip() or raw.lstrip().startswith("#"):
                continue
            if raw.count('"""') % 2 == 1:
                in_string = True
            stripped = raw.strip()
            indent = _indent_of(raw)

            if GD_FUNC_HEAD_RE.match(raw):
                stack = [(0, next_id)]
                next_id += 1
                decls = {}
                header = raw
                probe = idx
                while ")" not in header and probe < len(lines):
                    probe += 1
                    header += " " + lines[probe - 1].strip()
                skip_until = probe if probe > idx else idx
                func_scope = (stack[0][1],)
                for name in _param_names(header):
                    decls.setdefault(name, []).append((func_scope, idx))
                continue

            while stack and stack[-1][0] >= indent:
                stack.pop()
            path_ids = tuple(block_id for _, block_id in stack)

            m = GD_LOCAL_VAR_RE.match(raw)
            if m:
                name = m.group(2)
                if len(name) >= 3:
                    decls.setdefault(name, []).append((path_ids, idx))
            else:
                clean = re.sub(r'"[^"]*"', '""', raw)
                if "func(" in clean:
                    for name in _param_names(clean[clean.index("func(") + 4:]):
                        decls.setdefault(name, []).append((path_ids, idx))
                for fm in GD_FOR_RE.finditer(clean):
                    decls.setdefault(fm.group(1), []).append((path_ids, idx))
                for word in set(re.findall(r"(?<![\w.])[A-Za-z_][A-Za-z0-9_]{2,}\b(?!\s*\()", clean)):
                    sites = decls.get(word)
                    if not sites:
                        continue
                    ok_scope = False
                    for scope, _decl_line in sites:
                        if len(scope) <= len(path_ids) and path_ids[: len(scope)] == scope:
                            ok_scope = True
                            break
                    if not ok_scope:
                        decl_line = sites[-1][1]
                        fail(f"{path.relative_to(ROOT)}:{idx}: «{word}» объявлена внутри блока "
                             f"(строка {decl_line}) и здесь уже не видна — "
                             f"GDScript не скомпилируется", errors)

            if stripped.endswith(":"):
                stack.append((indent, next_id))
                next_id += 1
        checked += 1
    ok(f"Проверено {checked} GDScript-файлов на области видимости локальных переменных")

GD_UI_FACTORY_RE = re.compile(
    r"var\s+([A-Za-z_]\w*)\s*:?=\s*UI\.\w+\(\s*([A-Za-z_]\w*)"
)


def check_gdscript_duplicate_children(errors: list[str]) -> None:
    """`UI.button(parent, ...)` уже добавляет узел в parent — повторный add_child даёт
    ошибку «Can't add child ... already has a parent»."""
    checked = 0
    for path in sorted((ROOT / "scripts").rglob("*.gd")):
        lines = path.read_text(encoding="utf-8").splitlines()
        created: dict[str, tuple[str, int]] = {}
        for idx, line in enumerate(lines, 1):
            if line.lstrip().startswith("#"):
                continue
            m = GD_UI_FACTORY_RE.search(line)
            if m:
                created[m.group(1)] = (m.group(2), idx)
                continue
            for name, (parent, decl) in created.items():
                if re.search(r"\b%s\.add_child\(\s*%s\s*\)" % (re.escape(parent), re.escape(name)), line):
                    fail(f"{path.relative_to(ROOT)}:{idx}: повторный add_child({name}) — "
                         f"UI-фабрика уже добавила узел в «{parent}» (строка {decl}); "
                         f"получится ошибка «already has a parent»", errors)
        checked += 1
    ok(f"Проверено {checked} GDScript-файлов на двойное добавление узлов")


# ---------------------------------------------------------------------------
# Правки по плейтесту (запрос #10): курсор, режимы окна, копирование адреса,
# лавина, тонкие шкалы над героем, кара, рикошеты, облики всех врагов.
# ---------------------------------------------------------------------------
def check_playtest_fixes(loaded: dict[str, object], errors: list[str]) -> None:
    balance = json.loads((ROOT / "data" / "balance.json").read_text(encoding="utf-8"))
    player_cfg = balance.get("player", {})
    targets = int(player_cfg.get("retribution_targets", 0))
    if not (3 <= targets <= 4):
        fail(f"balance.player.retribution_targets={targets} (кара должна бить 3–4 врагов)", errors)
    radius = float(player_cfg.get("retribution_radius", 0.0))
    if radius < 120.0:
        fail(f"balance.player.retribution_radius={radius} слишком мал", errors)
    ok(f"Кара: {targets} цели в радиусе {radius:.0f} px")

    perks = json.loads((ROOT / "data" / "perks.json").read_text(encoding="utf-8"))
    boomerang = [p for p in perks.get("perks", []) if str(p.get("tree", "")) == "boomerang"]
    ricochets = sum(int(float(p.get("flags", {}).get("boomerang_ricochet", 0))) for p in boomerang)
    if ricochets < 6:
        fail(f"Дерево бумеранга даёт только {ricochets} рикошетов (ожидалось ≥6: +1/+2/+3)", errors)
    ok(f"Бумеранг: рикошеты в дереве +{ricochets}")

    # курсор и режимы окна
    game_src = (ROOT / "scripts" / "game" / "game.gd").read_text(encoding="utf-8")
    if "func _sync_cursor()" not in game_src:
        fail("game.gd: нет _sync_cursor() — курсор в меню паузы/перков может пропасть", errors)
    if "MOUSE_MODE_VISIBLE" not in game_src:
        fail("game.gd: курсор никогда не становится видимым", errors)
    gm_src = (ROOT / "scripts" / "autoload" / "game_manager.gd").read_text(encoding="utf-8")
    for token in ("func apply_window_mode(", "MODE_EXCLUSIVE_FULLSCREEN", "func _fit_window("):
        if token not in gm_src:
            fail(f"game_manager.gd: нет {token} — режимы окна не переключаются", errors)
    if "PROCESS_MODE_ALWAYS" not in gm_src:
        fail("game_manager.gd: автозагрузка не работает на паузе (режим окна зависнет)", errors)

    # копирование адреса для друзей
    net_src = (ROOT / "scripts" / "autoload" / "net_manager.gd").read_text(encoding="utf-8")
    if "func address_text()" not in net_src:
        fail("net_manager.gd: нет address_text()", errors)
    menu_src = (ROOT / "scripts" / "ui" / "main_menu.gd").read_text(encoding="utf-8")
    if "КОПИРОВАТЬ IP И ПОРТ" not in menu_src:
        fail("main_menu.gd: нет кнопки копирования адреса", errors)
    if "clipboard_set" not in menu_src:
        fail("main_menu.gd: адрес не копируется в буфер обмена", errors)

    # лавина должна наносить урон
    av_match = re.search(r'"avalanche":.*?(?=\n\t\t"[a-z_]+":)', game_src, re.S)
    av_block = av_match.group(0) if av_match else ""
    if not av_block:
        fail("game.gd: нет ветки события «avalanche»", errors)
    elif "aoe_damage" not in av_block:
        fail("game.gd: события «avalanche» не наносит урон (нет aoe_damage)", errors)
    if '"avalanche"' not in (ROOT / "scripts" / "autoload" / "audio_manager.gd").read_text(encoding="utf-8"):
        fail("audio_manager.gd: нет звука «avalanche»", errors)

    # тонкие шкалы над героем, а не одна широкая
    player_src = (ROOT / "scripts" / "player" / "player.gd").read_text(encoding="utf-8")
    if "BAR_H" not in player_src or "func _bar_fill(" not in player_src:
        fail("player.gd: шкалы HP/патронов над героем выглядят как одна полоса", errors)
    if "func nearest_enemies(" not in game_src:
        fail("game.gd: нет nearest_enemies() для мультицельных эффектов", errors)

    # облики всех врагов на всех картах
    sdir = ROOT / "assets" / "sprites"
    enemies = loaded.get("data/enemies.json")
    maps = loaded.get("data/maps.json")
    missing: list[str] = []
    if isinstance(enemies, list) and isinstance(maps, list):
        for e in enemies:
            eid = str(e.get("id", ""))
            if not eid or eid.startswith("mb_"):
                continue
            for m in maps:
                mid = str(m.get("id", ""))
                if not mid:
                    continue
                if not (sdir / f"{eid}__{mid}.png").exists():
                    missing.append(f"{eid}__{mid}")
    if missing:
        fail(f"нет обликов врагов для карт: {', '.join(missing[:6])} (всего {len(missing)})", errors)
    else:
        ok(f"Облики врагов: {len(enemies or [])} врагов × {len(maps or [])} карт")

    for spr in ("ally_boomerang.png", "icon_tree_scythe.png", "illus_scythe_t1.png",
                "illus_scythe_t2a.png", "illus_scythe_t2b.png", "illus_scythe_t3.png"):
        if not (sdir / spr).exists():
            fail(f"нет обновлённого арта assets/sprites/{spr}", errors)

    # защита от повторения бага «перебор nearest_enemy() как списка врагов»
    for path in (ROOT / "scripts").rglob("*.gd"):
        src = path.read_text(encoding="utf-8")
        if re.search(r"for\s+\w+\s+in\s+[\w.]*nearest_enemy\(", src):
            fail(f"{path.relative_to(ROOT)}: nearest_enemy() возвращает [враг, дистанция], "
                 f"его нельзя перебирать циклом — используйте nearest_enemies()", errors)

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
    check_sprites(loaded, errors)
    check_balance_and_net(errors)
    check_playtest_fixes(loaded, errors)
    check_gdscript_typos(errors)
    check_gdscript_scopes(errors)
    check_gdscript_duplicate_children(errors)
    check_python_tools(errors)

    if errors:
        print(f"\nValidation FAILED with {len(errors)} error(s).")
        return 1
    print("\nAll static repository validations PASSED.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
