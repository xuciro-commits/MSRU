# 跨平台呈现与 UI 语言

这是一份基于当前代码的设计判断，不是对 Apple Music/Finder/Xcode 等应用的视觉实测。本次优先完成架构取舍，不新增组件或假装已经交付双平台 renderer。

UI 语言首先是行为约定：位置表达层级，选择决定操作对象，toolbar 表达当前任务，上下文区解释选择或显示活动，持久 accessory 承载跨页面能力。不要把每个原生 View 包装成同名 Foundation 类型。

| 分类 | 内容与取舍 |
|---|---|
| 语义组件 | Shell、Workspace、上下文角色、持久 accessory、命令与搜索描述。复用的是区域关系与行为。 |
| 原生 primitive | List、Table、Grid、Form、NavigationSplitView、toolbar、inspector、sheet、ContentUnavailableView。默认直接组合使用。 |
| 产品 View | 音乐卡片、曲目列表、播放队列、迷你播放器。留 MSRU，即使别的应用也可能有“卡片”。 |
| 状态约定 | 首次加载、空结果、错误重试、已有数据上的刷新分别表达；不能每次刷新都抹去旧内容。 |
| 选择/详情 | Feature 拥有类型化选择；查看详情和修改选择分开。不要全局 `AnySelection`。 |

## 第一条跨平台验收切片：Browse

```text
同一 Scene 的 browse.state + actions + navigation
  → 同一 Workspace / Shell 语义描述
  → macOS / iPad 的呈现策略
  → 原生控件
```

macOS：侧栏 + 结果工作区；搜索放 toolbar；队列作为 activity 辅助区；持久播放器为 accessory。

iPad：宽屏使用 adaptive split，窄宽度折叠导航；搜索选择原生 searchable 合适位置；队列按宽度显示辅助区域或 sheet；播放器在安全区域内持续可达。iPhone/visionOS 先留策略扩展点，不能因为源码能编译就宣称交互验证通过。

`SwiftUISceneRootView` 通过 `SwiftUIApplicationShell` 消费与 macOS 相同的 Shell 语义，不复制 Feature/runtime。只在 renderer/平台组合入口使用编译条件。不得为消除三行 `#if` 发明统一窗口 API。

Browse 目前页面内搜索和新 toolbar 搜索重复。第一批工作应是单一 query 状态、每个平台一个主要搜索入口，以及队列按钮改变 scene 状态、renderer 随状态刷新。现有“动作先 toggle 原生控件，再回写 scene”的链条应逐步统一为状态驱动，并防止反馈循环。

## 完成标准

同一套 fixture，两个平台分别验证：搜索、取消/替换搜索、导航后回来、队列开关、播放状态共享、场景 UI 独立、保存并恢复。原生 toolbar 文本与 enabled 的更新不能丢键盘焦点。iPad 同时验证一个 Scene 的语义与多个 WindowGroup 会话的隔离；不要把 `.new` 命令被拒绝误报为已支持跨窗口路由。

每个导出的独立 View/renderer 提供无网络、无真实持久化的 Preview/PreviewHost，覆盖有内容、空、失败、窄宽度及长文本。行为类型用契约测试，不要求每个 struct 都造一个 Preview。当前 Workspace/Context/Accessory 和 Mac renderer 已有 preview host，先复用它们；暂不新增通用 Card、Page、Form、Table 包装。
