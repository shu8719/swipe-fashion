import Foundation

enum MockDataService {
    static func loadItems() -> [Item] {
        let files = ["sample_ladies", "sample_mens", "sample_onepiece"]
        return files.flatMap { load(file: $0) }.shuffled()
    }

    private static func load(file: String) -> [Item] {
        guard
            let url = Bundle.main.url(forResource: file, withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let response = try? JSONDecoder().decode(RakutenResponse.self, from: data)
        else { return [] }
        return response.Items.map { $0.Item }
    }
}
