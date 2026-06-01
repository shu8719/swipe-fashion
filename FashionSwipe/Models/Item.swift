import Foundation

struct Item: Identifiable, Codable {
    let itemCode: String
    let itemName: String
    let catchcopy: String
    let itemPrice: Int
    let shopName: String
    let reviewAverage: Double
    let reviewCount: Int
    let itemUrl: String
    let mediumImageUrls: [ImageUrl]
    let genreId: Int

    var id: String { itemCode }

    var cleanName: String {
        itemName
            .replacingOccurrences(of: "【[^】]*】", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    var largeImageUrl: URL? {
        guard let raw = mediumImageUrls.first?.imageUrl else { return nil }
        let enlarged = raw.replacingOccurrences(of: "_ex=128x128", with: "_ex=600x600")
        return URL(string: enlarged)
    }

    var productUrl: URL? { URL(string: itemUrl) }

    struct ImageUrl: Codable {
        let imageUrl: String
    }
}

struct RakutenResponse: Decodable {
    let Items: [ItemWrapper]

    struct ItemWrapper: Decodable {
        let Item: Item
    }
}
