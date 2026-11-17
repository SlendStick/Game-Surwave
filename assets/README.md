# Ассеты Surwave 1.1.0 — что сюда класть

Сейчас игра рисует процедурные фигуры (`scripts/utils/assets.gd`). Настоящие файлы
подхватываются автоматически, код менять не нужно.

## Спрайты

- Папка: `assets/sprites/`
- Один PNG на класс: `slime.png`, `werewolf.png`, `aldar.png`, `boss_shemhaz.png` и т.д.
- Полный список классов и форм — `assets/manifest.json` (`sprites.player_characters`,
  `sprites.enemies`, `sprites.projectiles`, `sprites.pickups`, `sprites.ui`).
- Базовый размер 32×32 px, фильтр nearest, палитра из данных (`data/enemies.json`,
  `data/characters.json`), чтобы рамка карты и юнит не сливались.
- Анимации: `assets/sprites/<cls>_<state>_<frame>.png`, где state ∈
  `idle/walk/attack/hurt/death`, frame 0…7. Пока кадров нет, спрайт статичен
  (`Assets.frames()` возвращает пустой массив — заменить на AnimPlayer по готовности).

## Музыка и звук

- Папка: `assets/audio/`, имена — из `manifest.json` (`audio.sfx`, `audio.music_layers`).
- Игра зовёт `AudioManager.play_sfx("<id>")` и `play_music(mood)`; отсутствующий файл
  сейчас заменяется синтезированным тоном-заглушкой.
- Музыка задумана слоями (base/drums/lead/boss) — `AudioManager.set_intensity()` уже
  управляет громкостью слоёв, достаточно положить стемы.

## Правила стиля (из предпочтений проекта)

- Внутриигровые подписи — по-русски, шрифт читаемый при 640×360.
- Никаких рамок «из простых фигур» в финальной графике: silhouette-first, контрастный
  силуэт важнее деталей; у каждой карты своя палитра (`data/maps.json` → `palette`).
