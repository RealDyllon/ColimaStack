import Foundation

protocol ColimaOutputParsing {
    func parseList(_ output: String) throws -> [ColimaProfile]
    func parseStatus(_ output: String, profile: String) throws -> ColimaStatusDetail
}

enum ColimaOutputParserError: LocalizedError, Equatable {
    case malformedListRow(String)
    case unsafeProfileName(String)

    var errorDescription: String? {
        switch self {
        case let .malformedListRow(row):
            return "Unable to parse Colima list row: \(row)"
        case let .unsafeProfileName(name):
            return "Colima reported an unsafe profile name: \(name)"
        }
    }
}

extension ProfileState {
    static func inferred(from raw: String?) -> ProfileState {
        let lower = raw?.lowercased() ?? ""
        if lower.contains("stopped") || lower.contains("not") { return .stopped }
        if lower.contains("degraded") { return .degraded }
        if lower.contains("starting") { return .starting }
        if lower.contains("stopping") { return .stopping }
        if lower.contains("broken") { return .broken }
        if lower.contains("running") { return .running }
        return .unknown
    }
}

struct ColimaOutputParser: ColimaOutputParsing {
    func parseList(_ output: String) throws -> [ColimaProfile] {
        let jsonProfiles = try parseJSONList(output)
        if !jsonProfiles.isEmpty { return jsonProfiles }

        let lines = output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !isColimaLogLine($0) }
        guard let header = lines.first else { return [] }
        let headers = splitColumns(header).map { $0.lowercased() }
        return try lines.dropFirst().map { line in
            guard let profile = try parseListLine(line, headers: headers) else {
                throw ColimaOutputParserError.malformedListRow(line)
            }
            return profile
        }
    }

    func parseStatus(_ output: String, profile: String) throws -> ColimaStatusDetail {
        if let jsonStatus = try parseJSONStatus(output, profile: profile) {
            return jsonStatus
        }

        let normalized = output.replacingOccurrences(of: "INFO[0000]", with: "")
        let lower = normalized.lowercased()
        let state: ProfileState
        if lower.contains("stopped") || lower.contains("not running") {
            state = .stopped
        } else if lower.contains("degraded") {
            state = .degraded
        } else if lower.contains("running") {
            state = .running
        } else {
            state = .unknown
        }
        let keyValues = parseKeyValues(normalized)
        let resources = ResourceAllocation(
            cpu: Int(digits(in: keyValues["cpu"] ?? keyValues["cpus"] ?? "")) ?? 0,
            memoryGiB: parseGiB(keyValues["memory"] ?? ""),
            diskGiB: parseGiB(keyValues["disk"] ?? "")
        )
        let dockerContext = profile == "default" ? "colima" : "colima-\(profile)"
        let kubernetesEnabled = parseBooleanish(keyValues["kubernetes"])
        return ColimaStatusDetail(
            profileName: profile,
            state: state,
            runtime: parseRuntime(keyValues["runtime"]),
            architecture: parseArchitecture(keyValues["arch"] ?? keyValues["architecture"]),
            vmType: parseVMType(keyValues["driver"] ?? keyValues["vmtype"]),
            mountType: parseMountType(keyValues["mounttype"]),
            resources: resources.cpu == 0 && resources.memoryGiB == 0 && resources.diskGiB == 0 ? nil : resources,
            kubernetes: KubernetesConfig(enabled: kubernetesEnabled ?? false, version: keyValues["kubernetesversion"] ?? "", context: dockerContext),
            networkAddress: keyValues["address"] ?? keyValues["ipaddress"] ?? "",
            socket: keyValues["dockersocket"] ?? keyValues["containerdsocket"] ?? keyValues["incussocket"] ?? keyValues["socket"] ?? "",
            dockerContext: dockerContext,
            errors: normalized.components(separatedBy: .newlines).filter { $0.lowercased().contains("error") || $0.lowercased().contains("fatal") },
            rawOutput: output
        )
    }

    private func parseJSONList(_ output: String) throws -> [ColimaProfile] {
        let decoder = JSONDecoder()
        let lines = output.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if output.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[") {
            return try decoder.decode([ColimaListJSON].self, from: Data(output.utf8)).map { try $0.profile }
        }
        return try lines.filter { $0.hasPrefix("{") }.map { try decoder.decode(ColimaListJSON.self, from: Data($0.utf8)).profile }
    }

    private func parseJSONStatus(_ output: String, profile: String) throws -> ColimaStatusDetail? {
        guard let payload = jsonObjectPayload(in: output) else { return nil }
        return try JSONDecoder().decode(ColimaStatusJSON.self, from: Data(payload.utf8)).detail(profile: profile, rawOutput: output)
    }

    private func jsonObjectPayload(in output: String) -> String? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}"), start <= end else {
            return nil
        }
        return String(trimmed[start...end])
    }

    private func parseListLine(_ line: String, headers: [String]) throws -> ColimaProfile? {
        let columns = splitColumns(line)
        guard !columns.isEmpty else { return nil }
        func value(_ aliases: [String], fallback: Int? = nil) -> String {
            for alias in aliases {
                if let index = headers.firstIndex(where: { $0 == alias || $0.contains(alias) }), index < columns.count {
                    return columns[index]
                }
            }
            if let fallback, fallback < columns.count { return columns[fallback] }
            return ""
        }
        let name = value(["profile", "name"], fallback: 0)
        guard !name.isEmpty else { return nil }
        guard ProfileNameValidator.isValid(name) else {
            throw ColimaOutputParserError.unsafeProfileName(name)
        }
        let resources = ResourceAllocation(cpu: Int(value(["cpu", "cpus"])) ?? 0, memoryGiB: parseGiB(value(["memory", "mem"])), diskGiB: parseGiB(value(["disk"])))
        return ColimaProfile(
            name: name,
            state: parseState(value(["status", "state"], fallback: 1)),
            runtime: parseRuntime(value(["runtime"])),
            architecture: parseArchitecture(value(["arch", "architecture"])),
            resources: resources.cpu == 0 && resources.memoryGiB == 0 && resources.diskGiB == 0 ? nil : resources,
            diskUsage: value(["disk"]),
            ipAddress: value(["address", "ip"]),
            dockerContext: name == "default" ? "colima" : "colima-\(name)",
            kubernetes: parseKubernetes(fromRuntime: value(["runtime"]), profile: name),
            vmType: nil,
            mountType: nil,
            socket: "",
            rawSummary: line
        )
    }

    private func splitColumns(_ line: String) -> [String] {
        line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
    }

    private func isColimaLogLine(_ line: String) -> Bool {
        ["INFO[", "WARN[", "ERRO[", "FATA["].contains { line.hasPrefix($0) }
    }

    private func parseKeyValues(_ output: String) -> [String: String] {
        var values: [String: String] = [:]
        for line in output.components(separatedBy: .newlines) {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let key = canonicalKey(String(line[..<separator]))
            let value = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            values[key] = value
        }
        return values
    }

    private func canonicalKey(_ key: String) -> String {
        key.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func parseState(_ value: String) -> ProfileState {
        ProfileState.inferred(from: value)
    }

    private func parseRuntime(_ value: String?) -> ColimaRuntime? {
        guard let value else { return nil }
        return ColimaRuntime.allCases.first { value.lowercased().contains($0.rawValue) }
    }

    private func parseArchitecture(_ value: String?) -> CPUArchitecture? {
        guard let value else { return nil }
        return CPUArchitecture.allCases.first { value.lowercased().contains($0.rawValue.lowercased()) }
    }

    private func parseVMType(_ value: String?) -> VMType? {
        guard let value else { return nil }
        return VMType.allCases.first { value.lowercased().contains($0.rawValue) || value.lowercased().contains($0.label.lowercased()) }
    }

    private func parseMountType(_ value: String?) -> MountType? {
        guard let value else { return nil }
        return MountType.allCases.first { value.lowercased().contains($0.rawValue.lowercased()) }
    }

    private func parseGiB(_ value: String) -> Int {
        ResourceQuantityParser.gib(value)
    }

    private func digits(in value: String) -> String {
        value.filter(\.isNumber)
    }

    private func parseBooleanish(_ value: String?) -> Bool? {
        guard let value else { return nil }
        let lower = value.lowercased()
        if lower.contains("false") || lower.contains("disabled") || lower.contains("stopped") || lower == "no" {
            return false
        }
        if lower.contains("true") || lower.contains("enabled") || lower.contains("running") || lower == "yes" {
            return true
        }
        return nil
    }

    private func parseKubernetes(fromRuntime runtime: String, profile: String) -> KubernetesConfig {
        let enabled = runtime.lowercased().contains("k3s")
        return KubernetesConfig(enabled: enabled, version: "", context: profile == "default" ? "colima" : "colima-\(profile)")
    }
}

