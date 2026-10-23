import SwiftData
import SwiftUI

@main
struct PaperLensApp: App {
    private let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: Document.self)
        } catch {
            fatalError("无法创建本地数据库：\(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            DocumentLibraryView()
        }
        .modelContainer(modelContainer)
    }
}
