import SwiftUI
import ProkachkaCore

enum Section: String, CaseIterable, Identifiable {
    case today, journal, skills, quests, achievements, rewards, stats
    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Сегодня"
        case .journal: "Журнал"
        case .skills: "Навыки"
        case .quests: "Квесты"
        case .achievements: "Достижения"
        case .rewards: "Награды"
        case .stats: "Статистика"
        }
    }

    var symbol: String {
        switch self {
        case .today: "sun.max"
        case .journal: "list.bullet"
        case .skills: "star"
        case .quests: "target"
        case .achievements: "trophy"
        case .rewards: "gift"
        case .stats: "chart.bar"
        }
    }
}

struct RootView: View {
    @Environment(EventStore.self) private var store
    // PROKACHKA_SECTION=achievements — открыть раздел при запуске (для скриншотов).
    @State private var section: Section? = Section(rawValue: ProcessInfo.processInfo.environment["PROKACHKA_SECTION"] ?? "") ?? .today

    var body: some View {
        @Bindable var store = store
        NavigationSplitView {
            List(selection: $section) {
                row(.today)
                row(.journal)
                SwiftUI.Section("Прогресс") {
                    row(.skills)
                    row(.quests, badge: store.snapshot.quests.filter { !$0.done }.count)
                    row(.achievements)
                }
                SwiftUI.Section("Ещё") {
                    row(.rewards, badge: store.snapshot.coins)
                    row(.stats)
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210)
            .safeAreaInset(edge: .bottom) { profile }
        } detail: {
            detail(section ?? .today)
                .navigationTitle((section ?? .today).title)
                .navigationSubtitle(subtitle)
        }
        .overlay(alignment: .topTrailing) { BannerStack().padding(.top, 8).padding(.trailing, 12) }
        .sheet(item: $store.levelUp) { LevelUpSheet(levelUp: $0) }
        .alert("Проблема с данными", isPresented: Binding(get: { store.problem != nil }, set: { if !$0 { store.problem = nil } })) {
            Button("Понятно") { store.problem = nil }
        } message: {
            Text(store.problem ?? "")
        }
    }

    private func row(_ s: Section, badge: Int = 0) -> some View {
        Label(s.title, systemImage: s.symbol).badge(badge).tag(s)
    }

    @ViewBuilder
    private func detail(_ s: Section) -> some View {
        switch s {
        case .today: TodayView()
        case .journal: JournalView()
        case .skills: SkillsView()
        case .quests: QuestsView()
        case .achievements: AchievementsView()
        case .rewards: RewardsView()
        case .stats: StatsView()
        }
    }

    private var subtitle: String {
        switch section ?? .today {
        case .today: Date().formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalizedFirst
        case .journal: "Все дела по дням"
        case .skills: "Семь навыков и их уровни"
        case .quests: "Дневные обновляются в 4 утра, недельные — в понедельник"
        case .achievements: "\(store.snapshot.achievements.filter(\.done).count) из \(store.snapshot.achievements.count)"
        case .rewards: "\(store.snapshot.coins) \(Fmt.plural(store.snapshot.coins, "монета", "монеты", "монет"))"
        case .stats: "Последние 12 недель"
        }
    }

    private var profile: some View {
        let s = store.snapshot
        return HStack(spacing: 10) {
            LevelRing(progress: s.level.progress, level: s.level.level, size: 32, line: 3.5)
            VStack(alignment: .leading, spacing: 0) {
                Text("Уровень \(s.level.level)").font(.callout.weight(.semibold))
                Text("\(s.rank) · \(Fmt.days(s.streak)) подряд").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct BannerStack: View {
    @Environment(EventStore.self) private var store

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(store.banners) { b in
                HStack(spacing: 10) {
                    IconSquare(symbol: "bolt.fill", color: .accentColor, size: 28)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(b.title).font(.callout.weight(.semibold))
                        Text(b.body).font(.callout).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(width: 300, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                .onTapGesture { store.dismiss(b) }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: store.banners)
    }
}

struct LevelUpSheet: View {
    let levelUp: LevelUp
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 10) {
            LevelRing(progress: 1, level: levelUp.level, size: 96, line: 10)
            Text("Уровень \(levelUp.level)").font(.title2.weight(.bold))
            Text("Звание: \(levelUp.rank). До следующего уровня \(Levels.req(levelUp.level)) XP.")
                .foregroundStyle(.secondary)
            Button("Отлично") { dismiss() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .padding(.top, 6)
        }
        .padding(28)
        .frame(width: 340)
    }
}
