# Copilot Instructions for test_game

## Project Overview
iOS match-3 puzzle game (「おでん」themed) built with **SpriteKit**. Features time-attack gameplay, Firebase leaderboards, and AdMob integration.

## Core Architecture

### Model-View Separation
- **Model Layer**: `Board`, `Tile`, `MatchFinder` - pure Swift, no SpriteKit dependencies
- **View Layer**: `GameScene`, `OpeningScene`, `TileNode` - SpriteKit presentation
- **Critical Invariant**: `nodeMap` (Position→TileNode dictionary) must stay synchronized with `Board.grid`

### Key Components
- **Board**: 8x8 grid manager with match-free initialization. Uses `grid[row][col]` for tile access
- **MatchFinder**: Detects horizontal/vertical 3+ matches via run-length scanning algorithm
- **TileNode**: Renders tiles as colored shapes (circle/triangle/square). Uses CGPath cache for performance
- **GameScene**: Orchestrates touch→swap→match→collapse→refill cycle. Manages state machine for animations

### Game Loop Flow
1. User touch drag → detect adjacent swap
2. `Board.swap()` → `MatchFinder.findMatches()` 
3. If matches: remove tiles → `Board.collapseAndRefill()` → animate
4. Chain reactions: loop back to step 3 until no matches
5. Reset timer on successful match

**Critical**: Set `isAnimating = true` during any animation sequence to block new input

## Tile System
6 types map to おでん ingredients (daikon, tamago, konnyaku, chikuwa, hanpen, shirataki):
```swift
TileType.daikon.color // → UIColor.systemGreen
TileType.daikon.shape // → ShapeType.circle
```

## Scoring & Combo System
- Base: 10 points/tile, +10 per tile beyond 3
- Combo multiplier: 1.5× (2-combo), 2.0× (3-combo), then +0.5× per level
- Combo resets after 1.5s of no matches (tracked in `update()`)
- Display formatted with `formatNumber()` for thousands separator

## Firebase Integration
- **RankingsManager**: Firestore + anonymous auth. Transactional updates ensure highest score per user
- **Collection**: `rankings` with `{uid, name?, score, timestamp}` documents
- Submit after game over; fetch top 10 for leaderboard

## AdMob Integration
- **AdMobManager singleton**: Manages rewarded + interstitial ads
- Show interstitial every 3 games (`gameCount % 3 == 0`)
- Rewarded ad for "continue" feature (限1回/day via UserDefaults date key)
- Test ad unit IDs currently active (replace before production)

## Scene Transitions
- `AppDelegate` → `GameViewController` presents `OpeningScene`
- `OpeningScene`: Menu with difficulty selector (5s/10s/30s), rankings button
- Difficulty saved to `UserDefaults.standard.integer(forKey: "selectedDifficulty")`
- Transition: `view.presentScene(GameScene(size: size), transition: SKTransition.fade(withDuration: 0.5))`

## Developer Workflows

### Build & Run
Xcode project at `test_game.xcodeproj`. Standard Cmd+R to build/run.

### Dependencies (Swift Package Manager)
- Firebase iOS SDK (Auth, Firestore)
- Google Mobile Ads SDK
- Check `Package.resolved` for versions

### Debug Features
- FPS/node count shown (`showsFPS = true`)
- `debugBoardState()` logs nil/tile counts, detects duplicate nodes
- Search for `[BOARD DEBUG]` prints to trace model/view sync issues

### Key Files
- [GameScene.swift](test_game/GameScene.swift): Main game logic (950 lines)
- [Board.swift](test_game/Board.swift): Match-3 model
- [MatchFinder.swift](test_game/MatchFinder.swift): Core matching algorithm
- [AdMobManager.swift](test_game/AdMobManager.swift): Ad lifecycle
- [RankingsManager.swift](test_game/RankingsManager.swift): Leaderboard backend

## Common Patterns

### Position Coordinate System
- **Model**: `grid[row][col]` where (0,0) is top-left
- **View**: `boardOrigin` is top-left corner in SpriteKit points. Y increases downward in model, upward in SpriteKit
- Use `positionFor(row:col:)` and `positionForTouch(_:)` for conversions

### Animation Sequencing
Always use completion handlers to maintain state flow:
```swift
node.run(action) {
    self.isAnimating = false
    // next step
}
```

### State Management
- `isGameOver`: Blocks most interactions
- `inputEnabled`: Toggles for specific UI states (e.g., ad offer)
- `countdownActive`: Controls timer decrement

## Testing
- Placeholder test files in `test_gameTests/` and `test_gameUITests/`
- No custom test coverage yet - manual testing via simulator

## Configuration Files
- `GoogleService-Info.plist`: Firebase config (must be present)
- `test-game-Info.plist`: App metadata (bundle ID, permissions)
- Assets in `Assets.xcassets/` (AppIcon, background colors)
