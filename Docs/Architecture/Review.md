# 本次架构评审入口

先读三份：

1. [North Star Architecture](NorthStarArchitecture.md)：概念、模块、生命周期、依赖方向，以及为什么不应该再建一个万能 ApplicationRuntime。
2. [Abstraction Audit](AbstractionAudit.md)：逐项取舍和五个有源码依据的优先问题。
3. [Foundation Roadmap](../Roadmap/FoundationRoadmap.md)：NOW / NEXT / LATER / NOT YET、迁移文件、API 删除、测试与停止条件。

其余问题：

- 问题 3：North Star 中的 Runtime 职责。
- 问题 4、5：[跨平台与 UI 语言](../UI/ApplicationUILanguage.md)。包含 Browse 双平台切片方案；本次未实现 renderer、组件，也未进行参考应用视觉研究。
- 问题 6：[数据边界](DataBoundaries.md)。
- 问题 7、8：[并发与恢复](ConcurrencyModel.md)。
- 问题 9：[架构验证](ArchitectureVerification.md)，已增加文本门禁和 MSRU 实际 definition 契约测试；不是完整语义架构编译器，也未部署 CI。

## 已运行的验证

- `swift test --package-path Packages/AppFoundation`：49 项通过（36 UI + 13 Core）。
- macOS `MSRUTests` 原有测试：86 项通过。
- 新增 `ApplicationDefinitionContractTests`：1 项通过。
- `Scripts/verify-architecture.py`：当前源码通过；临时反例验证四种违规均被拒绝。
- 新增文件无尾随空白。全仓库 `git diff --check` 仍报告用户已有 `MSRU/Pro.swift` 中三处尾随空白，本次未修改。

没有运行 UI 自动化、人工双窗口/退出恢复验收、iPad/visionOS 构建或故障时序复现。单元测试通过不代表文档指出的缺口已经修复。

本次只新增这些文档、门禁脚本和契约测试；未修改生产代码，未提交 Git，也未接管当前未提交迁移。审计为定向源码核查与测试验证，不是全仓库和全部 Git 历史的穷尽审计。
