import Foundation

enum JSONCommandParser {
    struct JSONLinesParseResult {
        var objects: [[String: Any]]
        var malformedLineNumbers: [Int]
    }

    static func objects(fromJSONLines output: String) -> [[String: Any]] {
        parseJSONLines(output).objects
    }

    static func parseJSONLines(_ output: String) -> JSONLinesParseResult {
        output
            .components(separatedBy: .newlines)
            .enumerated()
            .reduce(into: JSONLinesParseResult(objects: [], malformedLineNumbers: [])) { result, line in
                let trimmed = line.element.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                guard let object = object(trimmed) else {
                    result.malformedLineNumbers.append(line.offset + 1)
                    return
                }
                result.objects.append(object)
            }
    }

    static func object(from output: String) -> [String: Any]? {
        guard let data = output.data(using: .utf8),
              let value = try? JSONSerialization.jsonObject(with: data),
              let object = value as? [String: Any] else {
            return nil
        }
        return object
    }

    static func object(_ line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8),
              let value = try? JSONSerialization.jsonObject(with: data),
              let object = value as? [String: Any] else {
            return nil
        }
        return object
    }
}

extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

extension Optional where Wrapped == String {
    var nonEmpty: String? {
        switch self?.trimmingCharacters(in: .whitespacesAndNewlines) {
        case .some(let value) where !value.isEmpty:
            value
        default:
            nil
        }
    }
}

enum ResourceQuantityParser {
    static func numericPrefix(_ value: String) -> Double {
        let allowed = Set("0123456789.,")
        let prefix = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix { allowed.contains($0) }
            .replacingOccurrences(of: ",", with: "")
        return Double(prefix) ?? 0
    }

    static func bytes(_ value: String) -> Double {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let number = numericPrefix(trimmed)
        let unit = trimmed
            .drop { Set("0123456789., ").contains($0) }
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch unit {
        case "b", "byte", "bytes", "":
            return number
        case "kb":
            return number * 1_000
        case "mb":
            return number * 1_000_000
        case "gb":
            return number * 1_000_000_000
        case "tb":
            return number * 1_000_000_000_000
        case "kib":
            return number * 1_024
        case "mib":
            return number * 1_048_576
        case "gib":
            return number * 1_073_741_824
        case "tib":
            return number * 1_099_511_627_776
        default:
            return number
        }
    }

    static func bytePair(_ value: String) -> (first: Double, second: Double) {
        let parts = value.split(separator: "/", maxSplits: 1).map(String.init)
        return (bytes(parts.first ?? ""), bytes(parts.dropFirst().first ?? ""))
    }
}

extension Dictionary where Key == String, Value == Any {
    func string(_ keys: String...) -> String {
        for key in keys {
            if let value = self[key] as? String {
                return value
            }
            if let value = self[key] {
                return String(describing: value)
            }
        }
        return ""
    }

    func int(_ keys: String...) -> Int {
        for key in keys {
            if let value = self[key] as? Int {
                return value
            }
            if let value = self[key] as? NSNumber {
                return value.intValue
            }
            if let value = self[key] as? String, let integer = Int(value) {
                return integer
            }
        }
        return 0
    }

    func bool(_ keys: String...) -> Bool {
        for key in keys {
            if let value = self[key] as? Bool {
                return value
            }
            if let value = self[key] as? NSNumber {
                return value.boolValue
            }
            if let value = self[key] as? String {
                return ["true", "yes", "1"].contains(value.lowercased())
            }
        }
        return false
    }

    func dictionary(_ key: String) -> [String: Any] {
        self[key] as? [String: Any] ?? [:]
    }

    func dictionaries(_ key: String) -> [[String: Any]] {
        self[key] as? [[String: Any]] ?? []
    }

    func stringArray(_ key: String) -> [String] {
        if let array = self[key] as? [String] {
            return array
        }
        if let array = self[key] as? [Any] {
            return array.map { String(describing: $0) }
        }
        return []
    }

    func labels(_ key: String) -> [String: String] {
        if let dictionary = self[key] as? [String: String] {
            return dictionary
        }
        if let dictionary = self[key] as? [String: Any] {
            return dictionary.mapValues { String(describing: $0) }
        }
        let raw = string(key)
        guard !raw.isEmpty else { return [:] }
        return raw
            .split(separator: ",")
            .reduce(into: [String: String]()) { result, pair in
                let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
                guard let key = parts.first, !key.isEmpty else { return }
                result[key] = parts.dropFirst().first ?? ""
            }
    }
}
