import SwiftUI

struct DailyView: View {
    var viewModel: AppViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.23, blue: 0.34),
                    Color(red: 0.12, green: 0.38, blue: 0.82),
                    Color(red: 0.06, green: 0.62, blue: 0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.16)

            if viewModel.phrases.isEmpty {
                emptyState
            } else if viewModel.dailyIsComplete {
                completionState
            } else if let entry = viewModel.currentDailyEntry {
                gameCard(for: entry)
            } else {
                emptyState
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 34))
                .foregroundStyle(.pink)
            Text("Add a few phrases to unlock your daily speaking drill.")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var completionState: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Image(systemName: "rosette")
                    .font(.system(size: 42))
                    .foregroundStyle(.yellow)
                Text("Daily drill complete")
                    .font(.title3.weight(.bold))
                Text("\(viewModel.dailyScore) / \(viewModel.dailyEntries.count) phrases felt solid")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            scoreStrip

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    viewModel.restartDailySession()
                }
            } label: {
                Label("Play Again", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
            .padding(.horizontal, 34)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func gameCard(for entry: PolishEntry) -> some View {
        VStack(spacing: 14) {
            progressHeader

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Say this in Polish", systemImage: "mic.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.pink.gradient, in: Capsule())

                    Spacer()

                    Text("\(viewModel.dailySession.currentIndex + 1)/\(viewModel.dailyEntries.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                Text(entry.english)
                    .font(.title2.weight(.bold))
                    .lineLimit(4)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if viewModel.dailySession.isAnswerRevealed {
                    answerBlock(for: entry)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.92).combined(with: .opacity),
                            removal: .opacity
                        ))
                } else {
                    promptBlock
                }
            }
            .padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.45), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
            .padding(.horizontal, 14)

            if viewModel.dailySession.isAnswerRevealed {
                gradeButtons
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        viewModel.revealDailyAnswer()
                    }
                } label: {
                    Label("Reveal Polish", systemImage: "eye.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .padding(.horizontal, 24)
            }
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var progressHeader: some View {
        HStack(spacing: 7) {
            ForEach(Array(viewModel.dailyEntries.enumerated()), id: \.element.id) { index, entry in
                Capsule()
                    .fill(progressColor(for: index, phraseID: entry.id))
                    .frame(height: 8)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 18)
    }

    private var promptBlock: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.title2)
                .foregroundStyle(.teal)
            Text("Speak it out loud, then check yourself.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
    }

    private func answerBlock(for entry: PolishEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(entry.polish)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .textSelection(.enabled)

            HStack {
                Button {
                    Task { await viewModel.playAudio(for: entry) }
                } label: {
                    Label("Listen", systemImage: "speaker.wave.2.fill")
                }
                .buttonStyle(.bordered)
                .tint(.blue)

                Spacer()

                Text("How close were you?")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.93, green: 1.0, blue: 0.96), in: RoundedRectangle(cornerRadius: 8))
    }

    private var gradeButtons: some View {
        HStack(spacing: 8) {
            gradeButton(.missed, color: .red, icon: "xmark")
            gradeButton(.almost, color: .orange, icon: "triangle")
            gradeButton(.gotIt, color: .green, icon: "checkmark")
        }
        .padding(.horizontal, 14)
    }

    private var scoreStrip: some View {
        HStack(spacing: 8) {
            ForEach(viewModel.dailySession.results, id: \.phraseID) { result in
                Text(result.grade.label)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(resultColor(result.grade).opacity(0.18), in: Capsule())
                    .foregroundStyle(resultColor(result.grade))
            }
        }
        .frame(minHeight: 26)
    }

    private func gradeButton(_ grade: DailyGrade, color: Color, icon: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                viewModel.gradeDailyAnswer(grade)
            }
        } label: {
            Label(grade.label, systemImage: icon)
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
    }

    private func progressColor(for index: Int, phraseID: UUID) -> Color {
        if let result = viewModel.dailySession.results.first(where: { $0.phraseID == phraseID }) {
            return resultColor(result.grade)
        }
        if index == viewModel.dailySession.currentIndex {
            return .blue
        }
        return .white.opacity(0.62)
    }

    private func resultColor(_ grade: DailyGrade) -> Color {
        switch grade {
        case .gotIt: return .green
        case .almost: return .orange
        case .missed: return .red
        }
    }
}

#Preview {
    DailyView(viewModel: AppViewModel())
        .frame(width: 380, height: 380)
}
