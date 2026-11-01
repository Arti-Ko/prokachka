import SwiftUI
import ProkachkaCore

struct JournalView: View {
    @Environment(EventStore.self) private var store

    var body: some View {
        let s = store.snapshot
        let days = Array(Set(s.entries.map(\.day))).sorted(by: >)
        Form {
            if days.isEmpty {
                Text("Журнал пуст. Записи появятся здесь по дням.").foregroundStyle(.secondary)
            }
            ForEach(days, id: \.self) { day in
                SwiftUI.Section {
                    ForEach(s.entries.filter { $0.day == day }.reversed()) { EntryRow(entry: $0) }
                } header: {
                    HStack {
                        Text(DayTitle.of(day, today: s.today))
                        Spacer()
                        Text("\(Fmt.signed(Double(s.dayTotals[day] ?? 0))) XP").monospacedDigit()
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct SkillsView: View {
    @Environment(EventStore.self) private var store

    var body: some View {
        let s = store.snapshot
        Form {
            SwiftUI.Section {
                ForEach(Skill.trained, id: \.self) { skill in
                    let st = s.skills[skill] ?? SkillState(total: 0)
                    HStack(spacing: 12) {
                        SkillIcon(skill: skill, size: 30)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(skill.title).font(.headline)
                                Spacer()
                                Text("ур. \(st.info.level)").font(.system(.callout, design: .rounded).weight(.semibold)).foregroundStyle(.secondary)
                            }
                            Text(skill.about).font(.caption).foregroundStyle(.secondary)
                            ProgressView(value: st.info.progress).tint(skill.color)
                            HStack {
                                Text("\(st.info.into) из \(st.info.need)")
                                Spacer()
                                Text("всего \(st.total)")
                                if let k = s.calibration[skill] { Text("· калибровка ×\(Fmt.k(k))") }
                            }
                            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                    .padding(.vertical, 4)
                }
            } footer: {
                Text("Квесты подбираются под два навыка, которые растут медленнее остальных.").foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct QuestsView: View {
    @Environment(EventStore.self) private var store

    var body: some View {
        let q = store.snapshot.quests
        Form {
            SwiftUI.Section("На сегодня") { ForEach(q.filter { $0.period == .day }) { QuestRow(quest: $0) } }
            SwiftUI.Section {
                ForEach(q.filter { $0.period == .week }) { QuestRow(quest: $0) }
            } header: {
                Text("На неделю")
            } footer: {
                Text("Награда за выполненный квест начисляется сама. Набор подбирается под отстающие навыки и не меняется до конца дня или недели.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct AchievementsView: View {
    @Environment(EventStore.self) private var store
    private let symbols = ["first": "sparkles", "lvl10": "crown.fill", "streak7": "flame.fill", "xp300": "bolt.fill", "self10": "star.fill",
                           "early5": "sunrise.fill", "mind20": "book.fill", "clean7": "heart.fill", "lvl15": "crown.fill", "streak30": "flame.circle.fill"]
    private let tints: [Color] = [.orange, .yellow, .red, .blue, .purple, .pink, .indigo, .green, .teal, .orange]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(Array(store.snapshot.achievements.enumerated()), id: \.element.id) { i, a in
                    VStack(spacing: 8) {
                        Image(systemName: a.done ? symbols[a.id] ?? "star.fill" : "lock.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(a.done ? .white : .secondary)
                            .frame(width: 56, height: 56)
                            .background(a.done ? AnyShapeStyle(tints[i % tints.count].gradient) : AnyShapeStyle(.quaternary), in: Circle())
                        Text(a.title).font(.callout.weight(.semibold))
                        Text(a.text).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Text(a.done ? "Получено" : "\(a.progress) из \(a.goal)").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(20)
        }
    }
}

struct RewardsView: View {
    @Environment(EventStore.self) private var store
    @State private var title = ""
    @State private var cost = 100

    var body: some View {
        let coins = store.snapshot.coins
        Form {
            SwiftUI.Section {
                HStack(spacing: 12) {
                    IconSquare(symbol: "circle.circle.fill", color: .orange, size: 34)
                    VStack(alignment: .leading) {
                        Text("\(coins)").font(.system(size: 28, weight: .bold, design: .rounded)).monospacedDigit()
                        Text("монет · 10% от каждого плюса").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            SwiftUI.Section("Магазин") {
                ForEach(store.rewards) { r in
                    HStack(spacing: 10) {
                        IconSquare(symbol: r.symbol, color: .orange)
                        VStack(alignment: .leading) {
                            Text(r.title)
                            Text("\(r.cost) монет").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                        }
                        Spacer()
                        Button("Взять") { store.take(r) }.disabled(coins < r.cost)
                    }
                    .contextMenu { Button("Удалить из магазина", role: .destructive) { store.removeReward(r) } }
                }
            }
            SwiftUI.Section {
                TextField("Название", text: $title, prompt: Text("Например, поход в кино"))
                Stepper(value: $cost, in: 10...5000, step: 10) {
                    LabeledContent("Цена", value: "\(cost) монет")
                }
                Button("Добавить в магазин") {
                    store.addReward(title: title, cost: cost)
                    title = ""
                }
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            } header: {
                Text("Своя награда")
            } footer: {
                Text("Удалить награду из магазина — правый клик по ней.").foregroundStyle(.secondary)
            }
            if !store.snapshot.spends.isEmpty {
                SwiftUI.Section("Уже взято") {
                    ForEach(store.snapshot.spends.reversed()) { e in
                        LabeledContent(e.text ?? "", value: "−\(e.cost ?? 0)")
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
