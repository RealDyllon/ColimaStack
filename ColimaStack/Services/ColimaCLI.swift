import Foundation

typealias ColimaControlling = ColimaCLI

enum ColimaCLIError: LocalizedError, Sendable, Equatable {
    case missingColima
    case missingTool(name: String, searchPaths: [String])
    case processFailure(underlying: String)
    case commandFailed(command: String, exitStatus: Int32, stdout: String, stderr: String)
    case unexpectedOutput(command: String, details: String, rawOutput: String)
    case missingFile(url: URL)
    case unreadableFile(url: URL, underlying: String)

    var errorDescription: String? {
        switch self {
        case .missingColima:
            return "Colima is not installed or not available in PATH"
        case let .missingTool(name, searchPaths):
            return "Required tool '\(name)' was not found in PATH (\(searchPaths.joined(separator: ":")))"
        case let .processFailure(underlying):
            return underlying
        case let .commandFailed(command, exitStatus, stdout, stderr):
            let output = [stdout, stderr]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: "\n")
            return "Command failed with exit status \(exitStatus): \(command)\(output.isEmpty ? "" : "\n\(output)")"
        case let .unexpectedOutput(command, details, rawOutput):
            return "Unexpected output for \(command): \(details)\(rawOutput.isEmpty ? "" : "\n\(rawOutput)")"
        case let .missingFile(url):
            return "Expected Colima file does not exist: \(url.path)"
        case let .unreadableFile(url, underlying):
            return "Unable to read \(url.path): \(underlying)"
        }
    }
}

protocol ColimaCLI {
    func diagnostics() async -> DiagnosticReport
    func listProfiles() async throws -> [ColimaProfile]
    func status(profile: String) async throws -> ColimaStatusDetail
    func logs(profile: String) async throws -> String
    func start(_ configuration: ProfileConfiguration) async throws -> ProcessResult
    func stop(profile: String) async throws -> ProcessResult
    func restart(profile: String) async throws -> ProcessResult
    func delete(profile: String) async throws -> ProcessResult
    func kubernetes(profile: String, enabled: Bool) async throws -> ProcessResult
    func update(profile: String) async throws -> ProcessResult
    func template() async throws -> String
    func configuration(profile: String) async throws -> ProfileConfiguration?
}

struct LiveColimaCLI: ColimaCLI {
    enum ExecutionMode: Sendable {
        case env
        case resolvedPath
    }

    private let processRunner: AsyncProcessRunning
    private let toolLocator: ToolLocator
    private let fileManager: FileManager
    private let environment: [String: String]
    private let executionMode: ExecutionMode

    init(
        processRunner: ProcessRunner = LiveProcessRunner(),
        toolLocator: ToolLocator = LiveToolLocator(),
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        executionMode: ExecutionMode = .resolvedPath
    ) {
        self.processRunner = AsyncProcessRunnerAdapter(processRunner: processRunner)
        self.toolLocator = toolLocator
        self.fileManager = fileManager
        self.environment = environment
        self.executionMode = executionMode
    }

    func diagnostics() async -> DiagnosticReport {
        let tools = await toolChecks(["colima", "docker", "kubectl", "limactl"])
        let colimaStatus = await colimaRuntimeStatus(from: tools)
        let dockerStatus = await dockerStatus(from: tools, colimaStatus: colimaStatus)
        var messages: [String] = []
        if let kubectlURL = toolURL(named: "kubectl", in: tools) {
            let context = await commandOutput(executableURL: kubectlURL, arguments: ["config", "current-context"], timeout: 5)
            if !context.output.isEmpty {
                messages.append(EnvironmentRedactor.redacted("Kubernetes context: \(context.output)"))
            } else if let error = context.error {
                messages.append(EnvironmentRedactor.redacted("Kubernetes context unavailable: \(error)"))
            }
        }
        return DiagnosticReport(tools: tools, colima: colimaStatus, docker: dockerStatus, messages: messages)
    }

    func listProfiles() async throws -> [ColimaProfile] {
        let entry = try await run(.list)
        try requireSuccess(entry)
        return try ColimaOutputParser().parseList(entry.standardOutput)
    }

