import Foundation

nonisolated enum ColimaRuntime: String, CaseIterable, Codable, Sendable, Identifiable {
    case docker
    case containerd
    case incus
    case none
    case unknown

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    nonisolated init(cliValue: String) {
        switch cliValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "docker":
            self = .docker
        case "containerd":
            self = .containerd
        case "incus":
            self = .incus
        case "", "none", "-", "n/a":
            self = .none
        default:
            self = .unknown
        }
    }
}

nonisolated enum ProfileState: String, CaseIterable, Codable, Sendable {
    case running
    case stopped
    case degraded
    case starting
    case stopping
    case broken
    case unknown

    var label: String {
        switch self {
        case .running: "Running"
        case .stopped: "Stopped"
        case .degraded: "Degraded"
        case .starting: "Starting"
        case .stopping: "Stopping"
        case .broken: "Broken"
        case .unknown: "Unknown"
        }
    }
}

nonisolated enum CPUArchitecture: String, CaseIterable, Codable, Sendable, Identifiable {
    case host
    case aarch64
    case x86_64

    var id: String { rawValue }
    var label: String {
        switch self {
        case .host: "Host Default"
        case .aarch64: "Apple Silicon"
        case .x86_64: "Intel"
        }
    }
}

nonisolated enum VMType: String, CaseIterable, Codable, Sendable, Identifiable {
    case qemu
    case vz
    case krunkit

    var id: String { rawValue }

    var label: String {
        switch self {
        case .qemu:
            return "QEMU"
        case .vz:
            return "Virtualization.framework"
        case .krunkit:
            return "Krunkit"
        }
    }
}

nonisolated enum MountType: String, CaseIterable, Codable, Sendable, Identifiable {
    case virtiofs
    case sshfs
    case nineP = "9p"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .virtiofs: "VirtioFS"
        case .sshfs: "SSHFS"
        case .nineP: "9p"
        }
    }
}

nonisolated enum PortForwarder: String, CaseIterable, Codable, Sendable, Identifiable {
    case ssh
    case grpc
    case none

    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
}

nonisolated struct ResourceAllocation: Hashable, Codable, Sendable {
    var cpu: Int
    var memoryGiB: Int
    var diskGiB: Int

    static let standard = ResourceAllocation(cpu: 2, memoryGiB: 4, diskGiB: 60)
}

nonisolated struct KubernetesConfig: Hashable, Codable, Sendable {
    var enabled: Bool
    var version: String
    var context: String

    static let disabled = KubernetesConfig(enabled: false, version: "", context: "")
}

nonisolated struct ColimaMount: Identifiable, Hashable, Codable, Sendable {
    var id: String { cliValue }
    var location: String
    var mountPoint: String?
    var writable: Bool?
    var cliValue: String

    init(location: String, mountPoint: String? = nil, writable: Bool? = nil, cliValue: String? = nil) {
        self.location = location
        self.mountPoint = mountPoint
        self.writable = writable
        self.cliValue = cliValue ?? location
    }
}

nonisolated struct ColimaNetworking: Hashable, Codable, Sendable {
    var address: String
    var socket: String
    var dockerContext: String
    var dnsServers: [String]
    var portForwarder: String?

    init(
        address: String = "",
        socket: String = "",
        dockerContext: String = "",
        dnsServers: [String] = [],
        portForwarder: String? = nil
    ) {
        self.address = address
        self.socket = socket
        self.dockerContext = dockerContext
        self.dnsServers = dnsServers
        self.portForwarder = portForwarder
    }
}

nonisolated struct ColimaConfigurationPaths: Hashable, Codable, Sendable {
    var homeDirectory: URL
    var profileConfiguration: URL
    var template: URL
    var sshConfiguration: URL
    var limaOverride: URL
}

nonisolated enum ColimaDocumentKind: String, CaseIterable, Codable, Sendable {
    case template
    case profileConfiguration
    case sshConfiguration
    case limaOverride
    case logs
}

