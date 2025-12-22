import Foundation

public struct Position: Hashable {
    public let row: Int
    public let col: Int
    public init(row: Int, col: Int) {
        self.row = row
        self.col = col
    }
}

final class MatchFinder {
    // returns set of positions that form matches (>=3 in a row horizontally or vertically)
    static func findMatches(in grid: [[Tile?]]) -> Set<Position> {
        var matches = Set<Position>()
        let rows = grid.count
        guard rows > 0 else { return matches }
        let cols = grid[0].count

        // horizontal scan
        for r in 0..<rows {
            var runType: TileType? = nil
            var runStart = 0
            var runLength = 0
            for c in 0...cols { // iterate one past end to flush
                let t = (c < cols) ? grid[r][c]?.type : nil
                if let rt = runType, t == rt {
                    runLength += 1
                } else {
                    if runLength >= 3 {
                        for cc in runStart..<(runStart + runLength) {
                            matches.insert(Position(row: r, col: cc))
                        }
                    }
                    runType = t
                    runStart = c
                    runLength = (t == nil) ? 0 : 1
                }
            }
        }

        // vertical scan
        for c in 0..<cols {
            var runType: TileType? = nil
            var runStart = 0
            var runLength = 0
            for r in 0...rows { // flush at end
                let t = (r < rows) ? grid[r][c]?.type : nil
                if let rt = runType, t == rt {
                    runLength += 1
                } else {
                    if runLength >= 3 {
                        for rr in runStart..<(runStart + runLength) {
                            matches.insert(Position(row: rr, col: c))
                        }
                    }
                    runType = t
                    runStart = r
                    runLength = (t == nil) ? 0 : 1
                }
            }
        }

        return matches
    }

    static func hasMatches(in grid: [[Tile?]]) -> Bool {
        return !findMatches(in: grid).isEmpty
    }
}
