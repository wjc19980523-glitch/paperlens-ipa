import SwiftUI

/// M1 只占位；M2 的翻译/解释和 M3 的摘要会填进这个侧栏。
struct AISidebarPlaceholder: View {
    let document: Document

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.accentColor)
                Text("AI 助手")
                    .font(.headline)
                Spacer()
                Text("即将推出")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("这一步先留个位置")
                    .font(.title3.weight(.semibold))
                Text("M2 会在这里显示选中文字的翻译和解释；M3 会加入全文摘要和要点卡片。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Label("\(document.pageCount) 页", systemImage: "doc.text")
                Label("上次读到第 \(document.lastPage) 页", systemImage: "bookmark")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            Spacer()

            Text("阅读进度会自动保存，下次打开回到这一页。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(uiColor: .secondarySystemBackground))
    }
}
