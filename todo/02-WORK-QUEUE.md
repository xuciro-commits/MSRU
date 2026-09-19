# 工作队列

这里维护行动与状态；设计正文留在 Docs，不复制成多个版本。当前已获授权执行目录重构、旧代码清理、全部视图 Preview 覆盖，并继续处理下列待办。

## 已交付的文档与小型门禁

- [x] 顶层产品/框架蓝图、客户端/服务端方案、体验原则。
- [x] 同一份分层界面图册：20 个章节、63 幅纯文本结构与交互图。
- [x] 架构定向审计、抽象取舍与分阶段迁移路线。
- [x] 架构文本检查脚本与实际 ApplicationDefinition 注册契约测试。
- [x] 用户意图、默认导览与 AI 入口。

以上完成的是指定交付物，不代表图册中的产品/组件已实现。初始测试结果及审计范围见 [架构审视](../Docs/Architecture/Review.md)；它们属于当时基线，不自动代表以后工作树。

## 当前实现任务

以下来自上一轮审计记录，实施前仅核对相关代码，未经复核不得直接当作当前故障或标记已解决。

| 顺序 | 待办 | 依据与退出条件 |
|---|---|---|
| 1 | 进行中：目录重构、Preview 覆盖与 Shell / Window 迁移收口 | FoundationRoadmap NOW 0；编译、相关测试与原生窗口验收 |
| 2 | 进行中：任务取消后的回传失效、场景关闭后的回调边界 | ConcurrencyModel；可控时序反例通过 |
| 3 | 已完成：恢复逐条容错、关闭回调边界及退出恢复 | ConcurrencyModel；单元回归与真实 Cmd+Q / 重启 XCUITest 通过 |
| 4 | 已完成：App 和测试 target 使用 Swift 6 | Debug/Release 配置已更新；纯 URL command 转换显式 nonisolated；macOS 测试通过 |
| 5 | 进行中：双平台 Shell 与搜索同步已实现 | ExperienceBlueprint / 图册；构建与状态测试通过，原生焦点测试通过，紧凑布局视觉待验收 |
| 6 | 进行中：收藏事务、重启和播放入口已实现 | 图册；保存失败、并发、重启、混合队列测试通过，真实媒体待验收 |
| 7 | 已完成：曲目属性检查器 (Track Inspector) 与上下文面板切换 | 图册 1.2 / 9.1；单元测试、Preview 门禁与架构检查全部通过 |
| 8 | 已完成：基础框架收敛（DependencyValues 并发硬化与 ShellResolver 命名澄清） | AbstractionAudit / NorthStarArchitecture；Sendable 存储收窄、无状态组合器重命名，全量 53 项框架测试与 113 项应用测试全部通过 |
| 9 | 已完成：曲库原生 Table / Grid 双模式集合、即时搜索排序与 Inspector 联动 | ExperienceBlueprint 第 5 节 / 图册 7.1、7.3；SwiftUI 原生 Table/Grid，排序过滤与选中单向/双向同步，7 项单元测试、Preview 门禁覆盖 39 视图，全量 120 项测试全部通过 |

具体文件和迁移范围见 [迁移路线](../Docs/Roadmap/FoundationRoadmap.md)。不要把本表与该路线维护成两套详细任务拆解。

## 按真实需求启动

- 酒店预订/文档工具的异类验证切片；不提前建设多个完整产品。
- 组织后端、同步、Web 管理端；先有明确用户、权威数据与交易用例。
- 新的框架公共能力；先证明重复机制和所有权/失败语义一致。

## 更新规则

每项实施任务记录：状态、用户结果、最小改动范围、设计链接、验收、遗留问题。状态只用：待开始 / 进行中 / 待决定 / 已完成 / 已取消。已完成必须有对应结果与验证说明。

新任务先归入现有设计位置；避免产生未标状态的“最终版2”“下一阶段”等散落文件。现存待办未在本次读取或迁移，不因本表而失效；下一次实际使用时再确认其适用性，避免无依据删除。

## 当前实施证据

按能力维护结果，不累计每轮日志。以下验证发生于 2026-09-20；后续改动须按影响范围重验。详细命令与证据边界见 [架构验证](../Docs/Architecture/ArchitectureVerification.md)。

