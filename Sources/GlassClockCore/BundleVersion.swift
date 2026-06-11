import Foundation

/// Dotted version-string comparison for the self-installer's upgrade check.
public enum BundleVersion {
    /// True when `a` is strictly older than `b`, comparing dot-separated
    /// components numerically ("1.9" is older than "1.10"). Missing or
    /// malformed components count as zero.
    public static func isVersion(_ a: String, olderThan b: String) -> Bool {
        let lhs = a.split(separator: ".").map { Int($0) ?? 0 }
        let rhs = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(lhs.count, rhs.count) {
            let x = i < lhs.count ? lhs[i] : 0
            let y = i < rhs.count ? rhs[i] : 0
            if x != y { return x < y }
        }
        return false
    }
}
