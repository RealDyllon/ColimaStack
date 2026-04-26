import Foundation
import Testing
@testable import ColimaStack

@MainActor
struct ColimaParserTests {
    @Test func parsesListJSONLinesWithByteUnitsAndKubernetesRuntime() throws {
        let output = """
        {"name":"default","status":"Running","arch":"aarch64","cpus":2,"memory":2147483648,"disk":107374182400,"address":"192.168.5.15","runtime":"docker+k3s"}
        {"name":"dev","status":"Stopped","arch":"x86_64","cpus":4,"memory":8589934592,"disk":214748364800}
        """

        let profiles = try ColimaOutputParser().parseList(output)

        #expect(profiles.count == 2)
        #expect(profiles[0].name == "default")
        #expect(profiles[0].state == .running)
        #expect(profiles[0].runtime == .docker)
        #expect(profiles[0].kubernetes.enabled)
        #expect(profiles[0].resources?.memoryGiB == 2)
        #expect(profiles[0].resources?.diskGiB == 100)
        #expect(profiles[1].dockerContext == "colima-dev")
    }

    @Test func parsesStatusJSON() throws {
        let output = """
        {"display_name":"colima","driver":"QEMU","arch":"aarch64","runtime":"docker","mount_type":"sshfs","ip_address":"192.168.5.15","docker_socket":"unix:///Users/me/.colima/default/docker.sock","containerd_socket":"unix:///Users/me/.colima/default/containerd.sock","kubernetes":true,"cpu":2,"memory":2147483648,"disk":107374182400}
        """

        let detail = try ColimaOutputParser().parseStatus(output, profile: "default")

        #expect(detail.state == .running)
        #expect(detail.vmType == .qemu)
        #expect(detail.mountType == .sshfs)
        #expect(detail.resources?.memoryGiB == 2)
        #expect(detail.resources?.diskGiB == 100)
        #expect(detail.kubernetes.enabled)
        #expect(detail.socket == "unix:///Users/me/.colima/default/docker.sock")
    }

    @Test func parsesStatusJSONWithLogPrefix() throws {
        let output = """
        INFO[0000] status
        {"display_name":"dev","driver":"vz","arch":"aarch64","runtime":"containerd+k3s","mount_type":"virtiofs","ip_address":"192.168.5.20","containerd_socket":"unix:///tmp/containerd.sock","kubernetes":true,"cpu":4,"memory":4294967296,"disk":85899345920}
        """

        let detail = try ColimaOutputParser().parseStatus(output, profile: "dev")

        #expect(detail.profileName == "dev")
        #expect(detail.runtime == .containerd)
        #expect(detail.vmType == .vz)
        #expect(detail.mountType == .virtiofs)
        #expect(detail.resources?.memoryGiB == 4)
        #expect(detail.socket == "unix:///tmp/containerd.sock")
    }

    @Test func parsesPlainStatusWithoutMisclassifyingNotRunning() throws {
        let output = """
        colima is not running
        Kubernetes: disabled
        """

        let detail = try ColimaOutputParser().parseStatus(output, profile: "default")

        #expect(detail.state == .stopped)
        #expect(!detail.kubernetes.enabled)
    }

    @Test func parsesPlainStatusAliasesAndResources() throws {
        let output = """
        Colima is running
        Runtime: docker
        Driver: vz
        Mount Type: virtiofs
        CPU: 6
        Memory: 12GiB
        Disk: 120GiB
        IP Address: 192.168.5.15
        Docker Socket: unix:///tmp/docker.sock
        Kubernetes: enabled
        Kubernetes Version: v1.30.4+k3s1
        """

        let detail = try ColimaOutputParser().parseStatus(output, profile: "default")

        #expect(detail.state == .running)
        #expect(detail.resources == ResourceAllocation(cpu: 6, memoryGiB: 12, diskGiB: 120))
        #expect(detail.networkAddress == "192.168.5.15")
        #expect(detail.socket == "unix:///tmp/docker.sock")
        #expect(detail.kubernetes.enabled)
        #expect(detail.kubernetes.version == "v1.30.4+k3s1")
    }

    @Test func parsesPlainListFallback() throws {
        let output = """
        PROFILE STATUS ARCH CPUS MEMORY DISK RUNTIME ADDRESS
        default Running aarch64 2 4GiB 60GiB docker 192.168.5.15
        """

        let profiles = try ColimaOutputParser().parseList(output)

        #expect(profiles.count == 1)
        #expect(profiles[0].name == "default")
        #expect(profiles[0].state == .running)
        #expect(profiles[0].runtime == .docker)
    }

    @Test func parsesListJSONArrayAndMissingOptionalColumns() throws {
        let output = """
        [
          {"name":"default","status":"Running","runtime":"docker"},
          {"name":"lab","status":"Stopped","arch":"aarch64"}
        ]
        """

        let profiles = try ColimaOutputParser().parseList(output)

        #expect(profiles.map(\.name) == ["default", "lab"])
        #expect(profiles[0].resources?.cpu == 0)
        #expect(profiles[1].runtime == nil)
    }

    @Test func plainListIgnoresLogLinesAndAllowsEmptyProfileSet() throws {
        let output = """
        INFO[0000] listing profiles
        PROFILE STATUS ARCH CPUS MEMORY DISK RUNTIME ADDRESS
        """

        let profiles = try ColimaOutputParser().parseList(output)
        #expect(profiles.isEmpty)
    }

    @Test func rejectsUnsafeProfileNamesFromListOutput() throws {
        let output = """
        {"name":"../secrets","status":"Running","runtime":"docker"}
        """

        #expect(throws: ColimaOutputParserError.unsafeProfileName("../secrets")) {
            _ = try ColimaOutputParser().parseList(output)
        }
    }
}

