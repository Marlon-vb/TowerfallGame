// InputBus.swift
// Bridges the touch controls (UI thread) to the sim loop. The controls write
// continuous state and latch one-shot actions; the scene reads one InputCommand
// per simulation tick. Floats are fine here: this is the input layer, not the
// sim. Only the resulting integer InputCommand crosses into the deterministic
// simulation.

import ArrowClashSim

final class InputBus {
    // Continuous state.
    var moveX: Int = 0        // -1, 0, +1
    var jumpHeld: Bool = false
    var dashHeld: Bool = false
    var aim: UInt8 = 0

    // One-shot: a shoot request fires on the next tick only.
    private var shootLatched: Bool = false

    func requestShoot(aim: UInt8) {
        self.aim = aim
        self.shootLatched = true
    }

    // Called exactly once per simulation tick by the scene.
    func consumeForTick() -> InputCommand {
        var buttons: InputCommand.Buttons = []
        if moveX < 0 { buttons.insert(.left) }
        if moveX > 0 { buttons.insert(.right) }
        if jumpHeld { buttons.insert(.jump) }
        if dashHeld { buttons.insert(.dash) }
        if shootLatched {
            buttons.insert(.shoot)
            shootLatched = false
        }
        return InputCommand(buttons: buttons, aim: aim)
    }
}
