# Changelog

All notable changes to ArrowClash, newest first. Updated on every build/push.
Format loosely follows Keep a Changelog. Dates are when the work landed on the
`claude/arrowclash-ios-game-adl5c1` branch.

## [Unreleased]

### Content - 10 maps + 9 characters (2026-06-29)
- Added a `Maps` catalog: 10 original 20x12 arenas (Arena, Pillars, Stairs,
  Towers, Cross, Ledges, Bridges, Diamond, Layers, Scatter) with per-map spawns.
- `GameState` carries its spawn points; round resets use them; `RollbackSession`
  takes a map. The server picks a map per match and sends `mapId` in START; both
  clients build and render the same arena (per-map color theme, render-only).
- 9 cosmetic character skins (level-gated) on server and client.
- Tests: `MapsTests` (all maps well-formed, deterministic, players settle).
- Art note: all visuals are original (layouts + color palettes/themes). No
  scraped or third-party assets.

## Phase 6 - Polish (2026-06-29)
- Game feel (render-only, no sim/netcode impact): screen shake, hit flash, and a
  death particle burst on a kill.
- Audio: generated WAV blips (shoot, jump, dash, hit, ui) + `AudioManager`;
  movement sounds fire for the local player, the hit sound on any death.
- Event detection diffs each tick's before/after state to trigger sounds/FX.
- Settings screen: sound toggle and server host (set a LAN IP for device play
  without code changes), persisted in UserDefaults.
- Menu cleanup: shows level/XP, adds Loadout and Settings entries.

## Phase 5 - Progression (2026-06-29)
- Server-authoritative Go runtime: `match_end`, `get_profile`, `set_loadout`
  RPCs; profile stored in Nakama storage with server-only write permission;
  XP/level curve; `arrowclash_xp` leaderboard updated on match end.
- Cosmetic catalog (skins + arrow trails) gated by level; `set_loadout`
  validates ownership before applying.
- Match START now carries both players' loadouts so cosmetics render for both.
- Client: `ProfileService` (RPC wrapper), `Cosmetics` catalog mirror, Loadout
  screen (equip unlocked cosmetics), match result submitted on match end, skin
  and arrow-trail colors applied in-match from START.
- `ProfileService` talks to Nakama over the HTTP REST API (URLSession) because
  nakama-swift v1.2.0 exposes RPC/storage payloads as `internal` and they can't
  be read from the app module. Added a dev-only ATS exception (cleartext HTTP to
  the local server) via a generated Info.plist.

## Phase 4 - Match flow (2026-06-29)
- Added deterministic round/match state machine (`MatchPhase`: countdown,
  playing, roundOver, matchOver) in `GameState`.
- One-hit death: arrow hits (non-owner) and head stomps (stomper bounces).
- Best-of-5 scoring, round reset, double-KO draws, match win + winner.
- HUD score and center label (countdown / ROUND OVER / WIN-LOSE); dead players
  hidden; post-match Victory/Defeat overlay with Rematch/Leave.
- `MatchFlowTests` added; `StateHash` extended with phase/scores/round/alive.

### Controls
- Redesigned touch controls: single left joystick for move + aim; right-side
  icon buttons (Dash, Jump, Fire) instead of text.
- Repositioned action buttons: Fire bottom-right, Jump above, Dash upper-left.

## Phase 3 - Nakama online 1v1 (2026-06-29)
- Local Nakama backend: `docker-compose` + Postgres + Go runtime plugin.
- Go relay match handler (slot + shared-seed assignment, input relay) and a
  matchmaker-matched hook that creates the match.
- `PacketCodec` (unit-tested) for the input wire format.
- Swift client: `NakamaTransport` (InputTransport over a Nakama socket) and
  `OnlineMatchController` (device auth, matchmaking, join, START, RollbackSession).
- App: Find Online Match / Local Practice menu, online vs local via SceneDriver.
- Fixes: pinned Go deps to Nakama 3.22.0 (nakama-common 1.32.0 / protobuf
  1.34.1) so the plugin loads; pinned nakama-swift to 1.2.0 and matched its API.

## Phase 2 - Rollback netcode, offline (2026-06-29)
- `ArrowClashNet` module: `NetcodeSession` and `InputTransport` protocols.
- `RollbackSession`: input delay, prediction, snapshot save/restore, rollback +
  re-simulate on mispredict, confirmed-frame frontier.
- `SimulatedNetwork` (deterministic latency/jitter/loss) + `RollbackHarness`.
- Tests prove both peers match a full-information reference replay at every
  confirmed frame across many fuzzed network conditions.

## Phase 1 - Local render harness (2026-06-29)
- Arrows in the sim: shoot (press edge), light-gravity flight, stick-on-tile,
  reclaim on overlap; baked `AimTable` (256 directions, no runtime trig).
- SpriteKit `GameScene` renders the sim on a fixed 60 Hz timestep with
  interpolation; touch controls feed one InputCommand per tick.
- XcodeGen project spec; `swift run ArrowClashSimCheck` for CLT-only verification.

## Phase 0 - Deterministic sim core (2026-06-28)
- `ArrowClashSim` Swift package (no UIKit/SpriteKit): Q16.16 fixed-point math,
  value-type `GameState`, `InputCommand`, seeded PRNG.
- 60 Hz tick: run, jump (coyote + buffer + cut), dash (cooldown), gravity,
  swept-AABB tile collision, both-axis wrapping.
- `StateHash` (FNV-1a) and determinism + movement unit tests.

### Decisions
- Arena wraps on both axes; best of 5 (first to 3); Nakama Go runtime; proposed
  tunable feel defaults in `GameConfig`.