nonisolated struct ColimaDocument: Identifiable, Hashable, Codable, Sendable {
    var id: String { url.path }
    var kind: ColimaDocumentKind
    var profileName: String?
    var url: URL
    var contents: String
    var lastModified: Date?
}

nonisolated enum ToolAvailability: Hashable, Sendable {
    case available(path: String, version: String?)
    case missing
    case error(String)
}

nonisolated struct ToolCheck: Identifiable, Hashable, Sendable {
    var id: String
    var name: String { id }
    var availability: ToolAvailability
}

nonisolated struct DockerStatus: Hashable, Sendable {
    var available: Bool
    var context: String
    var version: String
    var error: String
}

nonisolated struct ColimaRuntimeStatus: Hashable, Sendable {
    var profileName: String
    var state: ProfileState
    var runtime: ColimaRuntime?
    var output: String
    var error: String

    init(profileName: String, state: ProfileState, runtime: ColimaRuntime? = nil, output: String, error: String) {
        self.profileName = profileName
        self.state = state
        self.runtime = runtime
        self.output = output
        self.error = error
    }
}

nonisolated struct DiagnosticReport: Hashable, Sendable {
    var tools: [ToolCheck]
    var colima: ColimaRuntimeStatus
    var docker: DockerStatus
    var messages: [String]

    static let empty = DiagnosticReport(
        tools: [],
        colima: ColimaRuntimeStatus(profileName: "default", state: .unknown, output: "", error: ""),
        docker: DockerStatus(available: false, context: "", version: "", error: ""),
        messages: []
    )
}

nonisolated struct ColimaDiagnostics: Hashable, Codable, Sendable {
    var rawListOutput: String?
    var rawStatusOutput: String?
    var rawKubernetesOutput: String?
    var warnings: [String]
    var errors: [String]
}

nonisolated struct ColimaStatusDetail: Hashable, Codable, Sendable {
    var profileName: String
    var state: ProfileState
    var runtime: ColimaRuntime?
    var architecture: CPUArchitecture?
    var vmType: VMType?
    var mountType: MountType?
    var resources: ResourceAllocation?
    var kubernetes: KubernetesConfig
    var networkAddress: String
    var socket: String
    var dockerContext: String
    var errors: [String]
    var rawOutput: String
}

nonisolated struct ColimaProfile: Identifiable, Hashable, Codable, Sendable {
    var id: String { name }
    var name: String
    var state: ProfileState
    var runtime: ColimaRuntime?
    var architecture: CPUArchitecture?
    var resources: ResourceAllocation?
    var diskUsage: String
    var ipAddress: String
    var dockerContext: String
    var kubernetes: KubernetesConfig
    var vmType: VMType?
    var mountType: MountType?
    var socket: String
    var rawSummary: String
    var configurationPaths: ColimaConfigurationPaths
    var mounts: [ColimaMount]
    var diagnostics: ColimaDiagnostics

    init(
        name: String,
        state: ProfileState,
        runtime: ColimaRuntime?,
        architecture: CPUArchitecture?,
        resources: ResourceAllocation?,
        diskUsage: String,
        ipAddress: String,
        dockerContext: String,
        kubernetes: KubernetesConfig,
        vmType: VMType?,
        mountType: MountType?,
        socket: String,
        rawSummary: String,
        configurationPaths: ColimaConfigurationPaths = .default(for: "default"),
        mounts: [ColimaMount] = [],
        diagnostics: ColimaDiagnostics = .init(rawListOutput: nil, rawStatusOutput: nil, rawKubernetesOutput: nil, warnings: [], errors: [])
    ) {
        self.name = name
        self.state = state
        self.runtime = runtime
        self.architecture = architecture
        self.resources = resources
        self.diskUsage = diskUsage
        self.ipAddress = ipAddress
        self.dockerContext = dockerContext
        self.kubernetes = kubernetes
        self.vmType = vmType
        self.mountType = mountType
        self.socket = socket
        self.rawSummary = rawSummary
        self.configurationPaths = configurationPaths
        self.mounts = mounts
        self.diagnostics = diagnostics
    }

    var statusDetail: ColimaStatusDetail {
        ColimaStatusDetail(
            profileName: name,
            state: state,
            runtime: runtime,
            architecture: architecture,
            vmType: vmType,
            mountType: mountType,
            resources: resources,
            kubernetes: kubernetes,
            networkAddress: ipAddress,
            socket: socket,
            dockerContext: dockerContext,
            errors: diagnostics.errors,
            rawOutput: diagnostics.rawStatusOutput ?? rawSummary
        )
    }
}

