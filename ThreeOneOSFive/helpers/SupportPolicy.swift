import Foundation

enum ExploitSupportPolicy {
    // Display strings shown in Settings / Onboarding
    static let verifiedIOS15Range = "15.0–15.x"
    static let verifiedIOS16Range = "16.0–16.x"
    static let verifiedIOS17Range = "17.0–17.x"
    static let verifiedIOS18Range = "18.0–18.x"
    static let verifiedIOS26Range = "26.0–26.x"

    /// iOS 27 beta builds — kept for display purposes only.
    /// All iOS 27 builds are now accepted regardless of specific build string.
    static let verifiedIOS27Builds: [(beta: Int, publicBeta: Int?, build: String)] = [
        (1,  nil, "24A5355q"),
        (2,  nil, "24A5370h"),
        (3,  1,   "24A5380h"),
        (4,  2,   "24A5390f")
    ]

    static func iOS27BetaNumber(for build: String) -> Int? {
        verifiedIOS27Builds.first { $0.build == build }?.beta
    }

    static func iOS27PublicBetaNumber(for build: String) -> Int? {
        verifiedIOS27Builds.first { $0.build == build }?.publicBeta
    }

    /// Returns true if the kernel exploit path is available for this version.
    /// Covers iOS 15–18 (all minor/patch) and iOS 26+ (including 26.x, 27, 27.x and beyond).
    static func supportsKernelExploit(major: Int, minor: Int, patch: Int) -> Bool {
        guard minor >= 0, patch >= 0 else { return false }
        // iOS 15, 16, 17, 18 — kernel R/W exploit path
        if major >= 15 && major <= 18 { return true }
        // iOS 26 and above (26.x, 27, 27.x, 28…) — sandbox escape + bad_query path
        if major >= 26 { return true }
        return false
    }

    /// Master gate: accept iOS 15 through 27+ (any build).
    static func isSupported(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        guard major >= 15 else { return false }
        // iOS 15, 16, 17, 18 — all versions supported
        if major >= 15 && major <= 18 { return true }
        // iOS 19–25 bridging (future-proof)
        if major >= 19 && major <= 25 { return true }
        // iOS 26 — all minor/patch
        if major == 26 { return true }
        // iOS 27 and beyond (beta or release) — all supported
        if major >= 27 { return true }
        return false
    }
}
