#!/bin/bash
# Автопрогоны: разные персонажи/оружие/карты. Ищет ошибки движка и падения.
GODOT=${GODOT:-/tmp/godot/Godot_v4.7.2-stable_linux.x86_64}
cd "$(dirname "$0")/.." || exit 1
fail=0
while read -r ch wp mp secs; do
  [ -z "$ch" ] && continue
  out=$(SURW_CHAR=$ch SURW_WEAPON=$wp SURW_MAP=$mp SURW_LOG=$secs timeout $((secs+40)) \
    "$GODOT" --headless --path . -- --autoplay --god --fast 2>&1)
  errs=$(echo "$out" | grep -E "SCRIPT ERROR|ERROR:|Parse Error" | grep -v "meta" | head -3)
  line=$(echo "$out" | grep -E "SURWAVE\] t=" | tail -1)
  if [ -n "$errs" ]; then
    echo "FAIL $ch/$wp/$mp"; echo "$errs"; fail=1
  else
    echo "OK   $ch/$wp/$mp  $line"
  fi
done <<'LIST'
aldar fire_staff sands 240
gavan holy_spears tundra 240
morkana magic_books peak 240
korgash shotgun abyss 240
liel bow forest 240
ten shadow_daggers rift 240
voltra lightning_staff graveyard 240
rain crossbow hive 240
ignis fire_ring bloodmoon 240
gavan ice_needles chaos 240
morkana poison_clouds temple 240
rain revolver throne 240
LIST
exit $fail
