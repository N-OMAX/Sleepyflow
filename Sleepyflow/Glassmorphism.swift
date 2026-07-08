import SwiftUI

// MARK: - Glass Card Modifier (iOS Native Style)
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // The actual blur layer
                    VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark)
                    // Subtle white tint on top
                    Color.white.opacity(0.06)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 8)
    }
}

extension View {
    func glassmorphic(cornerRadius: CGFloat = 20) -> some View {
        self.modifier(GlassCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Visual Effect Blur (UIKit bridge)
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}

// MARK: - App Color Palette
struct AppColors {
    static let background = Color(red: 0.04, green: 0.04, blue: 0.08)
    static let accentPurple = Color(red: 0.55, green: 0.15, blue: 0.88)
    static let accentLightPurple = Color(red: 0.72, green: 0.42, blue: 0.98)
    static let accentGlow = Color(red: 0.65, green: 0.25, blue: 0.95).opacity(0.6)
}

// MARK: - Primary Button (Solid Purple Gradient)
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        AppColors.accentPurple,
                        AppColors.accentLightPurple
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(
                color: AppColors.accentPurple.opacity(configuration.isPressed ? 0.3 : 0.55),
                radius: configuration.isPressed ? 6 : 14,
                x: 0,
                y: configuration.isPressed ? 2 : 6
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button (Glassmorphic)
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .glassmorphic(cornerRadius: 16)
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
