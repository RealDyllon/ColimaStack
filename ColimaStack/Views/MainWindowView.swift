//
//  MainWindowView.swift
//  ColimaStack
//
//  Hosts the legacy delete-confirmation flow and forwards everything
//  else into the new `WorkspaceChrome`. The actual chrome is built in
//  `Views/Chrome/WorkspaceChrome.swift`.
//

import AppKit
import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""
    @State private var confirmDelete = false
    @State private var deleteTargetProfile: ColimaProfile?
    @State private var deleteConfirmationText = ""

    var body: some View {
        WorkspaceChrome(searchText: $searchText) {
            WorkspaceDetailRouter(route: appState.selectedSection, searchText: searchText)
                .environmentObject(appState)
        }
        .frame(minWidth: 1100, minHeight: 760)
        .alert(deleteConfirmationTitle, isPresented: $confirmDelete) {
            TextField(deleteConfirmationPrompt, text: $deleteConfirmationText)
                .accessibilityIdentifier("delete.confirmationText")
            Button(deleteConfirmationButtonTitle, role: .destructive) {
                let profileID = deleteTargetProfile?.id
                finishDeleteConfirmation()
                if let profileID {
                    Task { await appState.delete(profileID: profileID) }
                }
            }
            .disabled(!isDeleteConfirmationValid)
            .accessibilityIdentifier("delete.confirm")
            Button("Cancel", role: .cancel) {}
                .accessibilityIdentifier("delete.cancel")
        } message: {
            Text(deleteConfirmationMessage)
        }
        .onChange(of: confirmDelete) { _, isPresented in
            if !isPresented {
                finishDeleteConfirmation()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .workspaceChromeRequestDeleteConfirmation)) { note in
            if let profile = note.object as? ColimaProfile {
                beginDeleteConfirmation(for: profile)
            } else {
                beginDeleteConfirmation(for: appState.selectedProfile)
            }
        }
    }

    // MARK: - Delete confirmation

    private var deleteProfileName: String {
        deleteTargetProfile?.name ?? "selected profile"
    }

    private var deleteConfirmationTitle: String {
        "Delete \(deleteProfileName)?"
    }

    private var deleteConfirmationPrompt: String {
        "Type \(deleteProfileName) to confirm"
    }

    private var deleteConfirmationMessage: String {
        "This permanently deletes the Colima profile named \(deleteProfileName), including its VM and data. This cannot be undone."
    }

    private var deleteConfirmationButtonTitle: String {
        "Delete \(deleteProfileName)"
    }

    private var isDeleteConfirmationValid: Bool {
        deleteConfirmationText == deleteTargetProfile?.name
    }

    private func beginDeleteConfirmation(for profile: ColimaProfile?) {
        guard let profile else { return }
        deleteTargetProfile = profile
        deleteConfirmationText = ""
        confirmDelete = true
    }

    private func finishDeleteConfirmation() {
        deleteConfirmationText = ""
        deleteTargetProfile = nil
    }
}

struct MainWindowView_Previews: PreviewProvider {
    static var previews: some View {
        MainWindowView()
            .environmentObject(PreviewSupport.appState)
    }
}
