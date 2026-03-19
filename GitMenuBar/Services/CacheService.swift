import Foundation

struct CacheService {
    private let cacheDirectory: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        cacheDirectory = appSupport.appendingPathComponent("GitMenuBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func save(prs: [PullRequest], filter: PRFilter) {
        let url = cacheDirectory.appendingPathComponent("cache_\(filter.rawValue).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(prs) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func load(filter: PRFilter) -> [PullRequest]? {
        let url = cacheDirectory.appendingPathComponent("cache_\(filter.rawValue).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([PullRequest].self, from: data)
    }
}
