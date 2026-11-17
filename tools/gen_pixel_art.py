# -*- coding: utf-8 -*-
"""Generates all Surwave retro gothic RPG pixel-art assets into assets/sprites/."""

from __future__ import annotations

import gen_art_actors
import gen_art_items
import gen_art_world


def main() -> None:
    n_actors = gen_art_actors.run()
    n_items = gen_art_items.run()
    n_world = gen_art_world.run()
    total = n_actors + n_items + n_world
    print(f"Generated {total} pixel-art assets: actors={n_actors}, items/icons={n_items}, world/ui={n_world}")


if __name__ == "__main__":
    main()
