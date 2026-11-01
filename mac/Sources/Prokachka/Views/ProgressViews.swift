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

    var body: some View {
        let all = store.snapshot.achievements
        let groups = all.map(\.group).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        let got = all.filter(\.done).count
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Получено \(got) из \(all.count)").font(.headline)
                    ProgressView(value: Double(got), total: Double(max(all.count, 1)))
                }
                ForEach(groups, id: \.self) { g in
                    let items = all.filter { $0.group == g }
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(g).font(.title3.weight(.semibold))
                            Spacer()
                            Text("\(items.filter(\.done).count) из \(items.count)").foregroundStyle(.secondary).monospacedDigit()
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                            ForEach(items) { AchievementCard(a: $0) }
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}

struct AchievementCard: View {
    let a: AchievementState

    var body: some View {
        let secret = a.hidden && !a.done
        VStack(spacing: 8) {
            Image(systemName: a.done ? Self.symbol(a.metric) : secret ? "questionmark" : "lock.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(a.done ? .white : .secondary)
                .frame(width: 54, height: 54)
                .background(a.done ? AnyShapeStyle(Self.tier(a.tier).gradient) : AnyShapeStyle(.quaternary), in: Circle())
                .overlay { if a.done { Circle().stroke(.white.opacity(0.35), lineWidth: 1.5).padding(3) } }
            Text(secret ? "???" : a.title).font(.callout.weight(.semibold)).multilineTextAlignment(.center)
            Text(secret ? "Секретное достижение" : a.text).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if a.done {
                Text(Self.tierName(a.tier)).font(.caption2.weight(.semibold)).foregroundStyle(Self.tier(a.tier))
            } else if !secret {
                ProgressView(value: Double(a.progress), total: Double(a.goal)).controlSize(.small)
                Text("\(a.progress) из \(a.goal)").font(.caption2).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .top)
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .help(secret ? "Откроется само, когда получишь" : a.text)
    }

    static func tier(_ t: Int) -> Color {
        switch t {
        case 1: Color(red: 0.78, green: 0.50, blue: 0.27)
        case 2: Color(red: 0.55, green: 0.60, blue: 0.68)
        case 3: Color(red: 0.95, green: 0.70, blue: 0.10)
        default: Color(red: 0.45, green: 0.55, blue: 0.95)
        }
    }

    static func tierName(_ t: Int) -> String { ["Бронза", "Серебро", "Золото", "Платина"][max(0, min(t, 4) - 1)] }

    static func symbol(_ metric: String) -> String {
        if metric.hasPrefix("skillActs.") || metric.hasPrefix("skillLevel.") {
            return Skill(rawValue: String(metric.split(separator: ".")[1]))?.symbol ?? "star.fill"
        }
        switch metric {
        case "level": return "crown.fill"
        case "xpTotal", "xpDayBest", "bigAct": return "bolt.fill"
        case "streakBest", "daysActive": return "flame.fill"
        case "cleanBest": return "leaf.fill"
        case "comebacks": return "arrow.uturn.up"
        case "weekends": return "calendar"
        case "acts": return "checkmark.seal.fill"
        case "skillsInDayBest": return "square.grid.3x3.fill"
        case "km": return "figure.run"
        case "pages": return "book.fill"
        case "focusMinutes": return "timer"
        case "selfMade": return "hand.raised.fill"
        case "hard", "records": return "trophy.fill"
        case "abstains": return "shield.fill"
        case "minuses": return "checkmark.shield.fill"
        case "disputes": return "scalemass.fill"
        case "early": return "sunrise.fill"
        case "night": return "moon.stars.fill"
        case "questsDone": return "target"
        default: return "gift.fill"
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