    func status(profile: String) async throws -> ColimaStatusDetail {
        try validateProfileName(profile)
        let entry = try await run(.status(profile: profile))
        let output = entry.combinedOutput
        if entry.terminationStatus != 0 && !output.lowercased().contains("not running") {
            throw failure(for: entry)
        }
        return try ColimaOutputParser().parseStatus(output, profile: profile)
    }

    func logs(profile: String) async throws -> String {
        try validateProfileName(profile)
        let logURL = ColimaPaths.daemonLog(profile: profile, environment: environment, fileManager: fileManager)
        if let contents = try? String(contentsOf: logURL, encoding: .utf8) {
            return contents
        }
        return "No Colima daemon log found at \(logURL.path)."
    }

    func start(_ configuration: ProfileConfiguration) async throws -> ProcessResult {
        let validationErrors = await configuration.validationErrorsCheckingFilesystem(fileManager: fileManager)
        guard validationErrors.isEmpty else {
            throw ColimaCLIError.unexpectedOutput(command: "profile validation", details: validationErrors.joined(separator: "\n"), rawOutput: "")
        }
        var additionalArguments = configuration.additionalArgs
        additionalArguments += ["--port-forwarder", configuration.portForwarder.rawValue]
        if configuration.network.mode != "shared" {
            additionalArguments += ["--network-mode", configuration.network.mode]
        }
        if !configuration.network.interface.isEmpty {
            additionalArguments += ["--network-interface", configuration.network.interface]
        }
        if configuration.rosetta {
            additionalArguments.append("--vz-rosetta")
        }
        if configuration.nestedVirtualization {
            additionalArguments.append("--nested-virtualization")
        }
        for k3sArg in configuration.k3sArgs where !k3sArg.isEmpty {
            additionalArguments += ["--k3s-arg", k3sArg]
        }
        if let listenPort = configuration.k3sListenPort {
            additionalArguments += ["--k3s-listen-port", String(listenPort)]
        }
        let request = ColimaStartRequest(
            profileName: configuration.name,
            runtime: configuration.runtime,
            vmType: configuration.vmType,
            architecture: configuration.architecture,
            resources: configuration.resources,
            mountType: configuration.mountType,
            mounts: configuration.mounts.map {
                ColimaMount(location: $0.localPath, mountPoint: $0.vmPath.isEmpty ? nil : $0.vmPath, writable: $0.writable, cliValue: $0.commandValue)
            },
            dnsServers: configuration.network.dnsResolvers,
            environmentVariables: [:],
            enableKubernetes: configuration.kubernetes.enabled,
            kubernetesVersion: configuration.kubernetes.version.isEmpty ? nil : configuration.kubernetes.version,
            enableNetworkAddress: configuration.network.networkAddress,
            preferNetworkAddressRoute: nil,
            foreground: false,
            editConfiguration: false,
            editor: nil,
            additionalArguments: additionalArguments
        )
        let entry = try await run(.start(request))
        try requireSuccess(entry)
        return entry.processResult
    }

    func stop(profile: String) async throws -> ProcessResult {
        try validateProfileName(profile)
        let entry = try await run(.stop(ColimaStopRequest(profileName: profile, force: false)))
        try requireSuccess(entry)
        return entry.processResult
    }

    func restart(profile: String) async throws -> ProcessResult {
        try validateProfileName(profile)
        let entry = try await run(.restart(ColimaRestartRequest(profileName: profile, force: false)))
        try requireSuccess(entry)
        return entry.processResult
    }

    func delete(profile: String) async throws -> ProcessResult {
        try validateProfileName(profile)
        let entry = try await run(.delete(ColimaDeleteRequest(profileName: profile, force: true)))
        try requireSuccess(entry)
        return entry.processResult
    }

    func kubernetes(profile: String, enabled: Bool) async throws -> ProcessResult {
        try validateProfileName(profile)
        let action: ColimaKubernetesAction = enabled ? .start : .stop
        let entry = try await run(.kubernetes(ColimaKubernetesRequest(profileName: profile, action: action)))
        try requireSuccess(entry)
        return entry.processResult
    }

