# 工作队列

只放需要继续行动的事项。开始任务先读 [用户意图](01-USER-INTENT.md)，再按 [导览](00-START-HERE.md)读取对应设计；历史完成详情仅在需要追溯时读[实施历史归档](../Docs/Architecture/ImplementationHistory.md)。文档目标与代码现状分开，验证记录只证明记录时的版本。

## 进行中

- **#67 · Stage 2 大库性能口径决定**（待决定）。歌曲、专辑、艺人及后台维护已分页，本轮功能由用户验收。固定磁盘库的隔离存储路径 47–53ms；受控 App 进程就绪约 0.7 秒、总 RSS 比分页前降约 26%，各自扣除空库基线后的曲库额外 RSS 降约 76%。完整测量条件见[大曲库架构](../Docs/Architecture/LargeLibraryAndIdentityArchitecture.md)。路线图原文的全进程 `<100ms` 与总 RSS 降 70% 未达；等待用户决定保留原指标继续优化，或把 Stage 2 验收口径明确为曲库增量性能。
- **#61 · 本地专辑连续 PCM 排程**（已实现，待用户验收）。同采样率、同声道曲目在单个播放节点接续；定向代码测试 4 项及 macOS Debug 构建通过。依据 [Stage 2 路线图](../Docs/Roadmap/FoundationRoadmap.md)、[播放交互 15.2](../Docs/Blueprint/InteractionAtlas.md)；当时实现见[实施记录](../Docs/Architecture/ImplementationHistory.md)。完成条件：用户确认真实专辑交接听感、曲目信息切换与队列顺序。
- **#62 · NAS 专辑连续播放与异格式交接**（已实现，待用户验收）。普通单曲流播；专辑队列经临时下载和 PCM 预备接续，异格式退回正常切歌。定向代码测试 8 项通过；真实 NAS 听感、等待与错误体验由用户验收。依据[播放交互 15.2](../Docs/Blueprint/InteractionAtlas.md)，细节见[实施记录](../Docs/Architecture/ImplementationHistory.md)。

## Stage 2 剩余任务（按顺序推进）

以下是[Stage 2 总目标](../Docs/Roadmap/FoundationRoadmap.md)的执行拆分；一次只领取一项，完成后保留一行索引，细节归档。AI 负责构建、代码、接口与可重复的性能/数据测试；用户负责听感、设备实测与界面体验。未实测的能力不得写成已验收。

| 编号 / 状态 | 大任务与边界 | 完成条件 / 交接依据 |
| --- | --- | --- |
| **#67 · 待决定** | **50,000 首曲库性能验收口径**：固定设备、数据集、进程起止点和 RSS 基线已有[实测记录](../Docs/Architecture/LargeLibraryAndIdentityArchitecture.md)。隔离数据路径与曲库额外 RSS 达目标；全 App 进程指标未达路线图原文。 | 用户明确选定 Stage 2 的指标口径；若坚持全进程数字，则继续优化并复测，不能以曲库代码路径代替。用户已完成本轮界面体验验收。 |
| **#68 · 进行中** | **Stage 2 集成与收尾**：相关代码定向测试本轮 58 项通过，来源测试夹具修正后 3 项通过；macOS/iOS Simulator Debug 构建与架构导入门禁通过。阶段相关音频面板 Preview 已补；仓库另有 35 项既有 Preview 门禁欠账，独立处理。依据[Stage 2 路线图](../Docs/Roadmap/FoundationRoadmap.md)与[架构验证](../Docs/Architecture/ArchitectureVerification.md)。 | 等 #67 指标口径、#61/#62 用户听感及 DAC 硬件边界结论；明确 Bit-Perfect、切率、独占、热拔插哪些获证实，哪些留后续；路线图只记录实际达成，再标记 Stage 2 结束。 |

## 按真实需求启动

- 异类产品（酒店预订/文档工具）验证切片：先有明确使用场景，不提前建设多个完整产品。
- 自有后端、同步、Web 管理端：先明确用户、权威数据与交易用例。
- 新的框架公共能力：先证明重复机制和所有权、失败语义一致。

## 已完成索引

- 编号 **1–60** 已完成；范围、当时证据及必要背景见[实施历史归档](../Docs/Architecture/ImplementationHistory.md)。#59 的 Spotlight 与快捷指令已由用户验收通过；歌词功能由用户手动试用，端到端基本通过。
- **#63–#64** 已由用户于 2026-09-23 验收通过：非默认设备切换与均衡器音量问题修复；代码与测试证据见[实施历史归档](../Docs/Architecture/ImplementationHistory.md)。Bit-Perfect 等未证实的 DAC 边界留 #68 决定。
- **#65** 已由用户于 2026-09-23 验收当前响度功能；显式曲目/专辑 R128 分析、缓存和播放增益已实现，专辑缓存会校验全部成员签名。既有标签直接采用仍未实现；代码测试与限制见[实施历史归档](../Docs/Architecture/ImplementationHistory.md)。
- **#66** 已于 2026-09-24 落地：增量写入、迁移/重试对账、部分导入失败报告、删除时收藏/歌单与资产同事务级联；多来源收藏保留其他来源。代码与测试证据见[实施历史归档](../Docs/Architecture/ImplementationHistory.md)。
- 历史验证不作为当前构建或测试结果。新任务只做影响范围内的定向代码、接口测试；长期有效的回归用例留正式 Tests，任务探针用完移除。具体分工见[架构验证](../Docs/Architecture/ArchitectureVerification.md)。

## 维护规则

每项活跃任务写清目标、设计链接、完成条件与状态（待开始 / 进行中 / 待决定）。完成后在此保留一行索引，把必要详情移入对应长期设计或历史归档；不复制全量旧记录。Stage 2 由 #68 做最终关闭，不因单项编译或文档完成而提前宣告结束。实现事实以当前代码和定向验证为准。
