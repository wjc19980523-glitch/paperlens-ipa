# 给 AI 编程助手的说明

- 完整需求在 `docs/PRD.md`，开工前先读它。
- 工程用 XcodeGen（`project.yml`）生成，不要提交 `.xcodeproj`。新增源文件放进 `PaperLens/` 即可自动纳入。
- 构建由 `.github/workflows/build.yml` 在云端 Mac 完成，产出未签名 IPA；推 `v*` tag 会发布到 Release。不要改坏这条流程。
- Bundle ID 固定 `com.cheng.paperlens`，最低 iOS 17，只支持 iPad，不用第三方依赖，不把任何 API Key 写进代码。
- 一次只做一个里程碑，每次改完确保 Actions 仍然是绿的。
