// NetcodeSession.swift
// The protocol the game loop talks to, independent of HOW inputs are
// synchronized. RollbackSession is the v1 implementation; an authoritative-tick
// + client-prediction implementation could conform to the same protocol later
// without changing the sim or the render loop.
//
// Frame model: frame F is simulated from the state at the start of F using both
// players' inputs for F, producing the state at the start of F+1. stateAt(F)
// returns the start-of-frame state; latestState is the most advanced (possibly
// predicted) state for rendering. confirmedFrame is the largest frame for which
// every earlier frame's inputs are known for certain, so stateAt(confirmedFrame)
// matches what the peer computes.

import ArrowClashSim

public protocol NetcodeSession: AnyObject {
    var localPlayer: Int { get }

    // Next frame to be simulated (== number of frames simulated so far).
    var currentFrame: Int { get }

    // Largest frame whose entire history is confirmed by both peers.
    var confirmedFrame: Int { get }

    // Start-of-frame state for a frame in [0, currentFrame].
    func stateAt(frame: Int) -> GameState

    // Most advanced state, suitable for rendering (may include prediction).
    var latestState: GameState { get }

    // Provide this peer's local input and advance the session by one frame.
    func step(localInput: InputCommand)
}
