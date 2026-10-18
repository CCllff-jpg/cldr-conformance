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
  compact~ : Bool = false,
) -> AttributionContext {
  { suite, compact, }
}

///|
/// 分隔符的处理方式。
priv enum SeparatorMode {
  /// 分隔符必须逐字符相同。
  Keep
  /// 直接忽略分隔符（用于判断"是否只差分隔符"）。
  Drop
}

///|
/// Unicode 十进制数字块的起始码位（覆盖 CLDR 数据里会出现的数字系统）。
fn digit_zeroes() -> Array[Int32] {
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
fn digit_value(unit : Int32) -> Int32? {
  for zero in digit_zeroes() {
    if unit >= zero && unit <= zero + 9 {
      return Some(unit - zero)
    }
  }
  None
}

///|
fn is_ascii_digit(unit : Int32) -> Bool {
  unit >= 0x0030 && unit <= 0x0039
}

///|
fn unit_at(text : String, index : Int32) -> Int32 {
  text[index].to_int()
}

///|
/// 双向控制符：排版隔离用，不属于"格式化结果"本身。
fn is_bidi_control(unit : Int32) -> Bool {
  (unit >= 0x200E && unit <= 0x200F) ||
  (unit >= 0x202A && unit <= 0x202E) ||
  (unit >= 0x2066 && unit <= 0x2069) ||
  unit == 0x061C
}

///|
/// 分组与小数分隔符（含阿拉伯语 `٬` / `٫`、法语窄不换行空格、瑞士撇号）。
fn is_separator(unit : Int32) -> Bool {
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
/// 是否像"精度/舍入"差异：数字值层面接近，只是末位精度或进位不同。
///
/// 判据（都不做浮点或大整数运算，避免溢出）：
/// 1. 一方是另一方的前缀（`1.23` ↔ `1.2`）；
/// 2. 或：去掉末位后前缀一致，且末位只差 1（舍入进位：
///    `0.831765` → `0.832` 的第四位由 `1` 进成 `2`）。
///
/// 只差得"很小"才算精度问题——`1,234` ↔ `9,999` 不会被误判。
fn looks_like_precision(expected : String, actual : String) -> Bool {
  let left = digit_skeleton(expected)
  let right = digit_skeleton(actual)
  if left == right || left.length() == 0 || right.length() == 0 {
    return false
  }
  if is_prefix_of(left, right) || is_prefix_of(right, left) {
    return true
  }
  let limit = if left.length() < right.length() {
    left.length()
  } else {
    right.length()
  }
  if limit < 2 {
    return false
  }
  let mut index = 0
  while index + 1 < limit {
    if unit_at(left, index) != unit_at(right, index) {
      return false
    }
    index += 1
  }
  match
    (
      digit_value(unit_at(left, limit - 1)),
      digit_value(unit_at(right, limit - 1)),
    ) {
    (Some(a), Some(b)) => if a >= b { a - b <= 1 } else { b - a <= 1 }
    _ => false
  }
}

///|
/// 跳过"可忽略"的码元：按开关忽略双向控制符与分隔符。
fn skip_ignorable(
  text : String,
  start : Int32,
  drop_bidi : Bool,
  drop_separators : Bool,
) -> Int32 {
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
    if map_digits {
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
/// 形状串：数字 → `d`，分隔符 → `s`，双向控制符忽略，其余原样。
///
/// 用来区分"差异是结构性的（分隔符位置/文字不同）"还是"仅字符字形不同"。
fn shape_of(text : String) -> String {
  let out = StringBuilder()
  let mut index = 0
  while index < text.length() {
    let unit = unit_at(text, index)
    if is_bidi_control(unit) {
      ()
    } else if digit_value(unit) is Some(_) {
      out.write_string("d")
    } else if is_separator(unit) {
      out.write_string("s")
    } else {
      out.write_substring(text, index, 1)
    }
    index += 1
  }
  out.to_string()
}

///|
/// 分隔符字符序列（忽略双向控制符）。用来判断"分隔符字形是否被换过"。
fn separator_glyphs(text : String) -> String {
  let out = StringBuilder()
  let mut index = 0
  while index < text.length() {
    let unit = unit_at(text, index)
    if is_separator(unit) && !is_bidi_control(unit) {
      out.write_substring(text, index, 1)
    }
    index += 1
  }
  out.to_string()
}

///|
/// 提取数字的**字形**序列（码元本身，忽略分隔符）。
fn digit_glyphs(text : String) -> Array[Int32] {
  let glyphs : Array[Int32] = []
  let mut index = 0
  while index < text.length() {
    let unit = unit_at(text, index)
    if digit_value(unit) is Some(_) {
      glyphs.push(unit)
    }
    index += 1
  }
  glyphs
}

///|
/// 两侧的数字**字形**是否真的不同。
///
/// 这是数字系统归因的判据：`1,234` ↔ `١,٢٣٤` 是（换了数字系统），
/// 而 `১২,৩৪` ↔ `১২.৩৪` 不是（数字一字未变，只是分隔符换了字符）。
/// 若只用"出现了非 ASCII 数字"当判据，后者会被误判成数字系统问题。
fn digit_glyphs_differ(expected : String, actual : String) -> Bool {
  let left = digit_glyphs(expected)
  let right = digit_glyphs(actual)
  if left.length() != right.length() {
    return false
  }
  let mut index = 0
  while index < left.length() {
    if left[index] != right[index] {
      return true
    }
    index += 1
  }
  false
}

///|
/// 分隔符的角色：`true` = 分组符，`false` = 小数点。
///
/// 其后还有内容（另一个分隔符或更多数字）→ 只能是分组符；
/// 其后直到串尾是 3 位数字 → 按分组符处理（CLDR 里整数用分组）；
/// 其后直到串尾是 1–2 位数字 → 小数点。
fn is_grouping_role(text : String, index : Int32) -> Bool {
  let mut digits = 0
  let mut cursor = index + 1
  while cursor < text.length() && digit_value(unit_at(text, cursor)) is Some(_) {
    digits += 1
    cursor += 1
  }
  if cursor < text.length() {
    return true
  }
  digits == 3
}

///|
/// 在"只差分隔符"的失败里，判断差异出在分组符还是小数点。
///
/// 依据**首个差异位置**上的分隔符角色，而不是整串的形状：
/// `-1 230,05` → `-1 23005` 里被删掉的是小数点，尽管这串里也有分组符。
fn separator_diff_is_grouping(expected : String, actual : String) -> Bool {
  // 定位**忽略双向控制符后**的首个差异：否则 U+200E 之类会把差异位置顶偏。
  let mut i = 0
  let mut j = 0
  while i < expected.length() && j < actual.length() {
    i = skip_ignorable(expected, i, true, false)
    j = skip_ignorable(actual, j, true, false)
    if i >= expected.length() || j >= actual.length() {
      break
    }
    if expected[i] != actual[j] {
      break
    }
    i += 1
    j += 1
  }
  if i < expected.length() && is_separator(unit_at(expected, i)) {
    return is_grouping_role(expected, i)
  }
  if j < actual.length() && is_separator(unit_at(actual, j)) {
    return is_grouping_role(actual, j)
  }
  looks_grouped(expected) || looks_grouped(actual)
}

///|
/// 字母区块里的**标点/符号**（这些不是"文字内容"）。
///
/// 典型坑：阿拉伯语百分号 `٪`(U+066A) 落在阿拉伯字母区块内，
/// 若按区块范围一概当作字母，`٠٫٨٣١٧٦٥٪؜` 这种纯数值串会被判成"含文字"，
/// 从而丢掉本该命中的精度归因（实测踩过）。
fn is_script_punctuation(unit : Int32) -> Bool {
  match unit {
    0x060C
    | 0x061B
    | 0x061F
    | 0x066A
    | 0x066B
    | 0x066C
    | 0x066D
    | 0x06D4
    | 0x00D7
    | 0x00F7 => true
    _ => false
  }
}

///|
/// 是否"像字母"：ASCII 字母，或基本多文种平面里常见的字母区块。
///
/// 刻意**排除标点与符号**：`{|42|}` 的括号、阿拉伯语百分号 `٪` 都不属于"文字内容"，
/// 否则会把"语法/数值差异"误判成复数词形差异（踩过这个坑）。
fn is_letterish(unit : Int32) -> Bool {
  if is_ascii_letter(unit) {
    return true
  }
  // 拉丁扩展 / 希腊 / 西里尔
  if unit >= 0x00C0 && unit <= 0x052F {
    return !is_script_punctuation(unit)
  }
  // 希伯来 / 阿拉伯 / 天城文 / 孟加拉 / 泰 / 藏 / 缅甸 / 高棉 / 蒙古 …
  if unit >= 0x0590 && unit <= 0x1CFF {
    return !is_script_punctuation(unit) &&
      digit_value(unit) is None &&
      !is_separator(unit)
  }
  // 假名 / CJK 部首 / CJK 统一表意 / 谚文
  (unit >= 0x3040 && unit <= 0x30FF) ||
  (unit >= 0x2E80 && unit <= 0x9FFF) ||
  (unit >= 0xAC00 && unit <= 0xD7AF)
}

///|
/// 是否含字母性内容（用于判断"同一个数字换了说法"：复数词形、紧凑缩写）。
fn has_letter_content(text : String) -> Bool {
  let mut index = 0
  while index < text.length() {
    if is_letterish(unit_at(text, index)) {
      return true
    }
    index += 1
  }
  false
}

///|
/// 是否"数值形态"：含数字、且**不含字母**。
///
/// 允许前后缀（`%`、`+`/`-`、空格、双向控制符）——百分比用例就是 `0.83%` 这种形态；
/// 若把 `%` 判成"非数值"，本该归为精度差异的用例会掉进 `other`（实测踩过）。
fn is_numeric_like(text : String) -> Bool {
  digit_skeleton(text) != "" && !has_letter_content(text)
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
/// 是否含 LDML 的数字占位符 `#`（模式语法里最明确的标记）。
fn has_hash(text : String) -> Bool {
  let mut index = 0
  while index < text.length() {
    if unit_at(text, index) == 0x0023 {
      return true
    }
    index += 1
  }
  false
}

///|
/// 是否含花括号（模式占位符 `{0}`，或 MF2 的标记/fallback 语法）。
fn has_brace(text : String) -> Bool {
  let mut index = 0
  while index < text.length() {
    let unit = unit_at(text, index)
    if unit == 0x007B || unit == 0x007D {
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
/// 归因（完整版）：**独立**检验每个维度是否构成差异，可能给出多个原因。
///
/// 与"首个匹配即返回"相比，这里回答的是"**哪些**维度不同"，
/// 因此能表达复合失败（例如同时用错数字系统、又丢了小数点）——
/// 真实实现经常一次错好几处，只报一个原因会误导修复方向。
///
/// 返回顺序即优先级（第一个是主因）；无法证明任何具体维度时返回 `[Other]`。
/// 调用前提：`expected != actual`（相等即 `Pass`，不应进入归因）。
pub fn attribute_all(
  context : AttributionContext,
  expected : String,
  actual : String,
) -> Array[@conformance.FailReason] {
  let reasons : Array[@conformance.FailReason] = []
  // 兜底：相等串不该走到归因。若不拦，"忽略双向控制符后等价"会误判成
  // BidiControlMissing。
  if expected == actual {
    return [@conformance.FailReason::Other]
  }
  // 双向控制符是**唯一**差异
  if equivalent(expected, actual, true, Keep, false) {
    reasons.push(@conformance.FailReason::BidiControlMissing)
  }
  // 未展开的模式：实际输出出现了模式语法，而期望值里**没有**。
  //
  // 优先级排在维度分析**之前**：返回模式原文是很强的证据，应当作为主因，
  // 否则在非 ASCII 数字区域（如 `۰`）会被"数字字形不同"抢走主因。
  //
  // 判据按标记分别比较，而不是"含任一种模式字符"：
  //  - `#` 是 LDML 数字占位符，出现即说明返回了模式原文；
  //  - `{`/`}` 在 MF2 里是正常语法（`{|...|}` 是 CLDR 的期望输出），
  //    因此只有"实际有、期望没有"时才算未展开。
  if (has_hash(actual) && !has_hash(expected)) ||
    (has_brace(actual) && !has_brace(expected)) {
    reasons.push(@conformance.FailReason::PatternSyntaxUnsupported)
  }
  // 数字系统：数字**值序列相同**但**字形不同**
  if digit_glyphs_differ(expected, actual) &&
    digit_skeleton(expected) == digit_skeleton(actual) {
    reasons.push(@conformance.FailReason::DigitSystemMismatch)
  }
  // 分隔符差异：
  //  - 形状相同 → 只是分隔符**字形**被换了区域字符
  //  - 形状不同但忽略分隔符后相等 → 分隔符的**存在性**不同，
  //    再按首个差异位置判断是丢分组还是丢小数点
  if shape_of(expected) == shape_of(actual) {
    if separator_glyphs(expected) != separator_glyphs(actual) {
      reasons.push(@conformance.FailReason::GroupingMismatch)
    }
  } else if equivalent(expected, actual, true, Drop, true) {
    if separator_diff_is_grouping(expected, actual) {
      reasons.push(@conformance.FailReason::GroupingMismatch)
    } else {
      reasons.push(@conformance.FailReason::RoundingMismatch)
    }
  }
  let expected_digits = digit_skeleton(expected)
  let actual_digits = digit_skeleton(actual)
  let prefix_related = is_prefix_of(expected_digits, actual_digits) ||
    is_prefix_of(actual_digits, expected_digits)
  // 数字相同、文字不同 → 复数词形或紧凑缩写
  if expected_digits != "" &&
    expected_digits == actual_digits &&
    (has_letter_content(expected) || has_letter_content(actual)) {
    reasons.push(
      if context.compact {
        @conformance.FailReason::CompactFormMismatch
      } else {
        @conformance.FailReason::PluralCategoryMismatch
      },
    )
  }
  // 紧凑格式：骨架互为前缀（1.2K vs 1200）
  if context.compact &&
    prefix_related &&
    !reasons.contains(@conformance.FailReason::CompactFormMismatch) {
    reasons.push(@conformance.FailReason::CompactFormMismatch)
  }
  // 数值层面接近（精度不同，或末位因舍入进位而不同）→ 精度 / 舍入
  //
  // 要求骨架**确实不同**：`1,234` ↔ `1234` 的骨架相同，
  // 差异根本不在数字上，不该再加一条"舍入"。
  if is_numeric_like(expected) &&
    is_numeric_like(actual) &&
    expected_digits != actual_digits &&
    (prefix_related || looks_like_precision(expected, actual)) &&
    !reasons.contains(@conformance.FailReason::RoundingMismatch) {
    reasons.push(@conformance.FailReason::RoundingMismatch)
  }
  // 数值本身不同（既不是精度问题，也不是格式问题）→ 实现**算错了**
  //
  // 典型：百分比计算溢出（`1234565.0` 的 123,456,500% 变成 -1,097,551.584%）。
  // 与格式类差异分开报告，因为修复方向完全不同。
  if is_numeric_like(expected) &&
    is_numeric_like(actual) &&
    expected_digits != actual_digits &&
    !prefix_related &&
    !looks_like_precision(expected, actual) &&
    !reasons.contains(@conformance.FailReason::RoundingMismatch) {
    reasons.push(@conformance.FailReason::ValueMismatch)
  }
  if reasons.length() == 0 {
    reasons.push(@conformance.FailReason::Other)
  }
  reasons
}

///|
/// 归因（主因）：`attribute_all` 的第一项。
///
/// 报告里的"原因分布"按主因统计；需要看复合原因时用 `attribute_all`
/// （例如同一条用例同时有数字系统与分隔符问题）。
pub fn attribute(
  context : AttributionContext,
  expected : String,
  actual : String,
) -> @conformance.FailReason {
  attribute_all(context, expected, actual)[0]
}
