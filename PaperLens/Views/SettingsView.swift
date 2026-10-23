import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKeys.baseURL) private var baseURL = AppSettings.defaultBaseURL
    @AppStorage(SettingsKeys.model) private var model = AppSettings.defaultModel
    @AppStorage(SettingsKeys.targetLanguage) private var targetLanguage = AppSettings.defaultTargetLanguage

    @State private var apiKey = ""
    @State private var hasStoredKey = false
    @State private var isKeyRevealed = false
    @State private var isClearConfirmationPresented = false
    @State private var saveMessage: String?
    @State private var testState: ConnectionTestState = .idle

    var body: some View {
        NavigationStack {
            Form {
                apiKeySection
                apiConfigurationSection
                connectionSection
                milestoneSection
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadStoredKey()
            }
            .onChange(of: apiKey) { _, _ in
                testState = .idle
                saveMessage = nil
            }
            .confirmationDialog(
                "清除 API Key？",
                isPresented: $isClearConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("清除", role: .destructive) {
                    clearStoredKey()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("清除后 AI 功能将无法使用，需要重新填写。")
            }
        }
    }

    private var apiKeySection: some View {
        Section {
            HStack {
                Group {
                    if isKeyRevealed {
                        TextField("sk-...", text: $apiKey)
                    } else {
                        SecureField("sk-...", text: $apiKey)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.password)

                Button {
                    isKeyRevealed.toggle()
                } label: {
                    Image(systemName: isKeyRevealed ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }

            Button("保存到 Keychain") {
                saveAPIKey()
            }
            .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let saveMessage {
                Label(saveMessage, systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.green)
            } else if hasStoredKey {
                Label("已保存到 Keychain", systemImage: "checkmark.seal.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if hasStoredKey {
                Button("清除已保存的 Key", role: .destructive) {
                    isClearConfirmationPresented = true
                }
            }
        } header: {
            Text("API Key")
        } footer: {
            Text("Key 只保存在本机 Keychain，不会上传，也不会写进代码。")
        }
    }

    private var apiConfigurationSection: some View {
        Section {
            TextField("Base URL", text: $baseURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)

            TextField("模型", text: $model)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Picker("目标语言", selection: $targetLanguage) {
                Text("中文").tag("中文")
                Text("英文").tag("英文")
            }
        } header: {
            Text("API 配置")
        } footer: {
            Text("默认值适用于 DeepSeek；任何 OpenAI 兼容接口都可以填在这里。目标语言会在 M2 的翻译里使用。")
        }
    }

    private var connectionSection: some View {
        Section {
            Button {
                Task {
                    await runConnectionTest()
                }
            } label: {
                HStack {
                    Text("测试连接")
                    Spacer()
                    if testState.isTesting {
                        ProgressView()
                    }
                }
            }
            .disabled(
                testState.isTesting
                    || apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )

            connectionStatus
        } header: {
            Text("连接测试")
        } footer: {
            Text("测试只发送一个“ping”，不会上传任何文档内容。")
        }
    }

    @ViewBuilder
    private var connectionStatus: some View {
        switch testState {
        case .idle:
            Text("点“测试连接”检查网络、Key 和模型是否可用。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .testing:
            HStack(spacing: 8) {
                ProgressView()
                Text("正在连接…")
                    .font(.footnote)
            }
        case .success(let reply):
            VStack(alignment: .leading, spacing: 4) {
                Label("连接成功", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("模型回复：\(reply)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        case .failure(let message):
            VStack(alignment: .leading, spacing: 4) {
                Label("连接失败", systemImage: "xmark.octagon.fill")
                    .foregroundStyle(.red)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var milestoneSection: some View {
        Section {
            Text("当前是 M1：导入、PDF 阅读、设置和本地存储。翻译、解释和摘要会在后续里程碑加入。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func loadStoredKey() {
        guard let key = KeychainHelper.read(account: KeychainHelper.apiKeyAccount),
              !key.isEmpty else {
            return
        }
        apiKey = key
        hasStoredKey = true
    }

    private func saveAPIKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            testState = .failure("请先填写 API Key。")
            return
        }

        do {
            try KeychainHelper.save(trimmed, account: KeychainHelper.apiKeyAccount)
            apiKey = trimmed
            hasStoredKey = true
            saveMessage = "已保存到 Keychain"
            testState = .idle
        } catch {
            saveMessage = nil
            testState = .failure(error.localizedDescription)
        }
    }

    private func clearStoredKey() {
        KeychainHelper.delete(account: KeychainHelper.apiKeyAccount)
        apiKey = ""
        hasStoredKey = false
        saveMessage = nil
        testState = .idle
    }

    @MainActor
    private func runConnectionTest() async {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            testState = .failure("请先填写 API Key。")
            return
        }

        testState = .testing
        do {
            let reply = try await DeepSeekClient.testConnection(
                apiKey: trimmedKey,
                baseURL: baseURL,
                model: model
            )
            testState = .success(reply)
        } catch let error as DeepSeekError {
            testState = .failure(error.message)
        } catch {
            testState = .failure(error.localizedDescription)
        }
    }
}

private enum ConnectionTestState {
    case idle
    case testing
    case success(String)
    case failure(String)

    var isTesting: Bool {
        if case .testing = self {
            return true
        }
        return false
    }
}
