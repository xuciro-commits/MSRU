# 数据能力边界

不建立统一 Repository/Service/Provider/Cache 四层流水线。按一个能力实际需要的边界组合；新应用的业务模型不必继承 MSRU 的形状。

| 当前概念 | 归属与决定 |
|---|---|
| LibraryRepository | 留 MSRU。表达曲库持久化契约；已有 JSON 与 Ephemeral 实现，具备真实替换价值。 |
| JSONLibraryRepository | 留 MSRU。编码、读写及原子落盘；以后按相同业务契约换 SQLite/SwiftData，而非提供通用 CRUD。 |
| Catalog Provider / Store / Cache | 分别负责来源、可观察加载状态、缓存策略；当前不合并。缓存丢失可重取，用户曲库保存失败不能静默丢弃。 |
| PlaybackProvider | 留 MSRU，负责播放资源解析；与 CatalogProvider 不是同一种协议。 |
| PlaybackController | 继续承担产品播放协调；它同时持有 AVPlayer、PCM、计时、解析任务及队列，后续可先提取具体引擎生命周期适配器。不要新增通用 Manager。 |
| Foundation Persistence | 暂不新增。多消费者证实相同需求后，最多提取小型存储机制；schema、冲突处理、恢复与领域规则仍归产品。 |

Feature 应看到完成用例所需的最小能力。一个小型 client 或已有 Store 已足够时，不再套 Service；来源选择是用户业务的一部分时允许知道 provider identity，但不直接绑定某个网络 SDK。

CloudKit、SwiftData、SQLite、REST 并不天然等价：本地事务、订阅、冲突和远程失败语义不同。替换承诺只能落在具体用例契约上，并为每个适配器运行相同契约测试。Preview 使用内存/fixture，禁止隐含授权、联网和真实用户目录写入。

Offline-first 是领域同步策略：本地权威数据、待提交操作、幂等键、冲突和重试由相应领域拥有；不能靠通用 Cache 自动获得。现在先完成一次真实曲库保存与重启恢复，再决定是否需要同步抽象。

证据入口：`MSRU/Music/Library/Core/LibraryRepository.swift`、`MSRU/Music/Library/Storage/JSONLibraryRepository.swift`、`MSRU/App/AppDependencies.swift`、`MSRU/Music/Catalog/{Core,Store,Cache}`、`MSRU/Music/Playback/Core/PlaybackController.swift`。Catalog 缓存仍需按具体行为验证；不据此建议删除现有数据协议。

本地文件在读入领域模型前，通过 `resolvingSymlinksInPath().standardizedFileURL` 规范化路径，避免导入与重新扫描分别产生 `/var` 和 `/private/var` 身份。比较本地收藏来源时优先比较规范化文件 URL，兼容以前保存的路径别名；其他 Provider 仍使用其稳定 external ID，不用标题和艺术家合并曲目。该策略不承诺文件搬迁后保留来源身份；真正的移动/重定位功能需另定稳定标识。

`FileLocalLibraryRepository(directory:)` 可以显式注入媒体目录；真实文件集成测试只使用临时目录。测试生成 PCM WAV，验证复制、同名文件隔离、元数据读取、重新扫描、Provider 解析和 AVFoundation 可解码性，不把这些检查等同于扬声器输出或远程流媒体验收。

`LocalMediaIntegrationTests.actualPlaybackAdvancesQueueAndStopsAtEnd` 进一步使用真实、静音的 AVPlayer 顺序播放两个临时 WAV，不手动发送结束通知。它验证自动切歌、历史/剩余队列、最终停止状态，并读取两个 AVPlayer 的实际媒体时钟确认都到达文件末尾。硬件听感和公网流媒体仍需分别验收。
