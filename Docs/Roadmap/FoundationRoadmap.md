# 从当前工作树到可持续开发

顺序按风险和产品收益，不以增加类型数为进展。阶段表保留迁移顺序与退出条件；当前执行状态以 todo/02-WORK-QUEUE.md 为准，已完成的实现见文末对照。

| 阶段 | Goal / Files | API 增删 | Tests / Exit criteria | 用户收益 |
|---|---|---|---|---|
| NOW 0 | 收敛当前未提交的 Shell/Window 迁移；`App/Composition`、`Platform/macOS`、AppFoundationUI Platform | 不新增层；确认旧 MainWindowController/RootSplitViewController 的职责有且仅有一个接收者后删除旧路径 | package/app tests、macOS build；人工双窗口、切页、工具栏、关闭、Cmd+Q、重启 | 新窗口体系行为稳定，留下可回退基线 |
| NOW 1 | `FeatureHost` 回传 token 校验、`SceneModel`/coordinator 停止边界；restoration store 逐记录容错 | 必要时只加显式 scene stop；不增加 Runtime 总管 | 忽略取消的旧结果、关闭后 snapshot、多窗口好坏记录混合、终止序列测试全部通过 | 快速搜索/关闭窗口不再允许旧操作污染新状态，损坏记录不拖累全部窗口 |
| NOW 2 | `project.pbxproj` 将 App 迁入 Swift 6 language mode | 修具体隔离/Sendable 诊断；不批量 unchecked | macOS 与 iPad 目标均编译，现有测试通过，新增豁免逐项解释 | 后续异步功能获得更强编译约束 |
| NEXT 1 | `SwiftUISceneRootView`、Browse presentation/view、平台 Shell renderer；完成同一 Browse 切片 | 增加最小 SwiftUI renderer；删除重复搜索入口和迁移后的 iPad 旧组合路径；必要时 ShellRuntime 改名，无长期别名 | 同一 fixture 驱动两平台；query/enabled 同步、焦点不丢、多窗口状态独立、恢复正确；真机/模拟器验收 | iPad 获得一致功能与合适布局，macOS 搜索不重复 |
| NEXT 2 | 两个 command runtime 的维护边界；ApplicationCommandCenter 转发层已删除 | runtime 直接调用 gate，删除无策略转发类；Session 是否合并由双平台使用结果决定 | 保留命令排队、顺序、目标场景与 unsupported 的行为测试 | 降低维护成本，不改变交互 |
| LATER | 曲库导入/保存/重启、provider 错误、播放切换等真实功能 | 只按已暴露的问题提取播放引擎适配器；不先建数据框架 | 用例与失败路径测试；可完成持续使用的音乐流程 | 能搜索、收藏、播放、重启继续使用 |
| NOT YET | Finder/PMS/ERP/IDE、通用文档工作区、同步引擎、全局 selection/focus/search runtime、架构宏 | 无 | 第二个真实消费者或明确测得的维护痛点才启动 | 避免通用化拖延产品 |

每阶段单独可编译、可测试、可回退；改行为与机械重命名分开提交。过渡 API 在最后调用方迁移的同一阶段删除；如果迁移无法在一个小阶段结束，就缩小范围，不维持两套正式架构。

**停止继续设计框架的时间：从现在起就停止新增架构层。** 完成 NOW 的可靠性基线和 NEXT 1 的真实双平台切片后，冻结新的 Foundation 公共概念，转回 MSRU 功能；NEXT 2 可以随产品改动顺手完成，不阻塞产品。没有工作量与可用工时证据，不给虚构的具体日期。

以后每次框架提取只需回答三件事：实际消除了哪里重复的机制？相较产品直接实现是否减少概念？哪条契约测试证明行为不变？讲得通第二种应用不够；没有第二消费者的需求，先留在产品。

## 当前实现对照

- 已完成代码迁移至 App / Features / Music / Platform / Shared / PreviewSupport；旧窗口类、PageHeader、Pro 实验页、CommandCenter 转发层及 PlaybackRequest 旧构造器已退出主路径。没有任何调用者的 PlaybackDiagnostics、ProviderHealth 和 PlaybackProviderError 已删除；实际健康状态与错误处理保留在当前业务模型中。
- 四处内嵌封面解码统一使用 `Platform/SwiftUI/Image+ArtworkData.swift`，Feature 不再直接导入 AppKit / UIKit；占位图与尺寸仍归各视图管理。
- 直接 View / Representable 均有同文件 Preview，`Scripts/verify-previews.py` 防止回退；预览依赖与真实文件、账户、网络隔离。
- Feature 回传 token、关闭场景回调身份检查、逐记录恢复及损坏文档备份已实现。
- App 与测试 target 已使用 Swift 6；macOS、iOS 继续以实际构建和测试作为证据。
- SwiftUI Shell 已接入同一语义模型；Browse 只有 Shell 搜索入口，macOS 工具栏同结构刷新保留搜索控件身份并验证 enabled。
- 收藏写入串行化且成功后才发布状态；保存失败保持已提交状态。收藏页面已接入支持来源的播放、下一首和队列操作。

已通过原生搜索焦点测试和真实 Cmd+Q / 重启的双窗口恢复 XCUITest。仍需继续验收：紧凑宽度下的视觉布局、真实本地/远程音频输出。visionOS 真机及双架构模拟器的 FFmpeg 切片已补齐，平台 API 差异已适配，完整 App 编译链接通过；头显上的交互与媒体运行时仍待验收。
