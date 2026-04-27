import SwiftUI

struct AddEntryView: View {
    var viewModel: AppViewModel

    @State private var inputText = ""
    @State private var selectedType: EntryType = .word
    @FocusState private var isFocused: Bool

    private var canSubmit: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isTranslating
    }

    var body: some View {
        VStack(spacing: 8) {
            Picker("Type", selection: $selectedType) {
                Text("Word").tag(EntryType.word)
                Text("Phrase").tag(EntryType.phrase)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack {
                TextField("Type English word or phrase…", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .onSubmit { submit() }

                if viewModel.isTranslating {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 28, height: 28)
                } else {
                    Button(action: submit) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSubmit)
                }
            }

            if let error = viewModel.errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)

                    Button {
                        viewModel.clearError()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .imageScale(.small)
                    }
                    .buttonStyle(.plain)
                    .help("Dismiss error")
                }
            }
        }
        .padding(12)
    }

    private func submit() {
        guard canSubmit else { return }
        let text = inputText
        let type = selectedType
        inputText = ""
        Task {
            await viewModel.addEntry(english: text, type: type)
            isFocused = true
        }
    }
}
