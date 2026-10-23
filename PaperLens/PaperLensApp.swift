import SwiftUI

@main
struct PaperLensApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 64))
                Text("PaperLens").font(.largeTitle.bold())
                Text("骨架工程，构建流程已打通。功能见 docs/PRD.md")
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}
