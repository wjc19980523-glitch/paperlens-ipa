import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct DocumentLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Document.importedAt, order: .reverse) private var documents: [Document]

    @State private var isFileImporterPresented = false
    @State private var isSettingsPresented = false
    @State private var importErrorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if documents.isEmpty {
                    emptyState
                } else {
                    documentList
                }
            }
            .navigationTitle("文档库")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isFileImporterPresented = true
                    } label: {
                        Label("导入 PDF", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isSettingsPresented = true
                    } label: {
                        Label("设置", systemImage: "gearshape")
                    }
                }
            }
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    importDocument(at: url)
                case .failure(let error):
                    importErrorMessage = error.localizedDescription
                }
            }
            .sheet(isPresented: $isSettingsPresented) {
                SettingsView()
            }
            .alert("导入失败", isPresented: importErrorBinding) {
                Button("好", role: .cancel) {}
            } message: {
                Text(importErrorMessage ?? "未知错误")
            }
            .onOpenURL { url in
                importDocument(at: url)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("还没有文档", systemImage: "books.vertical")
        } description: {
            Text("导入 PDF 开始阅读。也可以在其他 App 里选择“在 PaperLens 中打开”。")
        } actions: {
            Button("导入 PDF") {
                isFileImporterPresented = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var documentList: some View {
        List {
            ForEach(documents) { document in
                NavigationLink {
                    PDFReaderView(document: document)
                } label: {
                    DocumentRow(document: document)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        withAnimation {
                            DocumentStore.delete(document, in: modelContext)
                        }
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var importErrorBinding: Binding<Bool> {
        Binding(
            get: { importErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    importErrorMessage = nil
                }
            }
        )
    }

    private func importDocument(at url: URL) {
        do {
            try DocumentStore.importPDF(from: url, into: modelContext)
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }
}

private struct DocumentRow: View {
    let document: Document

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.richtext")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 44)
                .background(
                    Color.accentColor.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 8)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.headline)
                    .lineLimit(2)
                Text("\(document.pageCount) 页 · 导入于 \(document.importedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if document.lastPage > 1 {
                    Text("上次读到第 \(document.lastPage) 页")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
