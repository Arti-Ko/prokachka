import Charts
import SwiftUI
import ProkachkaCore

struct StatsView: View {
    @Environment(EventStore.self) private var store

    private struct Week: Identifiable { let start: String; let xp: Int; var id: String { start } }
    private struct Share: Identifiable { let skill: Skill; let xp: Int; var id: Skill { skill } }

    var body: some View {
        let s = store.snapshot
        let lastMonday = DayClock.weekStart(s.today)
        let firstDay = DayClock.shift(lastMonday, by: -77)
        let days = (0..<(84)).map { DayClock.shift(firstDay, by: $0) }.filter { $0 <= s.today }
        let weeks = stride(from: 0, to: 84, by: 7).map { off -> Week in
            let start = DayClock.shift(firstDay, by: off)
            let xp = (0..<7).reduce(0) { $0 + (s.dayTotals[DayClock.shift(start, by: $1)] ?? 0) }
            return Week(start: start, xp: xp)
        }
        let monthAgo = DayClock.shift(s.today, by: -29)
        let shares = Skill.trained.map { k in
            Share(skill: k, xp: s.entries.filter { $0.skill == k && $0.xp > 0 && $0.day >= monthAgo }.reduce(0) { $0 + $1.xp })
        }.filter { $0.xp > 0 }

        Form {
            SwiftUI.Section("Опыт по дням") {
                Heatmap(days: days, totals: s.dayTotals, today: s.today)
            }
            SwiftUI.Section("Опыт по неделям") {
                Chart(weeks) { w in
                    BarMark(x: .value("Неделя", label(w.start)), y: .value("XP", w.xp))
                        .foregroundStyle(w.start == lastMonday ? Color.accentColor : Color.accentColor.opacity(0.45))
                        .cornerRadius(4)
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 180)
            }
            SwiftUI.Section("Плюсы по навыкам за 30 дней") {
                if shares.isEmpty {
                    Text("Пока нет данных.").foregroundStyle(.secondary)
                } else {
                    Chart(shares) { sh in
                        BarMark(x: .value("XP", sh.xp), y: .value("Навык", sh.skill.title))
                            .foregroundStyle(sh.skill.color)
                            .cornerRadius(4)
                            .annotation(position: .trailing) { Text("\(sh.xp)").font(.caption).foregroundStyle(.secondary) }
                    }
                    .chartLegend(.hidden)
                    .frame(height: CGFloat(shares.count) * 28 + 20)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func label(_ day: String) -> String {
        let p = day.split(separator: "-")
        return p.count == 3 ? "\(Int(p[2]) ?? 0).\(p[1])" : day
    }
}

/// Сетка по дням: столбец — неделя, строка — день недели. Один оттенок, темнее — больше опыта.
private struct Heatmap: View {
    let days: [String]
    let totals: [String: Int]
    let today: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyHGrid(rows: Array(repeating: GridItem(.fixed(13), spacing: 3), count: 7), spacing: 3) {
                ForEach(days, id: \.self) { d in
                    let v = max(0, totals[d] ?? 0)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(v == 0 ? AnyShapeStyle(.quaternary) : AnyShapeStyle(Color.accentColor.opacity(level(v))))
                        .overlay { if d == today { RoundedRectangle(cornerRadius: 3).stroke(.primary, lineWidth: 1.5) } }
                        .frame(width: 13, height: 13)
                        .help("\(DayTitle.of(d, today: today)): \(v) XP")
                }
            }
            .frame(height: 7 * 13 + 6 * 3)
            HStack(spacing: 4) {
                Text("Меньше")
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.accentColor.opacity($0)).frame(width: 10, height: 10)
                }
                Text("Больше · обведён сегодняшний день")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func level(_ v: Int) -> Double { v < 80 ? 0.25 : v < 160 ? 0.5 : v < 240 ? 0.75 : 1 }
}
