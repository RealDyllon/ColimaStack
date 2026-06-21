//
//  ProfileEditorView.swift
//  ColimaStack
//
//  Card-based profile editor. Replaces the legacy
//  `Form { Section { ... } }.formStyle(.grouped)` editor that lived
//  in `Views/MainWindowView.swift`. Implements the profile-editor
//  capability from the apple-design-award-ui change.
//

import AppKit
import SwiftUI

struct ProfileEditorView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var validationErrors: [String] = ProfileConfiguration.default.validationErrors
    @State private var isValidatingConfiguration = false
    @State private var showValidationPopover = false
    @State private var showDestructiveConfirm = false
    @State private var isNameFocused: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    profileCard
                    resourcesCard
                    kubernetesCard
                    networkCard
                    mountsCard
                    advancedCard
                }
                .padding(20)
            }
            Divider()
            validationFooter
        }
        .frame(minWidth: 720, minHeight: 760)
        .background(Material.regular)
        .alert("Recreate the profile?", isPresented: $showDestructiveConfirm) {
            Button("Recreate", role: .destructive) {
                Task { await appState.saveEditingConfiguration() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Changing runtime, VM type, or disk size on an existing profile will recreate the underlying Colima profile. The current VM and its data will be replaced.")
        }
        .task(id: appState.editingConfiguration) {
            await validate(configuration: appState.editingConfiguration)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.profileEditorActionTitle)
                    .font(.system(size: 17, weight: .semibold))
                Text(appState.editingConfiguration.name.isEmpty ? "Unnamed profile" : appState.editingConfiguration.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Cancel") {
                appState.cancelProfileEditing()
                dismiss()
            }
            .keyboardShortcut(".", modifiers: .command)
            Button(appState.profileEditorActionTitle) {
                handleApply()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!validationErrors.isEmpty || isValidatingConfiguration || appState.activeOperation != nil)
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func handleApply() {
        // A destructive-recreation is required if the user changed
        // runtime, vmType, or diskGiB on an existing profile. We
        // confirm before applying. New profiles skip the confirm.
        if appState.profileEditorMode?.isEdit == true,
           appState.hasDestructiveFieldChange {
            showDestructiveConfirm = true
        } else {
            Task { await appState.saveEditingConfiguration() }
        }
    }

    // MARK: - Cards

    private var profileCard: some View {
        SectionCard(title: "Profile", subtitle: "Identity, runtime, and architecture.", symbol: "person.text.rectangle") {
            VStack(spacing: 10) {
                EditorRow(label: "Name") {
                    TextField("Profile name", text: $appState.editingConfiguration.name)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!appState.canEditProfileName)
                }
                EditorRow(label: "Runtime") {
                    Picker("", selection: $appState.editingConfiguration.runtime) {
                        ForEach(ColimaRuntime.allCases.filter { $0 != .unknown && $0 != .none }) { runtime in
                            Text(runtime.label).tag(runtime)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                EditorRow(label: "VM Type") {
                    Picker("", selection: $appState.editingConfiguration.vmType) {
                        ForEach(VMType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                EditorRow(label: "Architecture") {
                    Picker("", selection: $appState.editingConfiguration.architecture) {
                        ForEach(CPUArchitecture.allCases) { arch in
                            Text(arch.label).tag(arch)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }
        }
    }

    private var resourcesCard: some View {
        SectionCard(title: "Resources", subtitle: "CPU, memory, and disk allocation for the VM.", symbol: "cpu") {
            VStack(spacing: 14) {
                ResourceSlider(
                    label: "CPU",
                    value: $appState.editingConfiguration.resources.cpu,
                    range: 1...32,
                    unit: "vCPU"
                )
                ResourceSlider(
                    label: "Memory",
                    value: $appState.editingConfiguration.resources.memoryGiB,
                    range: 1...128,
                    unit: "GiB"
                )
                ResourceSlider(
                    label: "Disk",
                    value: $appState.editingConfiguration.resources.diskGiB,
                    range: 10...2048,
                    unit: "GiB"
                )
            }
        }
    }

    private var kubernetesCard: some View {
        SectionCard(title: "Kubernetes", subtitle: "K3s control plane, version, and arguments.", symbol: Icon.Kubernetes.enabled.symbolName) {
            VStack(spacing: 10) {
                EditorRow(label: "Enable Kubernetes") {
                    Toggle("", isOn: $appState.editingConfiguration.kubernetes.enabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                EditorRow(label: "Version") {
                    TextField("Default (k3s latest)", text: $appState.editingConfiguration.kubernetes.version)
                        .textFieldStyle(.roundedBorder)
                }
                EditorRow(label: "K3s Listen Port") {
                    OptionalIntField(title: "K3s Listen Port", value: $appState.editingConfiguration.k3sListenPort)
                }
                TagListEditor(
                    title: "K3s Args",
                    values: $appState.editingConfiguration.k3sArgs
                )
            }
        }
    }

    private var networkCard: some View {
        SectionCard(title: "Network", subtitle: "VM networking mode, exposed address, and DNS resolvers.", symbol: "network") {
            VStack(spacing: 10) {
                EditorRow(label: "Expose VM Address") {
                    Toggle("", isOn: $appState.editingConfiguration.network.networkAddress)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                EditorRow(label: "Mode") {
                    Picker("", selection: $appState.editingConfiguration.network.mode) {
                        Text("Shared").tag("shared")
                        Text("Bridged").tag("bridged")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                EditorRow(label: "Interface") {
                    TextField("en0", text: $appState.editingConfiguration.network.interface)
                        .textFieldStyle(.roundedBorder)
                        .disabled(appState.editingConfiguration.network.mode == "shared")
                }
                TagListEditor(title: "DNS Resolvers", values: $appState.editingConfiguration.network.dnsResolvers)
            }
        }
    }

    private var mountsCard: some View {
        SectionCard(title: "Mounts", subtitle: "Host paths exposed inside the VM.", symbol: "folder") {
            VStack(spacing: 10) {
                EditorRow(label: "Mount Driver") {
                    Picker("", selection: $appState.editingConfiguration.mountType) {
                        ForEach(MountType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                VStack(spacing: 8) {
                    ForEach($appState.editingConfiguration.mounts) { $mount in
                        MountRow(mount: $mount, onRemove: {
                            removeMount(id: mount.id)
                        })
                    }
                }
                Button {
                    addMount()
                } label: {
                    Label("Add Mount", systemImage: Icon.Action.add.symbolName)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var advancedCard: some View {
        SectionCard(title: "Advanced", subtitle: "Port forwarding, Rosetta, nested virtualization, and additional CLI arguments.", symbol: "slider.horizontal.3") {
            VStack(spacing: 10) {
                EditorRow(label: "Port Forwarder") {
                    Picker("", selection: $appState.editingConfiguration.portForwarder) {
                        ForEach(PortForwarder.allCases) { forwarder in
                            Text(forwarder.label).tag(forwarder)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                EditorRow(label: "Rosetta") {
                    Toggle("", isOn: $appState.editingConfiguration.rosetta)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .disabled(appState.editingConfiguration.vmType != .vz || appState.editingConfiguration.architecture == .x86_64)
                }
                EditorRow(label: "Nested Virtualization") {
                    Toggle("", isOn: $appState.editingConfiguration.nestedVirtualization)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .disabled(appState.editingConfiguration.vmType != .vz)
                }
                TagListEditor(title: "Additional CLI Args", values: $appState.editingConfiguration.additionalArgs)
            }
        }
    }

    // MARK: - Validation footer

    private var validationFooter: some View {
        HStack(spacing: 10) {
            if validationErrors.isEmpty {
                Label("All settings valid", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button {
                    showValidationPopover.toggle()
                } label: {
                    Label("Resolve \(validationErrors.count) issue\(validationErrors.count == 1 ? "" : "s") before applying", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.borderless)
                .popover(isPresented: $showValidationPopover, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Validation errors")
                            .font(.headline)
                        ForEach(validationErrors, id: \.self) { error in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundStyle(.orange)
                                Text(error)
                                    .font(.callout)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: 360)
                }
            }
            Spacer()
            if isValidatingConfiguration {
                ProgressView()
                    .controlSize(.small)
            }
            if appState.activeOperation != nil {
                Label("Operation in progress", systemImage: "bolt.horizontal.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Actions

    private func addMount() {
        let newMount = MountConfiguration(localPath: "", vmPath: "", writable: true)
        appState.editingConfiguration.mounts.append(newMount)
    }

    private func removeMount(id: MountConfiguration.ID) {
        appState.editingConfiguration.mounts.removeAll { $0.id == id }
        if appState.editingConfiguration.mounts.isEmpty {
            addMount()
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

// MARK: - Editor row primitive

/// A label-left / control-right row used inside editor cards.
struct EditorRow<Control: View>: View {
    let label: String
    @ViewBuilder let control: () -> Control

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(.subheadline)
                .frame(minWidth: 140, alignment: .leading)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            control()
                .frame(maxWidth: 360, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Resource slider

/// A labeled slider with a live value label on the trailing edge.
struct ResourceSlider: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text("\(value) \(unit)")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = Int($0) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 1
            )
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Mount row

private struct MountRow: View {
    @Binding var mount: MountConfiguration
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("Local Path", text: $mount.localPath)
                .textFieldStyle(.roundedBorder)
            TextField("VM Path", text: $mount.vmPath)
                .textFieldStyle(.roundedBorder)
            Toggle("Writable", isOn: $mount.writable)
                .toggleStyle(.checkbox)
            Button(role: .destructive) {
                onRemove()
            } label: {
                Image(systemName: Icon.Action.remove.symbolName)
            }
            .buttonStyle(.borderless)
        }
    }
}

// MARK: - Tag list editor

struct TagListEditor: View {
    let title: String
    @Binding var values: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Button {
                    values.append("")
                } label: {
                    Image(systemName: Icon.Action.add.symbolName)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Add \(title) entry")
            }

            ForEach(values.indices, id: \.self) { index in
                HStack(spacing: 6) {
                    TextField(title, text: Binding(get: { values[index] }, set: { values[index] = $0 }))
                        .textFieldStyle(.roundedBorder)
                    Button {
                        values.remove(at: index)
                    } label: {
                        Image(systemName: Icon.Action.remove.symbolName)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Remove \(title) entry")
                }
            }
        }
    }
}

// MARK: - Optional int field

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
        .textFieldStyle(.roundedBorder)
    }
}
