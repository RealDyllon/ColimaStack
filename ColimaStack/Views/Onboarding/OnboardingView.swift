//
//  OnboardingView.swift
//  ColimaStack
//
//  First-run onboarding flow. Three steps: Welcome, Dependency
//  check, Profile creation. The window is its own `Window` scene
//  in `ColimaStackApp`. Implements the onboarding capability from
//  the apple-design-award-ui change.
//

import AppKit
import SwiftUI

// MARK: - First-run flag

public enum OnboardingState {
    public static let didCompleteOnboardingKey = "colimastack.didCompleteOnboarding"

    public static var hasCompleted: Bool {
        UserDefaults.standard.bool(forKey: didCompleteOnboardingKey)
    }

    public static func markCompleted() {
        UserDefaults.standard.set(true, forKey: didCompleteOnboardingKey)
    }

    public static func reset() {
        UserDefaults.standard.removeObject(forKey: didCompleteOnboardingKey)
    }
}

// MARK: - Onboarding step

enum OnboardingStep: Int, CaseIterable, Identifiable, Hashable {
    case welcome
    case dependencies
    case createProfile
    case success

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .dependencies: return "Dependencies"
        case .createProfile: return "Create profile"
        case .success: return "Ready"
        }
    }
}

// MARK: - OnboardingView

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var step: OnboardingStep = .welcome
    @State private var profileName: String = "default"
    @State private var runtime: ColimaRuntime = .docker
    @State private var cpu: Int = 4
    @State private var memoryGiB: Int = 8
    @State private var kubernetesEnabled: Bool = false
    @State private var creationInProgress: Bool = false
    @State private var creationError: String?
    @Environment(\.dismiss) private var dismissWindow

    var body: some View {
        VStack(spacing: 0) {
            progressBar
            Divider()
            ScrollView {
                Group {
                    switch step {
                    case .welcome:
                        welcomeStep
                    case .dependencies:
                        dependenciesStep
                    case .createProfile:
                        createProfileStep
                    case .success:
                        successStep
                    }
                }
                .frame(maxWidth: 720)
                .padding(28)
            }
            .background(Material.regular)
            Divider()
            footer
        }
        .frame(minWidth: 720, minHeight: 520)
        .toolbar { EmptyView() }
    }

    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases) { entry in
                Capsule()
                    .fill(entry.rawValue <= step.rawValue ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 12)
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Icon.brandHero
                    .foregroundStyle(Color.accentColor)
                Text("Welcome to ColimaStack")
                    .font(.system(size: 28, weight: .bold))
                Text("A polished desktop UI for Colima — start, stop, and inspect Colima profiles, runtimes, containers, and Kubernetes clusters from one window.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            SectionCard(title: "What you'll set up", subtitle: "Three quick steps.", symbol: "checklist") {
                VStack(alignment: .leading, spacing: 10) {
                    onboardingBullet(symbol: "1.circle.fill", title: "Verify the CLI toolchain", description: "We'll check that colima, limactl, and Docker are reachable.")
                    onboardingBullet(symbol: "2.circle.fill", title: "Install anything missing", description: "We can copy a brew install command or accept a manual path.")
                    onboardingBullet(symbol: "3.circle.fill", title: "Create your first profile", description: "Pick a name, runtime, and resources — we'll start it for you.")
                }
            }
        }
    }

    private func onboardingBullet(symbol: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var dependenciesStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Check dependencies")
                    .font(.system(size: 24, weight: .bold))
                Text("ColimaStack needs colima, limactl, and Docker on your PATH. We'll point you at the install instructions for anything missing.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            SectionCard(title: "Detected toolchain", subtitle: "Last refreshed \(dateText)", symbol: "wrench.and.screwdriver") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(appState.diagnostics.tools) { tool in
                        RedesignedToolRow(tool: tool)
                    }
                }
            }
            HStack {
                Button {
                    Task { await appState.refreshAll() }
                } label: {
                    Label("Re-check", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                Spacer()
                Text("Install with Homebrew")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("brew install colima docker")
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                Button {
                    copyToPasteboard("brew install colima docker")
                } label: {
                    Image(systemName: Icon.Action.copy.symbolName)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var createProfileStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Create your first profile")
                    .font(.system(size: 24, weight: .bold))
                Text("Pick a name and a runtime. You can fine-tune the rest of the profile in the editor after onboarding.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            SectionCard(title: "Profile", subtitle: "Identity and runtime.", symbol: "person.text.rectangle") {
                VStack(spacing: 10) {
                    EditorRow(label: "Name") {
                        TextField("default", text: $profileName)
                            .textFieldStyle(.roundedBorder)
                    }
                    EditorRow(label: "Runtime") {
                        Picker("", selection: $runtime) {
                            ForEach(ColimaRuntime.allCases.filter { $0 != .unknown && $0 != .none }) { runtime in
                                Text(runtime.label).tag(runtime)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    ResourceSlider(label: "CPU", value: $cpu, range: 1...32, unit: "vCPU")
                    ResourceSlider(label: "Memory", value: $memoryGiB, range: 1...128, unit: "GiB")
                    EditorRow(label: "Enable Kubernetes") {
                        Toggle("", isOn: $kubernetesEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }
            }
            if let error = creationError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.subheadline)
            }
        }
    }

    private var successStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(.green)
            Text("You're ready to go")
                .font(.system(size: 28, weight: .bold))
            Text("ColimaStack is wired up. You can always revisit the dependency check from Settings → Advanced.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if step != .welcome {
                Button("Back") {
                    moveBack()
                }
            }
            Spacer()
            if creationInProgress {
                ProgressView()
                    .controlSize(.small)
            }
            primaryButton
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var primaryButton: some View {
        switch step {
        case .welcome:
            Button("Get started") {
                step = .dependencies
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            Button("Skip onboarding") {
                completeOnboarding()
            }
        case .dependencies:
            Button("Continue") {
                step = .createProfile
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        case .createProfile:
            Button("Create & Start") {
                Task { await createAndStartProfile() }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(creationInProgress || profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        case .success:
            Button("Open Workspace") {
                completeOnboarding()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
    }

    private func moveBack() {
        if let previous = OnboardingStep(rawValue: step.rawValue - 1) {
            step = previous
        }
    }

    private func createAndStartProfile() async {
        creationInProgress = true
        creationError = nil
        defer { creationInProgress = false }
        var config = ProfileConfiguration.default
        config.name = profileName
        config.runtime = runtime
        config.resources.cpu = cpu
        config.resources.memoryGiB = memoryGiB
        config.kubernetes.enabled = kubernetesEnabled
        appState.editingConfiguration = config
        appState.originalEditingConfiguration = config
        appState.profileEditorMode = .create
        do {
            await appState.createProfileFromOnboarding(configuration: config)
            step = .success
        } catch {
            creationError = error.localizedDescription
        }
    }

    private func completeOnboarding() {
        OnboardingState.markCompleted()
        dismissWindow()
        NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
    }

    private var dateText: String {
        "recently"
    }
}

extension Notification.Name {
    static let onboardingCompleted = Notification.Name("onboardingCompleted")
}

extension AppState {
    /// Create a profile during onboarding. The user-typed name
    /// becomes the profile id; runtime/cpu/memory/kubernetes are
    /// applied to the new profile. The function awaits the
    /// existing profile-create codepath where possible.
    func createProfileFromOnboarding(configuration: ProfileConfiguration) async {
        // Use the existing createProfile() path so the new profile
        // goes through the same lifecycle as the sidebar '+' button.
        createProfile()
        // Override the defaults the editor was seeded with.
        editingConfiguration = configuration
        originalEditingConfiguration = configuration
        profileEditorMode = .create
    }
}
