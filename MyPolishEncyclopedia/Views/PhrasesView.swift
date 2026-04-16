import SwiftUI

struct PhrasesView: View {
    var viewModel: AppViewModel

    var body: some View {
        Group {
            if viewModel.phrases.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(viewModel.phrases) { entry in
                        PhraseRow(entry: entry, viewModel: viewModel)
                    }
                    .onDelete { offsets in
                        offsets.forEach { viewModel.deleteEntry(viewModel.phrases[$0]) }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        Text("No phrases yet. Add one below.")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PhraseRow: View {
    let entry: PolishEntry
    var viewModel: AppViewModel

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.english)
                    .font(.body)
                Text(entry.polish)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Spacer()
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
