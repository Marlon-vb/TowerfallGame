# Phase 6 - Polish

Goal: game feel, audio, menu cleanup, and basic settings, so it reads as a small
finished game. Everything here is render/UI-layer only; the deterministic sim and
rollback netcode are untouched, so none of it can cause a desync.

## Game feel (GameScene, render-only)

- All world visuals live under a `world` node so it can shake without moving the
  HUD.
- On a kill: screen shake, a brief white hit flash, and a particle burst at the
  dead player.
- Event detection diffs the last tick's before/after states (only when a tick
  occurred) to fire effects and sounds. Movement sounds (shoot/jump/dash) are
  local-player only, since those inputs are not predicted and so do not flicker
  under rollback; the hit sound fires for either player's death.

## Audio

- `Sounds/*.wav` are small generated blips (shoot, jump, dash, hit, ui).
- `AudioManager` preloads them as reusable `SKAction`s and plays them on a node,
  gated by the Settings sound toggle.

## Settings

- `Settings` persists a sound toggle and the server host in UserDefaults.
- `SettingsView` exposes both. The server host lets a physical device point at
  the Mac's LAN IP without editing code (simulator uses 127.0.0.1). It feeds both
  `OnlineMatchController` and `ProfileService`.

## Menu

- Shows level/XP (from the profile) and routes to Find Match / Local Practice /
  Loadout / Settings.

## Verify

This phase is visual/audio/UI; build and run:

```
cd App
~/XcodeGen/.build/release/xcodegen generate   # picks up new files + Sounds
open ArrowClash.xcodeproj
```

Check: kills shake the screen, flash, and spray particles; sounds play and the
toggle silences them; Settings server host changes where the app connects; the
menu shows your level/XP.

## Flags

- Under heavy rollback a predicted death could, in rare cases, trigger the hit
  effect and then be undone. Movement sounds avoid this by being local-only;
  death FX accept the rare double. Can be gated on confirmed frames later if it
  is noticeable.
- Sounds are simple synthesized blips (placeholders); swap in real assets any
  time by replacing the files in `Sounds/`.
