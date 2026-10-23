# PRD：AI 读 PDF / 论文助手（iPad）

> 版本：v0.1 草案｜构建方式：SwiftUI + GitHub Actions（云端 macOS/Xcode）产出未签名 IPA → 全能签侧载｜LLM：DeepSeek API（用户自带 Key）

## 1. 目标与用户场景

**目标**：在 iPad 上读 PDF 时，选中一段就能马上翻译或解释，并能一键拿到全文摘要和要点卡片。

**核心用户**：化妆品研发和工艺人员（也就是作者本人），日常要读英文论文、原料技术资料（TDS/MSDS）和法规文件。

**典型场景**
1. 读英文论文时遇到一段方法描述，选中后点"翻译"，在侧栏看到中文。
2. 遇到"HLB 值"这类专业术语，选中后点"解释"，得到结合上下文的通俗解释。
3. 拿到一份 40 页的原料资料，点"全文摘要"，得到一段摘要和 5 到 10 张要点卡片。
4. 一周后再打开同一份 PDF，之前的翻译、解释和摘要都还在。

## 2. MVP 功能清单与验收标准

| # | 功能 | 验收标准 |
|---|---|---|
| F1 | 导入 PDF | 能从"文件"App 的文件选择器导入，也能从其他 App 的分享菜单用"在…中打开"导入；导入后文件复制进 App 沙盒；文档库列表显示标题、页数和导入时间 |
| F2 | PDF 阅读 | 用 PDFKit 显示，支持缩放、翻页和缩略图跳转；再次打开时回到上次阅读的页码 |
| F3 | 选中文字 → 翻译 | 选中文字后出现"翻译"按钮，在侧栏流式显示译文（英译中，中文原文译成英文）；选中超过 4000 字时提示过长 |
| F4 | 选中文字 → 解释 | 同上，输出包括：一句话解释、关键术语和相关背景；会附带选区前后约 500 字作为上下文 |
| F5 | 全文摘要 + 要点卡片 | 点击后分块处理并显示进度（如"3/8 块"）；最后生成 200 到 400 字的摘要和 5 到 10 张卡片（标题、内容、来源页码）；中途可以取消 |
| F6 | 长文分块 | 按页提取文本，每块约 6000 字；先对各块做摘要，再合并成全文摘要（map-reduce）；100 页的文档能完成处理 |
| F7 | 本地历史 | 每份文档的翻译、解释、摘要和卡片都存在本地；杀掉 App 重开后仍然在；可以单条删除 |
| F8 | API Key 设置 | 设置页输入 Key，存进 Keychain；有"测试连接"按钮；Base URL 和模型名可改（默认 `https://api.deepseek.com`、`deepseek-chat`） |
| F9 | 诚实的错误提示 | 断网、Key 无效、限流、超时都显示具体原因和"重试"按钮；失败就明确显示失败，绝不把半截内容当成结果保存 |

## 3. 页面与交互

1. **文档库（首页）**：网格或列表显示文档；右上角"+"用于导入；左滑可删除；右上角齿轮进入设置。
2. **阅读页**：用 `NavigationSplitView` 或 HStack 布局，左边约 65% 是 PDFView，右边约 35% 是 AI 侧栏，可以收起。
   - 选中文字后，在菜单（`UIEditMenuInteraction` / PDFView 选区菜单）或底部浮条显示「翻译｜解释｜复制」。
   - 侧栏分三个标签：**当前结果**、**历史**（本文档的全部记录，点一条会跳到对应页）、**摘要与卡片**。
   - 竖屏时侧栏改为底部弹出的 sheet。
3. **摘要页**：顶部是摘要，下面是卡片网格；点卡片的页码跳回原文；可以"复制全部为 Markdown"。
4. **设置页**：API Key（遮罩显示）、Base URL、模型、目标语言、测试连接。

## 4. 技术方案

**框架**：SwiftUI、PDFKit（显示和 `page.string` 提取文本）、UniformTypeIdentifiers、`fileImporter`、Security（Keychain）、URLSession（SSE 流式输出）、SwiftData（iOS 17 及以上；如果要兼容更老的系统就改用 JSON 文件）。

**扫描版 PDF**：MVP 只判断"这一页提取不到文字"，并提示"此页为图片，暂不支持"。OCR 放到 V2，用 Vision 在设备上识别。DeepSeek API 不支持图片输入，所以不能把页面图片发给它。

**数据模型（SwiftData）**
```swift
@Model class Document { var id: UUID; var title: String; var fileName: String
  var pageCount: Int; var importedAt: Date; var lastPage: Int
  @Relationship(deleteRule: .cascade) var notes: [AINote]
  var summary: String?; @Relationship(deleteRule: .cascade) var cards: [KeyCard] }
@Model class AINote { var id: UUID; var kind: String /* translate|explain */
  var sourceText: String; var result: String; var page: Int; var createdAt: Date }
@Model class KeyCard { var id: UUID; var title: String; var body: String; var page: Int }
```

**API 调用**：用 OpenAI 兼容的 `POST {baseURL}/chat/completions`，参数 `stream: true`，`temperature` 设为 0.3。超时设为 60 秒，限流（429）和服务器 5xx 错误时按指数退避最多重试 2 次。

**Prompt 模板**
- 翻译（system）：`你是专业学术翻译，领域：化妆品、化学、材料。忠实翻译，保留术语原文于括号中，不添加解释。只输出译文。`
  user：`请将以下内容翻译为{目标语言}：\n"""{选中文本}"""`
