# 数据来源与许可证（Data Sources）

本项目的全部测试数据来自 **CLDR（Unicode Common Locale Data Repository）官方仓库**，
不使用任何第三方自制测试集，以保证结论的权威性与可复现性。

---

## 一、数据基线

| 项 | 值 |
|---|---|
| 上游仓库 | <https://github.com/unicode-org/cldr> |
| **ref（不可变 tag）** | **`release-49-beta3`** |
| 上游目录 | `common/testData/` |
| 摘要的**权威记录** | [`fixtures/SOURCES.json`](fixtures/SOURCES.json)（每个文件的 URL / 字节数 / SHA256） |
| 离线校验 | `moon run cmd/fetch-data -- --verify` |
| 数据许可证 | [Unicode License v3](https://www.unicode.org/license.txt) |

### 为什么钉不可变 tag 而不是 `main`

`main` 会漂移。实测同一批数据在两个 ref 下的差异：

| 文件 | `main` | `release-49-beta3` |
|---|---|---|
| `decimal/decimals_modern_locales.tsv` | 74,459 字节 / `1366950f…` | 74,417 字节 / `d885874f…` |
| 其余 11 个快速档文件 | 完全相同 | 完全相同 |

也就是说：**不钉 ref 的话，「一致率」这个数字会在无人察觉的情况下改变依据。**
钉到 tag 后 URL 不可变，摘要可以长期复核；万一上游改了数据，`--verify` 会立刻报
`Mismatch`，而不是静默通过。

### 为什么是 `release-49-beta3`

- final `release-48` **尚未包含**这批测试数据（`decimals.tsv` 等是之后加入的，实测 404）；
- CLDR 49 尚未 GA；
- `release-49-beta3` 是目前唯一**同时具备全部 16 个文件、且 URL 不可变**的 ref。

升级方式：改 `internal/source/catalog.mbt` 里的 `cldr_ref()` 常量 → 重跑
`moon run cmd/fetch-data -- --sync` → 审阅 `fixtures/SOURCES.json` 的摘要 diff。

---

## 二、文件清单（16 个）

快速档 12 个（入库，保证离线可复现）：

| 套件 | 上游路径（相对 `common/testData/`） | 本地路径 | 字节 | 结构 |
|---|---|---|---|---|
| decimal | `decimal/decimals.tsv` | `fixtures/decimal/decimals.tsv` | 7,395 | TSV：`locale / number_format / format_length / input / expected` |
| decimal | `decimal/decimals_modern_locales.tsv` | `fixtures/decimal/decimals_modern_locales.tsv` | 74,417 | 同上 |
| datetime | `datetime/datetime.json` | `fixtures/datetime/datetime.json` | 82,880 | JSON |
| datetime | `datetime/skeletons.tsv` | `fixtures/datetime/skeletons.tsv` | 10,888 | TSV |
| datetime | `datetime/skeletons_all_calendars.tsv` | `fixtures/datetime/skeletons_all_calendars.tsv` | 33,406 | TSV |
| message-format-2 | `messageFormat/tests/syntax.json` | `fixtures/messageFormat/tests/syntax.json` | 22,541 | JSON |
| message-format-2 | `messageFormat/tests/syntax-errors.json` | `fixtures/messageFormat/tests/syntax-errors.json` | 6,154 | JSON |
| message-format-2 | `messageFormat/tests/data-model-errors.json` | `fixtures/messageFormat/tests/data-model-errors.json` | 4,156 | JSON |
| message-format-2 | `messageFormat/tests/pattern-selection.json` | `fixtures/messageFormat/tests/pattern-selection.json` | 4,283 | JSON |
| message-format-2 | `messageFormat/tests/fallback.json` | `fixtures/messageFormat/tests/fallback.json` | 2,142 | JSON |
| message-format-2 | `messageFormat/tests/bidi.json` | `fixtures/messageFormat/tests/bidi.json` | 5,176 | JSON |
| message-format-2 | `messageFormat/tests/u-options.json` | `fixtures/messageFormat/tests/u-options.json` | 3,243 | JSON |
| | | **合计** | **256,681** | ≈ 251 KB |

全量档 4 个（**不入库**，`--full` 按需下载，已在 `.gitignore` 中）：

| 套件 | 上游路径 | 字节 | 说明 |
|---|---|---|---|
| decimal | `decimal/decimals_extended_numbers.tsv` | 216,809 | 扩展数值（极大/极小/边界） |
| datetime | `datetime/skeletons_all_locales.tsv` | 121,148 | 全语言骨架矩阵 |
| datetime | `datetime/skeletons_all_skeletons.tsv` | 112,963 | 全骨架矩阵 |
| datetime | `datetime/skeletons_random_5percent.tsv` | 287,018 | 随机抽样 5% |
| | **合计** | **737,938** | ≈ 721 KB |

本地路径刻意与上游目录结构保持一致（`common/testData/<x>` → `fixtures/<x>`），便于逐条溯源。

### 尚未纳入本期

- `messageFormat/tests/functions/`：MF2 自定义函数测试目录，需先枚举其文件名
- 其余官方测试数据：`units/`、`rbnf/`、`localeIdentifiers/`、`segmentation/`、
  `personNameTest/`、`transforms/`（二期候选）

---

## 三、摘要的权威记录

**SHA256 不在此文档中重复维护**，避免两处数据漂移。权威值在清单里：

```json
{
  "cldr_version": "release-49-beta3",
  "files": [
    {
      "suite": "decimal",
      "path": "fixtures/decimal/decimals.tsv",
      "url": "https://raw.githubusercontent.com/unicode-org/cldr/release-49-beta3/common/testData/decimal/decimals.tsv",
      "sha256": "…",
      "bytes": 7395,
      "tier": "Fast"
    }
  ]
}
```

清单由 `--sync` 生成、由 `--verify` 离线复核，两者的语义在 `DESIGN.md` 中有记录。

---

## 四、复现方式

```bash
# 拉取快速档（12 个）并写入 fixtures/SOURCES.json
moon run cmd/fetch-data -- --sync

# 连全量档（4 个大文件，约 721 KB）一起拉
moon run cmd/fetch-data -- --sync --full

# 离线校验：重算摘要并与清单比对，任何不一致都以非 0 退出码结束
moon run cmd/fetch-data -- --verify
```

实测行为（可复核）：`--sync` 首次下载 11 个、跳过 1 个已存在的文件；**再次执行 12 个全部跳过**（幂等）。

---

## 五、`decimals.tsv` 的样例行

用于说明该测试集的难度分布——这些正是"手写规则"最容易出错的边界：

```
locale	number_format	format_length	input		expected
ar	decimal	short		1234565.0	1.2 مليون        # 紧凑格式 + RTL 标记
ar_EG	decimal			1234565.0	١٬٢٣٤٬٥٦٥       # 阿拉伯-印度数字 + 阿拉伯千分位
bn	decimal			1234565.0	১২,৩৪,৫৬৫       # 印度式分组（2,2,3 而非 3,3,3）
de_CH	decimal			1234565.0	1'234'565        # 撇号分组
ja	decimal	short		1234565.0	123万            # 东亚紧凑格式
ru	decimal	long		1234565.0	1,2 миллиона     # 复数词形随数值变化
```

---

## 六、许可证与合规要求

1. **本项目代码**：Apache-2.0（见 `LICENSE`）。
2. **CLDR 测试数据**：Unicode License v3。使用时必须：
   - 保留 Unicode 的版权与许可证声明；
   - 在报告与文档中标注数据基线（本项目的做法是记录 `release-49-beta3`）；
   - 不暗示 Unicode 对本项目的背书。
3. **引用结论**：任何引用本项目一致率结论的场合，都应同时给出数据基线 tag 与
   所用文件的 SHA256（即 `fixtures/SOURCES.json` 的内容），否则结论不可复现。

---

## 七、第三方依赖与许可证

本项目自身代码全部为 MoonBit；第三方依赖共 3 个（含 1 个传递依赖），**全部 Apache-2.0**，
与项目自身的许可证兼容。依赖树可用 `moon tree` 复核。

| 依赖 | 版本 | 许可证 | 用途 |
|---|---|---|---|
| `moonbitlang/async` | 0.22.4 | Apache-2.0 | HTTP(S) 下载、文件 IO、重试组合子（仅 native 后端） |
| `gmlewis/sha256` | 0.18.0 | Apache-2.0 | SHA-256 摘要 |
| `gmlewis/base64` | 0.16.13 | Apache-2.0 | `gmlewis/sha256` 的传递依赖 |

> 数据（Unicode License）与代码（Apache-2.0）的许可证不同，**请勿混用**：数据文件的
> 再分发须遵循 Unicode License v3。
