// Build-time check of src/Strings.swift: every language has every key, non-empty,
// with the same format specifiers as Russian.
import Foundation

let spec = try! NSRegularExpression(pattern: "%l?[@d]")
func specs(_ s: String) -> [String] {
    spec.matches(in: s, range: NSRange(s.startIndex..., in: s)).map { String(s[Range($0.range, in: s)!]) }
}
var problems = 0
for l in Lang.allCases {
    guard let table = T[l] else { print("missing language \(l)"); problems += 1; continue }
    for k in K.allCases {
        guard let s = table[k], !s.isEmpty else { print("\(l): missing \(k)"); problems += 1; continue }
        guard let ref = T[.ru]?[k] else { continue }  // missing Russian is reported in the .ru pass
        if specs(s) != specs(ref) { print("\(l).\(k): format differs: \(s)"); problems += 1 }
        // In strings passed to String(format:), every % must start a known specifier.
        if !specs(ref).isEmpty, s.components(separatedBy: "%").count - 1 != specs(s).count {
            print("\(l).\(k): stray %: \(s)"); problems += 1
        }
    }
}
if problems > 0 { print("Strings check failed: \(problems) problem(s)"); exit(1) }
