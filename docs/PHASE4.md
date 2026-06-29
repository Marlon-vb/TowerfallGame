# Phase 4 — Match flow

Goal: rounds, countdown, scoring, one-hit death, match win, and a post-match
screen with rematch/leave. A full best-of-5 match plays start to finish online.

## Sim (deterministic, headless-tested)

The whole round/match lifecycle lives in `GameState` so it rolls back with
everything else:

- `MatchPhase`: `countdown` -> `playing` -> `roundOver` -> (`countdown` | `matchOver`).
- `PlayerState.alive`, `GameState.scores`, `round`, `winner`, `phaseTimer`.
- One-hit death: a flying arrow overlapping a non-owner kills them; a player
  descending onto another's head stomps and kills them (stomper bounces).
- Round end: the survivor scores; a double kill scores for no one. After a
  `roundOverTicks` pause the round resets (positions, arrows, quivers) or, if
  someone reached `roundsToWin` (3 = best of 5), the match ends.
- Countdown and roundOver freeze input but still settle players with gravity.
- `matchOver` freezes the sim entirely.

New config: `countdownTicks` (90), `roundOverTicks` (120), `roundsToWin` (3),
`stompBounceSpeed` (5). `StateHash` now folds in phase, timers, scores, round,
winner, and per-player alive.

### Rollback interaction

Because all of this is part of the deterministic state, deaths and round
transitions roll back and re-simulate correctly. The renderer reads the
predicted (latest) state, so under bad prediction a kill could briefly show and
then be undone by a rollback before it is confirmed. Acceptable for v1; the
confirmed timeline is always correct.

## App

- HUD shows the score and a center label for the countdown number, "ROUND
  OVER", and "YOU WIN" / "YOU LOSE".
- Dead players are hidden for the round.
- Post-match overlay (Victory/Defeat) with Rematch and Menu. Rematch re-queues
  online or restarts local practice. (Coordinated rematch with the same
  opponent is a later nicety; for now each side re-enters matchmaking.)

## Verify

Headless:
```
cd ArrowClashSim
swift test                 # MatchFlowTests + everything prior
swift run ArrowClashSimCheck
```

App: build and run two simulators, Find Online Match on both, and play a full
match to a winner.

## Flags

- Stomp detection is a heuristic (upper, overlapping, descending player kills
  the lower). It feels right for clean head-stomps; edge cases at equal height
  simply do not trigger. Tune later if needed.
- Local Practice never ends (player 2 is an idle dummy), so the post-match
  screen only appears online.
