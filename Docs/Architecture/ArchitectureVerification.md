# 架构验证：从小门禁开始

不要先建宏或 SwiftSyntax 框架。不同规则需要不同证据：

| 规则 | 最可靠的第一道约束 |
|---|---|
| Foundation 不引用 MSRU、Core 不引用 UI | 现有 SPM target 依赖图 + 编译；源码 lint 防止轻易破坏方向 |
| 语义呈现不引用 AppKit/UIKit | Platform 目录边界 lint；第二平台稳定后再考虑独立 target |
| 产品 View 不创建原生窗口/split controller | 窄范围符号 lint；平台组合根允许集成原生能力 |
| Feature 不互读私有状态 | Swift private/internal/package 可见性、窄上下文；同一模块内不能靠命名实现真正隔离 |
| Route/destination、sidebar/route、重复 ID | 现有 validate() 单元测试 + 实际 MSRU definition 的契约测试 |
| 应用状态不进入场景快照 | 明确 Codable DTO、白名单字段审查、round-trip 与行为测试；字符串扫描不能证明语义 |
| Scene state 不进入 ApplicationModel | 所有权审查与多窗口隔离测试；宏不能可靠判断业务寿命 |

新增 `Scripts/verify-architecture.py` 是便宜的文本门禁，不是 Swift parser，也不能处理所有别名/动态行为。已有编译器与行为测试才是最终证据；规则扩大后出现真实语法误判，再考虑 SwiftSyntax。它不会把“每个模型都能从 UI 独立运行”或“全部路由均覆盖”包装成已经证明的事实。

产品侧扫描全部 Swift 文件，不依赖 `*View.swift` 命名：AppKit / UIKit 导入及原生窗口、分栏控制器构造限定在 `MSRU/Platform`。内嵌封面数据通过 `Platform/SwiftUI/Image+ArtworkData.swift` 转换为 SwiftUI Image；各 Feature 继续拥有占位图、布局及裁剪。该边界不要求把纯 SwiftUI 表达迁入平台目录。

FFmpeg 重建使用 `Packages/MSRUCodecFFmpeg/Scripts/build-ffmpeg-micro-apple.sh`。每次构建独立写入 `.build-ffmpeg/run.*`，失败日志保留；现有 Vendor 在全部构建及检查成功前保持可用。暂存产物通过同文件系统重命名发布，中途失败则恢复旧目录。`.build-ffmpeg.lock` 防止并发发布；异常断电或强杀后，须先确认原构建进程已结束，再处理遗留锁和暂存/备份目录。不要把仍存在的旧二进制当作本次构建成功证据。脚本构建 macOS arm64、iOS/visionOS 真机 arm64，以及各自包含 arm64 + x86_64 的模拟器切片。缓存压缩包按 FFmpeg 版本复用；下载先写临时文件，成功后才进入缓存。2026-09-20 已实际重建完整 XCFramework，iOS Simulator 和历史 visionOS 模拟器的 App 编译链接均已验证通过。**依据最新用户指令，visionOS 涉及的所有开发与设备验收已明确暂停，watchOS 与 iOS 继续保留推进**；历史已生成的 visionOS 构建切片保留作为静态归档。

本地/未来 CI 执行：

