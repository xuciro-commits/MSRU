# 工作队列

只放需要继续行动的事项。开始任务先读 [用户意图](01-USER-INTENT.md)，再按 [导览](00-START-HERE.md)读取对应设计；历史完成详情仅在需要追溯时读[实施历史归档](../Docs/Architecture/ImplementationHistory.md)。文档目标与代码现状分开，验证记录只证明记录时的版本。

## 下一波：Stage 3 异类切片与框架独立

| 编号 / 状态 | 大任务与边界 | 完成条件 / 交接依据 |
| --- | --- | --- |
| **#69 · 下一项，待开始** | **确定首个异类切片和框架基线**：对照[Stage 3 路线图](../Docs/Roadmap/FoundationRoadmap.md)、[产品平台蓝图第 12 节](../Docs/Blueprint/ProductPlatformBlueprint.md)和[交互图谱](../Docs/Blueprint/InteractionAtlas.md)，选一个真实、可执行的文档或酒店工作流；明确对象、状态、保存/提交、冲突、失败恢复、多窗口与 Undo 边界。盘点 `AppFoundation` 的音乐依赖和可复用 Shell，不先建万能 Undo。 | 给出最小产品任务、纯文本交互框图、独立 Demo 的可验证退出条件及框架依赖处置清单；按结果细化 #70–#73。默认从无需后端的 Markdown 文档编辑切片评估，若有更具体的酒店业务场景则调整顺序。 |
| **#70 · 排队** | **首个独立 Demo App**：在 `Examples/` 中用现有 AppFoundation 装配、路由、窗口和 Shell 完成 #69 定义的单一工作流；业务状态留在 Demo，不能导入 MSRU。 | Demo 可独立构建，主要操作、空态、失败恢复和双窗口行为有定向代码测试；记录复用时必须改动的框架 API。 |
| **#71 · 排队** | **第二异类切片**：以酒店预订时间轴或文档/文件用例补足与首切片不同的数据和交互语义；自定义 Surface 归产品。 | 独立运行，草稿/提交/冲突或文件保存语义可复现；证明框架无需音乐类型，也无需为了 Surface 改核心。 |
| **#72 · 排队** | **Undo/Redo 机制提取**：先在产品切片内落实原生撤销，再比较两个真实用例的事务寿命、失败与恢复语义，仅提取相同机制。 | 多窗口撤销范围、提交/失败回滚定向测试通过；不能证明共性时保留产品局部实现并说明原因。 |
| **#73 · 排队** | **Stage 3 集成审查**：检查 Demo 独立性、框架音乐依赖、预览/构建/定向测试以及不必要的公共 API。 | 依据实测与代码审查决定哪些 API 留在框架、哪些回归产品；用户验收产品体验后收尾。 |

### 新会话从这里接手

- 当前只有 MSRU App 和 `Packages/AppFoundation`，尚无 `Examples/` 或框架级 Undo。`AppFoundation/Package.swift` 仍依赖 ChromaSwift、MediaLibrary、SubsonicKit，`Exports.swift` 还导出后两者；音乐领域类型见 `Fingerprint/AudioFingerprint.swift`、`External/ExternalCatalogService.swift`。#69 先区分可删除的包耦合和仍有真实调用者的业务代码，不直接迁移全包。
- 装配参考 `MSRU/App/Composition/MSRUApplication.swift`；框架入口为 `AppFoundationUI/Application/ApplicationDefinition.swift`、`ApplicationShell.swift` 与 `Workspace/WorkspacePresentation.swift`。新 Demo 应独立引用 package，而非复制 MSRU 的音乐状态。已有框架契约测试位于 `Packages/AppFoundation/Tests/AppFoundationUITests`。
- [路线图](../Docs/Roadmap/FoundationRoadmap.md)将 DocStudio 排在 HotelDesk 前，[产品平台蓝图第 12 节](../Docs/Blueprint/ProductPlatformBlueprint.md)建议酒店时间轴先行；这是设计顺序差异，不是代码冲突。#69 按真实使用场景决定，未得到具体酒店需求时可先用 Markdown 文件编辑验证独立 Shell、多窗口与撤销。
- AI 只做必要构建、契约与接口测试；用户负责视觉、使用体感和端到端。长期回归留正式 Tests，任务探针用完删除。visionOS 开发暂停。下一任务先完成 #69，再领取 #70；不要重做已验收的 #67/#68。

## 按真实需求启动

- 异类产品（酒店预订/文档工具）验证切片：先有明确使用场景，不提前建设多个完整产品。
- 自有后端、同步、Web 管理端：先明确用户、权威数据与交易用例。
- 新的框架公共能力：先证明重复机制和所有权、失败语义一致。

## 已完成索引

- 编号 **1–60** 已完成；范围、当时证据及必要背景见[实施历史归档](../Docs/Architecture/ImplementationHistory.md)。#59 的 Spotlight 与快捷指令已由用户验收通过；歌词功能由用户手动试用，端到端基本通过。
- **#63–#64** 已由用户于 2026-09-23 验收通过：非默认设备切换与均衡器音量问题修复；代码与测试证据见[实施历史归档](../Docs/Architecture/ImplementationHistory.md)。Bit-Perfect 等未证实的 DAC 边界留 #68 决定。
- **#65** 已由用户于 2026-09-23 验收当前响度功能；显式曲目/专辑 R128 分析、缓存和播放增益已实现，专辑缓存会校验全部成员签名。既有标签直接采用仍未实现；代码测试与限制见[实施历史归档](../Docs/Architecture/ImplementationHistory.md)。
- **#66** 已于 2026-09-24 落地：增量写入、迁移/重试对账、部分导入失败报告、删除时收藏/歌单与资产同事务级联；多来源收藏保留其他来源。代码与测试证据见[实施历史归档](../Docs/Architecture/ImplementationHistory.md)。
- **#61–#62** 已由用户于 2026-09-24 确认本轮使用验收通过；本地与 NAS 专辑接续的实现和定向测试见[实施历史归档](../Docs/Architecture/ImplementationHistory.md)。该确认不替代 DAC 独占、物理采样率和热拔插的单独测量。
- **#67–#68 · Stage 2 收尾**已由用户于 2026-09-24 明确确认通过并停止继续处理。实际性能数字和原目标差距见[大曲库架构](../Docs/Architecture/LargeLibraryAndIdentityArchitecture.md)；Bit-Perfect、DAC 物理切率/独占/热拔插仍无单独证明，不能对外宣称已达到。集成验证及验收边界见[实施历史归档](../Docs/Architecture/ImplementationHistory.md)。
- 历史验证不作为当前构建或测试结果。新任务只做影响范围内的定向代码、接口测试；长期有效的回归用例留正式 Tests，任务探针用完移除。具体分工见[架构验证](../Docs/Architecture/ArchitectureVerification.md)。

## 维护规则

每项活跃任务写清目标、设计链接、完成条件与状态（待开始 / 进行中 / 待决定）。完成后在此保留一行索引，把必要详情移入对应长期设计或历史归档；不复制全量旧记录。实现事实以当前代码和定向验证为准。
