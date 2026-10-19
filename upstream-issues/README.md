# 上游 issue 草案

这四个问题是在 **[cldr-conformance](https://github.com/CCllff-jpg/cldr-conformance)** 里
用 CLDR 官方测试数据（`release-49-beta3`）对 `zlhahaha/moonlocale@0.1.0` 做对拍时发现的。
每条都能用几十行代码复现，且给出了定位到的源码位置。

| # | 标题 | 严重性 | 类型 |
|---|---|---|---|
| 1 | [数字系统（numbering system）未支持：数字永远 ASCII，符号却随语言](./01-numbering-system.md) | 高 | 缺陷 |
| 2 | [大数格式化溢出：`-1,097,551.584%`](./02-large-value-overflow.md) | 高 | 缺陷（静默错误结果） |
| 3 | [默认小数位上限 3 与 CLDR 期望不一致](./03-default-fraction-digits.md) | 低 | 设计选择（待确认） |
| 4 | [RTL 区域的百分比缺少双向控制符](./04-bidi-control-chars.md) | 低 | 功能缺失 |
| 5 | [MF2：未知函数 / 未解析变量应按回退语义渲染](./05-mf2-fallback.md) | 中 | 行为差异（64/337 条） |

**提交方式**：每个文件的第一行就是 issue 标题，正文可直接粘贴；
如果只想提最关键的两条，建议提 **1 和 2**。

**说明**：本文档只描述"实现与 CLDR 官方测试数据的差异"，不评价实现质量——
第 3 条尤其可能是有意的设计选择，提出来只为对齐预期。
