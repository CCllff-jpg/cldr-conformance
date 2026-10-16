///|
fn decimal_context() -> AttributionContext {
  AttributionContext::new(@conformance.Suite::Decimal)
}

///|
fn compact_context() -> AttributionContext {
  AttributionContext::new(@conformance.Suite::Decimal, compact=true)
}

///|
fn message_context() -> AttributionContext {
  AttributionContext::new(@conformance.Suite::MessageFormat2)
}

///|
/// 规则 0 的兜底：相等串不归因（否则会误判成"缺双向控制符"）。
test "相等串不归因（防误用兜底）" {
  assert_eq(
    attribute(decimal_context(), "1", "1"),
    @conformance.FailReason::Other,
  )
}

///|
test "规则 1：只差双向控制符 → BidiControlMissing" {
  assert_eq(
    attribute(decimal_context(), "1234", "\u{200E}1234"),
    @conformance.FailReason::BidiControlMissing,
  )
  assert_eq(
    attribute(decimal_context(), "1\u{200F}234", "1234"),
    @conformance.FailReason::BidiControlMissing,
  )
  assert_eq(
    attribute(decimal_context(), "\u{061C}1234", "1234\u{2069}"),
    @conformance.FailReason::BidiControlMissing,
  )
}

///|
test "规则 2：只差数字系统 → DigitSystemMismatch" {
  // 阿拉伯-印度数字
  assert_eq(
    attribute(decimal_context(), "1234", "١٢٣٤"),
    @conformance.FailReason::DigitSystemMismatch,
  )
  // 天城文数字
  assert_eq(
    attribute(decimal_context(), "12", "१२"),
    @conformance.FailReason::DigitSystemMismatch,
  )
  // 全角数字
  assert_eq(
    attribute(decimal_context(), "12", "１２"),
    @conformance.FailReason::DigitSystemMismatch,
  )
}

///|
test "规则 3：只差分组/小数分隔符 → GroupingMismatch" {
  assert_eq(
    attribute(decimal_context(), "1,234", "1234"),
    @conformance.FailReason::GroupingMismatch,
  )
  // 德语式分组（点作分组符）+ 阿拉伯语分隔符
  assert_eq(
    attribute(decimal_context(), "1.234", "1234"),
    @conformance.FailReason::GroupingMismatch,
  )
  assert_eq(
    attribute(decimal_context(), "1٬234", "1,234"),
    @conformance.FailReason::GroupingMismatch,
  )
  // 法语窄不换行空格作分组符
  assert_eq(
    attribute(decimal_context(), "1\u{202F}234", "1234"),
    @conformance.FailReason::GroupingMismatch,
  )
}

///|
test "规则 4：返回未展开的模式 → PatternSyntaxUnsupported" {
  assert_eq(
    attribute(decimal_context(), "1,234.00", "#,##0.00"),
    @conformance.FailReason::PatternSyntaxUnsupported,
  )
  assert_eq(
    attribute(decimal_context(), "2026-10-15", "{0}-{1}-{2}"),
    @conformance.FailReason::PatternSyntaxUnsupported,
  )
  // MF2 里输出 `{|...|}`（fallback 语法）同样是返回了未处理的语法
  assert_eq(
    attribute(message_context(), "abc", "{|x|}"),
    @conformance.FailReason::PatternSyntaxUnsupported,
  )
}

///|
/// 反向保护：**期望值本身**含模式语法时（MF2 的 `{|...|}` 是 CLDR 的正常期望输出），
/// 不能把实现的普通输出判成"未展开模式"。
test "期望值本身含模式语法时不归为未展开模式" {
  assert_eq(
    attribute(message_context(), "{|42|}", "42"),
    @conformance.FailReason::Other,
  )
  assert_eq(
    attribute(message_context(), "{#tag u:id=x}content", "content"),
    @conformance.FailReason::Other,
  )
}

///|
test "规则 5：数字相同、文字不同 → 复数词形 / 紧凑缩写" {
  assert_eq(
    attribute(message_context(), "1 message", "1 messages"),
    @conformance.FailReason::PluralCategoryMismatch,
  )
  // 紧凑格式用例走紧凑分类
  assert_eq(
    attribute(compact_context(), "1.2 thousand", "1.2K"),
    @conformance.FailReason::CompactFormMismatch,
  )
}

///|
test "规则 6：紧凑格式的数字骨架互为前缀 → CompactFormMismatch" {
  assert_eq(
    attribute(compact_context(), "1.2K", "1200"),
    @conformance.FailReason::CompactFormMismatch,
  )
}

///|
test "规则 7：纯数字且互为前缀 → RoundingMismatch" {
  assert_eq(
    attribute(decimal_context(), "1.23", "1.2"),
    @conformance.FailReason::RoundingMismatch,
  )
  // 小数点丢失（数值相同、呈现不同）
  assert_eq(
    attribute(decimal_context(), "1.2", "12"),
    @conformance.FailReason::RoundingMismatch,
  )
}

///|
test "保守兜底：无法证明只差某一类时一律 Other" {
  // 完全不同
  assert_eq(
    attribute(decimal_context(), "abc", "xyz"),
    @conformance.FailReason::Other,
  )
  // 数字不同且不成前缀
  assert_eq(
    attribute(decimal_context(), "1,234", "9,999"),
    @conformance.FailReason::Other,
  )
  // 空输出（不做猜测：可能是没实现，也可能是别的问题）
  assert_eq(
    attribute(decimal_context(), "1,234", ""),
    @conformance.FailReason::Other,
  )
  // 紧凑格式但数字毫无关系
  assert_eq(
    attribute(compact_context(), "1.2K", "9M"),
    @conformance.FailReason::Other,
  )
}

///|
/// 归因必须能区分"只差分隔符"与"只差数字系统"——两者的修复方向完全不同。
test "归因的优先级：分隔符与数字系统不会互相误判" {
  assert_eq(
    attribute(decimal_context(), "1,234", "1.234"),
    @conformance.FailReason::GroupingMismatch,
  )
  assert_eq(
    attribute(decimal_context(), "١٬٢٣٤", "1,234"),
    @conformance.FailReason::DigitSystemMismatch,
  )
}