private struct ColimaListJSON: Decodable {
    var name: String
    var status: String?
    var arch: String?
    var cpus: Int?
    var memory: Int?
    var disk: Int?
    var address: String?
    var runtime: String?

    var profile: ColimaProfile {
        get throws {
            guard ProfileNameValidator.isValid(name) else {
                throw ColimaOutputParserError.unsafeProfileName(name)
            }
        let parsedRuntime = runtime.flatMap { value in ColimaRuntime.allCases.first { value.lowercased().contains($0.rawValue) } }
        return ColimaProfile(
            name: name,
            state: Self.state(status),
            runtime: parsedRuntime,
            architecture: arch.flatMap { CPUArchitecture(rawValue: $0) },
            resources: ResourceAllocation(cpu: cpus ?? 0, memoryGiB: bytesToGiB(memory), diskGiB: bytesToGiB(disk)),
            diskUsage: disk.map { "\(bytesToGiB($0)) GiB" } ?? "",
            ipAddress: address ?? "",
            dockerContext: name == "default" ? "colima" : "colima-\(name)",
            kubernetes: Self.kubernetes(runtime: runtime, profile: name),
            vmType: nil,
            mountType: nil,
            socket: "",
            rawSummary: ""
        )
        }
    }

    private static func state(_ value: String?) -> ProfileState {
        ProfileState.inferred(from: value)
    }

