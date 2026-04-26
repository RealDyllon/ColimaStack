//
//  ContentView.swift
//  ColimaStack
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        MainWindowView()
            .environmentObject(appState)
    }
}

#Preview {
    ContentView()
        .environmentObject(PreviewSupport.appState)
}
