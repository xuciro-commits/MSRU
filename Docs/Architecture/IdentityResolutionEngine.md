# 音乐实体数据库与身份解析引擎 (Identity Resolution Engine)

> 核心思想：**文件不是歌曲。名字只是属性，ID 才是身份。**
> 架构参考：**Roon 实体与版本模型 + MusicBrainz 身份体系 + Picard/AcoustID 声纹聚类 + beets 加权匹配与置信度。**

---

## 1. 概念革命：从“扁平文件”到“实体图谱”

传统播放器将一个音频文件视作一首歌（1 File = 1 Song），导致歌手别名泛滥、合辑被拆散、格式与多版本冲突。MSRU 采用规范的音乐实体知识图谱：

```text
Artist (全球唯一实体 MBID，多语言 Aliases)
  │
  ├─────────────────────────┬─────────────────────────┐
  ▼                         ▼                         ▼
ArtistCredit              Work (抽象乐曲作品)       ReleaseGroup (专辑概念)
"Taylor Swift feat. ..."   "晴天" / "Symphony No.9"   "叶惠美" / "Kind of Blue"
                            │                         │
                            ▼                         ▼
                          Recording (具体录音事件)    Release (发行版本: CD/Remaster/Vinyl)
                            │                         │
                            └───────────┬─────────────┘
                                        ▼
                                      Track (Medium/CD 上的具体轨道)
                                        ▲
                                        │
                                   AudioAsset (音频资产: 编码/格式/声纹)
                                        ▲
                                        │
                                    AudioFile (磁盘物理文件: 路径/SHA256)
```

---

## 2. 三层元数据覆盖模型 (Three-Layer Metadata Overlay)

借鉴 Roon 的核心资产安全原则：**永远不修改、不销毁原文件标签**。

```text
┌─────────────────────────────────────────────────────────────┐
│ 3. User Metadata (最高优先级: 用户手动修改、选定封面、偏好)   │
├─────────────────────────────────────────────────────────────┤
│ 2. Canonical Metadata (权威图谱: MusicBrainz / 声纹识别结论)  │
├─────────────────────────────────────────────────────────────┤
│ 1. Original Metadata (只读底表: 音频文件原始 Tag，绝对保留)   │
└─────────────────────────────────────────────────────────────┘
```

- **解析优先级**：`User Metadata > Canonical Metadata > Original Metadata`。
- **字段级细粒度回退**：用户可指定“标题使用 Canonical，专辑使用 Original”；若识别错误，一键一键回退到 Original，绝不写坏本地几万首音乐文件。

---

## 3. 5 类重复判定与 Roon 式版本管理

重复不是简单的布尔值 `isDuplicate: Bool`，必须区分 5 种物理与艺术层次：

| 类型 | 特征 | 判定依据 | 处理策略 |
|---|---|---|---|
| **A. 物理重复 (File Duplicate)** | 完全相同文件 | SHA256 校验和完全一致 | 安全去重，保留一份物理文件 |
| **B. 格式不同 (Different Encoding)** | 同一录音，不同容器 | Recording ID 一致，声纹极高吻合（如 FLAC vs MP3） | 视作同一曲目不同编码，母带与移动版共存 |
| **C. 音质差异 (Different Quality)** | 同一录音，不同采样规格 | 16/44.1 CD vs 24/96 Hi-Res | 归入同一 `Versions` 集合，选定 `Primary Version` |
| **D. 版本/混音差异 (Different Master)** | 同一作品，不同后期 | 1982 首发版 vs 2011 Remaster vs 2025 Atmos | 归属同一 `ReleaseGroup` 下的不同 `Release`，全部保留 |
| **E. 演出差异 (Different Performance)** | 同一作品，不同现场录音 | Studio 录音室版 vs Live 1994 现场版 | 归属同一 `Work` 下的不同 `Recording`，绝非重复曲目 |

---

## 4. beets 式加权评分与置信度分层 (Confidence Tiers)

匹配不是 Yes/No，而是综合加权评分系统：

$$\text{Confidence} = \sum w_i \cdot \text{Similarity}_i$$

- **加权权重分布**：
  - `album_id` / `track_id` (内嵌 MBID): 权重 5.0
  - `artist` / `album` / `track_title`: 权重 3.0
  - `track_length` / `track_position` / `tracks_count`: 权重 2.0
  - `year` / `catalogue_number` / `label`: 权重 1.0

### 置信度三级漏斗与 Import Review 机制
1. **High Confidence (>= 0.90)**：直接入库建立实体关联，无需打扰用户；
2. **Medium Confidence (0.60 ~ 0.89)**：推入 `Import Review` 待审队列，用户集中决策；
3. **Low / Unidentified (< 0.60)**：以 Original Tags 原样展示，不强行匹配，不污染数据。

---

## 5. 声纹识别与专辑级聚类 (Picard / AcoustID)

1. **AcoustID 声学指纹**：通过 Chromaprint 提取音频内容声学特征，跨越 MP3/FLAC/WAV 格式差异定位 `Recording`；
2. **Cluster -> Lookup 聚类算法**：
   - 孤立的声纹只能识别单曲，无法确定专辑；
   - 导入前先按目录结构、曲目数、轨道序号、时长分布聚类为“潜在候选专辑 (Cluster)”；
   - 拿聚类集合匹配完整的 MusicBrainz `Release`，准确识别整轨专辑。

---

## 6. AI 的精准边界定位

- **严禁让 LLM 作为主识别器**：LLM 存在幻觉且成本高昂，不得由其直接断定歌曲实体。
- **AI 赋能长尾非结构化解析**：
  - 文件名解析器：`01晴天周杰伦葉惠美2003台湾版final2.flac` $\to$ 提取 `{ track: 1, title: "晴天", artist: "周杰伦", album: "叶惠美", year: 2003, edition: "Taiwan" }` 候选线索；
  - 异名与别名建议：将混乱命名建议归并为同一个 `ArtistEntity` 的 `aliases`。
  - 解析线索交由确定性声纹与 MBID 引擎执行严格验证。

---

## 7. 模块演进与目录规划

```text
MSRU/Music/Library/
├── Identity/
│   ├── ArtistEntity.swift         // 稳定身份、规范名、多语言别名
│   ├── ArtistCredit.swift         // 显示名与 Primary/Featured 关系
│   ├── Work.swift                 // 抽象作品
│   ├── Recording.swift            // 录音事件
│   ├── ReleaseGroup.swift         // 专辑概念
│   ├── Release.swift              // 发行实体 (CD/Remaster/Vinyl)
│   └── AudioAsset.swift           // 音频资产与声纹绑定
├── Metadata/
│   ├── OriginalMetadata.swift     // 物理文件只读原始标签
│   ├── CanonicalMetadata.swift    // 权威知识图谱规范元数据
│   ├── UserMetadata.swift         // 用户个性化覆盖与偏好
│   └── MetadataOverlay.swift      // 三层覆盖解析器
├── Deduplication/
│   ├── DuplicateCategory.swift    // 5 类重复判别枚举
│   ├── DuplicateClassifier.swift  // 音频资产查重分析器
│   └── TrackVersions.swift        // Roon 式多版本集合与 Primary 优选
├── Matching/
│   ├── MatchScorer.swift          // beets 式加权距离打分器
│   ├── ConfidenceTier.swift       // High / Review / Unidentified 分级
│   └── AlbumCluster.swift         // Picard 式专辑聚类模型
└── Import/
    ├── ImportPipeline.swift       // 11 步导入流水线状态机
    └── ImportReviewStore.swift    // 集中预审工作区存储
```
