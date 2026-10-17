///|
/// moonlocale（`zlhahaha/moonlocale@0.1.0`）的数字格式化适配器。
///
/// **能力范围**（由实测 API 决定，依据见 `可比性映射.md`）：
/// - ✅ 十进制（`DecimalFormatter::format`）
/// - ✅ 百分比（`DecimalFormatter::format_percent`，**内部乘 100**）
/// - ❌ 科学计数法（库无此 API）
/// - ❌ 紧凑格式 short / long（库无此 API）
///
/// 后两者由登记表按能力声明挡在门外（记 `unsupported`，不计失败），
/// 而不是让它们以"答错"的形式污染一致率。
///
/// **对拍基准**：使用库的**默认配置**（`DecimalFormatter::new` 默认开启分组、
/// 小数位 0–3）。这就是使用者开箱即得的输出；它与 CLDR 期望的差异本身就是互操作性问题
/// （例如 CLDR 对 `0.00831765` 期望 6 位小数，而库默认最多 3 位）。
pub(all) struct MoonlocaleAdapter {
  label : String
} derive(Debug, Eq)

///|
pub fn MoonlocaleAdapter::new() -> MoonlocaleAdapter {
  { label: "moonlocale", }
}

///|
/// 适配器自身的错误（与"答错"不同：这属于**无法执行**该用例）。
pub(all) suberror MoonlocaleAdapterError {
  /// locale 标签无法被库解析
  UnknownLocale(tag~ : String)
  /// 用例输入不是可解析的十进制字符串
  UnparsableValue(value~ : String)
  /// 库不支持该样式（正常情况下会被能力声明拦住，这里是兜底）
  UnsupportedStyle(style~ : String)
} derive(Debug)

///|
/// CLDR 用 `en_US`，BCP 47 用 `en-US`。
/// 库的 `Locale::from_string` 走 BCP 47 解析，因此必须先规范化。
pub fn canonical_locale_tag(tag : String) -> String {
  let out = StringBuilder()
  let mut run_start = 0
  let mut index = 0
  while index < tag.length() {
    if unit_at(tag, index) == 0x005F {
      out.write_substring(tag, run_start, index - run_start)
      out.write_string("-")
      run_start = index + 1
    }
    index += 1
  }
  out.write_substring(tag, run_start, tag.length() - run_start)
  out.to_string()
}

///|
fn unit_at(text : String, index : Int) -> Int {
  text[index].to_int()
}

///|
/// 把 CLDR 的十进制字符串解析成库的定点十进制 `Decimal`。
///
/// **全程不经 `Double`**：CLDR 的输入本身就是十进制字符串，转浮点会引入舍入误差，
/// 恰好污染本项目要度量的那个维度（`DESIGN.md` D2）。库的 `Decimal` 是
/// `{ coefficient : Int, scale : Int }` 的定点表示，与字符串输入天然匹配。
///
/// 解析失败返回 `None`（由调用方决定如何报告），不接受指数形式与特殊值。
pub fn parse_decimal(text : String) -> @upstream.Decimal? {
  if text.length() == 0 {
    return None
  }
  let mut index = 0
  let mut negative = false
  let first = unit_at(text, 0)
  if first == 0x002D {
    negative = true
    index = 1
  } else if first == 0x002B {
    index = 1
  }
  let mut coefficient : Int = 0
  let mut digits = 0
  let mut scale = 0
  let mut seen_point = false
  while index < text.length() {
    let unit = unit_at(text, index)
    if unit >= 0x0030 && unit <= 0x0039 {
      coefficient = coefficient * 10 + (unit - 0x0030)
      digits += 1
      if seen_point {
        scale += 1
      }
    } else if unit == 0x002E && !seen_point {
      seen_point = true
    } else {
      return None
    }
    index += 1
  }
  if digits == 0 {
    return None
  }
  let signed = if negative { -coefficient } else { coefficient }
  Some(@upstream.Decimal::new(signed, scale))
}

///|
pub impl @conformance.NumberAdapter for MoonlocaleAdapter with fn name(self) {
  self.label
}

///|
pub impl @conformance.NumberAdapter for MoonlocaleAdapter with fn format_number(
  self,
  locale,
  value,
  style~,
  length~,
) {
  ignore(self)
  ignore(length)
  let tag = canonical_locale_tag(locale)
  let parsed = match @upstream.Locale::from_string(tag) {
    Some(parsed) => parsed
    None => raise MoonlocaleAdapterError::UnknownLocale(tag~)
  }
  let decimal = match parse_decimal(value) {
    Some(decimal) => decimal
    None => raise MoonlocaleAdapterError::UnparsableValue(value~)
  }
  let formatter = @upstream.DecimalFormatter::new(parsed)
  match style {
    @conformance.NumberStyle::DecimalStyle => formatter.format(decimal)
    @conformance.NumberStyle::PercentStyle =>
      formatter.format_percent(decimal, @upstream.PercentSpacing::LocaleDefault)
    @conformance.NumberStyle::ScientificStyle =>
      raise MoonlocaleAdapterError::UnsupportedStyle(style="scientific")
    @conformance.NumberStyle::CurrencyStyle =>
      raise MoonlocaleAdapterError::UnsupportedStyle(style="currency")
  }
}