    func update(profile: String) async throws -> ProcessResult {
        try validateProfileName(profile)
        let entry = try await run(.update(profile: profile))
        try requireSuccess(entry)
        return entry.processResult
    }

    func template() async throws -> String {
        try readDocument(kind: .template, url: configurationPaths(for: resolvedProfileName(nil)).template, profileName: nil).contents
    }

    func configuration(profile: String) async throws -> ProfileConfiguration? {
        try validateProfileName(profile)
        let url = configurationPaths(for: profile).profileConfiguration
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let contents: String
        do {
            contents = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw ColimaCLIError.unreadableFile(url: url, underlying: error.localizedDescription)
        }
        return ColimaConfigurationParser(profileName: profile).parse(contents)
    }

    func templateDocument(named name: String? = nil) throws -> ColimaDocument {
        let templateName = name?.isEmpty == false ? name! : "default"
        let url = ColimaPaths.home(environment: environment, fileManager: fileManager).appendingPathComponent("_templates/\(templateName).yaml")
        return try readDocument(kind: .template, url: url, profileName: nil)
    }

    func profileConfigurationDocument(profile: String) throws -> ColimaDocument {
        try validateProfileName(profile)
        let paths = configurationPaths(for: profile)
        return try readDocument(kind: .profileConfiguration, url: paths.profileConfiguration, profileName: profile)
    }

    func sshConfigurationDocument(profile: String, layer: Bool? = nil) async throws -> ColimaDocument {
        try validateProfileName(profile)
        let entry = try await run(.sshConfiguration(profile: profile, layer: layer))
        try requireSuccess(entry)
        let paths = configurationPaths(for: profile)
        let contents = entry.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (try? readDocument(kind: .sshConfiguration, url: paths.sshConfiguration, profileName: profile).contents) ?? ""
            : entry.combinedOutput
        return ColimaDocument(
            kind: .sshConfiguration,
            profileName: profile,
            url: paths.sshConfiguration,
            contents: contents,
            lastModified: modificationDate(paths.sshConfiguration)
        )
    }

    func editTemplate(_ request: ColimaEditRequest) async throws -> ProcessResult {
        try validateProfileName(request.profileName)
        let entry = try await run(.template(request))
        try requireSuccess(entry)
        return entry.processResult
    }

    func editProfileConfiguration(_ request: ColimaEditRequest) async throws -> ProcessResult {
        try validateProfileName(request.profileName)
        let startRequest = ColimaStartRequest(
            profileName: request.profileName,
            runtime: nil,
            vmType: nil,
            architecture: nil,
            resources: nil,
            mountType: nil,
            mounts: [],
            dnsServers: [],
            environmentVariables: [:],
            enableKubernetes: nil,
            kubernetesVersion: nil,
            enableNetworkAddress: nil,
            preferNetworkAddressRoute: nil,
            foreground: false,
            editConfiguration: true,
            editor: request.editor,
            additionalArguments: []
        )
        let entry = try await run(.start(startRequest))
        try requireSuccess(entry)
        return entry.processResult
    }

    func ssh(_ request: ColimaSSHRequest) async throws -> ProcessResult {
        try validateProfileName(request.profileName)
        let entry = try await run(.ssh(request))
        try requireSuccess(entry)
        return entry.processResult
    }

