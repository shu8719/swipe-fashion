import Foundation

struct UserProfile: Codable, Equatable {
    var displayName: String
    var category: Category
    var priceRange: PriceRange
    var itemType: ItemType
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

    /// アイテム種別フィルタ。判定はファイル名キーワードで行う（MockDataService）。
    enum ItemType: String, Codable, CaseIterable, Identifiable {
        case all
        case tops
        case bottoms
        case shoes
        case onepiece

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .all:      return "すべて"
            case .tops:     return "トップス"
            case .bottoms:  return "ボトムス"
            case .shoes:    return "シューズ"
            case .onepiece: return "ワンピース"
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
        itemType: .all,
        favoriteStyles: []
    )
}

// MARK: - 後方互換デコード
// 既存の保存済みプロフィール（itemType フィールドが無い旧データ）も
// デコードできるよう、itemType は欠落時 .all として扱う。
// init(from:) を extension に置くことでメンバーワイズ初期化子は維持される。
extension UserProfile {
    enum CodingKeys: String, CodingKey {
        case displayName, category, priceRange, itemType, favoriteStyles
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        displayName    = try c.decode(String.self, forKey: .displayName)
        category       = try c.decode(Category.self, forKey: .category)
        priceRange     = try c.decode(PriceRange.self, forKey: .priceRange)
        itemType       = try c.decodeIfPresent(ItemType.self, forKey: .itemType) ?? .all
        favoriteStyles = try c.decode([String].self, forKey: .favoriteStyles)
    }
}
