import Foundation

enum DeepSeekError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case unauthorized
    case insufficientBalance
    case rateLimited
    case offline
    case timeout
    case server(Int)
    case network(String)
    case badResponse(String)

    var errorDescription: String? { message }

    var message: String {
        switch self {
        case .missingAPIKey:
            return "请先在设置页填写并保存 API Key。"
        case .invalidURL:
            return "Base URL 无效，请填写以 http:// 或 https:// 开头的地址。"
        case .unauthorized:
            return "API Key 无效（401），请检查后重试。"
        case .insufficientBalance:
            return "账户余额不足（402）。"
        case .rateLimited:
            return "请求过多（429），请稍后重试。"
        case .offline:
            return "当前离线，PDF 仍可阅读，AI 功能需联网。"
        case .timeout:
            return "连接超时，请检查网络后重试。"
        case .server(let statusCode):
            return "服务器错误（HTTP \(statusCode)），请稍后重试。"
        case .network(let detail):
            return "网络错误：\(detail)"
        case .badResponse(let detail):
            return "响应异常：\(detail)"
        }
    }
}

/// M1 只需要"测试连接"；M2 的流式翻译和解释会在这里继续扩展。
enum DeepSeekClient {
    static func testConnection(apiKey: String, baseURL: String, model: String) async throws -> String {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw DeepSeekError.missingAPIKey }

        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedModel.isEmpty else {
            throw DeepSeekError.badResponse("请填写模型名称，例如 deepseek-chat。")
        }
        guard let url = chatCompletionsURL(baseURL: baseURL) else {
            throw DeepSeekError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let payload = ChatRequest(
            model: trimmedModel,
            messages: [ChatRequest.Message(role: "user", content: "ping")],
            stream: false,
            max_tokens: 8
        )
        request.httpBody = try JSONEncoder().encode(payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            return try parseResponse(data: data, response: response)
        } catch let error as DeepSeekError {
            throw error
        } catch let error as URLError {
            throw mapURLError(error)
        } catch {
            throw DeepSeekError.network(error.localizedDescription)
        }
    }

    /// 把用户填的 Base URL 规范成 `.../chat/completions`。
    static func chatCompletionsURL(baseURL: String) -> URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              components.host?.isEmpty == false else {
            return nil
        }

        var path = components.path
        while path.hasSuffix("/") {
            path.removeLast()
        }
        if !path.hasSuffix("/chat/completions") {
            path += "/chat/completions"
        }
        components.path = path
        components.query = nil
        components.fragment = nil
        return components.url
    }

    private static func parseResponse(data: Data, response: URLResponse) throws -> String {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepSeekError.badResponse("无法识别服务器响应。")
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw DeepSeekError.unauthorized
        case 402:
            throw DeepSeekError.insufficientBalance
        case 429:
            throw DeepSeekError.rateLimited
        case 500...599:
            throw DeepSeekError.server(httpResponse.statusCode)
        default:
            let detail = apiErrorMessage(from: data)
            throw DeepSeekError.badResponse(
                "HTTP \(httpResponse.statusCode)\(detail.isEmpty ? "" : "：\(detail)")"
            )
        }

        guard let decoded = try? JSONDecoder().decode(ChatResponse.self, from: data) else {
            throw DeepSeekError.badResponse("服务器已响应，但返回内容不是 OpenAI 兼容格式，请检查 Base URL。")
        }

        let content = decoded.choices.first?.message?.content?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return content.isEmpty ? "服务器已响应" : content
    }

    private static func mapURLError(_ error: URLError) -> DeepSeekError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost,
             .dnsLookupFailed, .cannotConnectToHost:
            return .offline
        case .timedOut:
            return .timeout
        default:
            return .network(error.localizedDescription)
        }
    }

    private static func apiErrorMessage(from data: Data) -> String {
        guard let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data),
              let message = envelope.error?.message else {
            return ""
        }
        return message
    }

    private struct ChatRequest: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }

        let model: String
        let messages: [Message]
        let stream: Bool
        let max_tokens: Int
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String?
            }

            let message: Message?
        }

        let choices: [Choice]
    }

    private struct APIErrorEnvelope: Decodable {
        struct APIError: Decodable {
            let message: String?
        }

        let error: APIError?
    }
}
