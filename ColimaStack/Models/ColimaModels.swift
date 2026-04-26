import Foundation

enum ColimaRuntime: String, CaseIterable, Codable, Sendable, Identifiable {
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

enum ProfileState: String, CaseIterable, Codable, Sendable {
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

enum CPUArchitecture: String, CaseIterable, Codable, Sendable, Identifiable {
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

enum VMType: String, CaseIterable, Codable, Sendable, Identifiable {
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

enum MountType: String, CaseIterable, Codable, Sendable, Identifiable {
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

enum PortForwarder: String, CaseIterable, Codable, Sendable, Identifiable {
    case ssh
    case grpc
    case none

    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
}

struct ResourceAllocation: Hashable, Codable, Sendable {
    var cpu: Int
    var memoryGiB: Int
    var diskGiB: Int

    static let standard = ResourceAllocation(cpu: 2, memoryGiB: 4, diskGiB: 60)
}

struct KubernetesConfig: Hashable, Codable, Sendable {
    var enabled: Bool
    var version: String
    var context: String

    static let disabled = KubernetesConfig(enabled: false, version: "", context: "")
}

struct ColimaMount: Identifiable, Hashable, Codable, Sendable {
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

struct ColimaNetworking: Hashable, Codable, Sendable {
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

struct ColimaConfigurationPaths: Hashable, Codable, Sendable {
    var homeDirectory: URL
    var profileConfiguration: URL
    var template: URL
    var sshConfiguration: URL
    var limaOverride: URL
}

enum ColimaDocumentKind: String, CaseIterable, Codable, Sendable {
    case template
    case profileConfiguration
    case sshConfiguration
    case limaOverride
    case logs
}

struct ColimaDocument: Identifiable, Hashable, Codable, Sendable {
    var id: String { url.path }
    var kind: ColimaDocumentKind
    var profileName: String?
    var url: URL
    var contents: String
    var lastModified: Date?
}

enum ToolAvailability: Hashable, Sendable {
    case available(path: String, version: String?)
    case missing
    case error(String)
}

struct ToolCheck: Identifiable, Hashable, Sendable {
    var id: String
    var name: String { id }
    var availability: ToolAvailability
}

struct DockerStatus: Hashable, Sendable {
    var available: Bool
    var context: String
    var version: String
    var error: String
}

struct ColimaRuntimeStatus: Hashable, Sendable {
    var profileName: String
    var state: ProfileState
    var output: String
    var error: String
}

struct DiagnosticReport: Hashable, Sendable {
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

struct ColimaDiagnostics: Hashable, Codable, Sendable {
    var rawListOutput: String?
    var rawStatusOutput: String?
    var rawKubernetesOutput: String?
    var warnings: [String]
    var errors: [String]
}

struct ColimaStatusDetail: Hashable, Codable, Sendable {
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

struct ColimaProfile: Identifiable, Hashable, Codable, Sendable {
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

struct CommandLogEntry: Identifiable, Hashable, Sendable {
    enum Status: Hashable, Sendable {
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

struct ColimaCommandLogEntry: Identifiable, Hashable, Codable, Sendable, CombinedProcessOutput {
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

struct ColimaCommandLog: Hashable, Codable, Sendable {
    var profileName: String
    var collectedAt: Date
    var contents: String
    var entry: ColimaCommandLogEntry
}

struct ProfileConfiguration: Hashable, Codable, Sendable {
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

    var validationErrors: [String] {
        var errors: [String] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Profile name is required.")
        }
        if name.contains(" ") {
            errors.append("Profile name cannot contain spaces.")
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
        for mount in mounts where mount.localPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Mount local paths cannot be empty.")
        }
        return errors
    }
}

struct MountConfiguration: Identifiable, Hashable, Codable, Sendable {
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

struct NetworkConfiguration: Hashable, Codable, Sendable {
    var networkAddress: Bool
    var mode: String
    var interface: String
    var dnsResolvers: [String]

    static let standard = NetworkConfiguration(networkAddress: false, mode: "shared", interface: "", dnsResolvers: [])
}

struct ColimaStartRequest: Hashable, Codable, Sendable {
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

struct ColimaStopRequest: Hashable, Codable, Sendable {
    var profileName: String
    var force: Bool
}

struct ColimaRestartRequest: Hashable, Codable, Sendable {
    var profileName: String
    var force: Bool
}

struct ColimaDeleteRequest: Hashable, Codable, Sendable {
    var profileName: String
    var force: Bool
}

struct ColimaLogsRequest: Hashable, Codable, Sendable {
    var profileName: String
}

enum ColimaKubernetesAction: String, Codable, CaseIterable, Sendable {
    case status
    case start
    case stop
    case restart
    case reset
}

struct ColimaKubernetesRequest: Hashable, Codable, Sendable {
    var profileName: String
    var action: ColimaKubernetesAction
}

struct ColimaSSHRequest: Hashable, Codable, Sendable {
    var profileName: String
    var layer: Bool?
    var command: [String]
}

struct ColimaEditRequest: Hashable, Codable, Sendable {
    var profileName: String
    var editor: String?
}

extension ColimaConfigurationPaths {
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
