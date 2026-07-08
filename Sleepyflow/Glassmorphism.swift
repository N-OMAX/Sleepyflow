import SwiftUI

// MARK: - Glassmorphic Modifiers & Views

struct GlassmorphicBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                Color.black.opacity(0.3)
            )
            .background(
                VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark)
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

extension View {
    func glassmorphic() -> some View {
        self.modifier(GlassmorphicBackground())
    }
}

struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}

// MARK: - Colors
struct AppColors {
    static let background = Color(red: 0.05, green: 0.05, blue: 0.1)
    static let accentPurple = Color(red: 0.6, green: 0.2, blue: 0.9) // Deep vibrant purple based on typical logos
    static let accentLightPurple = Color(red: 0.7, green: 0.4, blue: 0.95)
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(gradient: Gradient(colors: [AppColors.accentPurple, AppColors.accentLightPurple]),
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
            )
            .foregroundColor(.white)
            .cornerRadius(15)
            .shadow(color: AppColors.accentPurple.opacity(0.5), radius: configuration.isPressed ? 5 : 10, x: 0, y: configuration.isPressed ? 2 : 5)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .frame(maxWidth: .infinity)
            .glassmorphic()
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(), value: configuration.isPressed)
    }
}
