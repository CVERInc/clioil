import Foundation

/// A deliberately tiny TOML reader: enough to pull simple string scalars from a
/// named top-level table (`[package]`, `[project]`). NOT a general TOML parser —
/// it handles the `key = "value"` / `key = value` forms that appear in a crate
/// or PEP 621 manifest's header table, which is all the scanner needs. Anything
/// fancier (arrays of tables, inline tables, multi-line strings) is ignored,
/// which is safe: a value we can't read simply degrades to "absent".
public enum TOMLLite {
    /// Return the simple key→value pairs inside `[<name>]`, up to the next table
    /// header. Values keep their unquoted string form (quotes/trailing comments
    /// stripped). Booleans/numbers come back as their literal text (`"false"`,
    /// `"1.2.3"`).
    public static func table(_ name: String, in text: String) -> [String: String] {
        var out: [String: String] = [:]
        var inTable = false
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = trimComment(String(rawLine)).trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") {
                // A table header. `[name]` enters our table; any other header exits.
                let header = line.dropFirst().drop(while: { $0 == "[" })
                    .prefix(while: { $0 != "]" })
                inTable = (String(header).trimmingCharacters(in: .whitespaces) == name)
                continue
            }
            guard inTable, let eq = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
            let value = unquote(String(line[line.index(after: eq)...])
                .trimmingCharacters(in: .whitespaces))
            if !key.isEmpty { out[key] = value }
        }
        return out
    }

    /// Strip a trailing `# comment`, but not a `#` inside a quoted string.
    private static func trimComment(_ s: String) -> String {
        var inString = false
        var quote: Character = "\""
        var idx = s.startIndex
        while idx < s.endIndex {
            let c = s[idx]
            if inString {
                if c == quote { inString = false }
            } else if c == "\"" || c == "'" {
                inString = true; quote = c
            } else if c == "#" {
                return String(s[..<idx])
            }
            idx = s.index(after: idx)
        }
        return s
    }

    /// Remove surrounding matching quotes from a scalar; leave bare values as-is.
    private static func unquote(_ s: String) -> String {
        if s.count >= 2, let f = s.first, let l = s.last, f == l, f == "\"" || f == "'" {
            return String(s.dropFirst().dropLast())
        }
        return s
    }
}

/// Pulls a single `key="value"` keyword argument out of a `setup(...)` call in a
/// legacy setup.py. Shallow on purpose — recognises the common literal form
/// (`name="foo"`, `version='1.2.3'`), not arbitrary Python expressions. When the
/// value isn't a plain string literal, returns nil so the caller degrades rather
/// than guessing.
public enum PySetupLite {
    public static func kwarg(_ key: String, in text: String) -> String? {
        // Match: <key> = "value" | 'value'  (with optional whitespace around =).
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: key))\\s*=\\s*([\"'])(.*?)\\1"
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let m = re.firstMatch(in: text, range: range),
              let r = Range(m.range(at: 2), in: text) else { return nil }
        let value = String(text[r])
        return value.isEmpty ? nil : value
    }
}
