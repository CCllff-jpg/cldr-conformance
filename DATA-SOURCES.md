# 数据来源与许可证（Data Sources）

本项目的全部测试数据来自 **CLDR（Unicode Common Locale Data Repository）官方仓库**，
不使用任何第三方自制测试集，以保证结论的权威性与可复现性。

- 上游仓库：<https://github.com/unicode-org/cldr>
- 测试数据目录：<https://github.com/unicode-org/cldr/tree/main/common/testData>
- 语言环境数据（二期用）：<https://github.com/unicode-org/cldr-json>
- 许可证：**Unicode License v3** — <https://www.unicode.org/license.txt>

---

## 已确认的数据文件

> 下表由 `cmd/fetch-data` 在 D2 落地时补全 `SHA256` 与 `CLDR 版本` 两列。
> 在此之前，「结构」列是已核对过的真实字段/文件名，可直接用于写解析器。

| 套件 | 文件 | 大小 | 结构 | SHA256 | 入库 |
|---|---|---|---|---|---|
| decimal | `common/testData/decimal/decimals.tsv` | 7 KB | TSV：`locale / number_format / format_length / input / expected` | 待 D2 生成 | ✅ |
| decimal | `common/testData/decimal/decimals_modern_locales.tsv` | 74 KB | 同上 | 待 D2 生成 | ✅ |
| decimal | `common/testData/decimal/decimals_extended_numbers.tsv` | 217 KB | 同上 | 待 D2 生成 | `--full` |
| datetime | `common/testData/datetime/datetime.json` | 83 KB | JSON | 待 D2 生成 | ✅ |
| datetime | `common/testData/datetime/skeletons.tsv` | 11 KB | TSV | 待 D2 生成 | ✅ |
| datetime | `common/testData/datetime/skeletons_all_calendars.tsv` | 33 KB | TSV | 待 D2 生成 | ✅ |
| datetime | `common/testData/datetime/skeletons_all_locales.tsv` | 121 KB | TSV | 待 D2 生成 | 可选 |
| datetime | `common/testData/datetime/skeletons_all_skeletons.tsv` | 113 KB | TSV | 待 D2 生成 | 可选 |
| datetime | `common/testData/datetime/skeletons_random_5percent.tsv` | 287 KB | TSV | 待 D2 生成 | `--full` |
| message-format-2 | `common/testData/messageFormat/tests/syntax.json` | 22 KB | JSON | 待 D2 生成 | ✅ |
| message-format-2 | `common/testData/messageFormat/tests/syntax-errors.json` | 6 KB | JSON | 待 D2 生成 | ✅ |
| message-format-2 | `common/testData/messageFormat/tests/data-model-errors.json` | 4 KB | JSON | 待 D2 生成 | ✅ |
| message-format-2 | `common/testData/messageFormat/tests/pattern-selection.json` | 4 KB | JSON | 待 D2 生成 | ✅ |
| message-format-2 | `common/testData/messageFormat/tests/fallback.json` | 2 KB | JSON | 待 D2 生成 | ✅ |
| message-format-2 | `common/testData/messageFormat/tests/bidi.json` | 5 KB | JSON | 待 D2 生成 | ✅ |
| message-format-2 | `common/testData/messageFormat/tests/u-options.json` | 3 KB | JSON | 待 D2 生成 | ✅ |
| message-format-2 | `common/testData/messageFormat/tests/functions/` | — | JSON 目录 | 待 D2 生成 | ✅ |

### 二期候选（本期不做）

`units/`、`rbnf/`（罗马数字 / 中文数字）、`localeIdentifiers/`、`segmentation/`、`personNameTest/`、`transforms/`。

---

## `decimals.tsv` 的实测样例行

以下为本次规划阶段从上游直接取回的真实内容，用于说明该测试集的难度分布（这些正是"手写规则"最容易出错的边界）：

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

## 许可证与合规要求

1. **代码**：本项目代码以 Apache-2.0 发布（见 `LICENSE`）。
2. **数据**：CLDR 测试数据以 Unicode License v3 分发。使用时必须：
   - 保留 Unicode 的版权与许可证声明；
   - 在报告与文档中标注 CLDR 版本号；
   - 不暗示 Unicode 对本项目的背书。
3. **报告**：任何引用本项目一致率结论的场合，都应同时给出 CLDR 版本与所用数据文件的 SHA256，
   否则结论不可复现。

## 复核命令

```bash
# 拉取数据并校验（D2 实现）
moon run cmd/fetch-data

# 手工核对上游文件是否存在（规划阶段使用过的方式）
# https://api.github.com/repos/unicode-org/cldr/contents/common/testData/decimal
```
