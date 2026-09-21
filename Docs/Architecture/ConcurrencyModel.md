# 并发与恢复契约

## 所有权规则

以下是目标契约，不是当前已全部实现的保证；当前缺口见后文。

| 对象 | 创建/拥有的工作 | 何时失效 |
|---|---|---|
| 应用业务服务 | 播放、同步、应用启动加载 | 明确 stop/shutdown；不能依赖终止回调完成持久化 |
| Scene | FeatureHost、场景观察及呈现刷新 | 明确关闭/丢弃场景；失活和进入后台不是关闭 |
| FeatureHost | 带 ID/token 的操作 | 替换、cancel、stop 时撤销结果回传权限；deinit 兜底 |
| View `.task` | 只为当前可见 UI 服务的工作 | SwiftUI 取消该任务时；向 host 发 action 不自动转移其取消关系 |
| Renderer | 原生 observer、delegate、订阅 | detach/close 时撤销；不拥有领域网络请求 |

UI/Observation 和 Feature 状态转换限定 MainActor。I/O 的异步接口不意味着整段工作自动离开 MainActor；实际 CPU 密集解码/扫描应有明确执行边界。声学特征提取与文件解码等 CPU/IO 密集工作必须通过专有后台 actor（如 `AudioFingerprintService`）调度并进行 in-flight 去重与并发合并，严禁在 `MainActor` 或其子 `Task` 中直接同步解码。只有需要保护共享可变状态的库、缓存、解码器才建 actor，不给每个名词套 actor。跨隔离边界的请求和结果要求 Sendable；原生句柄由适配器拥有，UI action 全在 MainActor 时不必为了形式强加 Sendable。

`DependencyValues` 的下标虽被 MainActor 约束，`@unchecked Sendable` 容器仍允许任意 `Key.Value`。目前不能仅凭这一点断言数据竞争，但也不能宣称任意依赖安全跨 actor。优先让 key 的值显式 Sendable（包括受全局 actor 保护的对象），并将擦除存储的不变量限制在一个实现点；后台工作只捕获所需 client/不可变值，不传整包依赖。Preview/Test 的未配置 I/O 应明确失败或返回 fixture，不应悄悄落到 live。

## 最先补的并发约束

FeatureHost 的回传闭包携带任务 token，在 MainActor 上确认它仍在登记表后才发送 action。cancel 先移除登记再通知任务取消；新任务使用新 token，旧任务完成不能清除新任务。这样同时获得协作式停止和“无权再提交旧结果”。

用可控 continuation/latch 测试：启动 A，替换为 B，B 返回，再让忽略取消的 A 返回，最终只能保留 B。另测 cancelAll、关闭场景、同 ID 多任务及依赖快照。不要靠 sleep 的长短证明时序。`FeatureTaskLifetimeTests` 已覆盖忽略取消的 operation、cancelAll、替换后旧结果及 operation 返回后逃逸回调；回传权限由运行登记表验证。场景关闭、同 ID 并行任务仍需单独验证。

`ApplicationModel.start()` 的启动 Task 目前无 handle；先明确它就是应用级加载，再由应用持有以便测试和显式 shutdown。不要把“每个 Task 必须写进 FeatureHost”作为规则。

## Lifecycle 与 Restoration

应用阶段可以继续使用现有 initialized/bootstrap/ready 等状态机；不要把场景 active/background、窗口关闭、记录删除全部塞进同一枚举。恢复记录是跨进程的产品意图，业务持久化是另一套数据。

| 事件 | 运行态 | 恢复记录 |
|---|---|---|
| Launch | 读取、筛选/迁移、创建场景，再释放排队命令 | 不能在判定损坏前当作空记录覆盖 |
| Scene deactivate/background | 依平台限制暂停可恢复工作；保留会话 | 提交最近稳定快照 |
| 用户关闭单窗口 | 移除场景注册，停止场景任务/观察 | 按当前 MSRU 策略删除该场景记录 |
| Cmd+Q | 先进入 quitting，再处理关闭通知 | 保留仍打开场景的最新记录 |
| Crash/强杀 | 不保证有任何最后回调 | 恢复最近成功写入的快照，不承诺最后一瞬间状态 |

