# Phase 5 - Progression (server-authoritative)

Goal: XP and levels computed and written by the server, a cosmetic unlock
catalog gated by level, a leaderboard, a loadout screen, and cosmetics shown
in-match for both players. The client never writes progression directly.

## Server (Go, compiled + plugin-built here)

- `catalog.go`: cosmetic catalog (skins + trails) with required levels, the
  XP/level curve (`50*(L-1)*L` cumulative), and per-match XP
  (`50 + 25*kills + 75 if won`).
- `progression.go`:
  - Profile stored at collection `profile`, key `main`, with
    `PermissionWrite = 0` (server-only) and `PermissionRead = 1` (owner). This is
    what makes forged client writes impossible: clients cannot write the object,
    only these RPCs can.
  - `match_end` RPC: computes XP server-side from the (clamped) reported result,
    updates level, writes the profile, and updates the `arrowclash_xp`
    leaderboard. The reported win/kills only feed the clamped formula; the XP
    value itself is never taken from the client.
  - `get_profile` RPC: returns (and lazily creates) the profile.
  - `set_loadout` RPC: validates each chosen cosmetic exists, is the right kind,
    and is owned (level >= required) before saving.
- `main.go`: registers the RPCs and creates the leaderboard.
- `match_relay.go`: on START, reads each player's loadout and includes both in
  the payload so clients can render opponent cosmetics.

## Client (Swift, not compiled here)

- `Cosmetics.swift`: mirror of the catalog with display colors and the curve.
- `ProfileService.swift`: authenticated RPC wrapper (`get_profile`, `match_end`,
  `set_loadout`).
- `LoadoutView.swift`: shows level/XP and the catalog; unlocked cosmetics can be
  equipped (validated server-side).
- `AppModel`: submits the match result on match end; builds the scene with skin
  and arrow-trail colors from the START loadouts.
- `GameScene`: player body uses the skin color; arrows use the shooter's trail
  color; both come from START so they match on both screens.

## Verify

Server (headless): `cd nakama && docker compose up --build` and confirm
`arrowclash module loaded` plus no errors. You can exercise the RPCs from the
Nakama console (http://127.0.0.1:7351) under a user, or just play.

Acceptance (in app, two simulators):
1. Play and win a match -> XP increases (check Loadout screen / console storage).
2. Reach a cosmetic's level -> it becomes selectable in Loadout.
3. Equip it -> next match both players see your skin/arrow color.
4. Forged writes: the `profile` storage object cannot be written by a client
   (write permission is server-only); only the RPCs change it.

## Flags

- Client progression code (ProfileService / Loadout screen) could not be
  compiled here (no iOS toolchain / Nakama SDK). The RPC call shape follows
  nakama-swift v1.2.0; paste any compile errors and I will fix them (confined to
  `ProfileService.swift`).
- Result reporting trusts the client's win/kills within clamped bounds. True
  anti-cheat would require the server to run or verify the simulation; out of
  scope for v1, noted for later. The XP value and storage writes are already
  server-only.
- Leaderboard is written server-side; a client leaderboard view is not built yet
  (optional, easy to add).
