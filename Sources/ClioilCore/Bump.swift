import Foundation

/// A semver bump level chosen before publishing.
public enum Bump: String, Sendable, CaseIterable {
    case none, patch, minor, major

    /// Apply the bump to a clean `x.y.z` string. Pre-release/build suffixes are
    /// dropped (the bump resets them), matching `npm version` behaviour closely
    /// enough for the preview shown to the user before the real tool runs.
    public func apply(to version: String) -> String {
        let core = version.split(separator: "-", maxSplits: 1).first.map(String.init) ?? version
        var parts = core.split(separator: ".").map { Int($0) ?? 0 }
        while parts.count < 3 { parts.append(0) }
        switch self {
        case .none:  return version
        case .patch: parts[2] += 1
        case .minor: parts[1] += 1; parts[2] = 0
        case .major: parts[0] += 1; parts[1] = 0; parts[2] = 0
        }
        return parts.map(String.init).joined(separator: ".")
    }
}
