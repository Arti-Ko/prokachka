import Foundation

/// Навык, к которому относится запись. `misc` — не распознан, `quest` — награда за квест.
public enum Skill: String, CaseIterable, Codable, Sendable {
    case body, mind, work, home, people, craft, rest, misc, quest

    /// Семь навыков, у которых есть свой уровень.
    public static let trained: [Skill] = [.body, .mind, .work, .home, .people, .craft, .rest]

    public var title: String {
        switch self {
        case .body: "Тело"
        case .mind: "Ум"
        case .work: "Дело"
        case .home: "Быт"
        case .people: "Связи"
        case .craft: "Творчество"
        case .rest: "Режим"
        case .misc: "Прочее"
        case .quest: "Квест"
        }
    }

    public var about: String {
        switch self {
        case .body: "Тренировки, бег, прогулки, зарядка"
        case .mind: "Книги, курсы, языки, разбор новой темы"
        case .work: "Работа, код, ТЗ, отчёты, свои проекты"
        case .home: "Уборка, готовка, ремонт, покупки"
        case .people: "Семья, друзья, помощь, встречи"
        case .craft: "Рисование, музыка, видео, посты"
        case .rest: "Сон, вода, медитация, отказ от вредного"
        case .misc, .quest: ""
        }
    }

    /// Сколько минут дела дают объём ×1: работа длиннее медитации.
    public var minuteNorm: Double {
        switch self {
        case .work: 60
        case .craft: 45
        case .rest: 15
        default: 30
        }
    }

    /// Базовый опыт за одно дело этого навыка.
    public var base: Double {
        switch self {
        case .body: 40
        case .mind: 30
        case .work: 45
        case .home: 20
        case .people: 25
        case .craft: 35
        case .rest: 15
        case .misc: 10
        case .quest: 0
        }
    }
}
