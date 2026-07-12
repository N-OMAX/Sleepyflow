import Foundation
import UIKit
import AuthenticationServices
import CryptoKit

// Local-only auth. No backend exists in this app and none of this ever
// leaves the device — it's just here so the app can greet you by name.
// Everything is stored in UserDefaults on-device only, whichever provider
// you sign in with.
//
// NSObject subclass is required because ASWebAuthenticationSession's
// presentationContextProvider is an Objective-C protocol.
@MainActor
class AuthManager: NSObject, ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var displayName: String = ""

    private let userIdKey = "authUserIdentifier"
    private let nameKey = "authDisplayName"

    private var webAuthSession: ASWebAuthenticationSession?

    override init() {
        super.init()
        loadStoredSession()
    }

    private func loadStoredSession() {
        if let storedID = UserDefaults.standard.string(forKey: userIdKey), !storedID.isEmpty {
            isSignedIn = true
            displayName = UserDefaults.standard.string(forKey: nameKey) ?? ""
        }
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: nameKey)
        isSignedIn = false
        displayName = ""
    }

    /// Called once at launch (from the loading screen) to make sure a
    /// previously stored Apple session hasn't been revoked in the meantime.
    /// Awaitable, so the loading screen can show real progress instead of a
    /// fixed timer.
    func refreshSession() async {
        guard isSignedIn,
              let storedID = UserDefaults.standard.string(forKey: userIdKey),
              storedID.hasPrefix("apple:") else { return }
        let appleUserID = String(storedID.dropFirst("apple:".count))

        let provider = ASAuthorizationAppleIDProvider()
        let state = await withCheckedContinuation { (continuation: CheckedContinuation<ASAuthorizationAppleIDProvider.CredentialState, Never>) in
            provider.getCredentialState(forUserID: appleUserID) { state, _ in
                continuation.resume(returning: state)
            }
        }
        if state != .authorized {
            signOut()
        }
    }

    // MARK: - Sign in with Apple

    func handleAppleSignIn(credential: ASAuthorizationAppleIDCredential) {
        let userID = credential.user

        // Apple only ever sends the full name on the very first sign-in for
        // this app + Apple ID combo — keep the name we already stored if a
        // later sign-in doesn't include one.
        var name = displayName
        if let fullName = credential.fullName {
            let formatted = PersonNameComponentsFormatter().string(from: fullName)
            if !formatted.trimmingCharacters(in: .whitespaces).isEmpty {
                name = formatted
            }
        }

        UserDefaults.standard.set("apple:\(userID)", forKey: userIdKey)
        UserDefaults.standard.set(name, forKey: nameKey)
        displayName = name
        isSignedIn = true
    }

    // MARK: - Google Sign-In (in-app browser, ASWebAuthenticationSession)

    // Google Cloud Console → APIs & Services → Credentials.
    // Bundle ID: com.joshuapawlowski.sleepyflow
    // No client secret needed — this is a native/public client flow.
    private static let googleClientID = "942324445418-v0760gg5oq92p9qcga5njk56ke3kvvev.apps.googleusercontent.com"

    /// Google's iOS OAuth clients require the redirect URL scheme to be the
    /// "reversed client ID" — everything before ".apps.googleusercontent.com",
    /// prefixed with "com.googleusercontent.apps.". This is Google's own
    /// convention (same one GoogleSignIn-iOS uses), not something we choose.
    private static var googleRedirectScheme: String {
        let suffix = ".apps.googleusercontent.com"
        guard googleClientID.hasSuffix(suffix) else { return "sleepyflow" }
        let idPart = String(googleClientID.dropLast(suffix.count))
        return "com.googleusercontent.apps.\(idPart)"
    }

    func signInWithGoogle() {
        guard !Self.googleClientID.hasPrefix("YOUR_GOOGLE_CLIENT_ID"), !Self.googleClientID.isEmpty else {
            print("⚠️ Google Sign-In: set AuthManager.googleClientID first (see comment above it).")
            return
        }

        let redirectScheme = Self.googleRedirectScheme
        let redirectURI = "\(redirectScheme):/oauth2redirect"
        let verifier = Self.makeCodeVerifier()
        let challenge = Self.codeChallenge(for: verifier)
        pendingCodeVerifier = verifier

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Self.googleClientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        guard let authURL = components.url else { return }

        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: redirectScheme
        ) { [weak self] callbackURL, error in
            guard let self = self else { return }
            guard let callbackURL = callbackURL else {
                if let error = error {
                    print("Google sign-in failed or cancelled: \(error.localizedDescription)")
                }
                return
            }
            Task { @MainActor in
                await self.exchangeCodeForToken(callbackURL: callbackURL, redirectURI: redirectURI)
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = true
        webAuthSession = session
        session.start()
    }

    private var pendingCodeVerifier: String?

    /// Authorization Code flow returns `code` as a normal query parameter
    /// (unlike the old implicit flow, which used a URL fragment).
    private func exchangeCodeForToken(callbackURL: URL, redirectURI: String) async {
        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value,
            let verifier = pendingCodeVerifier else {
            print("Google sign-in: no authorization code in callback.")
            return
        }
        pendingCodeVerifier = nil

        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let bodyParams = [
            "client_id": Self.googleClientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI
        ]
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let idToken = json["id_token"] as? String,
                  let payload = Self.decodeJWTPayload(idToken) else {
                print("Google sign-in: token exchange response missing id_token.")
                return
            }
            let name = (payload["name"] as? String) ?? (payload["email"] as? String) ?? "Google-Nutzer"
            let subject = (payload["sub"] as? String) ?? UUID().uuidString

            UserDefaults.standard.set("google:\(subject)", forKey: userIdKey)
            UserDefaults.standard.set(name, forKey: nameKey)
            displayName = name
            isSignedIn = true
        } catch {
            print("Google sign-in: token exchange failed — \(error.localizedDescription)")
        }
    }

    // MARK: PKCE helpers

    private static func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URL(Data(bytes))
    }

    private static func codeChallenge(for verifier: String) -> String {
        let hashed = SHA256.hash(data: Data(verifier.utf8))
        return base64URL(Data(hashed))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Minimal JWT payload decode — we only need the middle segment, and we
    /// don't need to verify the signature since this token never leaves the
    /// device or gets used to authorize anything server-side.
    private static func decodeJWTPayload(_ jwt: String) -> [String: Any]? {
        let segments = jwt.split(separator: ".")
        guard segments.count > 1 else { return nil }
        var base64 = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}

extension AuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }
}