| 能力 | 实现与验证范围 |
|---|---|
| 目录与旧代码 | App / Features / Music / Platform / Shared / PreviewSupport 已落地；旧窗口、实验页、兼容转发及无调用者的诊断/健康/错误定义已删除。封面解码集中到 Platform，Feature 不再直接导入 AppKit/UIKit。 |
| Preview | 39 个直接 View/Representable 有同文件 Preview，使用隔离数据与依赖；包含空、有内容、混合队列、检查器、曲库表格及窄布局。门禁识别后置协议、extension、枚举，过滤注释和字符串；间接协议仍需代码审查。 |
| 生命周期 | token 撤销、场景关闭身份检查、迟到结果失效有可控时序测试；恢复逐条容错并备份损坏原文。真实 NSWindow 与进程级退出恢复分别验证。 |
| Shell | App/测试采用 Swift 6；两种 Shell 共享语义，Browse 保留一个搜索入口；原生搜索保持控件身份、enabled 和 first responder。 |
| Inspector & Context | 支持右侧 Context 区域 `[曲目详情] [队列]` 双面板切换。选中本地/曲库曲目时自动展现 Track Inspector，展示封面、标题、艺术家、专辑、时长、音频格式、文件大小、路径，并支持播放、下一首、队列、收藏和「在访达中显示」。架构无跨界 import，全 Preview 隔离覆盖，新增 TrackInspectorTests 4 项测试全部通过。 |
| 曲库集合视图 | 支持资料库曲目与本地曲目原生 `Table`（表头、列排版、封面、时长、爱心及右键上下文菜单）与 `Grid` 双模式切换；顶部提供即时搜索文本过滤、多维度字段排序（添加时间、标题、艺术家、专辑、时长）与正反序切换；单选曲目双向联动 `SceneModel.selectedLibraryTrack` 并自动唤起右侧 Track Inspector；支持直接双击/右键发起播放、下一首与入队。 |
| 基础架构与并发 | `DependencyKey` 强化 `associatedtype Value: Sendable`，`DependencyValues` 擦除存储收窄为 `[ObjectIdentifier: any Sendable]` 并消除 `@unchecked Sendable`。纯函数式无状态组合器统一由 `ApplicationShellRuntime` 规范更名为 `ApplicationShellResolver`，不留无用兼容别名。AppFoundation 单元测试及应用全量测试完整回归。 |
| 数据 | 收藏先提交后发布；扫描、导入与收藏写入按序执行。失败、并发、路径别名、同名文件及重启恢复有回归测试。 |
| 播放 | 混合队列保留重复实例；真实静音 AVPlayer 顺播两个 WAV，核对媒体时钟与队列终态。AVPlayer/PCM 失败清理、旧回调隔离和保留队列重试有测试。 |
| FFmpeg | 构建暂存、互斥与发布回滚经过失败探针；完整重建 macOS/iOS/visionOS 切片，两个模拟器均含 arm64+x86_64。visionOS UI API 差异已适配。 |

验证基线：

- 应用：最近全量 **120 项通过**（原 113 项 + 7 项 LibraryCollection 排序/筛选/SceneModel 联动测试），使用 `MSRU-UnitTests` scheme；包含旧定义删除及 PCM 失败修复。
- 框架：最近 **53 项通过**（37 UI + 16 Core），包含 SwiftUI Shell 的平台适配。
- 构建：PCM 清理与旧定义删除后的当前代码已复验，visionOS 真机／模拟器和 iOS Simulator 均编译链接通过；关闭签名，不代表设备安装运行验收。
- UI：开发签名 Runner 的 **2 项通过**，验证前台启动、实际 Cmd+Q／重启、保留打开窗口并排除手动关闭窗口。使用独立恢复域与稳定 scene ID；后续播放改动及旧定义删除后已重新运行并通过。
- 门禁：架构（0 违规）、Preview（39 个全部覆盖）、diff 检查通过；入口链接须在修改后继续检查。源码检查不能替代渲染或运行时验收。

## 尚未完成的验收

- 紧凑布局视觉检查；原生 macOS 搜索焦点已有自动化验证。
- 实际扬声器听感与公网远程流媒体：本地真实 AVPlayer 静音播放已通过，不能代替硬件输出或公网环境验收。
- visionOS 头显交互及媒体运行时：完整构建已通过，尚未进行设备上的体验验收。
