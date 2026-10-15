///|
/// 归因上下文：判定失败原因时需要的**用例信息**，刻意保持最小。
///
/// 不把整个用例传进来，是为了让归因规则只依赖它真正用到的东西，
/// 也让每条规则都能用两个字符串 + 少量上下文单测覆盖。
pub(all) struct AttributionContext {
  suite : @conformance.Suite
  /// 是否紧凑格式用例（`decimals*.tsv` 的 short / long）。
  compact : Bool
} derive(Debug, Eq)

///|
pub fn AttributionContext::new(
  suite : @conformance.Suite,
  compact? : Bool = false,
) -> AttributionContext {
  { suite, compact, }
}

///|
/// 分隔符的处理方式（三级，逐级放宽）。
priv enum SeparatorMode {
  /// 分隔符必须逐字符相同。
  Keep
  /// 分隔符位置必须一致，但**允许字符不同**（`1,234` ↔ `1.234` 这类区域差异）。
  Canonical
  /// 直接忽略分隔符（用于判断"是否只差分组"）。
  Drop
}

///|
/// Unicode 十进制数字块的起始码位（覆盖 CLDR 数据里会出现的数字系统）。
fn digit_zeroes() -> Array[Int] {
  [
    0x0030, // ASCII
     0x0660, // 阿拉伯-印度数字
     0x06F0, // 扩展阿拉伯-印度（波斯）
     0x0966, // 天城文
     0x09E6, // 孟加拉
     0x0A66, // 古木基
     0x0AE6, // 古吉拉特
     0x0B66, // 奥里亚
     0x0BE6, // 泰米尔
     0x0C66, // 泰卢固
     0x0CE6, // 卡纳达
     0x0D66, // 马拉雅拉姆
     0x0E50, // 泰
     0x0ED0, // 老挝
     0x0F20, // 藏
     0x1040, // 缅甸
     0x17E0, // 高棉
     0x1810, // 蒙古
     0xFF10, // 全角
  ]
}

///|
/// 码元 → 数字值（0–9）；不是数字则返回 `None`。
fn digit_value(unit : Int) -> Int? {
  for zero in digit_zeroes() {
    if unit >= zero && unit <= zero + 9 {
      return Some(unit - zero)
    }
  }
  None
}

///|
fn is_ascii_digit(unit : Int) -> Bool {
  unit >= 0x0030 && unit <= 0x0039
}

///|
fn unit_at(text : String, index : Int) -> Int {
  text[index].to_int()
}

///|
/// 双向控制符：排版隔离用，不属于"格式化结果"本身。
fn is_bidi_control(unit : Int) -> Bool {
  (unit >= 0x200E && unit <= 0x200F) ||
  (unit >= 0x202A && unit <= 0x202E) ||
  (unit >= 0x2066 && unit <= 0x2069) ||
  unit == 0x061C
}

///|
/// 分组与小数分隔符（含阿拉伯语 `٬` / `٫`、法语窄不换行空格、瑞士撇号）。
fn is_separator(unit : Int) -> Bool {
  match unit {
    0x002C
    | 0x002E
    | 0x0027
    | 0x2019
    | 0x066C
    | 0x066B
    | 0x00A0
    | 0x202F
    | 0x0020
    | 0xFF0C
    | 0xFF0E => true
    _ => false
  }
}

///|
fn is_space(unit : Int) -> Bool {
  unit == 0x0020 || unit == 0x00A0 || unit == 0x202F || unit == 0x2009
}

///|
/// 跳过"可忽略"的码元：按开关忽略双向控制符与分隔符。
fn skip_ignorable(
  text : String,
  start : Int,
  drop_bidi : Bool,
  drop_separators : Bool,
) -> Int {
  let mut index = start
  while index < text.length() {
    let unit = unit_at(text, index)
    if (drop_bidi && is_bidi_control(unit)) ||
      (drop_separators && is_separator(unit)) {
      index += 1
    } else {
      break
    }
  }
  index
}

