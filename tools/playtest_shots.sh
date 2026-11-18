#!/usr/bin/env bash
# Графический прогон игры со снимками экрана (локально или в CI под Xvfb).
#
#   ./tools/playtest_shots.sh                 # бой на карте forest, кадры на 10 и 22 с
#   SURW_MAP=tundra ./tools/playtest_shots.sh # другая карта
#   GODOT=/path/to/Godot ./tools/playtest_shots.sh
#   SURW_SHOTS="6,12,30" ./tools/playtest_shots.sh
#
# Кадры падают в docs/playtest/ (SHOT_DIR можно переопределить).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
SHOT_DIR="${SHOT_DIR:-$ROOT/docs/playtest}"
mkdir -p "$SHOT_DIR"

# В контейнере без дисплея нужен Xvfb; локально игра идёт в обычном окне.
RUN=()
if [[ -z "${DISPLAY:-}" ]] && command -v xvfb-run >/dev/null 2>&1; then
  RUN=(xvfb-run -a -s "-screen 0 1280x720x24")
fi

ARGS=(
  --path "$ROOT" --resolution 1280x720
  -- "${@:---autoplay --god}"
)
# shellcheck disable=SC2086
SURW_SHOT_DIR="$SHOT_DIR" \
SURW_SHOT_TAG="${SURW_SHOT_TAG:-game}" \
SURW_SHOTS="${SURW_SHOTS:-10,22}" \
SURW_MAP="${SURW_MAP:-forest}" \
"${RUN[@]}" "$GODOT" "${ARGS[@]}"

echo "Снимки: $SHOT_DIR"
ls -la "$SHOT_DIR"
