import Foundation

enum MockDataService {
    private struct Manifest: Decodable {
        let version: Int
        let categories: [String: [String]]
    }

    private static var manifestCache: Manifest?

    static func loadItems(for category: UserProfile.Category = .all) -> [Item] {
        let files = filesForCategory(category)
        let merged = files.flatMap { load(file: $0) }
        var seenIds = Set<String>()
        var uniqueItems: [Item] = []
        for item in merged {
            if seenIds.insert(item.id).inserted {
                uniqueItems.append(item)
            }
        }
        return uniqueItems.shuffled()
    }

    private static func filesForCategory(_ category: UserProfile.Category) -> [String] {
        guard let manifest = loadManifest() else {
            return legacyFiles(for: category)
        }
        let mens   = manifest.categories["mens"]   ?? []
        let ladies = manifest.categories["ladies"] ?? []
        let unisex = manifest.categories["unisex"] ?? []
        switch category {
        case .all:    return mens + ladies + unisex
        case .ladies: return ladies + unisex
        case .mens:   return mens + unisex
        }
    }

    private static func loadManifest() -> Manifest? {
        if let cached = manifestCache { return cached }
        let url = Bundle.main.url(forResource: "DataManifest", withExtension: "json", subdirectory: "Data")
            ?? Bundle.main.url(forResource: "DataManifest", withExtension: "json")
        guard
            let url,
            let data = try? Data(contentsOf: url),
            let manifest = try? JSONDecoder().decode(Manifest.self, from: data)
        else { return nil }
        manifestCache = manifest
        return manifest
    }

    private static func legacyFiles(for category: UserProfile.Category) -> [String] {
        switch category {
        case .all:    return ["sample_ladies", "sample_mens", "sample_onepiece"]
        case .ladies: return ["sample_ladies", "sample_onepiece"]
        case .mens:   return ["sample_mens"]
        }
    }

    private static func load(file: String) -> [Item] {
        let url = Bundle.main.url(forResource: file, withExtension: "json", subdirectory: "Data")
            ?? Bundle.main.url(forResource: file, withExtension: "json")
        guard
            let url,
            let data = try? Data(contentsOf: url),
            let response = try? JSONDecoder().decode(RakutenResponse.self, from: data)
        else { return [] }
        return response.Items.map { $0.Item }
    }
}