///|
/// 在给定归一化策略下判断两串是否等价。
///
/// 用"边比较边归一化"而不是"先构造归一化字符串"：省一次分配，
/// 也让规则读起来就是它的定义。
fn equivalent(
  expected : String,
  actual : String,
  drop_bidi : Bool,
  separators : SeparatorMode,
  map_digits : Bool,
) -> Bool {
  let drop = separators is Drop
  let canonical = separators is Canonical
  let mut i = 0
  let mut j = 0
  while i < expected.length() && j < actual.length() {
    i = skip_ignorable(expected, i, drop_bidi, drop)
    j = skip_ignorable(actual, j, drop_bidi, drop)
    if i >= expected.length() || j >= actual.length() {
      break
    }
    let left = unit_at(expected, i)
    let right = unit_at(actual, j)
    if canonical && (is_separator(left) || is_separator(right)) {
      // 位置必须一致：一边是分隔符而另一边不是 → 不等价
      if !(is_separator(left) && is_separator(right)) {
        return false
      }
    } else if map_digits {
      match (digit_value(left), digit_value(right)) {
        (Some(a), Some(b)) => if a != b { return false }
        (None, None) => if left != right { return false }
        _ => return false
      }
    } else if left != right {
      return false
    }
    i += 1
    j += 1
  }
  skip_ignorable(expected, i, drop_bidi, drop) >= expected.length() &&
  skip_ignorable(actual, j, drop_bidi, drop) >= actual.length()
}

///|
/// 数字骨架：只保留数字（统一映射为 0–9），其余全部丢弃。
fn digit_skeleton(text : String) -> String {
  let out = StringBuilder()
  let mut index = 0
  while index < text.length() {
    match digit_value(unit_at(text, index)) {
      Some(value) => out.write_string(value.to_string())
      None => ()
    }
    index += 1
  }
  out.to_string()
}

///|
/// 是否含**非 ASCII 数字**（即实现用了另一套数字系统）。
///
/// 这个判据很关键：`1,234` ↔ `1.234` 只是分隔符的区域差异，不该算数字系统问题；
/// 只有真的出现了其它数字系统的字符，才归为 `DigitSystemMismatch`。
fn has_non_ascii_digit(text : String) -> Bool {
  let mut index = 0
  while index < text.length() {
    let unit = unit_at(text, index)
    if digit_value(unit) is Some(_) && !is_ascii_digit(unit) {
      return true
    }
    index += 1
  }
  false
}

///|
/// 是否含"文字性内容"（字母 / 汉字 / 货币符号等）。
///
/// 用于区分"同一个数字换了说法"（复数词形、紧凑缩写）与"数字本身不同"。
fn has_text_content(text : String) -> Bool {
  let mut index = 0
  while index < text.length() {
    let unit = unit_at(text, index)
    if digit_value(unit) is None &&
      !is_separator(unit) &&
      !is_bidi_control(unit) &&
      !is_space(unit) &&
      unit != 0x002B &&
      unit != 0x002D &&
      unit != 0x2212 {
      return true
    }
    index += 1
  }
  false
}

///|
/// 是否具有"分组"形状：某个分隔符后正好跟 3 个数字，且其后是串尾或另一个分隔符。
///
/// 用来区分"分组符差异"与"小数点差异"——`1,234` → `1234` 是丢分组，
/// `1.2` → `12` 是丢小数点，两者的修复方向完全不同。
fn looks_grouped(text : String) -> Bool {
  let mut index = 0
  while index < text.length() {
    if is_separator(unit_at(text, index)) {
      let mut digits = 0
      let mut cursor = index + 1
      while cursor < text.length() &&
            digit_value(unit_at(text, cursor)) is Some(_) {
        digits += 1
        cursor += 1
      }
      if digits == 3 &&
        (cursor >= text.length() || is_separator(unit_at(text, cursor))) {
        return true
      }
    }
    index += 1
  }
  false
}

