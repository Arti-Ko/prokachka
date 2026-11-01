import SwiftUI
import ProkachkaCore

struct SyncView: View {
    private var server: SyncServer { SyncServer.shared }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            Form {
                SwiftUI.Section {
                    LabeledContent("Этот Mac", value: server.name)
                    LabeledContent("Состояние") {
                        Label(server.status, systemImage: server.isListening ? "wifi" : "wifi.exclamationmark")
                            .foregroundStyle(server.isListening ? Color.secondary : Color.orange)
                    }
                }
                SwiftUI.Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(formatted(server.code))
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .textSelection(.enabled)
                        Text(hint(now: context.date)).font(.callout).foregroundStyle(.secondary)
                        Button("Новый код") { server.newCode() }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Подключить телефон")
                } footer: {
                    Text("Код действует 5 минут и сгорает после пяти неверных попыток. После подключения записи шифруются общим ключом и ходят только внутри вашей сети.")
                        .foregroundStyle(.secondary)
                }
                SwiftUI.Section("Подключённые устройства") {
                    if server.settings.devices.isEmpty {
                        Text("Пока ни одного").foregroundStyle(.secondary)
                    }
                    ForEach(server.settings.devices) { d in
                        HStack(spacing: 10) {
                            IconSquare(symbol: "iphone", color: .green)
                            VStack(alignment: .leading) {
                                Text(d.name)
                                Text(d.lastSync.map { "Обмен " + $0.formatted(.relative(presentation: .named)) } ?? "Ещё не обменивались")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Отключить", role: .destructive) { server.remove(d) }
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .onAppear { server.ensureCode() }
    }

    private func formatted(_ code: String?) -> String {
        guard let code, code.count == 6 else { return "— — —" }
        return code.prefix(3) + " " + code.suffix(3)
    }

    private func hint(now: Date) -> String {
        guard server.code != nil, let until = server.codeUntil else {
            return server.settings.devices.isEmpty ? "Нажмите «Новый код»." : "Чтобы подключить ещё одно устройство, нажмите «Новый код»."
        }
        guard until > now else { return "Код устарел — нажмите «Новый код»." }
        return "На телефоне: Прокачка → Сегодня → «Mac» и введите этот код. Действует до \(until.formatted(date: .omitted, time: .shortened))."
    }
}
