// Build-time check of src/Strings.swift: every key has one entry per language with the same format specifiers.
import Foundation

let spec = try! NSRegularExpression(pattern: "%l?[@d]")
func specs(_ s: String) -> [String] {
    spec.matches(in: s, range: NSRange(s.startIndex..., in: s)).map { String(s[Range($0.range, in: s)!]) }
}
var problems = 0
for k in K.allCases {
    guard let row = T[k] else { print("missing key \(k)"); problems += 1; continue }
    if row.count != Lang.allCases.count { print("\(k): \(row.count) entries, need \(Lang.allCases.count)"); problems += 1; continue }
    for (i, s) in row.enumerated() where s.isEmpty || specs(s) != specs(row[0]) {
        print("\(k) [\(Lang.allCases[i].rawValue)]: empty or format differs: \(s)"); problems += 1
    }
}
if problems > 0 { print("Strings check failed: \(problems) problem(s)"); exit(1) }
