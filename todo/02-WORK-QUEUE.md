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
| 1 | 已完成：目录重构、Preview 覆盖与 Shell / Window 迁移收口 | FoundationRoadmap NOW 0；旧 MainWindowController/RootSplitViewController 彻底清理、43 视图 100% 同文件独立 Preview、双窗口与 Cmd+Q 退出恢复测试通过、编译与原生窗口验收全部通过 |
| 2 | 已完成：任务取消后的回传失效、场景关闭后的回调边界 | ConcurrencyModel；FeatureHost 终态 stop、同ID并发任务控制、场景关闭边界与应用启动任务句柄通过可控时序测试 |
| 3 | 已完成：恢复逐条容错、关闭回调边界及退出恢复 | ConcurrencyModel；单元回归与真实 Cmd+Q / 重启 XCUITest 通过 |
| 4 | 已完成：App 和测试 target 使用 Swift 6 | Debug/Release 配置已更新；纯 URL command 转换显式 nonisolated；macOS 测试通过 |
| 5 | 已完成：双平台 Shell 与紧凑布局自适应适配 | ExperienceBlueprint 第 2 节 / 图册 2.1、2.2、7.2、15.1；MiniPlayerBar 极窄/紧凑/展开三级断点自适应、曲库 Table/List 紧凑多行自适应、FilterBar 标签消除折裂与两行自适应、Context 面板全时可关闭、SwiftUIApplicationShell 列折叠支持，全量 134 项测试（含 LayoutRenderProbe 7 个尺寸探针）全部通过，43 Preview 门禁通过 |
| 6 | 已完成：真实播放链路、统一音量架构与混合队列收口 | 图册 15.1、15.2；音量/静音双向绑定与跨切歌继承、Scrubber 拖拽时间预览与原子 seek、本地 WAV 到直播流混合队列切换、媒体时钟终态与失败重试，全量 137 项测试全部通过 |
| 7 | 已完成：曲目属性检查器 (Track Inspector) 与上下文面板切换 | 图册 1.2 / 9.1；单元测试、Preview 门禁与架构检查全部通过 |
| 8 | 已完成：基础框架收敛（DependencyValues 并发硬化与 ShellResolver 命名澄清） | AbstractionAudit / NorthStarArchitecture；Sendable 存储收窄、无状态组合器重命名，全量 53 项框架测试与 113 项应用测试全部通过 |
| 9 | 已完成：曲库原生 Table / Grid 双模式集合、即时搜索排序与 Inspector 联动 | ExperienceBlueprint 第 5 节 / 图册 7.1、7.3；SwiftUI 原生 Table/Grid，排序过滤与选中单向/双向同步，7 项单元测试、Preview 门禁覆盖 39 视图，全量 120 项测试全部通过 |
| 10 | 已完成：Radio 直播流网络电台专区、最佳实践演进（收藏/历史/自定义流）与 Inspector 联动 | 图册 7.6；RadioStation/RadioStore 领域模型、RadioPlaybackProvider 直播流管道接入、Hero Banner 与自适应网格、SceneModel.selectedRadioStation 互斥联动及 RadioStationInspectorView，演进支持电台收藏、最近播放历史、自定义网络电台添加/删除与原子 JSON 本地持久化，全量 141 项测试通过，Preview 门禁覆盖 44 视图 |
| 11 | 已完成：沉浸式正在播放大画卷 (Now Playing Immersive Canvas)、发烧级音频规格徽标与 4 模态右侧抽屉 | 参考 Apple Music、Bocan、Draft 播放器同有逻辑；底栏 MiniPlayerBar 增加点击封面直达画卷、歌词与频谱快捷按钮及高保真规格胶囊；新增 NowPlayingCanvasView 沉浸大画卷（大尺寸封面、环境弥散光晕、9频段波形律动、全功能控制、内嵌队列抽屉）；SceneModel.ContextPane 扩展为 Details/Queue/Spectrum/Lyrics 4 模态；全新 AudioVisualizerView、AmbientBackdropView、VisualizerPaneView、LyricsPaneView、AudioFormatBadgeView 视图落地；新增 NowPlayingCanvasTests 覆盖格式推导与画卷多窗口隔离；全量 148 项测试全部通过，Preview 门禁覆盖 50 视图，架构检查 0 违规 |
| 12 | 已完成：音乐实体数据库与三层元数据覆盖模型（阶段 1） | IdentityResolutionEngine / 图册 9.2、11.2；框架层（AppFoundation）提取通用三层级联覆盖容器 OverlayValue（raw/canonical/user 三层优先级与细粒度回退）与通用多语言实体别名解析器 EntityAlias/EntityAliasCollection；应用层（MSRU）构建音乐实体知识图谱（ArtistEntity、ArtistCredit、Work、Recording、ReleaseGroup、Release、Medium、MusicTrack、AudioAsset），实现稳定 MBID、多语言别名与声纹资产绑定；新增 TrackMetadataOverlay 驱动单曲字段级元数据管理；新增 MusicEntityGraphTests 与 TrackMetadataOverlayTests，全量通过（框架 61 项 + 应用 158 项全部通过），Preview 门禁 50 视图保持 100%，架构检查 0 违规 |
| 13 | 已完成：5 类重复判定分类器与 Roon 式多版本归集（阶段 2） | IdentityResolutionEngine 第 3 节 / 图册 9.2；框架层（AppFoundation）提取通用多版本管理容器 VersionGroup<Element> 与查重关系模型 DuplicateRelation；应用层（MSRU）落地 DuplicateCategory 5 类重复判定枚举（A 物理重复 / B 格式不同 / C 音质差异 / D 版本混音差异 / E 演出差异）及处理策略、确定性音频规格打分器 AudioQualityRanker、DuplicateClassifier 查重分类引擎，以及 Roon 式单曲多版本集合 TrackVersions（支持 24/192 > 24/96 > 16/44.1 > 320k 自动优选与手动钉选 Primary）；新增 VersionGroupTests、DuplicateClassifierTests 与 TrackVersionsTests，全量通过（框架 66 项 + 应用 168 项全部通过），Preview 门禁 50 视图保持 100%，架构检查 0 违规 |

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
| Preview | 50 个直接 View/Representable 有同文件 Preview，使用隔离数据与依赖；包含空、有内容、混合队列、检查器、曲库表格、Radio Hero 与卡片、自定义电台弹窗、窄布局、音频波形律动、弥散流光渐变、沉浸大画卷、高保真规格徽标、频谱侧栏与歌词侧栏。门禁识别后置协议、extension、枚举，过滤注释和字符串；间接协议仍需代码审查。 |
| 生命周期 | token 撤销、FeatureHost 终态 stop 与防重发、同 ID 并行任务与联合取消、场景关闭后的操作边界与回调绝缘、应用级启动任务句柄与 terminate() 均有可控时序测试；恢复逐条容错并备份损坏原文。真实 NSWindow 与进程级退出恢复分别验证。 |
| Shell & 紧凑布局 | App/测试采用 Swift 6；两种 Shell 共享语义；Browse 与 Radio 保留独立工具栏搜索入口；原生搜索保持控件身份、enabled 和 first responder；NSToolbarAdapter 杜绝重复控件崩溃。MiniPlayerBar 落地图册 15.1 极窄（<400pt）、紧凑（400-600pt）及标准（>=600pt）多级响应式布局；LibraryFilterBar 修复标签折裂并支持窄宽折行；曲库与本地表格在 <500pt 自动退避至图册 7.2 紧凑多行列表；Context 无论曲目/队列面板均支持一致关闭；LayoutRenderProbe 探针自动化覆盖 320/360/480/700/800pt 各尺寸并全部通过。 |
| Inspector & Context | 支持右侧 Context 区域 `[曲目/电台详情] [队列] [频谱] [歌词]` 4 模态面板切换。选中本地/曲库曲目时自动展现 Track Inspector，选中电台时自动展现 RadioStationInspectorView；切换到 Spectrum 时展示实时波形、详细发烧规格及一键放大画卷；切换到 Lyrics 时展示美学排版歌词及画卷联动。架构无跨界 import，全 Preview 隔离覆盖。 |
| Radio 电台专区与最佳实践 | 原占位页全面升级为原生 Radio 专区。接入内置精选公开网络电台（KEXP、SomaFM、BBC Radio 1、WQXR、Jazz24、Ambient 等）；支持流派胶囊筛选与即时搜索；实现精选主打 Hero Banner 与自适应电台卡片网格；打通 PlaybackProvider 直播流无缝接入原生 AVPlayer，MiniPlayerBar 识别 LIVE 广播状态；联动 SceneModel 互斥选中与右侧检查器；参考现代网络电台最佳实践，增加电台收藏（Favorites）置顶专区、最近收听历史（Recently Played）、自定义网络电台添加弹窗（AddStationSheetView，支持 URL 合法性校验及流派/国家定义）与卡片/检查器删除入口，支持原子 JSON 本地持久化与冷启动恢复。 |
| 曲库集合视图 | 支持资料库曲目与本地曲目原生 `Table`（表头、列排版、封面、时长、爱心及右键上下文菜单）与 `Grid` 双模式切换；顶部提供即时搜索文本过滤、多维度字段排序（添加时间、标题、艺术家、专辑、时长）与正反序切换；单选曲目双向联动 `SceneModel.selectedLibraryTrack` 并自动唤起右侧 Track Inspector；支持直接双击/右键发起播放、下一首与入队。 |
| 正在播放画卷与发烧规格 | 参照 Apple Music、Bocan、Draft 播放器优秀设计：落地 NowPlayingCanvasView 沉浸大画卷与 AmbientBackdropView 弥散流光动态背景；AudioVisualizerView 提供 9-15 频段动态起伏波形；AudioFormatBadgeView 提供 Lossless/Hi-Res/Codec/Bitrate/SampleRate 发烧级高保真徽标；MiniPlayerBar 接入点击封面展开画卷、歌词与频谱快捷按钮；SceneModel.isNowPlayingPresented 实现多窗口完全隔离控制。 |
| 实体数据库与三层元数据覆盖 | 对齐 Roon 实体与版本模型、MusicBrainz 身份体系与 beets 三层覆盖；通用能力抽取至 AppFoundation：OverlayValue<T> 泛型三层覆盖结构（raw/canonical/user，字段级细粒度回退，保证物理文件只读原始标签绝对不被篡改）与 EntityAlias/EntityAliasCollection 多语言别名选择器；应用层 MSRU 落地 ArtistEntity、ArtistCredit、Work、Recording、ReleaseGroup、Release、Medium、MusicTrack、AudioAsset 9 大实体知识图谱模型与 TrackMetadataOverlay 覆盖解析器；新增 MusicEntityGraphTests 与 TrackMetadataOverlayTests，全生命周期及 Codable 往返严格验证通过。 |
| 重复判定与多版本归集 | 落实 A~E 5 类重复判定枚举 DuplicateCategory 与 DeduplicationStrategy 策略指示；开发确定性音频规格打分器 AudioQualityRanker（无损、采样率、位深、码率严格赋权）；开发 DuplicateClassifier 分类引擎（精准识别 SHA256 物理重复、容器格式差异、采样率音质差异、不同后期母带版本以及严格绝非重复的现场录音演出差异）；封装 Roon 式 TrackVersions 容器，实现高品质自动优选、手动指定主版本、优雅退避与徽标展示；经 DuplicateClassifierTests 与 TrackVersionsTests 严格测试验证。 |
| 基础架构与并发 | `DependencyKey` 强化 `associatedtype Value: Sendable`，`DependencyValues` 擦除存储收窄为 `[ObjectIdentifier: any Sendable]` 并消除 `@unchecked Sendable`。纯函数式无状态组合器统一由 `ApplicationShellRuntime` 规范更名为 `ApplicationShellResolver`，不留无用兼容别名。NEXT 2 阶段 Command Runtime 边界硬化，直接由 Gate 调度，清除历史废弃标记；`MSRUApplication` 彻底消除 `transitionalHost` 过渡模块代码，`ListenNow`、`AddMusic`、`Settings` 全面模块化遵循 `ApplicationFeaturePresentation`，统一通过 `builder.add(...)` 声明式装配，经契约测试严格验证。 |
| 数据 | 收藏先提交后发布；扫描、导入与收藏写入按序执行。失败、并发、路径别名、同名文件及重启恢复有回归测试。 |
| 播放 | 统一音量与静音管理（支持 AVPlayer 与 PCM 混音节点双向同步、切歌继承与取消静音恢复）；MiniPlayerBar 标准模式落地音量滑块与静音按钮（图册 15.1）；HoverScrubber 拖拽时实时目标时间预览、松手原子 commit seek 并支持 LIVE 电台停用；本地真实 WAV 与网络电台直播流混合队列连续播放与切换测试全部通过；混合队列保留重复实例，真实静音 AVPlayer 顺播两个 WAV 核对媒体时钟与队列终态；AVPlayer/PCM 失败清理、旧回调隔离和保留队列重试有回归测试。 |
| FFmpeg | 构建暂存、互斥与发布回滚经过失败探针；完整重建 macOS/iOS/visionOS 切片，两个模拟器均含 arm64+x86_64。visionOS UI API 差异已适配。 |

