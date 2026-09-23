# 从当前工作树到可持续开发：长期演进路线图

版本：2.0 · 2026-09-21 · 规划视野：2026—2028+ · 状态：现行演进基准

顺序按真实风险与产品收益推进，不以增加类型数或虚构通用性为进展。阶段表保留演进顺序与退出条件；当前正在执行的任务以 [todo/02-WORK-QUEUE.md](../../todo/02-WORK-QUEUE.md) 为准。

---

## 阶段规划总览 (2026 — 2028+)

```text
┌────────────────────────────────────────────────────────────────────────┐
│ 阶段 0：工程基线与核心功能闭环 (Task 1 ~ 30，已全部交付验收)            │
│ · Swift 6 / 跨平台 Shell (macOS, iOS, watchOS) / 门禁 Preview 100%     │
│ · 声学指纹 (AcoustID) / 实体图谱 / 物理写回 / 沉浸画卷 / 动态歌词 / 歌单│
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ 阶段 1：极致原生体验与自动摄入 (Stage 1: Ingestion & Native Polish)      │
│ · 监控文件夹 (FSEvents) 自动扫描与增量摄入                             │
│ · 动态智能歌单与规则求值引擎                                           │
│ · macOS MenuBarExtra 状态栏极简驻留播放器                              │
│ · 歌词时间戳微调校准与物理写回                                         │
│ · 系统级 Spotlight 全局索引与 App Intents 快捷指令                    │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ 阶段 2：发烧音频链路与高并发存储 (Stage 2: Audiophile DSP & Storage)   │
│ · CoreAudio HAL 独占模式与 Bit-Perfect 直通输出                        │
│ · 发烧级 10 段专业均衡器与 EBU R128 / ReplayGain 响度标准化            │
│ · 大规模曲库 SQLite/SwiftData 存储引擎演进 (流式虚拟化分页)            │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ 阶段 3：异类切片压力测试与框架独立 (Stage 3: Heterogeneous & Framework) │
│ · 异类切片一：轻量 Markdown 文档工作台 (DocStudio)                     │
│ · 异类切片二：酒店预订时间轴 PMS 切片 (HotelDesk)                      │
│ · 框架级全局 Undo/Redo 事务架构                                       │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ 阶段 4：跨设备原生互联与生态闭环 (Stage 4: Apple Ecosystem Connectivity)│
│ · 基于 Network.framework (Bonjour) 局域网无感遥控播控 (Mac <-> iOS)    │
│ · 点对点本地高速曲库与歌单推流同步                                     │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 演进阶段详情与退出条件

| 阶段 | 核心目标 / 涉及模块 | API 增删与演进 | 验收测试与退出条件 | 用户与产品收益 |
|---|---|---|---|---|
| **STAGE 1**<br>极致原生体验与自动摄入 | **监控文件夹与动态歌单**：<br>`Music/Library/Watcher`<br>`Music/Library/Rules`<br>`Features/Playlists`<br>`Platform/macOS/MenuBar`<br>`Features/Playback/Lyrics` | · 引入 `FolderWatcherService` (FSEvents)<br>· 引入 `PlaylistRuleEngine`<br>· 引入 `MenuBarExtra` 声明<br>· 扩展 `LyricsService` 微调校准 | · 新增/删除音频文件后台秒级感知，增量送审<br>· 智能歌单动态过滤测试全绿<br>· 状态栏播控与主窗口无缝同步<br>· 歌词偏移 +/-0.5s 即时生效并可写回<br>· Spotlight 索引可检索调起 | 音乐文件下载或拷贝后无需手动反复拖入；歌单随库自动动态更新；无需切换窗口即可在系统顶栏切歌 |
| **STAGE 2**<br>发烧音频链路与高并发存储 | **发烧级音频与存储底座**：<br>`Music/Playback/DSP`<br>`Music/Playback/CoreAudio`<br>`Music/Library/Storage/SQLite` | · 增加 `AudioEngineAdapter` (AVAudioEngine)<br>· 增加 `ReplayGainScanner`<br>· 实现基于 SQLite 的 `LibraryRepository` | · 外接 DAC 采样率硬件直通，无系统重采样<br>· 10段均衡器与无缝播放(Gapless)实测<br>· 50,000 首曲目冷启动 < 100ms，内存下降 70%<br>· 契约测试保证数据零丢失 | 满足发烧友极致音质与硬件外接需求；曲目数量暴增时依然秒开丝滑 |
| **STAGE 3**<br>异类切片压力测试与框架独立 | **脱离音乐场景验证框架**：<br>`Examples/DocStudio`<br>`Examples/HotelDesk`<br>`Packages/AppFoundation/Undo` | · AppFoundationUI 提取通用 Undo 事务机制<br>· 严禁向框架泄漏任何 Music 依赖 | · 独立 Demo App 零修改复用 AppFoundation 架构装配与 Shell<br>· 多窗口文档编辑与 Undo/Redo 回滚测试全绿<br>· 证明框架具备 5 年多种产品支撑力 | 验证框架不是音乐特化封装，奠定未来开发不同领域 Apple 原生产品的基础 |
| **STAGE 4**<br>跨设备原生互联与生态闭环 | **Apple 多端协同**：<br>`Platform/Network`<br>`Features/RemoteControl` | · 纯 Apple 原生 `Network.framework` (Bonjour)<br>· 局域网轻量状态同步协议 | · iPhone / Apple Watch 自动发现 Mac 播放器并毫秒级遥控<br>· 局域网无损音轨传输与歌单高速下发 | 沙发或床上轻松遥控桌面发烧音响，实现媲美 Apple 官方生态的无缝体验 |

Stage 2 当前代码进度见[工作队列 #61–#68](../../todo/02-WORK-QUEUE.md)：本地/NAS 专辑 PCM 接续、macOS 输出选择及 10 段 EQ 已实现，仍待用户听感与 DAC 验收。Bit-Perfect 未获证明；ReplayGain、SQLite 收口与 50,000 首性能目标仍待执行。阶段收尾门槛以工作队列为准。

---

## 框架抽象准则与停止条件

1. **先产品后框架**：任何新抽象必须先在 MSRU 中经历过真实业务与边界打磨；无真实需求不预先建立通用层。
2. **提取框架三问**：
   - 实际消除了哪里重复的机制？
   - 相较产品直接实现是否减少概念？
   - 哪条契约测试证明行为不变？
3. **异类验证作为终审门槛**：只有当一个抽象同时被 MSRU 与第二异类切片（如 DocStudio / HotelDesk）独立使用且语义完全一致时，才允许晋升为框架公共稳定 API。

---

## 历史交付对照（基线：Task 1 ~ 30）

- **架构与并发**：AppFoundation 与 AppFoundationUI 独立 Target、纯函数式 `ApplicationDefinition` 组合声明、Swift 6 语言模式全面启用、`FeatureHost` 任务代次令牌与取消隔离。
- **跨平台多端 Shell**：macOS 原生三栏 Split 宿主、iOS 紧凑 Tab 宿主 (`CompactApplicationShell`) 与 iPad 分栏自适应、watchOS 极简短任务播控切片。
- **声学指纹与元数据管线**：AcoustID 官方 API Key 真实鉴权、Picard 专辑曲目聚类、beets 8维加权消歧打分、5类重复判定分类器与 Roon 式多版本归集、物理 Vorbis Comments/ID3v2.4 二进制写回与伴生封面导出。
- **视听交互与多媒体体验**：NowPlayingCanvas 沉浸大画卷、弥散动态光晕、9-15 频段音频波形律动、四级动态平滑滚动 LRC 歌词、高保真 Hi-Res 规格徽标、原生 Table/Grid 双模式浏览、Radio 电台专区、歌单 CRUD、集中预审工作区。
- **设计系统与国际化**：FoundationCard 通用卡片组件全面统一收口；Xcode String Catalogs (`Localizable.xcstrings`) 覆盖英语、简体中文、藏语，动态即刻响应切换。
- **系统级播控**：MPRemoteCommandCenter 与 MPNowPlayingInfoCenter 硬件按键/锁屏联动。
- **工程门禁证据**：70 个视图 100% 同文件独立 Preview 门禁、全量 295 项测试（应用 246 + 框架 49）全部通过，架构静态检查 0 违规。
