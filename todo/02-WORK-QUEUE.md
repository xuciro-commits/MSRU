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
| 14 | 已完成：beets 式加权打分匹配、置信度三级漏斗与 Picard 专辑聚类（阶段 3） | IdentityResolutionEngine 第 4 节 / 图册 9.2；框架层（AppFoundation）提取通用编辑距离/相似度计算器 StringDistance（Levenshtein + 分词 Jaccard + 标点/变音归一化）、通用三级置信度漏斗模型 ConfidenceTier（High >= 0.90 自动应用 / Medium 0.60~0.89 人工复核 / Low < 0.60 丢弃）、加权综合打分模型 WeightedScoreModel 与通用聚类模型 EntityCluster；应用层（MSRU）落地非结构化文件名启发式提取器 FileNameHeuristicParser、beets 式多维加权匹配打分引擎 MatchScorer（MBID 5.0、标题/歌手/专辑 3.0、时长/曲序 2.0、年份 1.0，并支持多别名与前缀清洗）与 Picard 式专辑曲目聚类引擎 AlbumCluster（基于物理目录、曲序连续性与总时长特征聚合）；新增 StringDistanceTests、WeightedScoreModelTests、FileNameHeuristicParserTests、MatchScorerTests 与 AlbumClusterTests（覆盖本地真实音乐目录音频测试用例），全量通过（框架 73 项 + 应用 178 项全部通过），Preview 门禁 50 视图保持 100%，架构检查 0 违规 |
| 15 | 已完成：声纹识别、MusicBrainz 外部元数据接入与整轨解析（阶段 4） | IdentityResolutionEngine 第 5 节；框架层（AppFoundation）提取声纹协议与模型 AudioFingerprint/AudioFingerprinting、外部目录服务协议与匹配模型 ExternalCatalogService/ExternalRecordingMatch/ExternalReleaseMatch；应用层（MSRU）落地基于 AVAsset 与 PCM 采样数据的确定性声纹提取器 AcoustIDFingerprintExtractor（真实本地音频提取实测 0.126s）、MusicBrainz 外部目录适配客户端 MusicBrainzCatalogClient 与 Picard 风格整轨聚类检索器 PicardAlbumLookupResolver；新增 AcoustIDFingerprintExtractorTests、MusicBrainzCatalogClientTests 与 PicardAlbumLookupResolverTests，全量通过，架构检查 0 违规 |
| 16 | 已完成：安全文件整理、撤销计划与集中预审工作区（阶段 5） | IdentityResolutionEngine 第 6 节 / 图册 9.2、11.2；框架层（AppFoundation）提取 beets 命名模板引擎 FileNamingTemplate（支持路径变量、APFS/POSIX 非法字符清洗与 255 字节截断）与安全文件移动/重命名器 SafeFileOrganizer（Dry-Run 预检计划、同名自动 (1) 防冲突、事务原子移动与反向 Undo 撤销记录）；应用层（MSRU）构建 11 步导入流水线 ImportPipeline、集中预审状态机 ImportReviewStore、InteractionAtlas 图册 11.2 预审仪表盘 ImportReviewView（置信度高亮胶囊、异名归并卡片、待确认聚类折叠面板、一键安全移动与撤销）与图册 9.2 曲目属性检查器多版本及三层元数据覆盖面板；新增 FileNamingTemplateTests、SafeFileOrganizerTests、ImportPipelineTests 与 ImportReviewStoreTests，全量通过（框架 80 项 + 应用 190 项全部通过），Preview 门禁 51 视图保持 100%，架构检查 0 违规 |
| 17 | 已完成：资料库三大核心维度（歌曲/专辑/艺人）与导入预审工作区全量端出 | 框架层（AppFoundation）抽取 AlbumPresentationModel、ArtistPresentationModel、DiscTrackGroup，并在 AppFoundationUI 落地通用 AlbumCardView、ArtistAvatarView 与三级有序带徽标 ApplicationSidebar；应用层（MSRU）全面端出 AlbumsView 与 AlbumDetailView、ArtistsView 与 ArtistDetailView，以及 ImportReviewWorkspaceView；新增 AlbumsFeatureTests、ArtistsFeatureTests 与 ImportWorkflowCoordinatorTests，全量通过，Preview 门禁覆盖 58 视图，架构检查 0 违规 |
| 18 | 已完成：轻量本地声纹记忆库、目录规则学习引擎、元数据管理中心及在线全链路打通 | LocalFingerprintRegistry（轻量本地声学指纹记忆持久化、0ms 本地秒级识别、容差匹配、增量学习与清空）；PathHeuristicRuleStore（目录路径模式匹配、导入时自动规则学习、规则增删改查）；MusicBrainzCatalogClient（公网实时 HTTP 查询、真实 AcoustID Web API 接入、1.0s/req 速率节流保护与超时回退）；PicardAlbumLookupResolver（解决搜索概要无 tracks 导致置信度 0% 的缺陷，自动 lookupRelease 补全音轨打分）；FileNameHeuristicParser（发烧友/PT 规格标签如 `[FLAC 24bit／48khz]`、`(WAV/Cue)` 智能清洗过滤与目录穿透）；MetadataManagerWorkspaceView（四合一管理中心）；TrackInspectorView（声纹状态胶囊与重新识别）；解决 NAS 沙盒权限拦截与浏览界面 AutoLayout 递归死循环闪退，搜索栏居中吸附分界线；新增 LocalFingerprintRegistryTests 与 PathHeuristicRuleStoreTests，全量通过（框架 82 项 + 应用 203 项 + UI 2 项全部通过），Preview 门禁覆盖 61 视图（100% 覆盖），架构检查 0 违规 |
| 19 | 已完成：声纹绝对第一生命线、多层级封面提取与端到端封面回填、重复导入 100% 绿色命中 | 确立“声纹先于一切”识别原则：导入音频无论原文件名称为何，第一步先查 LocalFingerprintRegistry 本地声纹记忆库，命中即锁定 100% 置信度（绿色 checkmark），以声纹权威名称覆盖原文件名解决异名冲突，杜绝 0% 或“原样保留”；本地未命中才请求公网 AcoustID/MusicBrainz 唯一 recordingMBID，再次未命中才走本地标签与启发式兜底。新建 LocalArtworkExtractor（多级探测同级目录 cover.jpg/folder.jpg/front.jpg、内嵌 APIC 音频元数据、Cover Art Archive 在线封面），解决 Unknown Album 及无封面问题；artworkData 全链路贯穿 ClusterTrackItem、AcousticFingerprintRecord、LocalTrack、AlbumPresentationModel、ArtistPresentationModel；AlbumCardView、AlbumDetailView、ArtistAvatarView、ArtistDetailView 全面接入真实图片解码渲染与占位回退；排除通用文件夹误匹配（Music/Songs/Downloads等）；全量通过（框架 82 项 + 应用 206 项全部通过），Preview 门禁保持 100%（61 个视图），架构检查 0 违规 |
| 20 | 已完成：歌曲管理与元数据中心解耦、Apple Music 接入恢复、多选批量操作与专辑/艺人级联删除 | 歌曲管理与元数据中心彻底解耦：LocalLibraryRepository 落地单曲/多曲删除接口与 external_tracks.json 持久化清除；LocalLibraryStore 落地单曲删除、专辑级联删除与艺术家级联删除；LocalTrackTableView 接入原生 SwiftUI Table 多选（Shift/Cmd）与底部悬浮 Liquid Glass 批量操作条（播放/入队/批量删除二次确认）；AlbumsView/AlbumDetailView 与 ArtistsView/ArtistDetailView 落地级联删除（同时清除名下全部专辑及歌曲）与 [+ 添加音乐] 快捷入口；MetadataProviderConfigStore 实现 Apple Music、MusicBrainz、Cover Art Archive、本地内嵌标签提供商的启用开关、优先级拖拽排序与独立持久化；MetadataManagerWorkspaceView 端出独立提供商配置页；AddMusicFeature 将侧栏拆分为「添加音乐」（恢复 Apple Music 官方 MusicKit 导入）与「元数据中心」；新增 LocalLibraryCascadeDeletionTests，全量通过（应用 216 项 + 框架 82 项全部通过），Preview 门禁覆盖 61 视图（100% 覆盖），架构检查 0 违规 |

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
| Preview | 61 个直接 View/Representable 有同文件 Preview，使用隔离数据与依赖；包含空、有内容、混合队列、检查器、曲库表格、Radio Hero 与卡片、自定义电台弹窗、窄布局、音频波形律动、弥散流光渐变、沉浸大画卷、高保真规格徽标、频谱侧栏与歌词侧栏、导入集中预审仪表盘（ImportReviewView）、专辑网格（AlbumsView）、专辑详情内页（AlbumDetailView）、艺人画廊（ArtistsView）、艺人专属主页（ArtistDetailView）、导入工作区（ImportReviewWorkspaceView）、通用专辑卡片（AlbumCardView）、通用艺人头像（ArtistAvatarView）、元数据与声纹管理中心（MetadataManagerWorkspaceView）。门禁识别后置协议、extension、枚举，过滤注释和字符串；间接协议仍需代码审查。 |
| 侧边栏与多维导航 | 侧边栏标准化三层结构：【发现 DISCOVERY】（立即收听、浏览、广播电台）、【资料库 LIBRARY】（歌曲、专辑、艺人）、【工具 TOOLS】（导入预审/元数据与声纹管理中心）；ApplicationSidebar 支持根据组内最小 order 稳定排序并支持徽标/数量渲染；SceneSection 扩展 albums、artists、importReview 语义路由，全量契约测试通过。 |
| 专辑维度画册与分碟 | 框架层落地 AlbumPresentationModel 与通用 AlbumCardView（悬浮播放动效、发烧音质金标）；应用层落地 AlbumsView 画册大网格（支持年份/艺人/名称排序过滤）与 AlbumDetailView（巨幅 Hero 封面、发行规格、CD1/CD2 多碟分段展示、整专播放与入队），无缝联动右侧 TrackInspectorView。 |
| 艺人维度画廊与主页 | 框架层落地 ArtistPresentationModel 与通用 ArtistAvatarView；应用层落地 ArtistsView 头像画廊网格与 ArtistDetailView 歌手专属聚合主页（多语言别名胶囊标签展示、精选热门单曲、录音室专辑时间线网格与非正规单曲集），打通歌手到专辑与歌曲的下钻浏览体系。 |
| 导入预审大工作区 | 彻底替代旧版简陋文件选择器；支持拖拽文件夹与一键导入，实时弹出 11 步进度条 HUD（声纹提取、Picard 聚类），直达 ImportReviewView 仪表盘（绿黄红三级置信度胶囊、异名智能归并推荐卡片），并在组织前提供 Dry-Run 树形预览与一键移动入库，底部常驻 Undo 撤销横幅，完整闭环。 |
| 本地声纹记忆与规则学习 | LocalFingerprintRegistry 实现轻量持久化声学指纹记忆，二次导入 0ms 秒级识别；PathHeuristicRuleStore 自动从导入目录学习歌手路径映射规则；接入 MusicBrainz 真实网络 API 与 1.0s 节流阀；落地 MetadataManagerWorkspaceView 四合一管理中心与 TrackInspectorView 声纹状态指示与在线重查。 |
| 生命周期 | token 撤销、FeatureHost 终态 stop 与防重发、同 ID 并行任务与联合取消、场景关闭后的操作边界与回调绝缘、应用级启动任务句柄与 terminate() 均有可控时序测试；恢复逐条容错并备份损坏原文。真实 NSWindow 与进程级退出恢复分别验证。 |
| Shell & 紧凑布局 | App/测试采用 Swift 6；两种 Shell 共享语义；Browse 与 Radio 保留独立工具栏搜索入口；原生搜索保持控件身份、enabled 和 first responder；NSToolbarAdapter 杜绝重复控件崩溃。MiniPlayerBar 落地图册 15.1 极窄（<400pt）、紧凑（400-600pt）及标准（>=600pt）多级响应式布局；LibraryFilterBar 修复标签折裂并支持窄宽折行；曲库与本地表格在 <500pt 自动退避至图册 7.2 紧凑多行列表；Context 无论曲目/队列面板均支持一致关闭；LayoutRenderProbe 探针自动化覆盖 320/360/480/700/800pt 各尺寸并全部通过。 |
| Inspector & Context | 支持右侧 Context 区域 `[曲目/电台详情] [队列] [频谱] [歌词]` 4 模态面板切换。选中本地/曲库曲目时自动展现 Track Inspector（含图册 9.2 曲目详情、多版本列表、三层元数据覆盖层分段切换、声纹激活徽标与在线重新识别按钮），选中电台时自动展现 RadioStationInspectorView；切换到 Spectrum 时展示实时波形、详细发烧规格及一键放大画卷；切换到 Lyrics 时展示美学排版歌词及画卷联动。架构无跨界 import，全 Preview 隔离覆盖。 |
| Radio 电台专区与最佳实践 | 原占位页全面升级为原生 Radio 专区。接入内置精选公开网络电台（KEXP、SomaFM、BBC Radio 1、WQXR、Jazz24、Ambient 等）；支持流派胶囊筛选与即时搜索；实现精选主打 Hero Banner 与自适应电台卡片网格；打通 PlaybackProvider 直播流无缝接入原生 AVPlayer，MiniPlayerBar 识别 LIVE 广播状态；联动 SceneModel 互斥选中与右侧检查器；参考现代网络电台最佳实践，增加电台收藏（Favorites）置顶专区、最近收听历史（Recently Played）、自定义网络电台添加弹窗（AddStationSheetView，支持 URL 合法性校验及流派/国家定义）与卡片/检查器删除入口，支持原子 JSON 本地持久化与冷启动恢复。 |
| 曲库集合视图 | 支持资料库曲目与本地曲目原生 `Table`（表头、列排版、封面、时长、爱心及右键上下文菜单）与 `Grid` 双模式切换；顶部提供即时搜索文本过滤、多维度字段排序（添加时间、标题、艺术家、专辑、时长）与正反序切换；单选曲目双向联动 `SceneModel.selectedLibraryTrack` 并自动唤起右侧 Track Inspector；支持直接双击/右键发起播放、下一首与入队。 |
| 正在播放画卷与发烧规格 | 参照 Apple Music、Bocan、Draft 播放器优秀设计：落地 NowPlayingCanvasView 沉浸大画卷与 AmbientBackdropView 弥散流光动态背景；AudioVisualizerView 提供 9-15 频段动态起伏波形；AudioFormatBadgeView 提供 Lossless/Hi-Res/Codec/Bitrate/SampleRate 发烧级高保真徽标；MiniPlayerBar 接入点击封面展开画卷、歌词与频谱快捷按钮；SceneModel.isNowPlayingPresented 实现多窗口完全隔离控制。 |
| 实体数据库与三层元数据覆盖 | 对齐 Roon 实体与版本模型、MusicBrainz 身份体系与 beets 三层覆盖；通用能力抽取至 AppFoundation：OverlayValue<T> 泛型三层覆盖结构（raw/canonical/user 三层优先级与细粒度回退，保证物理文件只读原始标签绝对不被篡改）与 EntityAlias/EntityAliasCollection 多语言别名选择器；应用层 MSRU 落地 ArtistEntity、ArtistCredit、Work、Recording、ReleaseGroup、Release、Medium、MusicTrack、AudioAsset 9 大实体知识图谱模型与 TrackMetadataOverlay 覆盖解析器；新增 MusicEntityGraphTests 与 TrackMetadataOverlayTests，全生命周期及 Codable 往返严格验证通过。 |
| 重复判定与多版本归集 | 落实 A~E 5 类重复判定枚举 DuplicateCategory 与 DeduplicationStrategy 策略指示；开发确定性音频规格打分器 AudioQualityRanker（无损、采样率、位深、码率严格赋权）；开发 DuplicateClassifier 分类引擎（精准识别 SHA256 物理重复、容器格式差异、采样率音质差异、不同后期母带版本以及严格绝非重复的现场录音演出差异）；封装 Roon 式 TrackVersions 容器，实现高品质自动优选、手动指定主版本、优雅退避与徽标展示；经 DuplicateClassifierTests 与 TrackVersionsTests 严格测试验证。 |
| 启发式识别、置信度漏斗与专辑聚类 | beets 式加权打分匹配、置信度三级漏斗与 Picard 专辑聚类（阶段 3）；通用文本编辑距离（Levenshtein + Token Jaccard）、三级置信度枚举（High/Medium/Low）及加权打分模型抽取至 AppFoundation；应用层实现非侵入式乱名启发式提取器、加权匹配引擎（支持别名与标题前缀净化）及基于目录与曲序特征的 Picard 专辑聚类器；真实本地音频文件与用例全面验证通过。 |
| 声纹提取与外部目录接入 | 阶段 4：框架层定义 AudioFingerprint 与 ExternalCatalogService 规范；应用层接入 AcoustIDFingerprintExtractor（实测真实音频 PCM 采样生成确定性声纹）与 MusicBrainzCatalogClient 外部元数据查询，实现 Picard 式聚类整轨检索器 PicardAlbumLookupResolver；经真实音频测试通过。 |
| 安全文件整理与导入预审工作区 | 阶段 5：框架层构建 FileNamingTemplate（beets 语法、非法字符清理与截断）与 SafeFileOrganizer（Dry-Run 预检计划、同名防冲突、原子移动与撤销机制）；应用层串联 11 步导入流水线 ImportPipeline 与状态机 ImportReviewStore，严格落实图册 11.2 集中预审仪表盘 ImportReviewView，支持高/中/低置信度分流、异名归并推荐与安全一键整理。 |
| 基础架构与并发 | `DependencyKey` 强化 `associatedtype Value: Sendable`，`DependencyValues` 擦除存储收窄为 `[ObjectIdentifier: any Sendable]` 并消除 `@unchecked Sendable`。纯函数式无状态组合器统一由 `ApplicationShellRuntime` 规范更名为 `ApplicationShellResolver`，不留无用兼容别名。NEXT 2 阶段 Command Runtime 边界硬化，直接由 Gate 调度，清除历史废弃标记；`MSRUApplication` 彻底消除 `transitionalHost` 过渡模块代码，`ListenNow`、`AddMusic`、`Settings` 全面模块化遵循 `ApplicationFeaturePresentation`，统一通过 `builder.add(...)` 声明式装配，经契约测试严格验证。 |
| 数据 | 收藏先提交后发布；扫描、导入与收藏写入按序执行。失败、并发、路径别名、同名文件及重启恢复有回归测试。 |
| 播放 | 统一音量与静音管理（支持 AVPlayer 与 PCM 混音节点双向同步、切歌继承与取消静音恢复）；MiniPlayerBar 标准模式落地音量滑块与静音按钮（图册 15.1）；HoverScrubber 拖拽时实时目标时间预览、松手原子 commit seek 并支持 LIVE 电台停用；本地真实 WAV 与网络电台直播流混合队列连续播放与切换测试全部通过；混合队列保留重复实例，真实静音 AVPlayer 顺播两个 WAV 核对媒体时钟与队列终态；AVPlayer/PCM 失败清理、旧回调隔离和保留队列重试有回归测试。 |
| FFmpeg | 构建暂存、互斥与发布回滚经过失败探针；完整重建 macOS/iOS/visionOS 切片，两个模拟器均含 arm64+x86_64。visionOS UI API 差异已适配。 |
| 实体增删、级联删除与元数据解耦 | LocalLibraryRepository 落地物理与记录删除；LocalLibraryStore 落地单曲、专辑、艺术家级联删除；LocalTrackTableView 接入原生 SwiftUI Table 多选（Shift/Cmd）与底部悬浮 Liquid Glass 批量操作条；AlbumsView/Detail 与 ArtistsView/Detail 落地级联删除二次确认及[+ 添加音乐]入口；MetadataProviderConfigStore 支持 Apple Music、MusicBrainz、Cover Art Archive、本地内嵌标签提供商的启用开关、优先级排序与独立持久化；MetadataManagerWorkspaceView 端出独立提供商配置页；AddMusicFeature 拆分为「添加音乐」（恢复 Apple Music 官方集成）与「元数据中心」。经 LocalLibraryCascadeDeletionTests 验证通过。 |

验证基线：

- 应用：全量 **216 项通过**，使用 `MSRUTests`。
- 框架：**82 项通过**（39 UI + 43 Core）。
- 构建：macOS 与 iOS 均编译链接通过；关闭签名，不代表设备安装运行验收。
- UI：开发签名 Runner 的 **2 项通过**，验证前台启动、实际 Cmd+Q／重启、保留打开窗口并排除手动关闭窗口。使用独立恢复域与稳定 scene ID；测试全部通过。
- 门禁：架构（0 违规）、Preview（61 个全部覆盖）、diff 检查通过；入口链接须在修改后继续检查。源码检查不能替代渲染或运行时验收。

## 尚未完成的验收

- 紧凑布局视觉检查；原生 macOS 搜索焦点已有自动化验证。
- 实际扬声器听感与公网远程流媒体：本地真实 AVPlayer 静音播放已通过，不能代替硬件输出或公网环境验收。
- visionOS 头显交互及媒体运行时：历史完整构建已通过。（依用户明确指令，visionOS 涉及的所有开发与验收已暂停，iOS 与 watchOS 继续保留推进）
