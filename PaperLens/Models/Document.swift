import Foundation
import SwiftData

/// 一份导入到 App 沙盒里的 PDF。
@Model
final class Document {
    var id: UUID = UUID()
    var title: String = ""
    var fileName: String = ""
    var pageCount: Int = 0
    var importedAt: Date = Date()
    var lastPage: Int = 1

    init(
        id: UUID = UUID(),
        title: String,
        fileName: String,
        pageCount: Int,
        importedAt: Date = Date(),
        lastPage: Int = 1
    ) {
        self.id = id
        self.title = title
        self.fileName = fileName
        self.pageCount = pageCount
        self.importedAt = importedAt
        self.lastPage = lastPage
    }

    /// PDF 在沙盒里的真实位置。文件名由导入时生成，避免重名覆盖。
    var fileURL: URL {
        DocumentStore.pdfDirectory.appendingPathComponent(fileName)
    }
}
