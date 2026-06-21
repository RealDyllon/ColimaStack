//
//  ProfileEditorView.swift
//  ColimaStack
//
//  Legacy `Form`-based profile editor. Lives here temporarily; it is
//  rewritten in group 4 (Profile editor) as a card-based sheet.
//

import SwiftUI

struct ProfileEditorView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var validationErrors: [String] = ProfileConfiguration.default.validationErrors
    @State private var isValidatingConfiguration = false

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Profile") {
                    TextField("Name", text: $appState.editingConfiguration.name)
                        .disabled(!appState.canEditProfileName)
                    Picker("Runtime", selection: $appState.editingConfiguration.runtime) {
                        ForEach(ColimaRuntime.allCases.filter { $0 != .unknown && $0 != .none }) { runtime in
                            Text(runtime.label).tag(runtime)
                        }
                    }
                    Picker("VM Type", selection: $appState.editingConfiguration.vmType) {
                        ForEach(VMType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    Picker("Architecture", selection: $appState.editingConfiguration.architecture) {
                        ForEach(CPUArchitecture.allCases) { architecture in
                            Text(architecture.label).tag(architecture)
                        }
                    }
                }

                Section("Resources") {
                    Stepper("CPU: \(appState.editingConfiguration.resources.cpu)", value: $appState.editingConfiguration.resources.cpu, in: 1...32)
                    Stepper("Memory: \(appState.editingConfiguration.resources.memoryGiB) GiB", value: $appState.editingConfiguration.resources.memoryGiB, in: 1...128)
                    Stepper("Disk: \(appState.editingConfiguration.resources.diskGiB) GiB", value: $appState.editingConfiguration.resources.diskGiB, in: 1...2048)
                }

                Section("Kubernetes") {
                    Toggle("Enable Kubernetes", isOn: $appState.editingConfiguration.kubernetes.enabled)
                    TextField("Kubernetes Version", text: $appState.editingConfiguration.kubernetes.version)
                    OptionalIntField(title: "K3s Listen Port", value: $appState.editingConfiguration.k3sListenPort)
                    TagListEditor(title: "K3s Args", values: $appState.editingConfiguration.k3sArgs)
                }

                Section("Network") {
                    Toggle("Expose VM Address", isOn: $appState.editingConfiguration.network.networkAddress)
                    Picker("Mode", selection: $appState.editingConfiguration.network.mode) {
                        Text("Shared").tag("shared")
                        Text("Bridged").tag("bridged")
                    }
                    TextField("Interface", text: $appState.editingConfiguration.network.interface)
                        .disabled(appState.editingConfiguration.network.mode == "shared")
                    TagListEditor(title: "DNS Resolvers", values: $appState.editingConfiguration.network.dnsResolvers)
                }

                Section("Mounts") {
                    Picker("Mount Driver", selection: $appState.editingConfiguration.mountType) {
                        ForEach(MountType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }

                    ForEach($appState.editingConfiguration.mounts) { $mount in
                        HStack {
                            TextField("Local Path", text: $mount.localPath)
                            TextField("VM Path", text: $mount.vmPath)
                            Toggle("Writable", isOn: $mount.writable)
                                .toggleStyle(.checkbox)
                            Button {
                                appState.editingConfiguration.mounts.removeAll { $0.id == mount.id }
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    Button {
                        appState.editingConfiguration.mounts.append(MountConfiguration(localPath: "", vmPath: "", writable: true))
                    } label: {
                        Label("Add Mount", systemImage: "plus")
                    }
                }

                Section("Advanced") {
                    Picker("Port Forwarder", selection: $appState.editingConfiguration.portForwarder) {
                        ForEach(PortForwarder.allCases) { forwarder in
                            Text(forwarder.label).tag(forwarder)
                        }
                    }
                    Toggle("Rosetta", isOn: $appState.editingConfiguration.rosetta)
                        .disabled(appState.editingConfiguration.vmType != .vz || appState.editingConfiguration.architecture == .x86_64)
                    Toggle("Nested Virtualization", isOn: $appState.editingConfiguration.nestedVirtualization)
                        .disabled(appState.editingConfiguration.vmType != .vz)
                    TagListEditor(title: "Additional CLI Args", values: $appState.editingConfiguration.additionalArgs)
                }
            }
            .formStyle(.grouped)

            ValidationSummary(errors: validationErrors)

            Divider()

            HStack {
                Button("Cancel") {
                    appState.cancelProfileEditing()
                    dismiss()
                }
                Spacer()
                Button(appState.profileEditorActionTitle) {
                    Task { await appState.saveEditingConfiguration() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!validationErrors.isEmpty || isValidatingConfiguration || appState.activeOperation != nil)
            }
            .padding()
        }
        .task(id: appState.editingConfiguration) {
            await validate(configuration: appState.editingConfiguration)
        }
    }

    private func validate(configuration: ProfileConfiguration) async {
        isValidatingConfiguration = true
        validationErrors = configuration.validationErrors
        let errors = await configuration.validationErrorsCheckingFilesystem()
        guard !Task.isCancelled else { return }
        validationErrors = errors
        isValidatingConfiguration = false
    }
}

struct ValidationSummary: View {
    let errors: [String]

    var body: some View {
        if !errors.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("Resolve these profile settings before applying", systemImage: "exclamationmark.triangle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                ForEach(errors, id: \.self) { error in
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.orange.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
        }
    }
}

struct TagListEditor: View {
    let title: String
    @Binding var values: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Button {
                    values.append("")
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
            }

            ForEach(values.indices, id: \.self) { index in
                HStack {
                    TextField(title, text: Binding(get: { values[index] }, set: { values[index] = $0 }))
                    Button {
                        values.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }
}

struct OptionalIntField: View {
    let title: String
    @Binding var value: Int?

    var body: some View {
        TextField(
            title,
            text: Binding(
                get: { value.map(String.init) ?? "" },
                set: { value = Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            )
        )
    }
}
