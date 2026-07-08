import SwiftUI

struct SplashView: View {
    @State private var isActive = false
    @State private var scale: CGFloat = 0.7
    @State private var opacity: Double = 0.0
    @State private var blurRadius: CGFloat = 20
    
    var body: some View {
        if isActive {
            ContentView()
        } else {
            ZStack {
                // Deep black background
                Color.black.ignoresSafeArea()
                
                // Purple radial glow
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.5, green: 0.1, blue: 0.85).opacity(0.4),
                        Color.clear
                    ]),
                    center: .center,
                    startRadius: 10,
                    endRadius: 300
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Logo from Assets
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .shadow(color: Color(red: 0.6, green: 0.2, blue: 0.9).opacity(0.8), radius: 30, x: 0, y: 0)
                        .blur(radius: blurRadius)
                    
                    VStack(spacing: 6) {
                        Text("Sleepyflow")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("by Joshua Pawlowski")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1.5)
                    }
                }
                .scaleEffect(scale)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                        scale = 1.0
                        opacity = 1.0
                        blurRadius = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                        withAnimation(.easeOut(duration: 0.4)) {
                            opacity = 0.0
                            scale = 1.05
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            isActive = true
                        }
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