    private static func kubernetes(runtime: String?, profile: String) -> KubernetesConfig {
        let enabled = runtime?.lowercased().contains("k3s") == true
        return KubernetesConfig(enabled: enabled, version: "", context: profile == "default" ? "colima" : "colima-\(profile)")
    }
}

private struct ColimaStatusJSON: Decodable {
    var displayName: String?
    var driver: String?
    var arch: String?
    var runtime: String?
    var mountType: String?
    var ipAddress: String?
    var dockerSocket: String?
    var containerdSocket: String?
    var buildkitdSocket: String?
    var incusSocket: String?
    var kubernetes: Bool?
    var cpu: Int?
    var memory: Int?
    var disk: Int?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case driver, arch, runtime, kubernetes, cpu, memory, disk
        case mountType = "mount_type"
        case ipAddress = "ip_address"
        case dockerSocket = "docker_socket"
        case containerdSocket = "containerd_socket"
        case buildkitdSocket = "buildkitd_socket"
        case incusSocket = "incus_socket"
    }

    func detail(profile: String, rawOutput: String) -> ColimaStatusDetail {
        let socket = dockerSocket ?? containerdSocket ?? incusSocket ?? buildkitdSocket ?? ""
        return ColimaStatusDetail(
            profileName: displayName ?? profile,
            // Colima only emits status JSON for a running VM; non-running states come from the command failure/plain-text path.
            state: .running,
            runtime: runtime.flatMap { value in ColimaRuntime.allCases.first { value.lowercased().contains($0.rawValue) } },
            architecture: arch.flatMap { CPUArchitecture(rawValue: $0) },
            vmType: driver.flatMap { value in VMType.allCases.first { value.lowercased().contains($0.rawValue) || value.lowercased().contains($0.label.lowercased()) } },
            mountType: mountType.flatMap { MountType(rawValue: $0) },
            resources: ResourceAllocation(cpu: cpu ?? 0, memoryGiB: bytesToGiB(memory), diskGiB: bytesToGiB(disk)),
            kubernetes: KubernetesConfig(enabled: kubernetes ?? false, version: "", context: profile == "default" ? "colima" : "colima-\(profile)"),
            networkAddress: ipAddress ?? "",
            socket: socket,
            dockerContext: profile == "default" ? "colima" : "colima-\(profile)",
            errors: [],
            rawOutput: rawOutput
        )
    }
}

private func bytesToGiB(_ bytes: Int?) -> Int {
    guard let bytes else { return 0 }
    if bytes < 1024 * 1024 { return bytes }
    return max(1, Int((Double(bytes) / 1_073_741_824.0).rounded()))
}
