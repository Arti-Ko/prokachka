import SwiftUI
import ProkachkaCore

/// Поле «Что сделал?» с оценкой до отправки. Одно и то же в окне, строке меню и панели ⌥Пробел.
struct Composer: View {
    var compact = false
    var autofocus = false
    var onSubmit: ((Assessment) -> Void)?
    @Environment(EventStore.self) private var store
    @State private var text = ""
    @State private var override: Skill?
    @State private var flash: Int?
    @FocusState private var focused: Bool

    var body: some View {
        let assessment = store.preview(text, override: override)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("Что сделал?", text: $text, prompt: Text(compact ? "Что сделал?" : "Что сделал? Например: сам написал алгоритм за 2 часа"))
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .multilineTextAlignment(.leading)
                    .controlSize(.large)
                    .focused($focused)
                    .onSubmit(submit)
                    .onChange(of: text) { _, new in if new.isEmpty { override = nil } }
                Button("Записать", action: submit)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(assessment == nil)
            }
            .overlay(alignment: .topTrailing) {
                if let xp = flash {
                    XPText(xp: xp, font: .system(.title3, design: .rounded).weight(.bold))
                        .offset(x: -110, y: -26)
                        .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .move(edge: .top).combined(with: .opacity)))
                }
            }
            AssessmentPreview(assessment: assessment, text: text, override: $override, compact: compact)
                .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
        }
        .onAppear { if autofocus { focused = true } }
    }

    private func submit() {
        guard let a = store.add(text, override: override) else { return }
        text = ""
        override = nil
        withAnimation(.snappy) { flash = a.xp }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.easeOut) { flash = nil }
        }
        onSubmit?(a)
    }
}
