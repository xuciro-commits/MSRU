# 从这里开始

本目录是项目工作的入口，不存放所有设计正文。先理解意图，再按任务定位设计，最后进入实现与验证。

## 阅读顺序

```text
01-USER-INTENT.md               用户要什么、偏好什么、如何交付
        │
        ▼
02-WORK-QUEUE.md                当前待办、优先级、完成证据
        │
        ├─ 产品与长期方向 ─────► Docs/Blueprint + Docs/Architecture
        ├─ 界面与逐层交互 ─────► Docs/UI + InteractionAtlas
        ├─ 客户端与服务端 ─────► ClientServerArchitecture
        └─ 架构与验证 ─────────► 对应专题文档 + 实际代码和测试
```

## 从意图定位设计

| 想知道什么 | 去哪里 | 如何使用 |
| --- | --- | --- |
| 用户终极目标、技术与合作偏好 | [用户意图](01-USER-INTENT.md) | 每项任务先对齐这里；以用户最新指令为准 |
| 下一步做什么、还有什么差距 | [工作队列](02-WORK-QUEUE.md) | 确定本次范围；旧条目与最新授权冲突时更新条目 |
| 产品平台整体蓝图 | [产品平台蓝图](../Docs/Blueprint/ProductPlatformBlueprint.md) | 理解产品与框架之间的关系 |
| 应用、场景、Feature 的总体方向 | [目标架构](../Docs/Architecture/NorthStarArchitecture.md) | 找职责、所有权与依赖边界 |
| 前后端与本地能力如何分工 | [客户端与服务端架构](../Docs/Blueprint/ClientServerArchitecture.md) | 定契约与数据边界，不默认必须建后端 |
| 产品体验如何组织 | [体验蓝图](../Docs/Blueprint/ExperienceBlueprint.md) | 理解跨页面的任务与交互组织 |
| 从窗口到组件的具体文本示意图 | [交互图谱](../Docs/Blueprint/InteractionAtlas.md) | 查结构、动作、状态与交互去向 |
| 通用界面区域与表达规则 | [应用 UI 语言](../Docs/UI/ApplicationUILanguage.md) | 对齐导航、工作区、上下文和附件等语义 |
| 哪些抽象值得保留 | [抽象审视](../Docs/Architecture/AbstractionAudit.md) | 判断复用价值，避免过度框架化 |
| 并发、取消、生命周期 | [并发模型](../Docs/Architecture/ConcurrencyModel.md) | 明确任务所有者和失效行为 |
| 数据、持久化与业务边界 | [数据边界](../Docs/Architecture/DataBoundaries.md) | 避免状态与存储职责混杂 |
| 音乐实体数据库与身份解析 | [身份解析引擎](../Docs/Architecture/IdentityResolutionEngine.md) | 实体模型、三层元数据、声纹聚类与加权匹配 |
| 如何验证架构要求 | [架构验证](../Docs/Architecture/ArchitectureVerification.md) | 转换为构建、测试和可执行约束 |
| 已有问题与审视背景 | [架构审视](../Docs/Architecture/Review.md) | 作为分析线索；历史结论须对照当前代码 |
| 分阶段演进方向 | [基础框架路线图](../Docs/Roadmap/FoundationRoadmap.md) | 作为顺序参考，不视作全部立即实施的授权 |

## todo 的职责

```text
todo/
├── README.md                 固定入口指针
├── 00-START-HERE.md           本导览：问题 → 对应文档
├── 01-USER-INTENT.md          长期用户意图
└── 02-WORK-QUEUE.md           唯一当前工作队列

Docs/
├── Blueprint/                产品、客户端服务端、体验与交互图谱
├── Architecture/             架构边界、专题审视与验证
├── UI/                       通用界面语义
└── Roadmap/                  长期阶段规划
```

以上是长期维护的主阅读路径，不是完整目录清单。新增设计应归入对应职责目录，并在本导览补充入口；不要另建第二套总导览。

## AI 接手规则

1. 阅读用户当次指令与用户意图，确认本次目标和限制。
2. 查看工作队列，只选择与本次目标相关的条目。
3. 按上表读取必要设计，不默认全文读取全部文档。
4. 涉及实现事实时检查对应代码；设计目标不能作为现状证据。
5. 完成后更新原设计与工作队列，记录实际结果及必要验证，不新增一次性汇报文档。

文档发生冲突时：用户最新指令决定需求；当前代码与验证决定实现事实；长期文档之间的矛盾应回到对应职责文件修正，不能继续新增另一份“最终版”。

## 工作队列维护约定

每项任务至少写清：目标、关联设计、完成条件、当前状态。已完成事项保留必要证据即可；进行中与待开始事项分开。阶段路线图不复制成第二套当前待办。

工作队列中的验证记录只证明记录时的版本。接手实现任务时，按改动范围复核代码与验证结果，不能把历史通过记录当作当前工作树的完成证明。