```sh
python3 Scripts/verify-architecture.py
python3 Scripts/verify-previews.py
swift test --package-path Packages/AppFoundation
xcodebuild test -project MSRU.xcodeproj -scheme MSRU-UnitTests -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

CI runner 须有当前项目要求的 Xcode/SDK。仓库目前没有现成 CI workflow，本次不假定某个托管服务可提供它。可先在每次提交前运行这些命令。

验证分工：AI 负责构建、接口调用和内部代码契约的定向测试，用户负责界面显示、使用体感及端到端验收；只有长期有效的回归用例进入正式 Tests，任务专用探针放在临时目录并在任务结束时移除，不加入日常全量测试。

macOS 音频输出的模拟硬件契约测试在 `MacAudioOutputTests`，真实设备枚举单独放在 `MacAudioHardwareSmokeTests`。常规定向运行只选前者；后者虽不改变设备采样率或独占状态，仍会访问本机当前输出，按硬件验证安排运行。当前 PCM 路径使用 Float32、EQ/响度节点和 `AVAudioEngine.mainMixerNode`；输入、引擎、设备采样率相等只能证明观测到的速率匹配，不能证明 Bit-Perfect 或无后续系统处理。

共享的 `MSRU-UnitTests` scheme 只构建应用与单元测试，不构建 UI Runner。主 `MSRU` scheme 保留完整 UI 测试入口；分开运行可以避免机器上的 GUI 调试权限影响普通回归测试。

macOS 进程级退出/重启测试位于 `MSRUUITests`。Debug 组合根识别测试提供的 `MSRU_UI_TEST_SUITE`（限定 `MSRU.UITests.` 前缀），使用独立恢复域、内存业务依赖和禁用 autosave 的窗口工厂；Release 不包含此入口。窗口公开稳定的 scene accessibility identifier，以便核对恢复后的窗口身份。UI Runner 必须正确签名，不能沿用单元测试的禁用签名参数：

```sh
xcodebuild test -project MSRU.xcodeproj -scheme MSRU \
  -destination 'platform=macOS' -derivedDataPath /tmp/msru-ui-development-build \
  -only-testing:MSRUUITests CODE_SIGNING_ALLOWED=YES
```

2026-09-20 用户放行系统权限后，上述命令已完成，2 项 UI 测试通过，包括实际退出与重启恢复。

这条命令沿用项目配置的开发签名，还依赖本机 XCTest GUI 自动化环境；编译及磁盘签名校验通过不等于系统允许 Runner 执行。本机 AMFI 明确拒绝 ad-hoc UI Runner，不能通过关闭系统保护解决。Runner 停留在启动阶段时先检查运行句柄、服务日志与签名，不把观察超时当作测试失败，也不并行启动重复测试。

静态 definition 的有限 routes 可以全量校验；任意 `matches` 闭包、关联值 Route 的无限取值不能由这套校验证明穷尽。不要为“Architecture Compiler”这个名字承诺做不到的保证。

## 目录与 Preview 维护契约

```text
MSRU/
├── App/                  应用装配、命令、场景、导航、跨平台 Shell
├── Features/             用户可见功能及其呈现
├── Music/                音乐目录、资料库、播放与 Provider 能力
├── Platform/             macOS 原生窗口接入、SwiftUI 平台根视图
├── Shared/UI/            跨功能复用的音乐视图
└── PreviewSupport/       确定的示例数据与隔离依赖
Packages/AppFoundation/
├── Sources/AppFoundation/    不依赖 UI 的基础语义与运行机制
└── Sources/AppFoundationUI/  语义呈现、预览宿主和内部平台适配
```

每个直接声明的 View / Representable 在同文件提供 `#Preview`，包括 private 子视图。使用 `MSRUPreviewData` 创建产品依赖；禁止在预览中直接使用 live 默认构造器。复杂视图至少覆盖有内容与空状态，逐步补齐失败和进行中状态。

本地资料库通过 `LocalLibraryRepository` 注入文件操作；Apple Music 通过 `AppleMusicLibraryServing` 注入授权与查询；Provider 配置可禁用持久化并注入连接响应。播放预览使用空 ProviderRegistry，不解析真实媒体。不要以进程环境检测或全局 preview 开关改变生产行为。

`verify-previews.py` 检查直接 View/Representable 声明是否在同文件的预览块中实例化，并拒绝常见 live 默认构造器。它不证明视觉质量、间接协议继承或任意闭包无副作用；平台构建验证宏，`LibraryDependencyTests` 验证主要依赖隔离和失败重试。

历史审计中的旧文件路径保留作为当时证据；当前实现按本目录表定位。新旧目录不双写，不保留转发用兼容类作为迁移终点。