nonisolated struct CommandLogEntry: Identifiable, Hashable, Sendable {
    nonisolated enum Status: Hashable, Sendable {
        case running
        case succeeded
        case failed(String)
    }

    var id: UUID = UUID()
    var date: Date
    var command: String
    var status: Status
    var output: String
}

nonisolated struct ColimaCommandLogEntry: Identifiable, Hashable, Codable, Sendable, CombinedProcessOutput {
    var id: UUID
    var executablePath: String
    var arguments: [String]
    var environmentOverrides: [String: String]
    var launchedAt: Date
    var duration: TimeInterval
    var terminationStatus: Int32
    var standardOutput: String
    var standardError: String

    init(
        id: UUID = UUID(),
        executablePath: String,
        arguments: [String],
        environmentOverrides: [String: String] = [:],
        launchedAt: Date,
        duration: TimeInterval,
        terminationStatus: Int32,
        standardOutput: String,
        standardError: String
    ) {
        self.id = id
        self.executablePath = executablePath
        self.arguments = arguments
        self.environmentOverrides = environmentOverrides
        self.launchedAt = launchedAt
        self.duration = duration
        self.terminationStatus = terminationStatus
        self.standardOutput = standardOutput
        self.standardError = standardError
    }

    var commandString: String {
        ([executablePath] + arguments).joined(separator: " ")
    }

}

nonisolated struct ColimaCommandLog: Hashable, Codable, Sendable {
    var profileName: String
    var collectedAt: Date
    var contents: String
    var entry: ColimaCommandLogEntry
}

