默认小数位上限 3 与 CLDR 部分用例的期望不一致（想确认是否有意为之）

**版本**：`zlhahaha/moonlocale@0.1.0`
**严重性**：低——**这可能是有意的设计选择**，提出来只为对齐预期
**类型**：使用问题 / 预期确认，不是缺陷报告

## 现象

`DecimalFormatter::new` 的默认 `maximum_fraction_digits` 是 **3**：

```moonbit
pub fn DecimalFormatter::new(locale : Locale) -> DecimalFormatter {
  { locale, grouping: true, minimum_fraction_digits: 0, maximum_fraction_digits: 3, ... }
}
```

而 CLDR 的数字测试数据里，部分用例的期望输出保留了 6 位小数：

| 输入 | CLDR 期望 | 默认配置下实际 |
|---|---|---|
| `0.00831765` | `0.008318` | `0.008` |
| `0.831765`（百分比） | `0.831765%` | `0.832%` |

## 想确认的问题

1. 默认 3 位是否是有意取舍（例如对齐 `#,##0.###` 的常见模式）？
2. 如果是，是否有文档说明"需要更多小数位时请显式
   `with_maximum_fraction_digits(n)`"？我们的对拍会据此把这类差异标为
   "默认值不同"而非"算错"，避免误报。
3. 如果有意保持默认值，也建议在 README 里点一句——使用者从 ICU/Intl 迁移过来
   时容易踩到（JS `Intl.NumberFormat` 默认也是 `maximumFractionDigits: 3`，
   但 CLDR 的测试期望按"有效数字"给了更多位数）。

## 复现

```moonbit
let en = @moonlocale.Locale::from_string("en").unwrap()
let formatter = @moonlocale.DecimalFormatter::new(en)   // max_fraction = 3
// 需要 6 位时要显式设置：
let wide = formatter.with_maximum_fraction_digits(6)
```

（顺带：`with_maximum_fraction_digits` 会 clamp 到 0–12，这一点很好，
只是默认值的选择值得在文档里说明。）

## 影响面

CLDR 数字套件里 **208 条**失败被归因为 `rounding-mismatch`，其中大部分是这一条；
若确认是有意取舍，我们的报告会把它从"缺陷"改为"默认值差异"。
