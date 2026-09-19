# 抽象取舍

基线与范围见 `NorthStarArchitecture.md`。KEEP 不是承诺永久公开 API；DELETE 是后续局部迁移建议，本次没有删除生产类型。

| 抽象 | 判断 | 真实价值、删除代价或缩减方向 |
|---|---|---|
| Feature | KEEP，限制使用 | 固定状态/动作/处理器关联；删除会失去 host 的类型约束。静态设置页无需加入。 |
| FeatureHost | KEEP | 拥有状态、依赖快照及任务登记。删掉只会让每个功能重复实现；先修取消后的回传权限。 |
| FeatureTask | KEEP / SIMPLIFY | 表达异步工作与取消。实际执行是 host 管理的非结构化 Task，不要称为 Swift 结构化并发；暂不扩成效果 DSL。 |
| FeatureService | SIMPLIFY | 实际是同步状态转换加任务描述。名字容易与数据 Service 混淆；不因此新增一层业务服务。 |
| DependencyValues | KEEP / CONSTRAIN | 支持 live/preview/test 和局部替换；删除会丢失已有测试能力。`Any` 加 `@unchecked Sendable` 的承诺需收窄，见并发文档。 |
| ApplicationFeature | KEEP，暂缓扩展 | 静态贡献入口；与运行 Feature 职责不同。不能强制所有贡献者有 FeatureHost。 |
| FeatureContribution | KEEP | 汇集一项功能的路由、侧栏、命令。保留纯值；不装运行对象。 |
| FeaturePack | KEEP / SIMPLIFY | 归一化及校验贡献。删除后 ApplicationDefinition 仍需同等逻辑；没有独立消费者前不要扩充插件系统。 |
| ApplicationDefinition | KEEP | 当前组合入口已经合理。Core/UI 的分割由 FeaturePack/PresentationPack 实现，不再拆一轮。 |
| RouteContribution | KEEP，注意边界 | 声明可导航入口。当前是具体 Route 值，不是无限参数路由的完整 schema。 |
| SidebarContribution | KEEP | 导航入口及排序，不拥有选中状态；无需成为通用导航树框架。 |
| RouteDestination | KEEP / CONSTRAIN | 路由到工作区；任意 `matches` 闭包无法由有限测试证明全部覆盖。动态实体路由出现后用穷尽 switch 或有约束的 case 映射。 |
| WorkspacePresentation | KEEP | 把主内容与该内容的操作、上下文组合起来。仅有一种工作区布局时不加工作区运行时。 |
| ContextPresentation | KEEP | 辅助信息的角色与内容；队列是 activity，选中对象属性才是 inspector。 |
| AccessoryPresentation / AccessoryScope | SIMPLIFY | 保留持久辅助 UI。当前 `.application` 表示跨工作区可见，不证明对象是应用单例；寿命与摆放位置必须分开。 |
| ToolbarPresentation | KEEP，补同步契约 | 操作与搜索已有真实使用。不要复制一整套原生菜单/toolbar API。 |
| ApplicationShellPresentation | KEEP | 定义跨工作区的辅助区域；同一描述可在多窗口各自呈现。 |
| ApplicationShellRuntime | SIMPLIFY | 无状态组合器。职责止于 resolve；下一次相关修改可改名 ShellResolver。 |
| ResolvedApplicationShell | KEEP，作为实现边界 | 消除 renderer 的产品泛型；`AnyView` 在此合理。不要序列化、跨 actor 传递或作为领域状态。 |
| MacApplicationShellRenderer | KEEP | 统一原生 split、hosting 和 accessory 安装。应用仍决定选择哪个辅助区域；这种少量组合代码是正常成本。 |
| MSRUApplicationShellSession | MERGE 候选 | 为 Scene/context/action 组装提供小包装。等 iPad slice 证明是否复用，再决定并入场景组合对象；现在直接删可能损害弱引用关系。 |
| ApplicationCommandCenter | DELETE 候选 | 当前只转发给 handler 并 map 数组，无策略或资源所有权。由 runtime 直接调用 gate 可等价替代；同一小改动删除类型及纯转发测试。 |
| Single/MultiScene CommandRuntime | KEEP，暂不泛化 | 提供真实不同的平台能力与挂起队列；重复几行比增加模式类型参数便宜。 |
| Scene Runtime / MacSceneWindowFactory | KEEP，留产品 | 支持测试和平台生命周期；待第二个真实消费者验证再提取通用实现。 |
| Restoration | KEEP，分清 schema 与存储 | 存储适配器可替换，快照字段/迁移由产品拥有。不序列化 Observable 对象图。 |

## 有证据的优先问题

1. **并发检查目标尚未兑现。** `MSRU.xcodeproj/project.pbxproj:486,546` 的 App 配置为 `SWIFT_VERSION = 5.0`；package 使用 Swift tools 6.0。编译器版本 6.4 并不能代替 App 的 Swift 6 语言模式。单独迁移，按诊断修边界，不批量添加 `@unchecked Sendable`。
2. **取消不等于撤销回传。** `FeatureHost.swift:213` 的 send 闭包不校验 token 是否仍登记。忽略取消的旧 operation 可以继续发 action；当前 Browse/Library 主动检查取消，因此这里是框架契约缺口，不是已复现的页面故障。
3. **呈现刷新不完整。** `MSRUMacWindowComposition.observePresentation()` 只读取 route；`MacToolbarAdapter.makeSearchItem()` 将 text 拷贝到原生控件。Browse 页面内搜索与 toolbar 同时存在，页面内 query 改变不会由该观察入口刷新 toolbar。应统一搜索入口，并验证同一路由下 query、enabled、标题等变化能同步，且不会因重建控件丢焦点。
4. **恢复容错是整数组粒度。** `MacSceneRestorationStore.loadSnapshots()` 中一个记录解码失败会让全部记录变为空，后续保存可能覆盖旧数据。需要逐条隔离与原始数据保留。
5. **第二平台尚未验证完整 Shell。** `iPadRootView` 直接构造 SidebarPaneView/MainContentView，没有消费与 macOS 同一份 resolved shell。它共享路由内容，不等于已经共享 toolbar、context、accessory 的完整语义。

无需因上述问题重写整个 framework。优先修可观察的行为，再判断包装层是否值得保留。