nonisolated struct ProfileConfiguration: Hashable, Codable, Sendable {
    var name: String
    var resources: ResourceAllocation
    var runtime: ColimaRuntime
    var vmType: VMType
    var architecture: CPUArchitecture
    var mountType: MountType
    var mounts: [MountConfiguration]
    var kubernetes: KubernetesConfig
    var network: NetworkConfiguration
    var rosetta: Bool
    var nestedVirtualization: Bool
    var portForwarder: PortForwarder
    var k3sArgs: [String]
    var k3sListenPort: Int?
    var additionalArgs: [String]

    static let `default` = ProfileConfiguration(
        name: "default",
        resources: .standard,
        runtime: .docker,
        vmType: .qemu,
        architecture: .host,
        mountType: .sshfs,
        mounts: [],
        kubernetes: .disabled,
        network: .standard,
        rosetta: false,
        nestedVirtualization: false,
        portForwarder: .ssh,
        k3sArgs: [],
        k3sListenPort: nil,
        additionalArgs: []
    )

    nonisolated var validationErrors: [String] {
        var errors: [String] = []
        if let profileNameError = ProfileNameValidator.validationError(for: name) {
            errors.append(profileNameError)
        }
        if resources.cpu < 1 {
            errors.append("CPU must be at least 1.")
        }
        if resources.memoryGiB < 1 {
            errors.append("Memory must be at least 1 GiB.")
        }
        if resources.diskGiB < 1 {
            errors.append("Disk must be at least 1 GiB.")
        }
        if kubernetes.enabled, let k3sListenPort, !(1...65_535).contains(k3sListenPort) {
            errors.append("K3s listen port must be between 1 and 65535.")
        }
        if network.mode == "bridged", network.interface.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Bridged networking requires an interface.")
        }
        if rosetta, vmType != .vz {
            errors.append("Rosetta requires the Virtualization.framework VM type.")
        }
        if nestedVirtualization, vmType != .vz {
            errors.append("Nested virtualization requires the Virtualization.framework VM type.")
        }
        for resolver in network.dnsResolvers where !resolver.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !Self.isValidDNSResolver(resolver) {
            errors.append("DNS resolver '\(resolver)' is not valid.")
        }
        if !kubernetes.version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           kubernetes.version.range(of: #"^v?[0-9]+(\.[0-9]+){1,2}([+\-.][A-Za-z0-9_.-]+)?$"#, options: .regularExpression) == nil {
            errors.append("Kubernetes version must look like v1.30.4+k3s1.")
        }
        for mount in mounts {
            let localPath = mount.localPath.trimmingCharacters(in: .whitespacesAndNewlines)
            let vmPath = mount.vmPath.trimmingCharacters(in: .whitespacesAndNewlines)
            if localPath.isEmpty {
                errors.append("Mount local paths cannot be empty.")
            } else {
                if !localPath.hasPrefix("/") {
                    errors.append("Mount local path '\(localPath)' must be absolute.")
                }
            }
            if !vmPath.isEmpty, !vmPath.hasPrefix("/") {
                errors.append("Mount VM path '\(vmPath)' must be absolute.")
            }
        }
        errors += Self.additionalArgumentValidationErrors(additionalArgs)
        return errors
    }

    nonisolated func validationErrorsCheckingFilesystem(fileManager: FileManager = .default) async -> [String] {
        let synchronousErrors = validationErrors
        let mounts = mounts
        let filesystemErrors = await Task.detached(priority: .userInitiated) {
            Self.filesystemValidationErrors(for: mounts, fileManager: fileManager)
        }.value
        return synchronousErrors + filesystemErrors
    }

    private nonisolated static func filesystemValidationErrors(for mounts: [MountConfiguration], fileManager: FileManager) -> [String] {
        var errors: [String] = []
        for mount in mounts {
            let localPath = mount.localPath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !localPath.isEmpty, localPath.hasPrefix("/") else { continue }
            if !fileManager.fileExists(atPath: localPath) {
                errors.append("Mount local path '\(localPath)' does not exist.")
            }
        }
        return errors
    }

    private nonisolated static func additionalArgumentValidationErrors(_ arguments: [String]) -> [String] {
        let managedFlags: Set<String> = [
            "--arch",
            "--cpu",
            "--cpus",
            "--disk",
            "--dns",
            "--edit",
            "--editor",
            "--env",
            "--force",
            "--foreground",
            "--k3s-arg",
            "--k3s-listen-port",
            "--kubernetes",
            "--kubernetes-version",
            "--memory",
            "--mount",
            "--mount-type",
            "--nested-virtualization",
            "--network-address",
            "--network-interface",
            "--network-mode",
            "--network-preferred-route",
            "--port-forwarder",
            "--profile",
            "--runtime",
            "--vm-type",
            "--vz-rosetta"
        ]

        var errors: [String] = []
        for argument in arguments {
            let trimmed = argument.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                errors.append("Additional CLI args cannot be blank.")
                continue
            }
            if trimmed != argument {
                errors.append("Additional CLI arg '\(trimmed)' cannot start or end with whitespace.")
            }
            if trimmed == "--" {
                errors.append("Additional CLI args cannot include '--'.")
            }
            if trimmed.hasPrefix("-"), !trimmed.hasPrefix("--") {
                errors.append("Additional CLI arg '\(trimmed)' cannot use short flags. Use the explicit long flag form.")
            }
            let flag = trimmed.split(separator: "=", maxSplits: 1).first.map(String.init) ?? trimmed
            if managedFlags.contains(flag) {
                errors.append("Additional CLI arg '\(flag)' is managed by Colima Stack and cannot be overridden.")
            }
        }
        return errors
    }

    private nonisolated static func isValidDNSResolver(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if trimmed.range(of: #"^([0-9]{1,3}\.){3}[0-9]{1,3}$"#, options: .regularExpression) != nil {
            return trimmed.split(separator: ".").allSatisfy { part in
                guard let value = Int(part) else { return false }
                return (0...255).contains(value)
            }
        }
        if trimmed.range(of: #"^[0-9A-Fa-f:]+$"#, options: .regularExpression) != nil, trimmed.contains(":") {
            return true
        }
        return trimmed.range(of: #"^[A-Za-z0-9.-]+$"#, options: .regularExpression) != nil
    }
}

