# 体验与基本样式蓝图

目标是“内容清楚、操作可找到、状态可信、平台自然”。本文与[结构交互图谱](InteractionAtlas.md)仅使用文字和纯文本框图。真实外观以 Apple 原生组件和系统 Liquid Glass 为准；不使用网页模拟或图片确定 Apple 应用的视觉标准。

## 1. 一套区域语言，多个产品

| 产品 | Navigation | Workspace | Context | 持续辅助 / Workflow |
|---|---|---|---|---|
| MSRU | 发现、浏览、资料库 | 曲目表格/专辑网格 | 选中曲目信息或播放队列；二者语义不同 | 播放器 / 导入音乐 |
| 酒店 PMS | 房态、预订、住客 | 房间×日期时间轴 | 选中预订的摘要与操作 | 同步提示 / 新建预订、办理入住 |
| ERP | 销售、采购、库存 | 订单表格或看板 | 当前记录的摘要 | 待提交状态 / 创建、审核、调整 |
| 文件/IDE 工具 | 位置、目录、项目 | 文件列表、编辑器、画布 | 预览或属性 | 状态栏、控制台 / 导入、导出 |

同一位置可以容纳不同 Context，但框架不应把队列伪装成“选中曲目属性”。Workflow 不是永远出现在导航中的地点；可独立访问、需长时间恢复的流程仍允许有 Route。

## 2. 跨平台与空间策略

| 语义 | macOS / 宽窗口 | iPad 中窄窗口 | 紧凑呈现 |
|---|---|---|---|
| Navigation | 原生 sidebar | 可折叠导航 | 原生返回/导航入口；是否 tab 由产品信息结构决定 |
| Workspace | Table、Grid、Timeline、Editor 等 | 同一业务，可有不同内容 View | 保留主要任务，不强行缩小全部列 |
| Context | trailing pane / inspector | 空间足够时保留，否则可主动打开 | sheet、详情层级等；可关闭并找回 |
| Toolbar/Search | 原生命令、显示控制、搜索 | 原生 toolbar/searchable，按任务调整 | 有优先级的操作与 overflow，不挤成图标墙 |
| Accessory | 主工作区关联的原生宿主 | 安全区域内持续可达 | 紧凑控件，展开完整操作 |
| Workflow | sheet 或独立窗口 | sheet / navigation | 根据复杂度呈现，不无条件全屏 |

适配首先取决于**可用空间和任务**，不能仅用 `os(macOS)` / `os(iOS)` 判断。Apple 指导明确要求处理 iPad 多种窗口宽度，并在主布局放不下时优先考虑隐藏第三栏；这支持区域渐进收起，而非两套业务流程。[Apple Layout](https://developer.apple.com/design/human-interface-guidelines/layout)、[Split views](https://developer.apple.com/design/human-interface-guidelines/split-views?changes=_6)

## 3. 基础样式规格

| 项目 | 起始规范 |
|---|---|
| 字体 | 系统字体和语义文字样式；标题与内容分级；表格数字对齐；尊重动态字体与本地化 |
| 密度 | Mac 默认紧凑、iPad 更宽松；由输入方式和内容决定，不用同一固定行高覆盖所有设备 |
| 间距 | 原生控件使用系统默认；自定义 Surface 可从 4/8/12/16/24/32pt 尺度开始，视内容验收调整 |
| 色彩 | 中性内容区、一个产品强调色；选择、错误、业务状态各有意义；状态配文字/符号，不能只靠颜色 |
| 材质 | 原生导航、toolbar、容器按系统提供 Liquid Glass 等材质；产品内容保持清晰。使用系统行为与可读性适配，不手工仿造一套玻璃层 |
| 边界 | 用层级、对齐、留白和必要分隔线组织内容；不默认把每组内容塞进圆角卡片 |
| 控件 | 优先原生 Button、Picker、Form、Table、searchable、menu；自定义只为系统无法表达的内容与交互 |
| 内容背景 | Workspace 拥有内容 Surface，平台容器管理其周边；画布/专辑图可有自己的背景策略 |
| 动效 | 表达状态和空间变化；尊重 Reduce Motion，不靠装饰动画维持“高级感” |
| 空/错/载入 | 首次加载、无数据、搜索无结果、局部失败、已有内容刷新分开；保留可用内容与恢复入口 |

这些数值是自定义区域的设计起点，不是必须进入 Foundation 的 token API。不得为统一 padding 包装全部 SwiftUI 控件。

## 4. 核心交互

一个操作若出现在多处，须共享语义、权限和 enabled 条件。Toolbar 放当前任务的常用操作，菜单保持完整可发现性；不要将所有操作搬进 toolbar。Apple 将 toolbar 定义为常用命令、导航、搜索和控件的便捷入口，而非固定按钮条。[Apple Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars?changes=la)

搜索的位置服从平台与产品结构；MSRU 同一工作区使用一个主查询入口。允许明确不同范围的局部搜索，不把“只有一个搜索框”上升为所有产品的禁令。当前官方指导也允许按清楚分离的区域提供局部搜索。[Apple Searching](https://developer.apple.com/design/human-interface-guidelines/searching?changes=_4)

选择不等于打开详情；切换列表/网格保留实体选择。多选、键盘移动、上下文菜单、拖放和撤销按用例逐项设计，不能因画出了表格就宣称支持。只读摘要与可编辑 Inspector 的提交、取消和错误语义不同。

## 5. 纯文本设计与实现边界

具体样式统一收录于[分层界面与交互设计图册](InteractionAtlas.md)，按完整窗口 → 区域 → 页面 → 内容组件 → 控件 → 状态逐层展开。它包含各产品完整窗口、Toolbar、Sidebar、Table/List/Grid/Gallery/Kanban、Timeline/Canvas/Editor、Inspector、Form、Sheet、Dialog、Popover、按钮与输入控件、辅助区、播放器、反馈和跨平台布局。每层均有纯文本框图及触发/结果说明，示例不代表这些产品已实现。

文本设计规定“内容放在哪里、操作影响谁、失败如何返回”；材质、圆角、光影、滚动边缘和系统交互由实际原生组件实现。文本图不验证 VoiceOver、原生窗口生命周期和键盘焦点恢复，也不固定像素值。图中区域可随空间重排，不能机械照画成固定三栏。

第一条工程切片仍是 Browse：修复搜索/toolbar 状态同步并共用平台语义；第二条是 Library：列表/网格、选择、收藏持久化与播放；第三条才是酒店 Timeline 及服务端冲突。这样同时照顾现有问题和原始文档选择 Library 的产品理由。

## 6. 每次设计验收

- 窗口逐步变窄时，主要内容和关键操作保持可达；隐藏的区域可找回。
- 测试键盘、指针、触控；焦点顺序有意义，按钮名称清楚，辅助技术可区分选中与播放状态。
- 明暗外观、增大字体、长文本、Reduce Motion、Increase Contrast 均可使用。
- Preview 无网络/真实磁盘副作用，覆盖加载、空、错误、有内容、长文本与窄宽度。
- 原生外观验收在真实 SwiftUI/AppKit/UIKit host 中完成；跨平台业务验收使用同样 fixture 与契约。

相同工作区内容在不同产品间可以完全不同。时间轴不是必须通用化的组件，播放器也不是框架组件；框架负责让它们自然进入应用。