验证基线：

- 应用：最近全量 **168 项通过**（原 158 项 + 6 项 DuplicateClassifierTests + 4 项 TrackVersionsTests），使用 `MSRU-UnitTests` scheme。
- 框架：最近 **66 项通过**（37 UI + 29 Core，新增 5 项 VersionGroupTests），包含泛型多版本容器与查重判定契约。
- 构建：macOS 与 iOS 均编译链接通过；关闭签名，不代表设备安装运行验收。
- UI：开发签名 Runner 的 **2 项通过**，验证前台启动、实际 Cmd+Q／重启、保留打开窗口并排除手动关闭窗口。使用独立恢复域与稳定 scene ID；后续播放改动及旧定义删除后已重新运行并通过。
- 门禁：架构（0 违规）、Preview（50 个全部覆盖）、diff 检查通过；入口链接须在修改后继续检查。源码检查不能替代渲染或运行时验收。

## 尚未完成的验收

- 紧凑布局视觉检查；原生 macOS 搜索焦点已有自动化验证。
- 实际扬声器听感与公网远程流媒体：本地真实 AVPlayer 静音播放已通过，不能代替硬件输出或公网环境验收。
- visionOS 头显交互及媒体运行时：历史完整构建已通过。（依用户明确指令，visionOS 涉及的所有开发与验收已暂停，iOS 与 watchOS 继续保留推进）
