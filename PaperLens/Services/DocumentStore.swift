import Foundation
import PDFKit
import SwiftData
import UniformTypeIdentifiers

enum DocumentImportError: LocalizedError {
    case notPDF
    case unreadablePDF
    case copyFailed(String)
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .notPDF:
            return "只能导入 PDF 文件。"
        case .unreadablePDF:
            return "无法读取这个 PDF，文件可能已损坏。"
        case .copyFailed(let message):
            return "复制文件失败：\(message)"
        case .saveFailed(let message):
            return "保存文档记录失败：\(message)"
        }
    }
}

/// 负责把外部 PDF 复制进沙盒，以及在删除记录时清理文件。
enum DocumentStore {
    static var pdfDirectory: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PDFs", isDirectory: true)
    }

    @discardableResult
    static func importPDF(from url: URL, into context: ModelContext) throws -> Document {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let isPDF = url.pathExtension.lowercased() == "pdf"
            || (UTType(filenameExtension: url.pathExtension)?.conforms(to: .pdf) ?? false)
        guard isPDF else { throw DocumentImportError.notPDF }

        guard let pdf = PDFDocument(url: url), pdf.pageCount > 0 else {
            throw DocumentImportError.unreadablePDF
        }

        let directory = pdfDirectory
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            let storedFileName = "\(UUID().uuidString).pdf"
            let destination = directory.appendingPathComponent(storedFileName)
            try FileManager.default.copyItem(at: url, to: destination)

            let document = Document(
                title: displayTitle(for: url, pdf: pdf),
                fileName: storedFileName,
                pageCount: pdf.pageCount
            )
            context.insert(document)

            do {
                try context.save()
            } catch {
                context.delete(document)
                try? FileManager.default.removeItem(at: destination)
                throw DocumentImportError.saveFailed(error.localizedDescription)
            }

            return document
        } catch let error as DocumentImportError {
            throw error
        } catch {
            throw DocumentImportError.copyFailed(error.localizedDescription)
        }
    }

    static func delete(_ document: Document, in context: ModelContext) {
        let url = document.fileURL
        context.delete(document)
        try? context.save()
        try? FileManager.default.removeItem(at: url)
    }

    private static func displayTitle(for url: URL, pdf: PDFDocument) -> String {
        if let metadataTitle = pdf.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String {
            let trimmed = metadataTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        let fallback = url.deletingPathExtension().lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return fallback.isEmpty ? "未命名文档" : fallback
    }
}
