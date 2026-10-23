# PaperLens

iPad 上的 AI PDF / 论文阅读助手。需求文档见 [docs/PRD.md](docs/PRD.md)。

当前进度：**M1（文档库、PDFKit 阅读、设置与 Keychain、SwiftData）**。翻译、解释和摘要尚未实现。

## M1 功能
- **文档库**：`.fileImporter` 导入 PDF，文件复制到沙盒 `Documents/PDFs/`；支持其他 App 的“在 PaperLens 中打开”；列表显示标题、页数、导入时间，左滑删除。
- **阅读页**：PDFKit（缩放、连续翻页），底部缩略图条可跳页，自动记住并恢复上次阅读页码；右侧是可折叠的占位 AI 侧栏。
- **设置页**：API Key 存入 Keychain（不写进代码）；Base URL、模型、目标语言存 `UserDefaults`；“测试连接”会真实请求 `POST {baseURL}/chat/completions`，并区分 401 / 402 / 429 / 离线 / 超时。
- **数据**：SwiftData 模型 `Document`（标题、文件名、页数、导入时间、上次页码）。

## 目录结构
```
PaperLens/
  PaperLensApp.swift        App 入口 + SwiftData 容器
  Models/Document.swift     SwiftData 模型
  Services/
    DocumentStore.swift     导入、复制、删除沙盒文件
    DeepSeekClient.swift    测试连接（后续 AI 调用的起点）
    KeychainHelper.swift    API Key 存取
    AppSettings.swift       UserDefaults key 与默认值
  Views/
    DocumentLibraryView.swift
    PDFReaderView.swift     PDFKit 封装 + 缩略图
    AISidebarPlaceholder.swift
    SettingsView.swift
```

## 构建与安装
1. 推送到 `main` 或在 Actions 页手动运行 **Build unsigned IPA**。
2. 在运行详情的 Artifacts 下载 `PaperLens-unsigned-ipa`（会过期）；或推送 `v*` tag，到 Releases 下载永久链接。
3. 用全能签签名后安装到 iPad。Bundle ID 固定为 `com.cheng.paperlens`，覆盖安装可保留沙盒数据。

工程由 XcodeGen 从 `project.yml` 生成，不要提交 `.xcodeproj`。新增源文件放进 `PaperLens/` 会自动纳入。

## 使用
1. 首次打开，点右上角齿轮，填入 DeepSeek API Key（[platform.deepseek.com](https://platform.deepseek.com)），保存后点“测试连接”。
2. 回到文档库，点右上角“+”导入 PDF；或在“文件”/其他 App 里用分享菜单“在 PaperLens 中打开”。
3. 打开文档阅读，翻页后退出会自动记住页码。若从其他 App 打开，文件会复制进 PaperLens 沙盒。
