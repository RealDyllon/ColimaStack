import Foundation

nonisolated protocol DockerResourceProviding {
    func loadSnapshot(socketPath: String) async -> ResourceLoadState<DockerResourceSnapshot>
    func snapshot(socketPath: String) async throws -> DockerResourceSnapshot
}
