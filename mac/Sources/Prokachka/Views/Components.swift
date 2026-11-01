import SwiftUI
import ProkachkaCore

extension Skill {
    var symbol: String {
        switch self {
        case .body: "figure.run"
        case .mind: "book.fill"
        case .work: "briefcase.fill"
        case .home: "house.fill"
        case .people: "person.2.fill"
        case .craft: "paintbrush.pointed.fill"
        case .rest: "moon.fill"
        case .misc: "sparkles"
        case .quest: "target"
        }
    }

    var color: Color {
        switch self {
        case .body: .pink
        case .mind: .indigo
        case .work: .blue
        case .home: .teal
        case .people: .green
        case .craft: .purple
        case .rest: .mint
        case .misc: .gray
        case .quest: .orange
        }
    }
}

/// Цветной квадрат с символом, как иконки в Системных настройках.
struct IconSquare: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.55, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
    }
}

struct SkillIcon: View {
    let skill: Skill
    var size: CGFloat = 22
    var body: some View { IconSquare(symbol: skill.symbol, color: skill.color, size: size) }
}

struct LevelRing: View {
    let progress: Double
    let level: Int
    var size: CGFloat = 80
    var line: CGFloat = 8

    var body: some View {
        ZStack {
            Circle().stroke(.quaternary, lineWidth: line)
            Circle()
                .trim(from: 0, to: max(0.001, min(progress, 1)))
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth, value: progress)
            Text("\(level)")
                .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Уровень \(level), \(Int(progress * 100)) процентов до следующего")
    }
}

/// Раскладка «в строку с переносом» для чипов.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(proposal.width ?? .infinity, subviews)
        return CGSize(width: rows.map(\.width).max() ?? 0, height: rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(bounds.width, subviews) {
            var x = bounds.minX
            for i in row.items {
                let s = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y + (row.height - s.height) / 2), proposal: ProposedViewSize(s))
                x += s.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var items: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(_ maxWidth: CGFloat, _ subviews: Subviews) -> [Row] {
        var rows = [Row()]
        for i in subviews.indices {
            let s = subviews[i].sizeThatFits(.unspecified)
            if !rows[rows.count - 1].items.isEmpty && rows[rows.count - 1].width + spacing + s.width > maxWidth { rows.append(Row()) }
            var r = rows[rows.count - 1]
            r.width += (r.items.isEmpty ? 0 : spacing) + s.width
            r.height = max(r.height, s.height)
            r.items.append(i)
            rows[rows.count - 1] = r
        }
        return rows
    }
}

struct FactorChip: View {
    let step: Step
    var body: some View {
        HStack(spacing: 4) {
            Text(step.name).foregroundStyle(.secondary)
            Text(step.val).fontWeight(.semibold)
        }
        .font(.caption)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(.quaternary.opacity(0.6), in: Capsule())
    }
}

struct XPText: View {
    let xp: Int
    var font: Font = .system(.body, design: .rounded).weight(.semibold)
    var body: some View {
        Text("\(Fmt.signed(Double(xp)))")
            .font(font)
            .monospacedDigit()
            .foregroundStyle(xp < 0 ? Color.red : Color.green)
    }
}

/// Оценка до отправки: опыт, навык, множители. Если навык не распознан — кнопки выбора.
struct AssessmentPreview: View {
    let assessment: Assessment?
    let text: String
    @Binding var override: Skill?
    var compact = false

    var body: some View {
        if let a = assessment {
            FlowLayout {
                Text("\(Fmt.signed(Double(a.xp))) XP")
                    .font(.system(.callout, design: .rounded).weight(.bold))
                    .foregroundStyle(a.xp < 0 ? Color.red : Color.green)
                Label(a.skill.title, systemImage: a.skill.symbol)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(a.skill.color)
                ForEach(Array(a.steps.dropFirst().prefix(compact ? 2 : 10).enumerated()), id: \.offset) { FactorChip(step: $0.element) }
                if compact && a.steps.count > 3 {
                    Text("и ещё \(a.steps.count - 3)").font(.caption).foregroundStyle(.tertiary)
                }
                if !a.sure {
                    Text("Какой это навык?").font(.caption).foregroundStyle(.secondary)
                    ForEach(Skill.trained, id: \.self) { s in
                        Button(s.title) { override = s }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(s.color)
                    }
                }
            }
            .animation(.snappy, value: a)
        } else if Assessor.hint(text) == .plan {
            Label("Похоже на план. Запиши, когда сделаешь — тогда и будет опыт.", systemImage: "calendar")
                .font(.caption).foregroundStyle(.secondary)
        } else if !text.trimmingCharacters(in: .whitespaces).isEmpty {
            Text("Опиши чуть подробнее: что сделал и сколько").font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// Строка дела. По нажатию — разбор оценки и правка.
struct EntryRow: View {
    let entry: Entry
    var showDay = false
    var editable = true
    @Environment(EventStore.self) private var store
    @State private var open = false

    var body: some View {
        Button { if editable { open.toggle() } } label: {
            HStack(spacing: 10) {
                SkillIcon(skill: entry.skill)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.text).lineLimit(1)
                    Text(meta).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                XPText(xp: entry.xp)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(store.lastAdded?.id == entry.id ? Color.accentColor.opacity(0.08) : .clear)
        .popover(isPresented: $open, arrowEdge: .trailing) { EntryDetail(entry: entry, close: { open = false }) }
    }

    private var meta: String {
        let time = Date(timeIntervalSince1970: Double(entry.ts) / 1000).formatted(date: .omitted, time: .shortened)
        let from = entry.device.hasPrefix("mac") ? "Mac" : "телефон"
        return [showDay ? DayTitle.of(entry.day, today: store.today) : nil, time, entry.skill.title, from, entry.edited ? "поправлено" : nil]
            .compactMap { $0 }.joined(separator: " · ")
    }
}

struct EntryDetail: View {
    let entry: Entry
    let close: () -> Void
    @Environment(EventStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(entry.text).font(.headline).fixedSize(horizontal: false, vertical: true)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                ForEach(Array(entry.steps.enumerated()), id: \.offset) { _, s in
                    GridRow {
                        Text(s.name).foregroundStyle(.secondary)
                        Text(s.val).monospacedDigit().gridColumnAlignment(.trailing)
                    }
                }
                Divider().gridCellUnsizedAxes(.horizontal)
                GridRow {
                    Text("Итого").fontWeight(.semibold)
                    XPText(xp: entry.xp).gridColumnAlignment(.trailing)
                }
            }
            .font(.callout)
            if !entry.isQuest {
                HStack {
                    if entry.xp > 0 {
                        Button("Мало", systemImage: "arrow.up") { store.tune(entry, .up); close() }
                        Button("Много", systemImage: "arrow.down") { store.tune(entry, .down); close() }
                    } else {
                        Button("Слишком строго", systemImage: "arrow.up") { store.tune(entry, .soft); close() }
                    }
                    Spacer()
                    Button("Удалить", systemImage: "trash", role: .destructive) { store.delete(entry); close() }
                }
                .controlSize(.small)
                Text("«Мало» и «Много» запоминаются: следующие дела этого навыка будут оцениваться иначе.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}

enum DayTitle {
    static func of(_ day: String, today: String) -> String {
        if day == today { return "Сегодня" }
        if day == DayClock.shift(today, by: -1) { return "Вчера" }
        let p = day.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3, let d = Calendar.current.date(from: DateComponents(year: p[0], month: p[1], day: p[2])) else { return day }
        return d.formatted(.dateTime.day().month(.wide).weekday(.wide)).capitalizedFirst
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