///|
/// 是否像**未展开的模式**（`#,##0.00`、`{0}`）而不是格式化结果。
fn looks_like_pattern(text : String) -> Bool {
  let mut index = 0
  while index < text.length() {
    let unit = unit_at(text, index)
    if unit == 0x0023 || unit == 0x007B || unit == 0x007D {
      return true
    }
    index += 1
  }
  false
}

///|
/// `shorter` 是否是 `longer` 的前缀（空串不算）。
fn is_prefix_of(shorter : String, longer : String) -> Bool {
  if shorter.length() == 0 || shorter.length() > longer.length() {
    return false
  }
  let mut index = 0
  while index < shorter.length() {
    if shorter[index] != longer[index] {
      return false
    }
    index += 1
  }
  true
}

///|
/// 归因：判断这条失败**最可能**属于哪一类。
///
/// 规则按证据强度排序，且**保守优先**：只有能证明"只差这一类"时才给出具体类别，
/// 否则一律 `Other`。宁可说"不确定"，也不给上游一个错误结论（见 `DESIGN.md` D5）。
///
/// 调用前提：`expected != actual`（相等即 `Pass`，不应进入归因）。
pub fn attribute(
  context : AttributionContext,
  expected : String,
  actual : String,
) -> @conformance.FailReason {
  // 0) 兜底：相等串不该走到归因。若不拦，"忽略双向控制符后等价"会误判成
  //    BidiControlMissing。
  if expected == actual {
    return @conformance.FailReason::Other
  }
  // 1) 只差双向控制符
  if equivalent(expected, actual, true, Keep, false) {
    return @conformance.FailReason::BidiControlMissing
  }
  // 2) 只差数字系统：必须**真的出现**非 ASCII 数字，
  //    否则 `1,234` ↔ `1.234` 会被误判成数字系统问题。
  if (has_non_ascii_digit(expected) || has_non_ascii_digit(actual)) &&
    equivalent(expected, actual, true, Canonical, true) {
    return @conformance.FailReason::DigitSystemMismatch
  }
  // 3) 只差分隔符：再按形状区分"丢分组"与"丢小数点"
  if equivalent(expected, actual, true, Drop, true) {
    return if looks_grouped(expected) || looks_grouped(actual) {
      @conformance.FailReason::GroupingMismatch
    } else {
      @conformance.FailReason::RoundingMismatch
    }
  }
  // 4) 返回了未展开的模式。数字与日期套件里 pattern 是常态；
  //    MF2 的 `{|...|}` 是正常输出，故排除该套件。
  if context.suite != @conformance.Suite::MessageFormat2 &&
    looks_like_pattern(actual) {
    return @conformance.FailReason::PatternSyntaxUnsupported
  }
  let expected_digits = digit_skeleton(expected)
  let actual_digits = digit_skeleton(actual)
  // 5) 数字相同、文字不同 → 复数词形或紧凑缩写
  if expected_digits != "" &&
    expected_digits == actual_digits &&
    (has_text_content(expected) || has_text_content(actual)) {
    return if context.compact {
      @conformance.FailReason::CompactFormMismatch
    } else {
      @conformance.FailReason::PluralCategoryMismatch
    }
  }
  let prefix_related = is_prefix_of(expected_digits, actual_digits) ||
    is_prefix_of(actual_digits, expected_digits)
  // 6) 紧凑格式用例：数字骨架互为前缀（1.2K vs 1200）
  if context.compact && prefix_related {
    return @conformance.FailReason::CompactFormMismatch
  }
  // 7) 纯数字且互为前缀 → 精度 / 舍入
  if !has_text_content(expected) && !has_text_content(actual) && prefix_related {
    return @conformance.FailReason::RoundingMismatch
  }
  @conformance.FailReason::Other
}
