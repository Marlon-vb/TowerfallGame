// ControlsOverlay.swift
// Touch controls drawn over the SpriteKit view.
//
// Left: a single joystick that BOTH moves and aims. Its horizontal component
// drives left/right movement; its full direction sets the aim used when firing.
// Releasing it stops movement but keeps the last aim.
//
// Right: icon buttons for Dash, Jump and Fire. Dash/Jump are press-and-hold;
// Fire shoots on press in the current aim direction.
//
// All of this writes into the InputBus; none of it touches the sim directly.

import SwiftUI

struct ControlsOverlay: View {
    let input: InputBus

    var body: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                MoveAimJoystick(input: input, radius: 60)
                Spacer()
                actionButtons
            }
            .padding(28)
        }
        .allowsHitTesting(true)
    }

    private var actionButtons: some View {
        VStack(alignment: .trailing, spacing: 14) {
            HStack(spacing: 14) {
                IconHoldButton(systemName: "hare.fill",
                               onPress: { input.dashHeld = true },
                               onRelease: { input.dashHeld = false })
                IconHoldButton(systemName: "arrow.up.circle.fill",
                               onPress: { input.jumpHeld = true },
                               onRelease: { input.jumpHeld = false })
            }
            IconTapButton(systemName: "scope") {
                input.requestShoot(aim: input.aim)
            }
        }
    }
}

// Combined move + aim joystick.
private struct MoveAimJoystick: View {
    let input: InputBus
    let radius: CGFloat

    @State private var thumb: CGSize = .zero

    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.08))
            Circle().fill(Color.white.opacity(0.20))
                .frame(width: radius, height: radius)
                .offset(thumb)
            Image(systemName: "dpad.fill")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(width: radius * 2, height: radius * 2)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    let length = max(1, (dx * dx + dy * dy).squareRoot())
                    let clamped = min(length, radius)
                    thumb = CGSize(width: dx / length * clamped, height: dy / length * clamped)

                    let nx = dx / radius
                    input.moveX = nx > 0.35 ? 1 : (nx < -0.35 ? -1 : 0)
                    if abs(dx) + abs(dy) > 10 {
                        input.aim = aimByte(dx: Double(dx), dy: Double(dy))
                    }
                }
                .onEnded { _ in
                    thumb = .zero
                    input.moveX = 0 // stop moving; keep last aim
                }
        )
    }
}

// Press-and-hold icon button (Dash, Jump).
private struct IconHoldButton: View {
    let systemName: String
    let onPress: () -> Void
    let onRelease: () -> Void

    @State private var pressed = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 26, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 66, height: 66)
            .background(Circle().fill(Color.white.opacity(pressed ? 0.35 : 0.15)))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if !pressed { pressed = true; onPress() } }
                    .onEnded { _ in pressed = false; onRelease() }
            )
    }
}

// Tap icon button that fires once on press (Fire).
private struct IconTapButton: View {
    let systemName: String
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 30, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 78, height: 78)
            .background(Circle().fill(Color(red: 0.95, green: 0.8, blue: 0.3).opacity(pressed ? 0.55 : 0.30)))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if !pressed { pressed = true; action() } }
                    .onEnded { _ in pressed = false }
            )
    }
}

// Screen and sim are both y-down, so the screen drag angle maps directly to an
// 8-bit aim direction with no flip.
private func aimByte(dx: Double, dy: Double) -> UInt8 {
    let turns = atan2(dy, dx) / (2.0 * Double.pi)
    let steps = Int((turns * 256.0).rounded())
    return UInt8(((steps % 256) + 256) % 256)
}
