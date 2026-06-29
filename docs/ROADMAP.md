# ArrowClash - Roadmap (A to Z)

Where we are and everything left to ship a polished game. Phases 0-6 (the
original build) plus the content/avatar/juice passes are done; this is the plan
from here. Phases are roughly sequenced but several can run in parallel (see
Tracks). "[me]" = I can do it in-repo; "[you]" = needs you (an account, art
commission, money, a decision); "[both]" = collaboration.

## Status snapshot (done)

- Deterministic 60Hz sim (Swift package), proven rollback netcode (headless),
  Nakama backend (docker), online 1v1 matchmaking + relayed transport.
- Match flow: countdown, one-hit death (arrow + stomp), best-of-5, post-match.
- Progression: server-authoritative XP, levels, coins, leaderboard.
- Avatar system (layered: skin/hair/shirt/pants/head/trail) + Store + Customize.
- 10 maps, per-map themes, basic juice (squash/stretch, dust, shake, zoom,
  vignette, gradients).
- Settings (sound, server host), CHANGELOG, per-phase docs.

Art today is original geometric/blocky placeholder. The big remaining lift is
real art + UX polish + production hardening + release.

---

## Phase 7 - Visual identity & art pipeline  [both]

The single biggest quality jump. Decide the style, then build a pipeline that
composites layered character art so we never pre-bake every combination.

7.1 Style decision [you/both]
- Pick pixel art vs clean vector/flat. Lock palette (see docs/ART_DIRECTION.md).
- Define character proportions, frame size, and the animation set.

7.2 Character layered-sprite system [me builds pipeline, you/[both] provide art]
- Animation set per character: idle, run, jump, fall, dash, draw, shoot, hit/die.
- One sprite sheet PER PART (skin/hair/shirt/pants/head), all sharing the same
  frame timeline; composite layers at runtime in draw order.
- Color variants via tinting greyscale/mask art (so 8 hair colors = 1 sheet + 8
  tints, not 8 sheets).
- Texture atlas per part; optional cached composited texture per equipped avatar
  at match start for perf.
- Replace AvatarRenderer's shapes with SKSpriteNode layers + frame animation
  driven by sim state/velocity.
- Placeholder pipeline first: I can generate simple programmatic part-sheets to
  build and validate the system before real art lands.

7.3 World art [both]
- Tileset per map theme (16x16) with auto-tiling/edges; replace flat tiles.
- Parallax background layers per theme (replace gradient).
- Arrow sprite + stuck-in-wall variant; pickup shimmer.

7.4 FX art [me]
- Hand-authored particle textures for dust, impact, death; muzzle/launch puff.
- (Optional, revisit) tasteful glow that matches the new art, not the old shapes.

7.5 Sourcing [you]
- CC0 packs (Kenney, OpenGameArt CC0) or commission. No ripped/scraped art.

## Phase 8 - UI/UX overhaul  [me]

8.1 Layout & scrolling fixes
- Make every screen scroll/lay out correctly on all iPhone sizes + landscape
  and within safe areas (menu, customize, store, settings, post-match).
- Fix main-menu scrolling/overflow specifically.
8.2 Navigation & flow
- First-run character creation flow; clean transitions; back-stack consistency.
- Loading/connecting/error/empty states (matchmaking, store, profile).
8.3 Screen polish
- Redesigned HUD, countdown, post-match; in-app leaderboard screen.
- Custom font, iconography, button styles, haptics.
8.4 Accessibility
- Dynamic type where possible, color-blind-safe palette, reduced-motion option.

## Phase 9 - Audio  [both]

- Real SFX (shoot/jump/dash/hit/death/UI) replacing placeholders. [you sources]
- Music per screen + per-map loops; ducking/mixing; master/SFX/music volumes.
- Wire through the existing AudioManager + Settings. [me]

## Phase 10 - Netcode & backend hardening  [me]

10.1 Robustness
- Disconnect/reconnect handling; graceful forfeit/abandon; pause-on-drop.
- Desync detection via confirmed-frame state-hash exchange + recovery/resync.
- Ring-buffer the rollback frame storage (cap memory over long matches).
- Input-delay/latency tuning; jitter buffer; configurable region.
10.2 Server authority / anti-cheat
- Validate match results server-side beyond clamping (e.g., server-checked
  match summaries or a server-run/verified sim) so XP/coins can't be forged.
- Rate-limit RPCs; sanity-check purchases/avatars (already validated) + logging.
10.3 Deploy
- Production Nakama hosting (Heroic Cloud or self-host), TLS, secrets,
  migrations, backups, monitoring/alerts. [both]

## Phase 11 - Accounts & social  [both]

- Game Center auth (behind the existing AuthProvider seam) + device-id linking.
- Account recovery / cross-device. [me/[both]]
- Leaderboard UI (global + friends); profile view.
- Friends, invites, private matches, rematch-with-same-opponent. (chat is later)

## Phase 12 - Economy & monetization  [both]

- Tune coin earn rates + prices; sinks; anti-grind.
- Store expansion (more heads/outfits/trails; seasonal/limited items).
- Real-money IAP via StoreKit 2 + server receipt validation; coin packs and/or
  direct cosmetic purchases. [you: App Store Connect products] [me: integration]
- Optional: daily rewards, quests/challenges, battle pass.

## Phase 13 - Content & game feel  [both]

- More maps + variety (and their art); map rotation/voting.
- Game-feel tuning pass (movement, dash, arrow speed, hit-stop) once art is in.
- Possible modes later (3-4 player FFA, team, time-limited) - explicitly beyond
  v1; revisit after 1v1 is great.
- Practice bots (offline AI) for onboarding.

## Phase 14 - Quality, performance, telemetry  [me/[both]]

- Performance profiling (60fps on min spec); atlas/draw-call optimization.
- Crash reporting + analytics (privacy-respecting); funnel + match metrics.
- Expand automated tests (sim already covered); add UI/integration smoke tests.
- CI: build + run sim tests on every push; lint.

## Phase 15 - Release  [both]

- App icon, App Store screenshots/preview, description, keywords. [you/[both]]
- Privacy policy, App Privacy nutrition labels, age rating, export compliance.
- TestFlight beta → feedback → fixes.
- App Store submission + review; staged rollout.

## Phase 16 - Live ops (ongoing)  [both]

- Seasons/events, balance patches, new cosmetics/maps, leaderboards resets,
  community feedback loop, monitoring + hotfix process.

---

## Tracks (what can run in parallel)

- Track A (art): Phase 7 + 9 sourcing - gated on your style/asset decisions.
- Track B (engineering): Phases 8, 10, 14 - I can progress now.
- Track C (business): Phases 12, 15 - gated on Apple Developer account + IAP.

## Recommended near-term order (quick wins first)

1. Phase 8.1 - fix menu/all-screen scrolling + responsive layout. [me, now]
2. Phase 7.2 - build the layered-sprite pipeline with PLACEHOLDER part-sheets so
   characters animate and the system is ready for real art. [me, now]
3. Phase 7.1 - you pick the art style + a CC0 pack (or commission). [you]
4. Phase 10.1 - reconnect + desync detection + ring buffer. [me]
5. Then real art drops into the pipeline; UX polish; audio; release prep.

## Decisions needed from you

- Art style (pixel vs vector) and who makes the art (CC0 vs commission).
- Apple Developer account (needed for device testing at scale, TestFlight, IAP,
  release).
- Monetization model (coins-only vs IAP, and what's sold).
- Hosting choice for production Nakama.
