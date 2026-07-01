#!/usr/bin/env python3
"""Generate ArrowClashSim/Sources/ArrowClashSim/Maps.swift from layout art.

TowerFall-style arenas: grounded floors and side structures with occasional
gaps (for vertical wrap), not just floating blocks. Legend per 20x12 layout:

  #  solid tile
  .  empty
  1  player 0 spawn (empty tile directly above solid ground)
  2  player 1 spawn (same rule)
  C  treasure chest spot (empty tile, reachable by a standing/jumping player)

The script validates every rule the sim/tests rely on, then emits Swift.
Run: python3 tools/generate_maps.py
"""

from pathlib import Path

TILE = 16
COLS, ROWS = 20, 12

# (name, theme, layout). Themes: alien, castle, lava, sludge, aquatic.
#
# Architecture rules of thumb (learned the hard way):
#   - Vertical structures CONNECT: towers stand on floors, pillars hang from
#     ceilings/platforms. Floating slabs are the exception, not the rule.
#   - Standing towers rise at most ~3 tiles above their base floor so a jump
#     (apex ~3 tiles) clears them; taller shafts always have a wrap escape.
#   - Ground rows keep gaps for vertical wrap play.
MAPS = [
    ("Alien Meadow", "alien", [
        "....................",
        "....................",
        ".........C..........",
        "......########......",
        ".........##.........",
        "....................",
        "...##..........##...",
        "....................",
        "C...................",
        "##................##",
        "##1..............2##",
        "####....####....####",
    ]),
    ("Mothership", "alien", [
        "######........######",
        "....##..........##..",
        "....................",
        "........C...........",
        "......########......",
        ".........##.........",
        "...##..........##...",
        "....................",
        "..1..............2..",
        "#####..........#####",
        "...##............##.",
        "....................",
    ]),
    ("Castle Walls", "castle", [
        "....................",
        "....................",
        ".........C..........",
        ".......######.......",
        "....................",
        "....................",
        "....................",
        "......##....##......",
        "......##....##......",
        "......##....##......",
        ".1....##....##....2.",
        "####..########..####",
    ]),
    ("Throne Room", "castle", [
        "####################",
        "......##....##......",
        "....................",
        "...###........###...",
        "....................",
        ".........C..........",
        "........####........",
        "....................",
        "....................",
        "........##..........",
        "..1.....##.......2..",
        "####################",
    ]),
    ("Magma Core", "lava", [
        "#####..........#####",
        "...##............##.",
        "....................",
        "....##........##....",
        ".........C..........",
        "........####........",
        ".........##.........",
        "...####......####...",
        "....................",
        "..................C.",
        ".1..............2##.",
        "######........######",
    ]),
    ("Lava Falls", "lava", [
        "....................",
        "....................",
        "##......C.........##",
        "##....######......##",
        "##.......##.......##",
        "....................",
        "....##........##....",
        "....................",
        "....................",
        "........##..........",
        "...1....##......2...",
        "####....####....####",
    ]),
    ("Sludge Works", "sludge", [
        "....................",
        "....................",
        "....................",
        "..####........####..",
        "....##........##....",
        ".........C..........",
        ".......######.......",
        ".........##.........",
        "....................",
        "..##.............C..",
        "..##.1.........2.##.",
        "#########..#########",
    ]),
    ("Toxic Vats", "sludge", [
        "####################",
        "..##............##..",
        "....................",
        "......C......C......",
        ".....###....###.....",
        "......#......#......",
        "....................",
        "...##..........##...",
        "....................",
        "....................",
        "..1......##......2..",
        "#####...####...#####",
    ]),
    ("Coral Reef", "aquatic", [
        "....................",
        "....................",
        "....##........##....",
        "....................",
        "........C...........",
        "......########......",
        "........##..........",
        "...##..........##...",
        "....................",
        ".....C........##....",
        "..1..###......##.2..",
        "..################..",
    ]),
    ("The Deep", "aquatic", [
        "##................##",
        "##................##",
        "....................",
        "....####..####......",
        "......##....##......",
        ".........C..........",
        "......######........",
        "....................",
        "..##............##..",
        "....................",
        ".1......C.......2...",
        "####################",
    ]),
]


def solid(layout, c, r):
    return layout[r % ROWS][c % COLS] == "#"


