// ControlsOverlay.swift
// On-screen touch controls drawn over the SpriteKit view. Left thumb is a move
// joystick; right side has Jump/Dash buttons and an aim joystick that fires on
// release. All of this writes into the InputBus; none of it touches the sim
// directly. Floats here are fine (input layer only).

import SwiftUI

struct ControlsOverlay: View {
    let input: InputBus

    var body: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                Joystick(radius: 56,
                         label: "MOVE",
                         onChange: { v in
                             input.moveX = v.dx > 0.35 ? 1 : (v.dx < -0.35 ? -1 : 0)
                         },
                         onEnd: { _ in input.moveX = 0 })
                Spacer()
                VStack(alignment: .trailing, spacing: 14) {
                    HStack(spacing: 14) {
                        PressButton(label: "DASH",
                                    onPress: { input.dashHeld = true },
                                    onRelease: { input.dashHeld = false })
                        PressButton(label: "JUMP",
                                    onPress: { input.jumpHeld = true },
                                    onRelease: { input.jumpHeld = false })
                    }
                    AimStick(input: input)
                }
            }
            .padding(28)
        }
        .allowsHitTesting(true)
    }
}

// Move joystick.
private struct Joystick: View {
    let radius: CGFloat
    let label: String
    let onChange: (CGVector) -> Void
    let onEnd: (CGVector) -> Void

    @State private var thumb: CGSize = .zero

    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.08))
            Circle().fill(Color.white.opacity(0.20))
                .frame(width: radius, height: radius)
                .offset(thumb)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
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
                    let cx = dx / length * clamped
                    let cy = dy / length * clamped
                    thumb = CGSize(width: cx, height: cy)
                    onChange(CGVector(dx: cx / radius, dy: cy / radius))
                }
                .onEnded { _ in
                    let v = CGVector(dx: thumb.width / radius, dy: thumb.height / radius)
                    thumb = .zero
                    onEnd(v)
                }
        )
    }
}

// Aim joystick: tracks aim while dragging, fires on release.
private struct AimStick: View {
    let input: InputBus
    let radius: CGFloat = 56

    @State private var thumb: CGSize = .zero

    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.08))
            Circle().fill(Color(red: 0.95, green: 0.8, blue: 0.3).opacity(0.5))
                .frame(width: radius, height: radius)
                .offset(thumb)
            Text("AIM / FIRE")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
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
                    if abs(dx) + abs(dy) > 8 {
                        input.aim = aimByte(dx: Double(dx), dy: Double(dy))
                    }
                }
                .onEnded { value in
                    let dx = Double(value.translation.width)
                    let dy = Double(value.translation.height)
                    let dir = (abs(dx) + abs(dy) > 8) ? aimByte(dx: dx, dy: dy) : input.aim
                    thumb = .zero
                    input.requestShoot(aim: dir)
                }
        )
    }
}

// Press-and-hold button: held is true between press and release.
private struct PressButton: View {
    let label: String
    let onPress: () -> Void
    let onRelease: () -> Void

    @State private var pressed = false

    var body: some View {
        Text(label)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 66, height: 66)
            .background(
                Circle().fill(Color.white.opacity(pressed ? 0.35 : 0.15))
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !pressed { pressed = true; onPress() }
                    }
                    .onEnded { _ in
                        pressed = false; onRelease()
                    }
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