nonisolated enum ProfileNameValidator {
    static func validationError(for name: String) -> String? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            return "Profile name is required."
        }
        if trimmedName.range(of: #"^[A-Za-z0-9][A-Za-z0-9_.-]*$"#, options: .regularExpression) == nil {
            return "Profile name can only contain letters, numbers, dots, underscores, and hyphens, and must start with a letter or number."
        }
        return nil
    }

    static func isValid(_ name: String) -> Bool {
        validationError(for: name) == nil
    }
}

nonisolated struct MountConfiguration: Identifiable, Hashable, Codable, Sendable {
    var id = UUID()
    var localPath: String
    var vmPath: String
    var writable: Bool

    var commandValue: String {
        var value = localPath
        if !vmPath.isEmpty, vmPath != localPath {
            value += ":\(vmPath)"
        }
        if writable {
            value += ":w"
        }
        return value
    }
}

nonisolated struct NetworkConfiguration: Hashable, Codable, Sendable {
    var networkAddress: Bool
    var mode: String
    var interface: String
    var dnsResolvers: [String]

    static let standard = NetworkConfiguration(networkAddress: false, mode: "shared", interface: "", dnsResolvers: [])
}

nonisolated struct ColimaStartRequest: Hashable, Codable, Sendable {
    var profileName: String
    var runtime: ColimaRuntime?
    var vmType: VMType?
    var architecture: CPUArchitecture?
    var resources: ResourceAllocation?
    var mountType: MountType?
    var mounts: [ColimaMount]
    var dnsServers: [String]
    var environmentVariables: [String: String]
    var enableKubernetes: Bool?
    var kubernetesVersion: String?
    var enableNetworkAddress: Bool?
    var preferNetworkAddressRoute: Bool?
    var foreground: Bool
    var editConfiguration: Bool
    var editor: String?
    var additionalArguments: [String]
}

nonisolated struct ColimaStopRequest: Hashable, Codable, Sendable {
    var profileName: String
    var force: Bool
}

nonisolated struct ColimaRestartRequest: Hashable, Codable, Sendable {
    var profileName: String
    var force: Bool
}

nonisolated struct ColimaDeleteRequest: Hashable, Codable, Sendable {
    var profileName: String
    var force: Bool
}

nonisolated struct ColimaLogsRequest: Hashable, Codable, Sendable {
    var profileName: String
}

nonisolated enum ColimaKubernetesAction: String, Codable, CaseIterable, Sendable {
    case status
    case start
    case stop
    case restart
    case reset
}

nonisolated struct ColimaKubernetesRequest: Hashable, Codable, Sendable {
    var profileName: String
    var action: ColimaKubernetesAction
}

nonisolated struct ColimaSSHRequest: Hashable, Codable, Sendable {
    var profileName: String
    var layer: Bool?
    var command: [String]
}

nonisolated struct ColimaEditRequest: Hashable, Codable, Sendable {
    var profileName: String
    var editor: String?
}

nonisolated extension ColimaConfigurationPaths {
    static func `default`(for profileName: String) -> ColimaConfigurationPaths {
        let home = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".colima")
        return ColimaConfigurationPaths(
            homeDirectory: home,
            profileConfiguration: home.appendingPathComponent("\(profileName)/colima.yaml"),
            template: home.appendingPathComponent("_templates/default.yaml"),
            sshConfiguration: home.appendingPathComponent("ssh_config"),
            limaOverride: home.appendingPathComponent("_lima/_config/override.yaml")
        )
    }
}