    private func run(_ command: ColimaCommand) async throws -> ColimaCommandLogEntry {
        do {
            let colimaURL = try toolLocator.require("colima")
            let executableURL: URL
            let arguments: [String]
            switch executionMode {
            case .env:
                executableURL = URL(fileURLWithPath: "/usr/bin/env")
                arguments = ["colima"] + command.arguments
            case .resolvedPath:
                executableURL = colimaURL
                arguments = command.arguments
            }

            let result = try await processRunner.run(
                ProcessRequest(
                    executableURL: executableURL,
                    arguments: arguments,
                    environment: environmentWithToolSearchPath(command.environment),
                    timeout: command.timeout
                )
            )

            return ColimaCommandLogEntry(
                executablePath: result.executableURL.path,
                arguments: EnvironmentRedactor.redacted(result.arguments),
                environmentOverrides: EnvironmentRedactor.redacted(result.environment),
                launchedAt: result.launchedAt,
                duration: result.duration,
                terminationStatus: result.terminationStatus,
                standardOutput: EnvironmentRedactor.redacted(result.standardOutput),
                standardError: EnvironmentRedactor.redacted(result.standardError)
            )
        } catch let error as ToolLocatorError {
            switch error {
            case let .toolNotFound(name, searchPaths):
                if name == "colima" {
                    throw ColimaCLIError.missingColima
                }
                throw ColimaCLIError.missingTool(name: name, searchPaths: searchPaths)
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw ColimaCLIError.processFailure(underlying: EnvironmentRedactor.redacted(error.localizedDescription))
        }
    }

    private func requireSuccess(_ entry: ColimaCommandLogEntry) throws {
        guard entry.terminationStatus == 0 else {
            throw failure(for: entry)
        }
    }

    private func environmentWithToolSearchPath(_ overrides: [String: String]) -> [String: String] {
        let searchPath = toolLocator.searchPaths().joined(separator: ":")
        guard !searchPath.isEmpty else {
            return overrides
        }

        var environment = overrides
        environment["PATH"] = searchPath
        return environment
    }

    private func validateProfileName(_ profile: String) throws {
        if let error = ProfileNameValidator.validationError(for: profile) {
            throw ColimaCLIError.unexpectedOutput(command: "profile validation", details: error, rawOutput: "")
        }
    }

    private func failure(for entry: ColimaCommandLogEntry) -> ColimaCLIError {
        .commandFailed(
            command: entry.commandString,
            exitStatus: entry.terminationStatus,
            stdout: entry.standardOutput,
            stderr: entry.standardError
        )
    }

    private func toolChecks(_ toolNames: [String]) async -> [ToolCheck] {
        var checks: [ToolCheck] = []
        checks.reserveCapacity(toolNames.count)
        for toolName in toolNames {
            checks.append(await toolCheck(toolName))
        }
        return checks
    }

    private func toolCheck(_ toolName: String) async -> ToolCheck {
        guard let toolURL = toolLocator.locate(toolName) else {
            return ToolCheck(id: toolName, availability: .missing)
        }

        let versionArgs: [String]
        switch toolName {
        case "docker":
            versionArgs = ["version", "--format", "{{.Client.Version}}"]
        case "kubectl":
            versionArgs = ["version", "--client=true", "-o", "json"]
        case "limactl":
            versionArgs = ["--version"]
        default:
            versionArgs = ["version"]
        }

        guard let result = try? await processRunner.run(ProcessRequest(executableURL: toolURL, arguments: versionArgs, timeout: 5)) else {
            return ToolCheck(id: toolName, availability: .error("\(toolURL.path) - failed to run version check"))
        }

        let output = result.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard result.terminationStatus == 0 else {
            return ToolCheck(id: toolName, availability: .error(EnvironmentRedactor.redacted([toolURL.path, output].filter { !$0.isEmpty }.joined(separator: " - "))))
        }

        return ToolCheck(id: toolName, availability: .available(path: toolURL.path, version: EnvironmentRedactor.redacted(displayVersion(for: toolName, output: output))))
    }

    private func colimaRuntimeStatus(from tools: [ToolCheck]) async -> ColimaRuntimeStatus {
        let profile = resolvedProfileName(nil)
        guard toolURL(named: "colima", in: tools) != nil else {
            return ColimaRuntimeStatus(profileName: profile, state: .unknown, output: "", error: "Colima CLI not found")
        }

        do {
            let entry = try await run(.status(profile: profile))
            let output = entry.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            let detail = try? ColimaOutputParser().parseStatus(output, profile: profile)
            let state = detail?.state ?? ProfileState.inferred(from: output)
            let error = entry.terminationStatus == 0 ? "" : output
            return ColimaRuntimeStatus(profileName: profile, state: state, output: output, error: error)
        } catch {
            return ColimaRuntimeStatus(profileName: profile, state: .unknown, output: "", error: EnvironmentRedactor.redacted(error.localizedDescription))
        }
    }

    private func dockerStatus(from tools: [ToolCheck], colimaStatus: ColimaRuntimeStatus) async -> DockerStatus {
        guard let dockerURL = toolURL(named: "docker", in: tools) else {
            return DockerStatus(available: false, context: "", version: "", error: "Not installed")
        }
        let context = await commandOutput(executableURL: dockerURL, arguments: ["context", "show"], timeout: 5)
        if colimaStatus.state != .running {
            let version = await commandOutput(executableURL: dockerURL, arguments: ["version", "--format", "{{.Server.Version}}"], timeout: 8)
            return DockerStatus(available: false, context: context.output, version: version.output, error: "Colima \(colimaStatus.profileName) is \(colimaStatus.state.label.lowercased())")
        }
        let expectedContext = colimaStatus.profileName == "default" ? "colima" : "colima-\(colimaStatus.profileName)"
        let version = await commandOutput(executableURL: dockerURL, arguments: ["--context", expectedContext, "version", "--format", "{{.Server.Version}}"], timeout: 8)
        if let error = version.error {
            return DockerStatus(available: false, context: context.output, version: "", error: error)
        }
        return DockerStatus(available: true, context: expectedContext, version: version.output, error: "")
    }

    private func displayVersion(for toolName: String, output: String) -> String {
        guard toolName == "kubectl",
              let data = output.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let client = object["clientVersion"] as? [String: Any],
              let gitVersion = client["gitVersion"] as? String
        else {
            return output
        }
        return gitVersion
    }

    private func toolURL(named name: String, in tools: [ToolCheck]) -> URL? {
        guard let tool = tools.first(where: { $0.id == name }) else { return nil }
        if case let .available(path, _) = tool.availability {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    private func commandOutput(executableURL: URL, arguments: [String], timeout: TimeInterval) async -> (output: String, error: String?) {
        do {
            let result = try await processRunner.run(ProcessRequest(executableURL: executableURL, arguments: arguments, timeout: timeout))
            let output = result.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            guard result.terminationStatus == 0 else {
                return (EnvironmentRedactor.redacted(output), output.isEmpty ? "Exited with status \(result.terminationStatus)" : EnvironmentRedactor.redacted(output))
            }
            return (EnvironmentRedactor.redacted(output), nil)
        } catch {
            return ("", EnvironmentRedactor.redacted(error.localizedDescription))
        }
    }

    private func resolvedProfileName(_ explicit: String?) -> String {
        if let explicit, !explicit.isEmpty {
            return ProfileNameValidator.isValid(explicit) ? explicit : "default"
        }
        if let envProfile = environment["COLIMA_PROFILE"], !envProfile.isEmpty {
            return ProfileNameValidator.isValid(envProfile) ? envProfile : "default"
        }
        return "default"
    }

    private func configurationPaths(for profile: String) -> ColimaConfigurationPaths {
        let home = ColimaPaths.home(environment: environment, fileManager: fileManager)
        return ColimaConfigurationPaths(
            homeDirectory: home,
            profileConfiguration: home.appendingPathComponent("\(profile)/colima.yaml"),
            template: home.appendingPathComponent("_templates/default.yaml"),
            sshConfiguration: home.appendingPathComponent("ssh_config"),
            limaOverride: home.appendingPathComponent("_lima/_config/override.yaml")
        )
    }

    private func readDocument(kind: ColimaDocumentKind, url: URL, profileName: String?) throws -> ColimaDocument {
        guard fileManager.fileExists(atPath: url.path) else {
            throw ColimaCLIError.missingFile(url: url)
        }
        do {
            return ColimaDocument(
                kind: kind,
                profileName: profileName,
                url: url,
                contents: try String(contentsOf: url, encoding: .utf8),
                lastModified: modificationDate(url)
            )
        } catch {
            throw ColimaCLIError.unreadableFile(url: url, underlying: error.localizedDescription)
        }
    }

    private func modificationDate(_ url: URL) -> Date? {
        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        return attributes?[.modificationDate] as? Date
    }
}

private struct ColimaCommand: Sendable {
    let arguments: [String]
    let environment: [String: String]
    let timeout: TimeInterval?

    static let list = ColimaCommand(arguments: ["list", "--json"], environment: [:], timeout: 15)

    static func status(profile: String) -> ColimaCommand {
        ColimaCommand(arguments: ["status", "--json"], environment: ["COLIMA_PROFILE": profile], timeout: 15)
    }

    static func start(_ request: ColimaStartRequest) -> ColimaCommand {
        var args = ["start"]
        if let runtime = request.runtime, runtime != .unknown, runtime != .none {
            args += ["--runtime", runtime.rawValue]
        }
        if let vmType = request.vmType {
            args += ["--vm-type", vmType.rawValue]
        }
        if let architecture = request.architecture, architecture != .host {
            args += ["--arch", architecture.rawValue]
        }
        if let resources = request.resources {
            args += ["--cpus", String(resources.cpu)]
            args += ["--memory", String(resources.memoryGiB)]
            args += ["--disk", String(resources.diskGiB)]
        }
        if let mountType = request.mountType {
            args += ["--mount-type", mountType.rawValue]
        }
        for mount in request.mounts {
            args += ["--mount", mount.cliValue]
        }
        for dns in request.dnsServers where !dns.isEmpty {
            args += ["--dns", dns]
        }
        for item in request.environmentVariables.sorted(by: { $0.key < $1.key }) {
            args += ["--env", "\(item.key)=\(item.value)"]
        }
        if let enableKubernetes = request.enableKubernetes {
            args.append("--kubernetes=\(enableKubernetes ? "true" : "false")")
        }
        if let kubernetesVersion = request.kubernetesVersion, !kubernetesVersion.isEmpty {
            args += ["--kubernetes-version", kubernetesVersion]
        }
        if let enableNetworkAddress = request.enableNetworkAddress {
            args.append("--network-address=\(enableNetworkAddress ? "true" : "false")")
        }
        if let preferNetworkAddressRoute = request.preferNetworkAddressRoute {
            args.append("--network-preferred-route=\(preferNetworkAddressRoute ? "true" : "false")")
        }
        if request.foreground {
            args.append("--foreground")
        }
        if request.editConfiguration {
            args.append("--edit")
        }
        if let editor = request.editor, !editor.isEmpty {
            args += ["--editor", editor]
        }
        args += request.additionalArguments
        return ColimaCommand(arguments: args, environment: ["COLIMA_PROFILE": request.profileName], timeout: 300)
    }

    static func stop(_ request: ColimaStopRequest) -> ColimaCommand {
        var args = ["stop"]
        if request.force {
            args.append("--force")
        }
        return ColimaCommand(arguments: args, environment: ["COLIMA_PROFILE": request.profileName], timeout: 120)
    }

    static func restart(_ request: ColimaRestartRequest) -> ColimaCommand {
        var args = ["restart"]
        if request.force {
            args.append("--force")
        }
        return ColimaCommand(arguments: args, environment: ["COLIMA_PROFILE": request.profileName], timeout: 180)
    }

    static func delete(_ request: ColimaDeleteRequest) -> ColimaCommand {
        var args = ["delete"]
        if request.force {
            args.append("--force")
        }
        return ColimaCommand(arguments: args, environment: ["COLIMA_PROFILE": request.profileName], timeout: 120)
    }

    static func logs(profile: String) -> ColimaCommand {
        ColimaCommand(arguments: ["logs"], environment: ["COLIMA_PROFILE": profile], timeout: 30)
    }

    static func kubernetes(_ request: ColimaKubernetesRequest) -> ColimaCommand {
        ColimaCommand(arguments: ["kubernetes", request.action.rawValue], environment: ["COLIMA_PROFILE": request.profileName], timeout: 180)
    }

    static func sshConfiguration(profile: String, layer: Bool?) -> ColimaCommand {
        var args = ["ssh-config"]
        if let layer {
            args.append("--layer=\(layer ? "true" : "false")")
        }
        return ColimaCommand(arguments: args, environment: ["COLIMA_PROFILE": profile], timeout: 15)
    }

    static func ssh(_ request: ColimaSSHRequest) -> ColimaCommand {
        var args = ["ssh"]
        if let layer = request.layer {
            args.append("--layer=\(layer ? "true" : "false")")
        }
        if !request.command.isEmpty {
            args.append("--")
            args += request.command
        }
        return ColimaCommand(arguments: args, environment: ["COLIMA_PROFILE": request.profileName], timeout: nil)
    }

    static func template(_ request: ColimaEditRequest) -> ColimaCommand {
        var args = ["template"]
        if let editor = request.editor, !editor.isEmpty {
            args += ["--editor", editor]
        }
        return ColimaCommand(arguments: args, environment: ["COLIMA_PROFILE": request.profileName], timeout: nil)
    }

    static func update(profile: String) -> ColimaCommand {
        ColimaCommand(arguments: ["update"], environment: ["COLIMA_PROFILE": profile], timeout: 180)
    }
}

enum ColimaPaths {
    static func home(environment: [String: String] = ProcessInfo.processInfo.environment, fileManager: FileManager = .default) -> URL {
        if let value = environment["COLIMA_HOME"], !value.isEmpty {
            return URL(fileURLWithPath: value)
        }
        return fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".colima")
    }

    static func daemonLog(
        profile: String,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> URL {
        home(environment: environment, fileManager: fileManager)
            .appendingPathComponent(profile)
            .appendingPathComponent("daemon")
            .appendingPathComponent("daemon.log")
    }
}

private struct ColimaConfigurationParser {
    let profileName: String

    func parse(_ contents: String) -> ProfileConfiguration {
        var configuration = ProfileConfiguration.default
        configuration.name = profileName
        var section: String?
        var currentMount: MountConfiguration?
        var pendingList: (section: String?, key: String)?

        func finishMount() {
            if let mount = currentMount {
                configuration.mounts.append(mount)
                currentMount = nil
            }
        }

        for rawLine in contents.components(separatedBy: .newlines) {
            let lineWithoutComment = rawLine.split(separator: "#", maxSplits: 1).first.map(String.init) ?? ""
            guard !lineWithoutComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let indent = lineWithoutComment.prefix { $0 == " " }.count
            let trimmed = lineWithoutComment.trimmingCharacters(in: .whitespacesAndNewlines)

            if indent == 0, trimmed.hasSuffix(":") {
                finishMount()
                section = String(trimmed.dropLast()).lowercased()
                pendingList = nil
                continue
            }

            if section == "mounts", trimmed.hasPrefix("-") {
                finishMount()
                pendingList = nil
                let value = trimmed.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
                currentMount = MountConfiguration(localPath: "", vmPath: "", writable: true)
                if let pair = keyValue(value), pair.key == "location" {
                    currentMount?.localPath = pair.value
                }
                continue
            }

            if let list = pendingList, trimmed.hasPrefix("-") {
                appendListValue(unquoted(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)), to: list, configuration: &configuration)
                continue
            }

            guard let pair = keyValue(trimmed) else { continue }
            pendingList = nil
            if section == "mounts" {
                if currentMount == nil {
                    currentMount = MountConfiguration(localPath: "", vmPath: "", writable: true)
                }
                switch pair.key {
                case "location":
                    currentMount?.localPath = pair.value
                case "mountpoint", "mount_point":
                    currentMount?.vmPath = pair.value
                case "writable":
                    currentMount?.writable = bool(pair.value) ?? true
                default:
                    break
                }
                continue
            }

            switch (section, pair.key) {
            case (nil, "cpu"), ("", "cpu"):
                configuration.resources.cpu = Int(pair.value) ?? configuration.resources.cpu
            case (nil, "memory"), ("", "memory"):
                configuration.resources.memoryGiB = Int(pair.value) ?? configuration.resources.memoryGiB
            case (nil, "disk"), ("", "disk"):
                configuration.resources.diskGiB = Int(pair.value) ?? configuration.resources.diskGiB
            case (nil, "runtime"), ("", "runtime"):
                configuration.runtime = ColimaRuntime(cliValue: pair.value)
            case (nil, "vmtype"), ("", "vmtype"), (nil, "vm_type"), ("", "vm_type"):
                configuration.vmType = VMType(rawValue: pair.value.lowercased()) ?? configuration.vmType
            case (nil, "arch"), ("", "arch"):
                configuration.architecture = CPUArchitecture(rawValue: pair.value) ?? configuration.architecture
            case (nil, "mounttype"), ("", "mounttype"), (nil, "mount_type"), ("", "mount_type"):
                configuration.mountType = MountType(rawValue: pair.value.lowercased()) ?? configuration.mountType
            case (nil, "rosetta"), ("", "rosetta"):
                configuration.rosetta = bool(pair.value) ?? configuration.rosetta
            case (nil, "nestedvirtualization"), ("", "nestedvirtualization"), (nil, "nested_virtualization"), ("", "nested_virtualization"):
                configuration.nestedVirtualization = bool(pair.value) ?? configuration.nestedVirtualization
            case (nil, "portforwarder"), ("", "portforwarder"), (nil, "port_forwarder"), ("", "port_forwarder"):
                configuration.portForwarder = PortForwarder(rawValue: pair.value.lowercased()) ?? configuration.portForwarder
            case ("kubernetes", "enabled"):
                configuration.kubernetes.enabled = bool(pair.value) ?? configuration.kubernetes.enabled
            case ("kubernetes", "version"):
                configuration.kubernetes.version = pair.value
            case ("kubernetes", "k3sargs"), ("kubernetes", "k3s_args"):
                configuration.k3sArgs = list(pair.value)
                if pair.value.isEmpty { pendingList = (section, pair.key) }
            case ("kubernetes", "k3slistenport"), ("kubernetes", "k3s_listen_port"):
                configuration.k3sListenPort = Int(pair.value)
            case ("network", "address"):
                configuration.network.networkAddress = bool(pair.value) ?? configuration.network.networkAddress
            case ("network", "mode"):
                configuration.network.mode = pair.value
            case ("network", "interface"):
                configuration.network.interface = pair.value
            case ("network", "dns"), ("dns", _):
                configuration.network.dnsResolvers = list(pair.value)
                if pair.value.isEmpty { pendingList = (section, pair.key) }
            default:
                continue
            }
        }
        finishMount()
        configuration.mounts.removeAll { $0.localPath.isEmpty }
        return configuration
    }

    private func keyValue(_ line: String) -> (key: String, value: String)? {
        guard let separator = line.firstIndex(of: ":") else { return nil }
        let key = String(line[..<separator])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
        let rawValue = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (key, unquoted(rawValue))
    }

    private func unquoted(_ value: String) -> String {
        var value = value
        if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
            value.removeFirst()
            value.removeLast()
        }
        return value
    }

    private func bool(_ value: String) -> Bool? {
        switch value.lowercased() {
        case "true", "yes", "1", "enabled":
            return true
        case "false", "no", "0", "disabled":
            return false
        default:
            return nil
        }
    }

    private func list(_ value: String) -> [String] {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("["), trimmed.hasSuffix("]") else {
            return trimmed.isEmpty ? [] : [trimmed]
        }
        let body = trimmed.dropFirst().dropLast()
        return body
            .split(separator: ",")
            .map { unquoted($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.isEmpty }
    }

    private func appendListValue(_ value: String, to list: (section: String?, key: String), configuration: inout ProfileConfiguration) {
        guard !value.isEmpty else { return }
        switch (list.section, list.key) {
        case ("kubernetes", "k3sargs"), ("kubernetes", "k3s_args"):
            configuration.k3sArgs.append(value)
        case ("network", "dns"), ("dns", _):
            configuration.network.dnsResolvers.append(value)
        default:
            break
        }
    }
}

private extension ColimaCommandLogEntry {
    var processResult: ProcessResult {
        ProcessResult(
            executableURL: URL(fileURLWithPath: executablePath),
            arguments: arguments,
            environment: environmentOverrides,
            launchedAt: launchedAt,
            duration: duration,
            terminationStatus: terminationStatus,
            standardOutput: standardOutput,
            standardError: standardError
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
