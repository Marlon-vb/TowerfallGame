// TileMap.swift
// Static, immutable tile grid the sim collides against. Because it never
// changes during a match it is NOT part of the snapshotted GameState; it is
// passed into the tick function alongside the config.
//
// Coordinate system: y increases downward (row 0 is the top row). Gravity is
// positive (pulls toward +y). The renderer is free to flip this for display.
//
// The arena wraps on BOTH axes (confirmed design decision). Wrapping means the
// outer edges have no solid border tiles; any tile coordinate outside the grid
// is treated as empty, and players wrap their position at the end of each tick.

public struct TileMap: Equatable {
    public let cols: Int
    public let rows: Int
    // Row-major solid flags, length == cols * rows. true == solid.
    public let solid: [Bool]

    public init(cols: Int, rows: Int, solid: [Bool]) {
        precondition(solid.count == cols * rows, "solid count must equal cols*rows")
        self.cols = cols
        self.rows = rows
        self.solid = solid
    }

    @inlinable
    public func isSolid(col: Int, row: Int) -> Bool {
        // Out-of-bounds is empty (open, wrapping edges).
        if col < 0 || col >= cols || row < 0 || row >= rows { return false }
        return solid[row * cols + col]
    }

    // floor(coord / tileSize) computed on the raw fixed-point value so it is
    // exact and handles negative coordinates correctly.
    @inlinable
    public static func tileIndex(_ coord: Fixed, tileSize: Int) -> Int {
        let divisor = Int32(tileSize) << Fixed.fractionalBits
        return Int(floorDiv(coord.raw, divisor))
    }

    @inlinable
    public static func floorDiv(_ a: Int32, _ b: Int32) -> Int32 {
        let q = a / b
        let r = a % b
        if r != 0 && ((r < 0) != (b < 0)) { return q - 1 }
        return q
    }

    // The single v1 arena: 20 x 12 tiles (320 x 192 px at tileSize 16).
    // '#' solid, '.' empty. Symmetric, edges open for wrapping.
    public static func defaultArena() -> TileMap {
        let layout = [
            "....................",
            "....................",
            "....................",
            "...####......####...",
            "....................",
            "....................",
            "......########......",
            "....................",
            "....................",
            "...####......####...",
            "....................",
            "....................",
        ]
        let rows = layout.count
        let cols = layout[0].count
        var solid = [Bool](repeating: false, count: cols * rows)
        for (r, line) in layout.enumerated() {
            precondition(line.count == cols, "all arena rows must be the same width")
            for (c, ch) in line.enumerated() {
                solid[r * cols + c] = (ch == "#")
            }
        }
        return TileMap(cols: cols, rows: rows, solid: solid)
    }
}
