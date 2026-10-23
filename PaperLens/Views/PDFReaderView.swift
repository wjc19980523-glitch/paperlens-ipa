import PDFKit
import SwiftData
import SwiftUI

struct PDFReaderView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var document: Document

    @State private var isSidebarVisible = true
    @State private var isThumbnailStripVisible = false
    @State private var pdfView: PDFView?

    private var fileExists: Bool {
        FileManager.default.fileExists(atPath: document.fileURL.path)
    }

    var body: some View {
        Group {
            if fileExists {
                readerContent
            } else {
                ContentUnavailableView {
                    Label("找不到 PDF 文件", systemImage: "doc.questionmark")
                } description: {
                    Text("文件可能已被删除。回到文档库删除这条记录后重新导入。")
                }
            }
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    isThumbnailStripVisible.toggle()
                } label: {
                    Label("页面缩略图", systemImage: "square.grid.2x2")
                }

                Button {
                    isSidebarVisible.toggle()
                } label: {
                    Label(
                        isSidebarVisible ? "收起 AI 侧栏" : "展开 AI 侧栏",
                        systemImage: "sidebar.right"
                    )
                }
            }
        }
        .onDisappear {
            try? modelContext.save()
        }
    }

    private var readerContent: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                PDFKitContainerView(
                    url: document.fileURL,
                    initialPage: document.lastPage,
                    pdfViewReference: $pdfView
                ) { page in
                    document.lastPage = page
                    try? modelContext.save()
                }

                if isThumbnailStripVisible, let pdfView {
                    Divider()
                    ThumbnailStripView(pdfView: pdfView)
                        .frame(height: 116)
                        .background(Color(uiColor: .secondarySystemBackground))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if isSidebarVisible {
                Divider()
                AISidebarPlaceholder(document: document)
                    .frame(width: 320)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSidebarVisible)
        .animation(.easeInOut(duration: 0.2), value: isThumbnailStripVisible)
    }
}

// MARK: - PDFKit

private struct PDFKitContainerView: UIViewRepresentable {
    let url: URL
    let initialPage: Int
    @Binding var pdfViewReference: PDFView?
    let onPageChange: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.maxScaleFactor = 6
        view.backgroundColor = .systemBackground
        view.document = PDFDocument(url: url)

        if let document = view.document, document.pageCount > 0 {
            let index = min(max(initialPage - 1, 0), document.pageCount - 1)
            if let page = document.page(at: index) {
                view.layoutIfNeeded()
                view.go(to: page)
            }
        }

        context.coordinator.attach(to: view)

        DispatchQueue.main.async {
            self.pdfViewReference = view
        }

        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        context.coordinator.parent = self
        if uiView.document == nil {
            uiView.document = PDFDocument(url: url)
        }
    }

    final class Coordinator {
        var parent: PDFKitContainerView
        private weak var pdfView: PDFView?
        private var pageObserver: NSObjectProtocol?

        init(_ parent: PDFKitContainerView) {
            self.parent = parent
        }

        func attach(to view: PDFView) {
            pdfView = view
            pageObserver = NotificationCenter.default.addObserver(
                forName: .PDFViewPageChanged,
                object: view,
                queue: .main
            ) { [weak self] _ in
                self?.handlePageChange()
            }
        }

        private func handlePageChange() {
            guard let view = pdfView,
                  let page = view.currentPage,
                  let document = view.document else {
                return
            }

            let index = document.index(for: page)
            guard index != NSNotFound else { return }
            parent.onPageChange(index + 1)
        }

        deinit {
            if let pageObserver {
                NotificationCenter.default.removeObserver(pageObserver)
            }
        }
    }
}

private struct ThumbnailStripView: UIViewRepresentable {
    let pdfView: PDFView

    func makeUIView(context: Context) -> PDFThumbnailView {
        let view = PDFThumbnailView(frame: .zero)
        view.layoutMode = .horizontal
        view.thumbnailSize = CGSize(width: 56, height: 72)
        view.backgroundColor = .secondarySystemBackground
        view.pdfView = pdfView
        return view
    }

    func updateUIView(_ uiView: PDFThumbnailView, context: Context) {
        if uiView.pdfView !== pdfView {
            uiView.pdfView = pdfView
        }
    }
}