- 解释（system）：`你是耐心的领域专家。用中文解释，输出：1) 一句话解释 2) 关键术语（每条一行）3) 必要背景。不确定时明确说不确定，不编造数据。`
  user：`上下文：\n"""{前后文}"""\n需要解释的部分：\n"""{选中文本}"""`
- 分块摘要（map）：`总结以下第{i}/{n}块（第{p1}-{p2}页），列出关键事实、数据、结论，每条注明页码。\n"""{块文本}"""`
- 合并（reduce）：`根据以下各块要点，输出 JSON：{"summary":"200-400字中文摘要","cards":[{"title":"","body":"","page":1}]}，卡片5-10张。只输出 JSON。` 使用 `response_format: {"type":"json_object"}`，如果 JSON 解析失败就重试一次，仍然失败就报错，不显示半截结果。

**错误处理**
| 情况 | 表现 |
|---|---|
| 没有配置 Key | 引导用户去设置页 |
| 断网（`URLError.notConnectedToInternet`） | 显示"当前离线，PDF 仍可阅读，AI 功能需联网"，不做假的离线结果 |
| 401 | 提示"API Key 无效" |
| 402 | 提示"余额不足" |
| 429 | 提示"请求过多，稍后重试" |
| 流式输出中途断开 | 保留已收到的内容，但标为"未完成"，不存进历史，并提供重试 |
| 摘要的某一块失败 | 停止处理并提示"第 i 块失败"，可以从这一块接着跑 |

## 5. 非目标（MVP 不做）
- 扫描件 OCR、PDF 批注或高亮回写、多文档对比
- 账号、云同步、iCloud
- 内置 Key 或代理服务器（只用用户自己的 Key）
- 上架 App Store

## 6. 分阶段计划
- **M1（2 到 3 天）**：搭好工程骨架，打通 GitHub Actions 未签名 IPA 构建；完成导入、文档库、PDFKit 阅读和记住页码；完成设置页和 Keychain。
- **M2（3 到 4 天）**：完成选中文字后的翻译和解释，包括流式侧栏、历史保存和错误处理。
- **M3（3 到 4 天）**：完成分块全文摘要、要点卡片、进度显示和取消，以及导出 Markdown。
- **V2 想法**：扫描页 Vision OCR；术语表（自定义翻译对照）；高亮并写回 PDF 批注；针对整篇文档提问（检索相关块后再回答）；多篇论文对比；导出到 Notion 或 Obsidian；配合 Apple Pencil 圈选翻译。

## 7. 风险
- **PDF 文本提取质量**：双栏排版、公式和表格可能乱序。MVP 接受这一点，并在结果下方提示"原文提取可能不完整"。
- **Token 成本**：100 页的文档约 15 到 30 万字。开始前要先显示预估块数，让用户确认。
- **侧载签名会过期**：属于全能签的问题。数据存在沙盒里，覆盖安装时只要 Bundle ID 不变，数据就会保留，所以 Bundle ID 要固定。
- **隐私**：公司保密文件不要上传到外部 API。首次使用时弹窗提示。

## 8. 给 AI 编程助手的开工提示词

```
请从零创建一个 iPad SwiftUI App，名称 "PaperLens"，Bundle ID 固定为 com.cheng.paperlens，最低 iOS 17，只支持 iPad。
本阶段只做里程碑 M1，不要实现 AI 翻译/摘要。

功能：
1. 文档库首页：用 .fileImporter（UTType.pdf）导入 PDF，复制到 App 的 Documents/PDFs；同时支持分享菜单"在…中打开"（Info.plist 声明 CFBundleDocumentTypes 为 com.adobe.pdf，LSSupportsOpeningDocumentsInPlace=NO），用 .onOpenURL 接收。列表显示标题、页数、导入时间，支持左滑删除。
2. 阅读页：UIViewRepresentable 封装 PDFKit 的 PDFView（autoScales、缩略图跳转），记住并恢复 lastPage。右侧预留可折叠的空白 AI 侧栏（显示"即将推出"）。
3. 设置页：API Key（SecureField，存 Keychain，写一个 KeychainHelper）、Base URL（默认 https://api.deepseek.com）、模型（默认 deepseek-chat），保存在 UserDefaults；"测试连接"按钮调用 POST /chat/completions 发送"ping"，显示成功或具体错误（401/402/429/离线），不要伪造成功。
4. 数据：SwiftData 模型 Document(id, title, fileName, pageCount, importedAt, lastPage)。

工程与构建：
- 用 XcodeGen（project.yml）生成工程，不要提交 .xcodeproj。
- 新增 .github/workflows/build.yml：runs-on macos-latest，安装 xcodegen，执行 xcodebuild -sdk iphoneos -configuration Release CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build，把 .app 放进 Payload/ 后 zip 成 PaperLens-unsigned.ipa，用 actions/upload-artifact 上传；同时在推送 v* tag 时用 softprops/action-gh-release 把 IPA 发布到 GitHub Release（永久下载链接，不会像 Actions 产物那样过期）。
- 不使用任何第三方依赖。不要把任何 Key 写进代码。
- 完成后给出 README：如何触发构建、下载 IPA、用全能签签名安装。
请先列出文件结构，再逐个给出完整文件内容。
```