def validate(name, layout):
    assert len(layout) == ROWS, f"{name}: {len(layout)} rows"
    for r, line in enumerate(layout):
        assert len(line) == COLS, f"{name} row {r}: {len(line)} cols: {line!r}"
    spawns = {}
    chests = []
    for r, line in enumerate(layout):
        for c, ch in enumerate(line):
            if ch in "12":
                assert ch not in spawns, f"{name}: duplicate spawn {ch}"
                assert not solid(layout, c, r), f"{name}: spawn {ch} inside wall"
                assert solid(layout, c, r + 1), f"{name}: spawn {ch} not grounded"
                spawns[ch] = (c, r)
            elif ch == "C":
                assert not solid(layout, c, r), f"{name}: chest inside wall"
                chests.append((c, r))
            else:
                assert ch in "#.", f"{name}: bad char {ch!r}"
    assert set(spawns) == {"1", "2"}, f"{name}: missing spawn markers"
    assert chests, f"{name}: no chest spots"
    return spawns, chests


def emit():
    lines = []
    lines.append("// Maps.swift")
    lines.append("// GENERATED by tools/generate_maps.py - do not edit by hand.")
    lines.append("// 10 TowerFall-style arenas (20x12): grounded floors and side structures")
    lines.append("// with occasional gaps for wrap. 'C' marks treasure chest spots.")
    lines.append("")
    lines.append("public struct SpawnPoint: Equatable {")
    lines.append("    public let x: Int")
    lines.append("    public let y: Int")
    lines.append("    public init(x: Int, y: Int) { self.x = x; self.y = y }")
    lines.append("}")
    lines.append("")
    lines.append("public struct MapDefinition: Equatable {")
    lines.append("    public let id: Int")
    lines.append("    public let name: String")
    lines.append("    public let layout: [String]")
    lines.append("    public let spawns: [SpawnPoint]")
    lines.append("    public var cols: Int { layout.first?.count ?? 0 }")
    lines.append("    public var rows: Int { layout.count }")
    lines.append("")
    lines.append("    public func tileMap() -> TileMap {")
    lines.append("        var solid = [Bool](repeating: false, count: cols * rows)")
    lines.append("        for (r, line) in layout.enumerated() {")
    lines.append("            for (c, ch) in line.enumerated() {")
    lines.append("                solid[r * cols + c] = (ch == \"#\")")
    lines.append("            }")
    lines.append("        }")
    lines.append("        return TileMap(cols: cols, rows: rows, solid: solid)")
    lines.append("    }")
    lines.append("")
    lines.append("    // Treasure chest spots: tile centers of 'C' cells in the layout.")
    lines.append("    public var chests: [SpawnPoint] {")
    lines.append("        var result: [SpawnPoint] = []")
    lines.append("        for (r, line) in layout.enumerated() {")
    lines.append("            for (c, ch) in line.enumerated() where ch == \"C\" {")
    lines.append("                result.append(SpawnPoint(x: c * 16 + 8, y: r * 16 + 8))")
    lines.append("            }")
    lines.append("        }")
    lines.append("        return result")
    lines.append("    }")
    lines.append("}")
    lines.append("")
    lines.append("public enum Maps {")
    lines.append("    public static let all: [MapDefinition] = [")

    for i, (name, theme, layout) in enumerate(MAPS):
        spawns, _ = validate(name, layout)
        # Spawn pixels: player AABB is 10x14; center on the marker tile, feet on
        # the tile boundary below it.
        sp = []
        for key in ("1", "2"):
            c, r = spawns[key]
            sp.append((c * TILE + 3, (r + 1) * TILE - 14))
        # Emit layout with markers blanked (the sim only reads '#'; keeping 'C'
        # for the chests property, blanking spawn digits for cleanliness).
        clean = [line.replace("1", ".").replace("2", ".") for line in layout]
        lines.append(f"        MapDefinition(id: {i}, name: \"{name}\", layout: [  // theme: {theme}")
        for line in clean:
            lines.append(f"            \"{line}\",")
        lines.append(f"        ], spawns: [SpawnPoint(x: {sp[0][0]}, y: {sp[0][1]}), SpawnPoint(x: {sp[1][0]}, y: {sp[1][1]})]),")

    lines.append("    ]")
    lines.append("")
    lines.append("    public static var `default`: MapDefinition { all[0] }")
    lines.append("    public static var count: Int { all.count }")
    lines.append("    public static func byID(_ id: Int) -> MapDefinition {")
    lines.append("        (id >= 0 && id < all.count) ? all[id] : all[0]")
    lines.append("    }")
    lines.append("")
    lines.append("    // World theme per map id (render-only; used by art/scene).")
    lines.append("    public static let themes: [String] = [")
    themes = ", ".join(f"\"{t}\"" for _, t, _ in MAPS)
    lines.append(f"        {themes},")
    lines.append("    ]")
    lines.append("}")
    lines.append("")

    out = Path(__file__).resolve().parent.parent / "ArrowClashSim/Sources/ArrowClashSim/Maps.swift"
    out.write_text("\n".join(lines))
    print(f"wrote {out} ({len(MAPS)} maps)")


if __name__ == "__main__":
    emit()
