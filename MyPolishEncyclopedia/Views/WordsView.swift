import SwiftUI

struct WordsView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        Group {
            if viewModel.words.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(viewModel.words) { entry in
                        WordRow(entry: entry, viewModel: viewModel)
                    }
                    .onDelete { offsets in
                        offsets.forEach { viewModel.deleteEntry(viewModel.words[$0]) }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        Text("No words yet. Add one below.")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WordRow: View {
    let entry: PolishEntry
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        HStack {
            Text(entry.english)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(entry.polish)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            playButton
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var playButton: some View {
        if viewModel.loadingAudioIDs.contains(entry.id) {
            ProgressView()
                .scaleEffect(0.7)
                .frame(width: 28, height: 28)
        } else {
            Button {
                Task { await viewModel.playAudio(for: entry) }
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            .frame(width: 28, height: 28)
        }
    }
}
