//
//  AmbientBackdropView.swift
//  MSRU
//

import SwiftUI

/// Fluid ambient backdrop that creates an ethereal, blurred, dynamic atmosphere
/// tailored to the currently playing media artwork and tone.
struct AmbientBackdropView: View {
    var artworkData: Data? = nil
    var artworkURL: URL? = nil
    var primaryTint: Color = .accentColor

    @State private var driftPhase: Double = 0.0

    var body: some View {
        ZStack {
            // Base dark tone
            Color.black
                .ignoresSafeArea()

            // Dynamic color fluid blobs
            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height

                ZStack {
                    if let artworkData, let image = Image(artworkData: artworkData) {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: width * 1.2, height: height * 1.2)
                            .blur(radius: 70)
                            .opacity(0.65)
                            .scaleEffect(1.0 + 0.05 * sin(driftPhase))
                    } else {
                        // Procedural harmonic gradient blobs
                        Circle()
                            .fill(primaryTint.opacity(0.55))
                            .frame(width: width * 0.75, height: width * 0.75)
                            .offset(
                                x: -width * 0.2 + 40 * cos(driftPhase),
                                y: -height * 0.15 + 30 * sin(driftPhase)
                            )
                            .blur(radius: 90)

                        Circle()
                            .fill(Color.purple.opacity(0.45))
                            .frame(width: width * 0.65, height: width * 0.65)
                            .offset(
                                x: width * 0.25 - 30 * sin(driftPhase),
                                y: height * 0.15 + 40 * cos(driftPhase)
                            )
                            .blur(radius: 80)

                        Circle()
                            .fill(Color.blue.opacity(0.35))
                            .frame(width: width * 0.5, height: width * 0.5)
                            .offset(
                                x: -width * 0.05 + 20 * sin(driftPhase * 1.5),
                                y: height * 0.2 - 20 * cos(driftPhase * 1.2)
                            )
                            .blur(radius: 70)
                    }
                }
                .frame(width: width, height: height)
                .clipped()
            }
            .ignoresSafeArea()

            // Subtle dark overlay to guarantee foreground typography readability
            Color.black.opacity(0.42)
                .ignoresSafeArea()

            // Subtle radial vignette
            RadialGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.65)
                ],
                center: .center,
                startRadius: 200,
                endRadius: 900
            )
            .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 9.0)
                .repeatForever(autoreverses: true)
            ) {
                driftPhase = .pi * 2
            }
        }
    }
}

#Preview("Ambient Backdrop") {
    ZStack {
        AmbientBackdropView(primaryTint: .blue)

        VStack(spacing: 12) {
            Image(systemName: "music.note")
                .font(.system(size: 64))
                .foregroundStyle(.white)
            Text("Now Playing Ambient Preview")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
        }
    }
    .frame(width: 800, height: 600)
}
