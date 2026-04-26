import Foundation

enum ToolLocatorError: LocalizedError, Sendable {
    case toolNotFound(name: String, searchPaths: [String])

    var errorDescription: String? {
        switch self {
        case let .toolNotFound(name, searchPaths):
            return "Required tool '\(name)' was not found in PATH (\(searchPaths.joined(separator: ":")))"
        }
    }
}

nonisolated protocol ToolLocator {
    func locate(_ toolName: String) -> URL?
    func require(_ toolName: String) throws -> URL
    func searchPaths() -> [String]
}

nonisolated struct LiveToolLocator: ToolLocator {
    private let fileManager: FileManager
    private let searchPathCache: [String]

    init(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fallbackSearchPaths: [String] = Self.defaultFallbackSearchPaths
    ) {
        self.fileManager = fileManager
        let environmentPaths = environment["PATH"]?
            .split(separator: ":")
            .map(String.init)
            .filter { !$0.isEmpty } ?? []
        self.searchPathCache = Self.uniquePaths(environmentPaths + fallbackSearchPaths)
    }

    func locate(_ toolName: String) -> URL? {
        if toolName.hasPrefix("/") {
            return fileManager.isExecutableFile(atPath: toolName) ? URL(fileURLWithPath: toolName) : nil
        }

        for path in searchPaths() {
            let candidate = URL(fileURLWithPath: path).appendingPathComponent(toolName)
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    func require(_ toolName: String) throws -> URL {
        if let url = locate(toolName) {
            return url
        }
        throw ToolLocatorError.toolNotFound(name: toolName, searchPaths: searchPaths())
    }

    func searchPaths() -> [String] {
        searchPathCache
    }

    private static func uniquePaths(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        return paths.filter { path in
            seen.insert(path).inserted
        }
    }
}

private extension LiveToolLocator {
    nonisolated static let defaultFallbackSearchPaths = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/opt/local/bin",
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin"
    ]
}
