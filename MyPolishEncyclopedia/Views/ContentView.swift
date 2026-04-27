import AppKit
import SwiftUI

struct ContentView: View {
    @State private var viewModel = AppViewModel()
    @State private var selectedTab: Tab = .words

    enum Tab {
        case words, phrases
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("View", selection: $selectedTab) {
                Text("Garrett's Words").tag(Tab.words)
                Text("Garrett's Phrases").tag(Tab.phrases)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(10)

            Divider()

            // Entry list
            Group {
                if selectedTab == .words {
                    WordsView(viewModel: viewModel)
                } else {
                    PhrasesView(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Add entry
            AddEntryView(viewModel: viewModel)

            Divider()

            HStack {
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .keyboardShortcut("q", modifiers: .command)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .frame(width: 380, height: 520)
        .onAppear { viewModel.loadEntries() }
    }
}

#Preview {
    ContentView()
}