@MainActor
struct ColimaCLITests {
    @Test func missingColimaThrowsBeforeList() async {
        let cli = LiveColimaCLI(
            processRunner: FakeProcessRunner(),
            toolLocator: FakeToolLocator(urls: [:])
        )

        await #expect(throws: ColimaCLIError.missingColima) {
            _ = try await cli.listProfiles()
        }
    }

    @Test func listUsesJSONFlagAndParsesProfiles() async throws {
        let runner = FakeProcessRunner(results: [
            "colima list --json": ProcessResult(
                request: ProcessRequest(arguments: ["colima", "list", "--json"]),
                exitCode: 0,
                stdout: #"{"name":"default","status":"Running","arch":"aarch64","cpus":2,"memory":2147483648,"disk":107374182400,"runtime":"docker"}"#,
                stderr: ""
            )
        ])
        let cli = LiveColimaCLI(
            processRunner: runner,
            toolLocator: FakeToolLocator(urls: ["colima": URL(fileURLWithPath: "/opt/homebrew/bin/colima")])
        )

        let profiles = try await cli.listProfiles()

        #expect(profiles.map(\.name) == ["default"])
        #expect(runner.requests.map { $0.arguments.joined(separator: " ") }.contains("list --json"))
        #expect(runner.requests.last?.executableURL.path == "/opt/homebrew/bin/colima")
    }

    @Test func colimaCommandsReceiveResolvedToolSearchPath() async throws {
        let runner = FakeProcessRunner(allowUnmatchedSuccess: true)
        let cli = LiveColimaCLI(
            processRunner: runner,
            toolLocator: FakeToolLocator(urls: ["colima": URL(fileURLWithPath: "/opt/homebrew/bin/colima")])
        )

        _ = try await cli.listProfiles()

        #expect(runner.requests.last?.environment["PATH"] == "/opt/homebrew/bin:/usr/local/bin")
    }

    @Test func processFailuresRedactSensitiveArguments() async throws {
        let runner = ThrowingProcessRunner(
            error: ProcessRunnerError.timedOut(
                executablePath: "/opt/homebrew/bin/colima",
                arguments: ["start", "--token", "hunter2", "API_TOKEN=abc123"],
                timeout: 1
            )
        )
        let cli = LiveColimaCLI(
            processRunner: runner,
            toolLocator: FakeToolLocator(urls: ["colima": URL(fileURLWithPath: "/opt/homebrew/bin/colima")])
        )

        do {
            _ = try await cli.listProfiles()
            Issue.record("Expected listProfiles to fail")
        } catch {
            let message = error.localizedDescription
            #expect(message.contains("--token <redacted>"))
            #expect(message.contains("API_TOKEN=<redacted>"))
            #expect(!message.contains("hunter2"))
            #expect(!message.contains("abc123"))
        }
    }

    @Test func processCancellationPropagatesWithoutProcessFailureWrapping() async {
        let cli = LiveColimaCLI(
            processRunner: ThrowingProcessRunner(error: CancellationError()),
            toolLocator: FakeToolLocator(urls: ["colima": URL(fileURLWithPath: "/opt/homebrew/bin/colima")])
        )

        await #expect(throws: CancellationError.self) {
            _ = try await cli.listProfiles()
        }
    }

    @Test func diagnosticsReportStoppedColimaSeparatelyFromInstalledCLI() async throws {
        let runner = FakeProcessRunner(results: [
            "version": ProcessResult(
                request: ProcessRequest(arguments: ["colima", "version"]),
                exitCode: 0,
                stdout: "colima version 0.10.1",
                stderr: ""
            ),
            "colima status --json": ProcessResult(
                request: ProcessRequest(arguments: ["colima", "status", "--json"], environment: ["COLIMA_PROFILE": "default"]),
                exitCode: 1,
                stdout: "",
                stderr: "FATA[0000] colima is not running"
            ),
            "version --format {{.Client.Version}}": ProcessResult(
                request: ProcessRequest(arguments: ["docker", "version", "--format", "{{.Client.Version}}"]),
                exitCode: 0,
                stdout: "28.2.2",
                stderr: ""
            ),
            "docker context show": ProcessResult(
                request: ProcessRequest(arguments: ["docker", "context", "show"]),
                exitCode: 0,
                stdout: "desktop-linux",
                stderr: ""
            ),
            "version --format {{.Server.Version}}": ProcessResult(
                request: ProcessRequest(arguments: ["docker", "version", "--format", "{{.Server.Version}}"]),
                exitCode: 0,
                stdout: "28.2.2",
                stderr: ""
            )
        ])
        let cli = LiveColimaCLI(
            processRunner: runner,
            toolLocator: FakeToolLocator(urls: [
                "colima": URL(fileURLWithPath: "/opt/homebrew/bin/colima"),
                "docker": URL(fileURLWithPath: "/usr/local/bin/docker")
            ])
        )

        let diagnostics = await cli.diagnostics()

        #expect(diagnostics.tools.first(where: { $0.id == "colima" })?.availability == .available(path: "/opt/homebrew/bin/colima", version: "colima version 0.10.1"))
        #expect(diagnostics.colima.state == .stopped)
        #expect(diagnostics.colima.error.contains("colima is not running"))
        #expect(!diagnostics.docker.available)
        #expect(diagnostics.docker.error == "Colima default is stopped")
    }

    @Test func diagnosticsUsesExplicitColimaDockerContextWhenActiveContextDiffers() async throws {
        let runner = FakeProcessRunner(results: [
            "version": ProcessResult(
                request: ProcessRequest(arguments: ["colima", "version"]),
                exitCode: 0,
                stdout: "colima version 0.10.1",
                stderr: ""
            ),
            "colima status --json": ProcessResult(
                request: ProcessRequest(arguments: ["colima", "status", "--json"], environment: ["COLIMA_PROFILE": "default"]),
                exitCode: 0,
                stdout: #"{"display_name":"colima","runtime":"docker","kubernetes":false}"#,
                stderr: ""
            ),
            "version --format {{.Client.Version}}": ProcessResult(
                request: ProcessRequest(arguments: ["docker", "version", "--format", "{{.Client.Version}}"]),
                exitCode: 0,
                stdout: "29.2.1",
                stderr: ""
            ),
            "docker context show": ProcessResult(
                request: ProcessRequest(arguments: ["docker", "context", "show"]),
                exitCode: 0,
                stdout: "desktop-linux",
                stderr: ""
            ),
            "--context colima version --format {{.Server.Version}}": ProcessResult(
                request: ProcessRequest(arguments: ["docker", "--context", "colima", "version", "--format", "{{.Server.Version}}"]),
                exitCode: 0,
                stdout: "29.2.1",
                stderr: ""
            )
        ])
        let cli = LiveColimaCLI(
            processRunner: runner,
            toolLocator: FakeToolLocator(urls: [
                "colima": URL(fileURLWithPath: "/opt/homebrew/bin/colima"),
                "docker": URL(fileURLWithPath: "/usr/local/bin/docker")
            ])
        )

        let diagnostics = await cli.diagnostics()

        #expect(diagnostics.docker.available)
        #expect(diagnostics.docker.context == "colima")
        #expect(diagnostics.docker.version == "29.2.1")
        #expect(diagnostics.docker.error.isEmpty)
    }

    @Test func statusTreatsNotRunningAsStopped() async throws {
        let runner = FakeProcessRunner(results: [
            "colima status --json": ProcessResult(
                request: ProcessRequest(arguments: ["colima", "status", "--json"], environment: ["COLIMA_PROFILE": "dev"]),
                exitCode: 1,
                stdout: "",
                stderr: "colima is not running"
            )
        ])
        let cli = LiveColimaCLI(
            processRunner: runner,
            toolLocator: FakeToolLocator(urls: ["colima": URL(fileURLWithPath: "/opt/homebrew/bin/colima")])
        )

        let detail = try await cli.status(profile: "dev")

        #expect(detail.state == .stopped)
        #expect(runner.requests.last?.environment["COLIMA_PROFILE"] == "dev")
    }

    @Test func statusThrowsForUnexpectedNonzeroOutput() async {
        let runner = FakeProcessRunner(results: [
            "colima status --json": ProcessResult(
                request: ProcessRequest(arguments: ["colima", "status", "--json"], environment: ["COLIMA_PROFILE": "dev"]),
                exitCode: 2,
                stdout: "",
                stderr: "permission denied"
            )
        ])
        let cli = LiveColimaCLI(
            processRunner: runner,
            toolLocator: FakeToolLocator(urls: ["colima": URL(fileURLWithPath: "/opt/homebrew/bin/colima")])
        )

        await #expect(throws: ColimaCLIError.commandFailed(command: "/opt/homebrew/bin/colima status --json", exitStatus: 2, stdout: "", stderr: "permission denied")) {
            _ = try await cli.status(profile: "dev")
        }
    }

    @Test func commandFailureRedactsSensitiveArguments() async throws {
        let runner = FakeProcessRunner(
            fallbackResult: ProcessResult(
                request: ProcessRequest(arguments: []),
                exitCode: 1,
                stdout: "",
                stderr: "failed"
            )
        )
        let cli = LiveColimaCLI(
            processRunner: runner,
            toolLocator: FakeToolLocator(urls: ["colima": URL(fileURLWithPath: "/opt/homebrew/bin/colima")])
        )
        var config = ProfileConfiguration.default
        config.additionalArgs = ["--token", "hunter2"]

        do {
            _ = try await cli.start(config)
            Issue.record("Expected start to fail")
        } catch {
            let message = error.localizedDescription
            #expect(message.contains("--token <redacted>"))
            #expect(!message.contains("hunter2"))
        }
    }

    @Test func logsReadDaemonLogFileWithoutInvokingColima() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let logURL = root.appendingPathComponent("dev/daemon/daemon.log")
        try FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "daemon ready".write(to: logURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: root) }
        let runner = FakeProcessRunner(allowUnmatchedSuccess: true)
        let cli = LiveColimaCLI(
            processRunner: runner,
            toolLocator: FakeToolLocator(urls: [:]),
            environment: ["COLIMA_HOME": root.path]
        )

        let logs = try await cli.logs(profile: "dev")

        #expect(logs == "daemon ready")
        #expect(runner.requests.isEmpty)
    }

    @Test func readsStoredProfileConfiguration() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let configURL = root.appendingPathComponent("dev/colima.yaml")
        try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        cpu: 6
        memory: 12
        disk: 120
        runtime: containerd
        vmType: vz
        arch: aarch64
        mountType: virtiofs
        portForwarder: grpc
        kubernetes:
          enabled: true
          version: v1.30.4+k3s1
          k3sArgs:
            - "--disable=traefik"
            - "--disable=servicelb"
          k3sListenPort: 6443
        network:
          address: true
          mode: bridged
          interface: en0
        mounts:
          - location: /Users/me/src
            mountPoint: /src
            writable: true
        """.write(to: configURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: root) }
        let cli = LiveColimaCLI(
            processRunner: FakeProcessRunner(),
            toolLocator: FakeToolLocator(urls: [:]),
            environment: ["COLIMA_HOME": root.path]
        )

        let configuration = try #require(try await cli.configuration(profile: "dev"))

        #expect(configuration.name == "dev")
        #expect(configuration.resources == ResourceAllocation(cpu: 6, memoryGiB: 12, diskGiB: 120))
        #expect(configuration.runtime == .containerd)
        #expect(configuration.vmType == .vz)
        #expect(configuration.mountType == .virtiofs)
        #expect(configuration.kubernetes.enabled)
        #expect(configuration.k3sArgs == ["--disable=traefik", "--disable=servicelb"])
        #expect(configuration.k3sListenPort == 6443)
        #expect(configuration.network.mode == "bridged")
        #expect(configuration.mounts.first?.commandValue == "/Users/me/src:/src:w")
    }

    @Test func readsTemplateFromColimaHomeWithoutInvokingProcess() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let templateURL = root.appendingPathComponent("_templates/default.yaml")
        try FileManager.default.createDirectory(at: templateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "cpu: 4\nmemory: 8\n".write(to: templateURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: root) }

        let runner = FakeProcessRunner(allowUnmatchedSuccess: true)
        let cli = LiveColimaCLI(
            processRunner: runner,
            toolLocator: FakeToolLocator(urls: [:]),
            environment: ["COLIMA_HOME": root.path]
        )

        let template = try await cli.template()

        #expect(template.contains("cpu: 4"))
        #expect(runner.requests.isEmpty)
    }

    @Test func profileConfigurationDocumentReadsExpectedPath() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let configURL = root.appendingPathComponent("dev/colima.yaml")
        try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "cpu: 4\n".write(to: configURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: root) }

        let cli = LiveColimaCLI(
            processRunner: FakeProcessRunner(),
            toolLocator: FakeToolLocator(urls: [:]),
            environment: ["COLIMA_HOME": root.path]
        )

        let document = try cli.profileConfigurationDocument(profile: "dev")

        #expect(document.kind == .profileConfiguration)
        #expect(document.profileName == "dev")
        #expect(document.url == configURL)
        #expect(document.contents == "cpu: 4\n")
        #expect(document.lastModified != nil)
    }

    @Test func rejectsUnsafeProfileNamesBeforePathUseOrProcessExecution() async {
        let runner = FakeProcessRunner(allowUnmatchedSuccess: true)
        let cli = LiveColimaCLI(
            processRunner: runner,
            toolLocator: FakeToolLocator(urls: ["colima": URL(fileURLWithPath: "/opt/homebrew/bin/colima")])
        )

        await #expect(throws: ColimaCLIError.self) {
            _ = try await cli.status(profile: "../secrets")
        }
        #expect(throws: ColimaCLIError.self) {
            _ = try cli.profileConfigurationDocument(profile: "../secrets")
        }
        #expect(runner.requests.isEmpty)
    }

    @Test func unsafeEnvironmentProfileFallsBackToDefaultForDiagnostics() async {
        let runner = FakeProcessRunner(results: [
            "version": ProcessResult(
                request: ProcessRequest(arguments: ["colima", "version"]),
                exitCode: 0,
                stdout: "colima version 0.10.1",
                stderr: ""
            ),
            "colima status --json": ProcessResult(
                request: ProcessRequest(arguments: ["colima", "status", "--json"], environment: ["COLIMA_PROFILE": "default"]),
                exitCode: 1,
                stdout: "",
                stderr: "colima is not running"
            )
        ])
        let cli = LiveColimaCLI(
            processRunner: runner,
            toolLocator: FakeToolLocator(urls: ["colima": URL(fileURLWithPath: "/opt/homebrew/bin/colima")]),
            environment: ["COLIMA_PROFILE": "../secrets"]
        )

        let diagnostics = await cli.diagnostics()

        #expect(diagnostics.colima.profileName == "default")
        #expect(runner.requests.contains { $0.environment["COLIMA_PROFILE"] == "default" })
    }

    @Test func sshConfigurationDocumentPrefersCLIOutput() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sshConfigURL = root.appendingPathComponent("ssh_config")
        try FileManager.default.createDirectory(at: sshConfigURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "Host stale\n".write(to: sshConfigURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: root) }

        let runner = FakeProcessRunner(results: [
            "colima ssh-config --layer=true": ProcessResult(
                request: ProcessRequest(arguments: ["colima", "ssh-config", "--layer=true"]),
                exitCode: 0,
                stdout: "Host colima\n  Port 60022\n",
                stderr: ""
            )
        ])
        let cli = LiveColimaCLI(
            processRunner: runner,
            toolLocator: FakeToolLocator(urls: ["colima": URL(fileURLWithPath: "/opt/homebrew/bin/colima")]),
            environment: ["COLIMA_HOME": root.path]
        )

        let document = try await cli.sshConfigurationDocument(profile: "dev", layer: true)

        #expect(document.kind == .sshConfiguration)
        #expect(document.profileName == "dev")
        #expect(document.url == sshConfigURL)
        #expect(document.contents.contains("Port 60022"))
        #expect(runner.requests.last?.environment["COLIMA_PROFILE"] == "dev")
    }

    @Test func editCommandsUseExpectedArguments() async throws {
        let runner = FakeProcessRunner(allowUnmatchedSuccess: true)
        let cli = LiveColimaCLI(
            processRunner: runner,
            toolLocator: FakeToolLocator(urls: ["colima": URL(fileURLWithPath: "/opt/homebrew/bin/colima")])
        )

        _ = try await cli.editTemplate(.init(profileName: "default", editor: "code"))
        _ = try await cli.editProfileConfiguration(.init(profileName: "dev", editor: "zed"))
        _ = try await cli.ssh(.init(profileName: "dev", layer: false, command: ["docker", "ps"]))

        let commands = runner.requests.map { $0.arguments.joined(separator: " ") }
        #expect(commands == [
            "template --editor code",
            "start --edit --editor zed",
            "ssh --layer=false -- docker ps"
        ])
        #expect(runner.requests[0].environment["COLIMA_PROFILE"] == "default")
        #expect(runner.requests[1].environment["COLIMA_PROFILE"] == "dev")
        #expect(runner.requests[2].environment["COLIMA_PROFILE"] == "dev")
    }

    @Test func invalidStartConfigurationThrowsBeforeProcessExecution() async {
        let runner = FakeProcessRunner(allowUnmatchedSuccess: true)
        let cli = LiveColimaCLI(
            processRunner: runner,
            toolLocator: FakeToolLocator(urls: ["colima": URL(fileURLWithPath: "/opt/homebrew/bin/colima")])
        )
        var config = ProfileConfiguration.default
        config.name = "bad name"

        await #expect(throws: ColimaCLIError.self) {
            _ = try await cli.start(config)
        }
        #expect(runner.requests.isEmpty)
    }

    @Test func defaultStartOmitsHostArchSharedNetworkAndBlankValues() async throws {
        let runner = FakeProcessRunner(allowUnmatchedSuccess: true)
        let cli = LiveColimaCLI(
            processRunner: runner,
            toolLocator: FakeToolLocator(urls: ["colima": URL(fileURLWithPath: "/opt/homebrew/bin/colima")])
        )
        var config = ProfileConfiguration.default
        config.runtime = .none
        config.network.interface = ""
        config.network.dnsResolvers = [""]
        config.k3sArgs = [""]

        _ = try await cli.start(config)

        let command = try #require(runner.requests.last?.arguments.joined(separator: " "))
        #expect(!command.contains("--runtime"))
        #expect(!command.contains("--arch"))
        #expect(!command.contains("--network-mode shared"))
        #expect(!command.contains("--network-interface"))
        #expect(!command.contains("--dns"))
        #expect(!command.contains("--k3s-arg"))
        #expect(runner.requests.last?.environment["COLIMA_PROFILE"] == "default")
    }

    @Test func startBuildsExpectedCommand() async throws {
        let runner = FakeProcessRunner(allowUnmatchedSuccess: true)
        let cli = LiveColimaCLI(
            processRunner: runner,
            toolLocator: FakeToolLocator(urls: ["colima": URL(fileURLWithPath: "/opt/homebrew/bin/colima")])
        )
        let mountURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("colima-stack-start-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: mountURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: mountURL) }
        var config = ProfileConfiguration.default
        config.name = "dev"
        config.resources = ResourceAllocation(cpu: 6, memoryGiB: 12, diskGiB: 120)
        config.runtime = .containerd
        config.vmType = .vz
        config.architecture = .x86_64
        config.mountType = .virtiofs
        config.mounts = [MountConfiguration(localPath: mountURL.path, vmPath: "/src", writable: true)]
        config.network = NetworkConfiguration(networkAddress: true, mode: "bridged", interface: "en0", dnsResolvers: ["1.1.1.1"])
        config.portForwarder = .grpc
        config.rosetta = true
        config.nestedVirtualization = true
        config.kubernetes = KubernetesConfig(enabled: true, version: "v1.30.4+k3s1", context: "colima-dev")
        config.k3sArgs = ["--disable=traefik"]
        config.k3sListenPort = 6443

        _ = try await cli.start(config)

        let command = try #require(runner.requests.last?.arguments.joined(separator: " "))
        #expect(command.contains("start"))
        #expect(command.contains("--runtime containerd"))
        #expect(command.contains("--kubernetes=true"))
        #expect(command.contains("--port-forwarder grpc"))
        #expect(command.contains("--network-mode bridged"))
        #expect(command.contains("--vz-rosetta"))
        #expect(command.contains("--nested-virtualization"))
        #expect(command.contains("--k3s-listen-port 6443"))
    }

    @Test func nonStartCommandsUseExpectedSubcommandsAndProfileEnvironment() async throws {
        let runner = FakeProcessRunner(allowUnmatchedSuccess: true)
        let cli = LiveColimaCLI(
            processRunner: runner,
            toolLocator: FakeToolLocator(urls: ["colima": URL(fileURLWithPath: "/opt/homebrew/bin/colima")])
        )

        _ = try await cli.stop(profile: "dev")
        _ = try await cli.restart(profile: "dev")
        _ = try await cli.delete(profile: "dev")
        _ = try await cli.update(profile: "dev")
        _ = try await cli.kubernetes(profile: "dev", enabled: true)
        _ = try await cli.kubernetes(profile: "dev", enabled: false)

        let commands = runner.requests.map { $0.arguments.joined(separator: " ") }
        #expect(commands == [
            "stop",
            "restart",
            "delete --force",
            "update",
            "kubernetes start",
            "kubernetes stop"
        ])
        #expect(runner.requests[4].timeout == 180)
        #expect(runner.requests[5].timeout == 180)
        #expect(runner.requests.allSatisfy { $0.environment["COLIMA_PROFILE"] == "dev" })
    }
}

struct CommandRunServiceTests {
    @Test func liveCommandRunnerUsesResolvedToolPathByDefaultAndRedactsSecrets() async throws {
        let runner = FakeProcessRunner(results: [
            "ps --password hunter2": ProcessResult(
                request: ProcessRequest(
                    executableURL: URL(fileURLWithPath: "/opt/homebrew/bin/docker"),
                    arguments: ["ps", "--password", "hunter2"],
                    environment: ["API_TOKEN": "abc123"]
                ),
                exitCode: 1,
                stdout: "TOKEN=abc123 Bearer deadbeef",
                stderr: #"{"password":"hunter2"}"#
            )
        ])
        let service = LiveCommandRunService(
            processRunner: AsyncProcessRunnerAdapter(processRunner: runner),
            toolLocator: FakeToolLocator(urls: ["docker": URL(fileURLWithPath: "/opt/homebrew/bin/docker")])
        )

        let run = try await service.run(
            ManagedCommandRequest(
                toolName: "docker",
                arguments: ["ps", "--password", "hunter2"],
                environment: ["API_TOKEN": "abc123"],
                purpose: "List containers"
            )
        )

        #expect(runner.requests.last?.executableURL.path == "/opt/homebrew/bin/docker")
        #expect(runner.requests.last?.arguments == ["ps", "--password", "hunter2"])
        #expect(run.commandString == "/opt/homebrew/bin/docker ps --password <redacted>")
        #expect(run.request.environment["API_TOKEN"] == "<redacted>")
        #expect(!run.standardOutput.contains("abc123"))
        #expect(!run.standardOutput.contains("deadbeef"))
        #expect(!run.standardError.contains("hunter2"))
    }

    @Test func commandRunnerOnlyForwardsExplicitParentEnvironmentKeys() async throws {
        let runner = FakeProcessRunner(allowUnmatchedSuccess: true)
        let service = LiveCommandRunService(
            processRunner: AsyncProcessRunnerAdapter(processRunner: runner),
            toolLocator: FakeToolLocator(urls: ["docker": URL(fileURLWithPath: "/opt/homebrew/bin/docker")]),
            environment: [
                "COLIMA_HOME": "/tmp/colima-home",
                "COLIMA_SECRET": "leak-me",
                "DOCKER_CONTEXT": "colima",
                "API_TOKEN": "leak-me-too"
            ]
        )

        _ = try await service.run(
            ManagedCommandRequest(
                toolName: "docker",
                arguments: ["ps"],
                purpose: "List containers"
            )
        )

        let environment = try #require(runner.requests.last?.environment)
        #expect(environment["COLIMA_HOME"] == "/tmp/colima-home")
        #expect(environment["DOCKER_CONTEXT"] == "colima")
        #expect(environment["COLIMA_SECRET"] == nil)
        #expect(environment["API_TOKEN"] == nil)
    }

    @Test func commandRunnerRedactsProcessFailureDescriptions() async throws {
        let runner = ThrowingProcessRunner(
            error: ProcessRunnerError.timedOut(
                executablePath: "/opt/homebrew/bin/docker",
                arguments: ["login", "--password", "hunter2"],
                timeout: 1
            )
        )
        let service = LiveCommandRunService(
            processRunner: AsyncProcessRunnerAdapter(processRunner: runner),
            toolLocator: FakeToolLocator(urls: ["docker": URL(fileURLWithPath: "/opt/homebrew/bin/docker")])
        )

        do {
            _ = try await service.run(
                ManagedCommandRequest(
                    toolName: "docker",
                    arguments: ["login", "--password", "hunter2"],
                    purpose: "Login"
                )
            )
            Issue.record("Expected command runner to fail")
        } catch {
            let message = error.localizedDescription
            #expect(message.contains("--password <redacted>"))
            #expect(!message.contains("hunter2"))
        }
    }

    @Test func commandRunnerPreservesCancellationErrors() async {
        let service = LiveCommandRunService(
            processRunner: AsyncProcessRunnerAdapter(processRunner: ThrowingProcessRunner(error: CancellationError())),
            toolLocator: FakeToolLocator(urls: ["docker": URL(fileURLWithPath: "/opt/homebrew/bin/docker")])
        )

        await #expect(throws: CancellationError.self) {
            _ = try await service.run(
                ManagedCommandRequest(
                    toolName: "docker",
                    arguments: ["ps"],
                    purpose: "List containers"
                )
            )
        }
    }

    @Test func fakeProcessRunnerThrowsWhenResultIsMissing() {
        let runner = FakeProcessRunner()

        #expect(throws: TestError.self) {
            _ = try runner.run(ProcessRequest(arguments: ["missing"]))
        }
    }
}

struct RedactionTests {
    @Test func redactsSensitiveEnvironmentArgumentsAndText() {
        #expect(EnvironmentRedactor.redacted(["API_TOKEN": "abc123"]) == ["API_TOKEN": "<redacted>"])
        #expect(EnvironmentRedactor.redacted(["--token=abc123", "--password", "hunter2", "USER=dyllon"]) == ["--token=<redacted>", "--password", "<redacted>", "USER=dyllon"])
        let text = EnvironmentRedactor.redacted(#"TOKEN=abc123 {"password":"hunter2"} Authorization: Bearer deadbeef"#)
        #expect(!text.contains("abc123"))
        #expect(!text.contains("hunter2"))
        #expect(!text.contains("deadbeef"))
    }
}

struct ToolLocatorTests {
    @Test func liveLocatorFallsBackToHomebrewStylePaths() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let bin = root.appendingPathComponent("bin")
        let tool = bin.appendingPathComponent("colima")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: tool.path, contents: Data())
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tool.path)
        defer { try? FileManager.default.removeItem(at: root) }

        let locator = LiveToolLocator(environment: ["PATH": "/usr/bin"], fallbackSearchPaths: [bin.path])

        #expect(locator.locate("colima") == tool)
        #expect(locator.searchPaths() == ["/usr/bin", bin.path])
    }
}

struct ProcessRunnerTests {
    @Test func liveRunnerDoesNotInheritSensitiveParentEnvironment() throws {
        let runner = LiveProcessRunner(
            baseEnvironment: [
                "HOME": "/tmp/colima-stack-home",
                "PATH": "/usr/bin:/bin",
                "SECRET_TOKEN": "must-not-leak"
            ]
        )

        let result = try runner.run(
            ProcessRequest(
                executableURL: URL(fileURLWithPath: "/usr/bin/env"),
                environment: ["COLIMA_PROFILE": "dev"]
            )
        )

        #expect(result.standardOutput.contains("HOME=/tmp/colima-stack-home"))
        #expect(result.standardOutput.contains("COLIMA_PROFILE=dev"))
        #expect(!result.standardOutput.contains("SECRET_TOKEN=must-not-leak"))
    }

    @Test func liveRunnerWritesStandardInputAfterLaunch() throws {
        let runner = LiveProcessRunner(baseEnvironment: ["PATH": "/usr/bin:/bin"])

        let result = try runner.run(
            ProcessRequest(
                executableURL: URL(fileURLWithPath: "/bin/cat"),
                standardInput: Data("hello stdin".utf8)
            )
        )

        #expect(result.standardOutput == "hello stdin")
        #expect(result.terminationStatus == 0)
    }

    @Test func liveRunnerTimesOutWhenChildDoesNotReadLargeStandardInput() throws {
        let runner = LiveProcessRunner(baseEnvironment: ["PATH": "/usr/bin:/bin"])
        let startedAt = Date()

        do {
            _ = try runner.run(
                ProcessRequest(
                    executableURL: URL(fileURLWithPath: "/bin/sleep"),
                    arguments: ["2"],
                    standardInput: Data(repeating: 120, count: 5 * 1_024 * 1_024),
                    timeout: 0.2
                )
            )
            Issue.record("Expected large stdin write to time out while child is not reading")
        } catch ProcessRunnerError.timedOut {
        } catch {
            Issue.record("Expected timeout, got \(error)")
        }

        #expect(Date().timeIntervalSince(startedAt) < 1.5)
    }

    @Test func liveRunnerCapsCapturedOutput() throws {
        let runner = LiveProcessRunner(baseEnvironment: ["PATH": "/usr/bin:/bin"], outputLimitBytes: 8)

        let result = try runner.run(
            ProcessRequest(
                executableURL: URL(fileURLWithPath: "/bin/sh"),
                arguments: ["-c", "printf 0123456789abcdef"]
            )
        )

        #expect(result.standardOutput.hasPrefix("01234567"))
        #expect(result.standardOutput.contains("[output truncated; dropped 8 bytes]"))
        #expect(result.standardOutputTruncated)
        #expect(!result.standardErrorTruncated)
    }

    @Test func asyncLiveRunnerCancelsSpawnedProcess() async throws {
        let runner = AsyncProcessRunnerAdapter(
            processRunner: LiveProcessRunner(baseEnvironment: ["PATH": "/usr/bin:/bin"])
        )
        let task = Task {
            try await runner.run(
                ProcessRequest(
                    executableURL: URL(fileURLWithPath: "/bin/sh"),
                    arguments: ["-c", "sleep 30"]
                )
            )
        }

        try await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()

        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
    }
}

@MainActor
struct ProfileConfigurationTests {
    @Test func validatesProfileConfig() {
        var config = ProfileConfiguration.default
        config.name = "bad name"
        config.resources.cpu = 0

        #expect(config.validationErrors.contains("Profile name can only contain letters, numbers, dots, underscores, and hyphens, and must start with a letter or number."))
        #expect(config.validationErrors.filter { $0.hasPrefix("Profile name") }.count == 1)
        #expect(config.validationErrors.contains("CPU must be at least 1."))
    }

    @Test func validatesMountExistenceAsynchronously() async {
        let missingPath = "/tmp/colima-stack-missing-\(UUID().uuidString)"
        var config = ProfileConfiguration.default
        config.mounts = [MountConfiguration(localPath: missingPath, vmPath: "/workspace", writable: true)]

        let expectedError = "Mount local path '\(missingPath)' does not exist."
        #expect(!config.validationErrors.contains(expectedError))
        #expect(await config.validationErrorsCheckingFilesystem().contains(expectedError))
    }

    @Test func rejectsManagedAdditionalArguments() {
        var config = ProfileConfiguration.default
        config.additionalArgs = ["--profile", "other", "--runtime=docker", " --force", "-p", "-f"]

        #expect(config.validationErrors.contains("Additional CLI arg '--profile' is managed by Colima Stack and cannot be overridden."))
        #expect(config.validationErrors.contains("Additional CLI arg '--runtime' is managed by Colima Stack and cannot be overridden."))
        #expect(config.validationErrors.contains("Additional CLI arg '--force' cannot start or end with whitespace."))
        #expect(config.validationErrors.contains("Additional CLI arg '--force' is managed by Colima Stack and cannot be overridden."))
        #expect(config.validationErrors.contains("Additional CLI arg '-p' cannot use short flags. Use the explicit long flag form."))
        #expect(config.validationErrors.contains("Additional CLI arg '-f' cannot use short flags. Use the explicit long flag form."))
    }
}

@MainActor
struct AppStateTests {
    @Test func refreshSyncsProfilesAndDetails() async {
        let cli = StatefulFakeColima()
        let state = AppState(colima: cli)

        await state.refreshAll()

        #expect(state.profiles.count == 1)
        #expect(state.selectedProfileID == "default")
        #expect(state.selectedProfileDetail?.state == .running)
        #expect(state.logs.contains("ready"))
    }

    @Test func refreshMissingColimaClearsState() async {
        let cli = StatefulFakeColima()
        cli.listError = ColimaCLIError.missingColima
        let state = AppState(colima: cli, profiles: [StatefulFakeColima.profile(named: "old")])
        state.selectedProfileDetail = StatefulFakeColima.detail(profile: "old")
        state.logs = "old logs"

        await state.refreshAll()

        #expect(state.profiles.isEmpty)
        #expect(state.selectedProfileDetail == nil)
        #expect(state.logs.isEmpty)
    }

    @Test func refreshGenericListFailureSurfacesError() async {
        let cli = StatefulFakeColima()
        cli.listError = TestError(message: "list failed")
        let state = AppState(colima: cli)

        await state.refreshAll()

        #expect(state.presentedError?.message == "list failed")
    }

    @Test func refreshPreservesRuntimeContextFieldsWhenStatusRefreshFails() async {
        let cli = StatefulFakeColima()
        cli.profiles = [StatefulFakeColima.shallowProfile(named: "default")]
        cli.statusError = TestError(message: "status failed")
        var previousProfile = StatefulFakeColima.profile(named: "default")
        previousProfile.ipAddress = "192.168.5.15"
        previousProfile.socket = "unix:///tmp/docker.sock"
        let state = AppState(colima: cli, profiles: [previousProfile])
        state.selectedProfileID = "default"

        await state.refreshAll()

        let profile = state.selectedProfile
        #expect(profile?.architecture == .aarch64)
        #expect(profile?.resources == .standard)
        #expect(profile?.vmType == .qemu)
        #expect(profile?.mountType == .sshfs)
        #expect(profile?.socket == "unix:///tmp/docker.sock")
        #expect(profile?.dockerContext == "colima")
        #expect(state.presentedError?.message == "status failed")
    }

    @Test func refreshResetsStaleSelectionToFirstProfile() async {
        let cli = StatefulFakeColima()
        cli.profiles = [StatefulFakeColima.profile(named: "new")]
        let state = AppState(colima: cli)
        state.selectedProfileID = "deleted"

        await state.refreshAll()

        #expect(state.selectedProfileID == "new")
    }

    @Test func failedApplyKeepsEditorOpenAndRecordsFailure() async {
        let cli = StatefulFakeColima()
        cli.commandError = TestError(message: "start failed")
        let state = AppState(colima: cli)
        state.isShowingProfileEditor = true
        state.editingConfiguration = .default

        await state.saveEditingConfiguration()

        #expect(state.isShowingProfileEditor)
        #expect(state.activeOperation == nil)
        #expect(state.presentedError?.message == "start failed")
        guard case .failed("start failed") = state.commandLog.first?.status else {
            Issue.record("Expected failed command entry")
            return
        }
    }
}

struct TestError: LocalizedError, Equatable {
    var message: String
    var errorDescription: String? { message }
}

final class FakeToolLocator: ToolLocator {
    var urls: [String: URL]

    init(urls: [String: URL]) {
        self.urls = urls
    }

    func locate(_ toolName: String) -> URL? {
        urls[toolName]
    }

    func require(_ toolName: String) throws -> URL {
        if let url = locate(toolName) {
            return url
        }
        throw ToolLocatorError.toolNotFound(name: toolName, searchPaths: ["/opt/homebrew/bin", "/usr/local/bin"])
    }

    func searchPaths() -> [String] {
        ["/opt/homebrew/bin", "/usr/local/bin"]
    }
}

final class FakeProcessRunner: ProcessRunner {
    var results: [String: ProcessResult]
    var fallbackResult: ProcessResult?
    var allowUnmatchedSuccess: Bool
    private(set) var requests: [ProcessRequest] = []

    init(results: [String: ProcessResult] = [:], fallbackResult: ProcessResult? = nil, allowUnmatchedSuccess: Bool = false) {
        self.results = results
        self.fallbackResult = fallbackResult
        self.allowUnmatchedSuccess = allowUnmatchedSuccess
    }

    func run(_ request: ProcessRequest) throws -> ProcessResult {
        requests.append(request)
        let argumentKey = request.arguments.joined(separator: " ")
        let executableKey = ([request.executableURL.lastPathComponent] + request.arguments).joined(separator: " ")
        if let result = results[argumentKey] ?? results[executableKey] ?? fallbackResult {
            return ProcessResult(
                executableURL: request.executableURL,
                arguments: request.arguments,
                environment: request.environment,
                launchedAt: result.launchedAt,
                duration: result.duration,
                terminationStatus: result.terminationStatus,
                standardOutput: result.standardOutput,
                standardError: result.standardError,
                standardOutputTruncated: result.standardOutputTruncated,
                standardErrorTruncated: result.standardErrorTruncated
            )
        }
        if allowUnmatchedSuccess {
            return ProcessResult(request: request, exitCode: 0, stdout: "", stderr: "")
        }
        let message = "No fake process result for '\(argumentKey)' or '\(executableKey)'"
        throw TestError(message: message)
    }
}

final class ThrowingProcessRunner: ProcessRunner {
    let error: Error
    private(set) var requests: [ProcessRequest] = []

    init(error: Error) {
        self.error = error
    }

    func run(_ request: ProcessRequest) throws -> ProcessResult {
        requests.append(request)
        throw error
    }
}

final class StatefulFakeColima: ColimaControlling {
    var profiles: [ColimaProfile] = [profile(named: "default")]
    var listError: Error?
    var statusError: Error?
    var logsError: Error?
    var commandError: Error?
    var logsText = "ready"
    var storedConfigurations: [String: ProfileConfiguration] = [:]

    func diagnostics() async -> DiagnosticReport {
        DiagnosticReport(
            tools: [ToolCheck(id: "colima", availability: .available(path: "/opt/homebrew/bin/colima", version: "test"))],
            colima: ColimaRuntimeStatus(profileName: "default", state: .running, output: "", error: ""),
            docker: DockerStatus(available: true, context: "colima", version: "test", error: ""),
            messages: []
        )
    }

    func listProfiles() async throws -> [ColimaProfile] {
        if let listError { throw listError }
        return profiles
    }

    func status(profile: String) async throws -> ColimaStatusDetail {
        if let statusError { throw statusError }
        return Self.detail(profile: profile)
    }

    func logs(profile: String) async throws -> String {
        if let logsError { throw logsError }
        return logsText
    }
    func start(_ configuration: ProfileConfiguration) async throws -> ProcessResult { try result("start") }
    func stop(profile: String) async throws -> ProcessResult { try result("stop") }
    func restart(profile: String) async throws -> ProcessResult { try result("restart") }
    func delete(profile: String) async throws -> ProcessResult { try result("delete") }
    func kubernetes(profile: String, enabled: Bool) async throws -> ProcessResult { try result("kubernetes") }
    func update(profile: String) async throws -> ProcessResult { try result("update") }
    func template() async throws -> String { "" }
    func configuration(profile: String) async throws -> ProfileConfiguration? { storedConfigurations[profile] }

    static func profile(named name: String) -> ColimaProfile {
        ColimaProfile(
            name: name,
            state: .unknown,
            runtime: .docker,
            architecture: .aarch64,
            resources: .standard,
            diskUsage: "",
            ipAddress: "",
            dockerContext: name == "default" ? "colima" : "colima-\(name)",
            kubernetes: .disabled,
            vmType: .qemu,
            mountType: .sshfs,
            socket: "",
            rawSummary: ""
        )
    }

    static func shallowProfile(named name: String) -> ColimaProfile {
        ColimaProfile(
            name: name,
            state: .running,
            runtime: nil,
            architecture: nil,
            resources: nil,
            diskUsage: "",
            ipAddress: "",
            dockerContext: name == "default" ? "colima" : "colima-\(name)",
            kubernetes: .disabled,
            vmType: nil,
            mountType: nil,
            socket: "",
            rawSummary: ""
        )
    }

    static func detail(profile: String) -> ColimaStatusDetail {
        ColimaStatusDetail(
            profileName: profile,
            state: .running,
            runtime: .docker,
            architecture: .aarch64,
            vmType: .qemu,
            mountType: .sshfs,
            resources: .standard,
            kubernetes: .disabled,
            networkAddress: "192.168.5.15",
            socket: "unix:///tmp/docker.sock",
            dockerContext: "colima",
            errors: [],
            rawOutput: ""
        )
    }

    private func result(_ command: String) throws -> ProcessResult {
        if let commandError { throw commandError }
        return ProcessResult(request: ProcessRequest(arguments: ["colima", command]), exitCode: 0, stdout: "ok", stderr: "")
    }
}
