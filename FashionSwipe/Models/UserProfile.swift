import Foundation

struct UserProfile: Codable, Equatable {
    var displayName: String
    var category: Category
    var priceRange: PriceRange
    var favoriteStyles: [String]

    enum Category: String, Codable, CaseIterable, Identifiable {
        case all
        case ladies
        case mens

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .all:    return "すべて"
            case .ladies: return "レディース"
            case .mens:   return "メンズ"
            }
        }
    }

    enum PriceRange: String, Codable, CaseIterable, Identifiable {
        case all
        case under3000
        case from3000to10000
        case over10000

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .all:             return "すべて"
            case .under3000:       return "〜¥3,000"
            case .from3000to10000: return "¥3,000〜¥10,000"
            case .over10000:       return "¥10,000〜"
            }
        }

        func matches(price: Int) -> Bool {
            switch self {
            case .all:             return true
            case .under3000:       return price <= 3000
            case .from3000to10000: return price > 3000 && price <= 10000
            case .over10000:       return price > 10000
            }
        }
    }

    static let availableStyles: [String] = [
        "カジュアル",
        "きれいめ",
        "ストリート",
        "フェミニン",
        "ナチュラル",
        "モード"
    ]

    static let `default` = UserProfile(
        displayName: "",
        category: .all,
        priceRange: .all,
        favoriteStyles: []
    )
}
