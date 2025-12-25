import Foundation

final class Board {
    let rows: Int
    let cols: Int
    private(set) var grid: [[Tile?]]

    init(rows: Int = 8, cols: Int = 8) {
        self.rows = rows
        self.cols = cols
        self.grid = Array(repeating: Array(repeating: nil, count: cols), count: rows)
        generateInitialBoard()
    }

    subscript(row: Int, col: Int) -> Tile? {
        get {
            guard row >= 0 && row < rows && col >= 0 && col < cols else { return nil }
            return grid[row][col]
        }
        set {
            guard row >= 0 && row < rows && col >= 0 && col < cols else { return }
            grid[row][col] = newValue
        }
    }

    // Generate board so that no initial 3-match exists.
    // For each cell pick a random type that does not create a 3-in-a-row with left/left-left or up/up-up.
    func generateInitialBoard() {
        for r in 0..<rows {
            for c in 0..<cols {
                var excluded: [TileType] = []

                // check left two
                if c >= 2, let t1 = grid[r][c-1]?.type, let t2 = grid[r][c-2]?.type, t1 == t2 {
                    excluded.append(t1)
                }
                // check up two
                if r >= 2, let u1 = grid[r-1][c]?.type, let u2 = grid[r-2][c]?.type, u1 == u2 {
                    excluded.append(u1)
                }

                let type = TileType.random(excluding: excluded)
                grid[r][c] = Tile(type: type)
            }
        }
        // as a safety, if any matches remain (very unlikely), shuffle and retry whole board
        if MatchFinder.hasMatches(in: grid) {
            // fallback: simple retry loop
            var attempts = 0
            repeat {
                attempts += 1
                for r in 0..<rows {
                    for c in 0..<cols {
                        grid[r][c] = Tile(type: TileType.random())
                    }
                }
                if attempts > 10 { break }
            } while MatchFinder.hasMatches(in: grid)
        }
    }

    func swap(from: Position, to: Position) {
        let a = grid[from.row][from.col]
        let b = grid[to.row][to.col]
        grid[from.row][from.col] = b
        grid[to.row][to.col] = a
    }

    @discardableResult
    func remove(positions: Set<Position>) -> Int {
        for pos in positions {
            grid[pos.row][pos.col] = nil
        }
        return positions.count
    }

    func collapseAndRefill() -> [(from: Position, to: Position, tile: Tile)] {
        var moves: [(Position, Position, Tile)] = []
        for c in 0..<cols {
            var writeRow = rows - 1
            for r in stride(from: rows - 1, through: 0, by: -1) {
                if let tile = grid[r][c] {
                    if r != writeRow {
                        grid[writeRow][c] = tile
                        grid[r][c] = nil
                        moves.append((Position(row: r, col: c), Position(row: writeRow, col: c), tile))
                    }
                    writeRow -= 1
                }
            }
            if writeRow >= 0 {
                for r in stride(from: writeRow, through: 0, by: -1) {
                    let newTile = Tile(type: TileType.random())
                    grid[r][c] = newTile
                    moves.append((Position(row: r, col: c), Position(row: r, col: c), newTile))
                }
            }
        }
        return moves
    }
    
    /// プレイ可能な手があるかチェック（隣接する2つのタイルをスワップして3マッチ以上になるか）
    func hasValidMoves() -> Bool {
        for r in 0..<rows {
            for c in 0..<cols {
                // 右とのスワップをチェック
                if c < cols - 1 {
                    swap(from: Position(row: r, col: c), to: Position(row: r, col: c + 1))
                    if MatchFinder.hasMatches(in: grid) {
                        // 元に戻す
                        swap(from: Position(row: r, col: c), to: Position(row: r, col: c + 1))
                        return true
                    }
                    // 元に戻す
                    swap(from: Position(row: r, col: c), to: Position(row: r, col: c + 1))
                }
                
                // 下とのスワップをチェック
                if r < rows - 1 {
                    swap(from: Position(row: r, col: c), to: Position(row: r + 1, col: c))
                    if MatchFinder.hasMatches(in: grid) {
                        // 元に戻す
                        swap(from: Position(row: r, col: c), to: Position(row: r + 1, col: c))
                        return true
                    }
                    // 元に戻す
                    swap(from: Position(row: r, col: c), to: Position(row: r + 1, col: c))
                }
            }
        }
        return false
    }
    
    /// 盤面をシャッフル（詰んだ時用）
    func shuffle() {
        var tiles: [Tile] = []
        // 全てのタイルを収集
        for r in 0..<rows {
            for c in 0..<cols {
                if let tile = grid[r][c] {
                    tiles.append(tile)
                }
            }
        }
        
        // シャッフル
        tiles.shuffle()
        
        // 再配置（マッチができないように）
        var index = 0
        for r in 0..<rows {
            for c in 0..<cols {
                if index < tiles.count {
                    grid[r][c] = tiles[index]
                    index += 1
                }
            }
        }
        
        // マッチがあれば削除してリフィル
        while MatchFinder.hasMatches(in: grid) {
            let matches = MatchFinder.findMatches(in: grid)
            remove(positions: matches)
            _ = collapseAndRefill()
        }
    }

    static func areAdjacent(_ a: Position, _ b: Position) -> Bool {
        let dr = abs(a.row - b.row)
        let dc = abs(a.col - b.col)
        return (dr == 1 && dc == 0) || (dr == 0 && dc == 1)
    }
}
