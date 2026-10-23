import Foundation

enum MockDataService {
    private struct Manifest: Decodable {
        let version: Int
        let categories: [String: [String]]
    }

    private static var manifestCache: Manifest?

    // ファイル単位のデコード結果キャッシュ。
    // Bundle内のJSONは実行中に変化しないため、一度読んだ結果を使い回す。
    // 注意: ロック無し。呼び出し元は全て @MainActor の SwipeViewModel 経由で
    // 単一スレッドアクセスを前提とする。バックグラウンドから呼ぶ場合は排他制御が必要。
    private static var fileCache: [String: [Item]] = [:]

    static func loadItems(for category: UserProfile.Category = .all,
                          type: UserProfile.ItemType = .all) -> [Item] {
        let files = filesForCategory(category).filter { fileMatches(type, file: $0) }
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

    // MARK: - 種別フィルタ（ファイル名キーワード判定）

    /// 指定種別にファイルが該当するか。
    /// `.all` は全許可。特定種別では、種別不明の汎用ファイル（ladies/mens 等）は除外する。
    private static func fileMatches(_ type: UserProfile.ItemType, file: String) -> Bool {
        guard type != .all else { return true }
        return classifyType(file) == type
    }

    /// ファイル名からアイテム種別を推定する。判定できなければ nil。
    /// 判定順は重要: ワンピース → ボトムス → シューズ → トップス。
    /// （例: "boot_cut" は boot を含むが先にボトムスで拾う）
    private static func classifyType(_ file: String) -> UserProfile.ItemType? {
        let name = file.lowercased()

        let onepiece = ["onepiece", "one_piece", "all_in_one", "jump_suit", "jumpsuit",
                        "rompers", "romper", "salopette", "boiler_suit", "overall"]
        let bottoms  = ["pants", "jeans", "denim", "chino", "slacks", "cargo", "skinny",
                        "trousers", "shorts", "leggings", "bell_bottom", "boot_cut",
                        "gaucho", "culotte", "sarrouel", "bottom"]
        let shoes    = ["shoes", "boots", "boot", "pumps", "pump", "sandals", "sandal",
                        "sneakers", "sneaker", "loafer", "mule", "heel", "espadrille",
                        "monk", "wing_tip", "oxford", "derby", "chelsea", "chukka",
                        "engineer", "ballet", "stiletto", "brogue", "zouri", "babouche",
                        "moccasin", "slipper"]
        let tops     = ["shirt", "blouse", "tops", "top", "sweater", "knit", "camisole",
                        "hoodie", "parka", "sweat", "tshirt", "tee", "polo", "cardigan",
                        "vest", "turtle", "tunic", "neck", "sleeve", "cut_and_sew", "bare"]

        func contains(_ keys: [String]) -> Bool { keys.contains { name.contains($0) } }

        if contains(onepiece) { return .onepiece }
        if contains(bottoms)  { return .bottoms }
        if contains(shoes)    { return .shoes }
        if contains(tops)     { return .tops }
        return nil
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
        if let cached = fileCache[file] { return cached }   // ① キャッシュヒット

        let url = Bundle.main.url(forResource: file, withExtension: "json", subdirectory: "Data")
            ?? Bundle.main.url(forResource: file, withExtension: "json")
        guard
            let url,
            let data = try? Data(contentsOf: url),
            let response = try? JSONDecoder().decode(RakutenResponse.self, from: data)
        else {
            fileCache[file] = []        // ② 見つからない/失敗も空でキャッシュし再探索を防ぐ
            return []
        }
        let items = response.Items.map { $0.Item }
        fileCache[file] = items         // ③ デコード結果を保存
        return items
    }
}