现有 AppDelegate 已在 should/willTerminate 调用 prepareForTermination，已有状态机、关闭删除和退出策略单元测试，不应再推倒重建；已通过真实窗口验证 AppDelegate → coordinator → 原生关闭通知的程序化退出顺序。已补：coordinator 仅接受当前注册 Scene 实例发出的同 sceneID 回调，关闭时调用 SceneModel.close() 撤销 Feature 任务；测试确认关闭后的 snapshot 不能复活记录。进程级 XCUITest 已通过实际 Cmd+Q 与重新启动验证，按稳定 scene ID 确认仍打开窗口恢复、手动关闭窗口不恢复。

快照只白名单保存 SceneID、稳定 route/entity ID、必要布局；播放队列等应用状态、Task、服务、缓存和临时 focus 不进 Scene snapshot。采用 version + sceneID + payload，逐记录解码；未知版本/损坏记录保留原始数据，恢复有效记录，必要时新建默认窗口。只有出现真实 schema 变更才编写迁移函数，不要先造迁移框架。

状态机测试用事件序列和不变量：重复 bootstrap/terminate 幂等；关闭 A 不影响 B；退出关闭不删记录；关闭后发布快照无效；新窗口不复用旧会话权限；好坏记录混合时好记录保留；迁移失败不覆盖原文；恢复完成前命令不执行。纯逻辑测试外，以进程级 XCUITest 验证双窗口、Cmd+Q、重启的用户可见结果；程序化原生窗口测试覆盖关闭回调顺序。自动化不替代视觉体验验收。

## 已提交数据与界面状态

AVPlayer 的时间与结束观察者即使已移除，也可能留下已排队的 MainActor 回调。回调执行时必须确认来源播放器仍是当前播放器，才能更新进度或推进队列。`LocalMediaIntegrationTests` 通过先发送旧曲目结束通知、在让出执行权前切换曲目，验证旧通知不能跳过新曲目；测试播放器静音且默认速率为零，不依赖真实播放结束时序。

地址解析成功不等于媒体播放成功。当前 AVPlayerItem 的失败状态和播放中断通知会撤销活动 transport、停止播放状态并发布错误；队列保持原位，重试重新解析当前失败项。失败回调同样检查播放器身份，旧播放器的失败不能清空新 transport。真实损坏 WAV 文件测试覆盖解析成功后的 AVFoundation 失败及保留队列的重试。

PCM 解码失败使用同一清理与重试路径。结束和失败回调均校验引擎身份；移除引擎时先断开回调，再异步关闭会话。`PCMPlaybackFailureTests` 注入每次读取都失败的解码会话，经过实际 PCMPlaybackEngine 验证错误状态、会话关闭，以及重试创建新会话且队列身份不变。

`LibraryStore` 的 load 和 mutation 进入同一串行队列。首次 mutation 必须成功读取现有资料库，持久化成功后才发布新 tracks；失败保持最近已提交状态并暴露错误。已接受的收藏写入属于应用级工作，关闭发起它的场景不撤销磁盘提交；被取消的 Feature 只失去更新自身 UI 状态的权限。

`LocalLibraryStore` 的扫描和导入也按接受顺序执行。扫描开始时取得的旧结果不能覆盖后来导入的曲目；第二批导入排队，不能因为第一批忙碌而直接丢弃。`isImporting` 覆盖全部已接受且未完成的导入请求。可控 continuation 测试验证这两种时序，不依赖固定延时。

`NativeSceneLifecycleTests` 使用真实 NSWindow、实际窗口关闭通知和注入的 AppDelegate，验证单窗口关闭删除记录、终止回调先保存再关闭、重新创建 coordinator 后只恢复仍有效的场景。测试使用独立 UserDefaults 域并关闭分栏 autosave；这是程序化原生调用链验证，不等同于操作系统实际终止进程后的端到端测试。同套测试还验证原生搜索字段的状态同步、控件身份和 first responder 保留。

恢复存储按记录独立解码，保留未知/损坏记录；顶层 JSON 损坏时，首次覆盖前把原始 Data 保存到恢复键的 `.quarantine` 数组。当前版本不尝试猜测未来 schema，不清理用户的未知数据。
