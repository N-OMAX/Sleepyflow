import SwiftUI

private enum LaunchPhase {
    case brandReveal
    case loading
    case ready
}

struct SplashView: View {
    @StateObject private var authManager = AuthManager()
    @State private var phase: LaunchPhase = .brandReveal

    // Brand reveal animation state
    @State private var logoScale: CGFloat = 0.62
    @State private var logoOpacity: Double = 0
    @State private var logoBlur: CGFloat = 18
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 14
    @State private var moonPulse: CGFloat = 1.0

    // Loading phase state
    @State private var loadingStatus = "Bereite Sleepyflow vor …"
    @State private var loadingProgress: CGFloat = 0.12

    var body: some View {
        Group {
            if phase == .ready {
                if authManager.isSignedIn {
                    ContentView(authManager: authManager)
                } else {
                    LoginView(authManager: authManager)
                }
            } else {
                ZStack {
                    AnimatedNightBackground()

                    if phase == .brandReveal {
                        brandRevealContent
                    } else {
                        loadingContent
                    }
                }
                .preferredColorScheme(.dark)
            }
        }
        .onAppear { runLaunchSequence() }
    }

    // MARK: - Phase 1: brand reveal

    private var brandRevealContent: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.55), Color.clear],
                            center: .center, startRadius: 0, endRadius: 130
                        )
                    )
                    .frame(width: 260, height: 260)
                    .scaleEffect(moonPulse)
                    .blur(radius: 22)

                Image(systemName: "moon.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 92, height: 92)
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.7), radius: 24)
            }
            .scaleEffect(logoScale)
            .opacity(logoOpacity)
            .blur(radius: logoBlur)

            VStack(spacing: 6) {
                Text("Sleepyflow")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("by Joshua Pawlowski")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1.5)
            }
            .opacity(titleOpacity)
            .offset(y: titleOffset)
        }
    }

    // MARK: - Phase 2: real loading screen

    private var loadingContent: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "moon.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .foregroundStyle(.white)
                .shadow(color: .white.opacity(0.6), radius: 14)

            Spacer()

            VStack(spacing: 14) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 5)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.accentLightPurple, AppColors.accentPurple],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * loadingProgress, height: 5)
                            .animation(.easeInOut(duration: 0.4), value: loadingProgress)
                    }
                }
                .frame(height: 5)
                .frame(maxWidth: 180)

                Text(loadingStatus)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .animation(nil, value: loadingStatus)
            }
            .padding(.bottom, 70)
        }
    }

    // MARK: - Launch sequence

    private func runLaunchSequence() {
        withAnimation(.spring(response: 0.9, dampingFraction: 0.72)) {
            logoScale = 1.0
            logoOpacity = 1
            logoBlur = 0
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.25)) {
            titleOffset = 0
            titleOpacity = 1
        }
        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
            moonPulse = 1.1
        }

        Task {
            // Let the brand reveal breathe for a moment.
            try? await Task.sleep(nanoseconds: 1_500_000_000)

            withAnimation(.easeInOut(duration: 0.35)) { phase = .loading }
            loadingStatus = "Prüfe Anmeldung …"
            loadingProgress = 0.35

            // Real work: confirm a stored Apple session is still valid.
            // Raced against a small minimum duration so the loading screen
            // never just flashes for a few milliseconds.
            async let sessionCheck: Void = authManager.refreshSession()
            async let minimumDuration: Void = try? Task.sleep(nanoseconds: 900_000_000)
            _ = await (sessionCheck, minimumDuration)

            loadingStatus = "Lade deine Daten …"
            withAnimation { loadingProgress = 0.8 }
            try? await Task.sleep(nanoseconds: 400_000_000)

            loadingStatus = "Fertig"
            withAnimation { loadingProgress = 1.0 }
            try? await Task.sleep(nanoseconds: 250_000_000)

            withAnimation(.easeInOut(duration: 0.4)) { phase = .ready }
        }
    }
}

// MARK: - Animated night-sky background (matches the app icon: crescent
// moon glow, twinkling stars, flowing "sleep wave" ribbons)
private struct AnimatedNightBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.02, blue: 0.09),
                    Color(red: 0.30, green: 0.11, blue: 0.58),
                    Color(red: 0.58, green: 0.36, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate

                    // Twinkling stars
                    let stars: [(CGFloat, CGFloat, CGFloat, Double)] = [
                        (0.72, 0.18, 3.0, 0.0), (0.82, 0.28, 2.2, 1.3),
                        (0.27, 0.20, 2.6, 2.1), (0.18, 0.31, 1.8, 0.6),
                        (0.87, 0.14, 1.8, 3.0), (0.12, 0.16, 2.2, 1.8),
                        (0.60, 0.10, 1.6, 2.6), (0.40, 0.14, 1.6, 0.9)
                    ]
                    for (fx, fy, r, starPhase) in stars {
                        let twinkle = 0.35 + 0.45 * (0.5 + 0.5 * sin(t * 1.6 + starPhase))
                        let point = CGPoint(x: size.width * fx, y: size.height * fy)
                        context.opacity = twinkle
                        context.fill(
                            Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)),
                            with: .color(.white)
                        )
                    }
                    context.opacity = 1

                    // Flowing "sleep wave" ribbons near the bottom
                    let waveY = size.height * 0.78
                    let amp = size.height * 0.03
                    let steps = 60

                    func wavePath(yOffset: CGFloat, ampScale: CGFloat, speed: Double, wavePhase: Double) -> Path {
                        var path = Path()
                        for i in 0...steps {
                            let x = size.width * CGFloat(i) / CGFloat(steps)
                            let y = waveY + yOffset + amp * ampScale * CGFloat(
                                sin(Double(i) / Double(steps) * .pi * 2.3 + t * speed + wavePhase)
                            )
                            if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                        return path
                    }

                    context.stroke(
                        wavePath(yOffset: 0, ampScale: 1.0, speed: 0.9, wavePhase: 0),
                        with: .color(.white.opacity(0.16)), lineWidth: 3
                    )
                    context.stroke(
                        wavePath(yOffset: size.height * 0.05, ampScale: 0.8, speed: 0.9, wavePhase: 2.4),
                        with: .color(.white.opacity(0.10)), lineWidth: 3
                    )
                }
            }
            .allowsHitTesting(false)
        }
    }
}
