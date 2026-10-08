///|
/// 一致性套件。每个套件对应 CLDR 官方测试数据中的一类（见 `DATA-SOURCES.md`）。
pub(all) enum Suite {
  Decimal
  Datetime
  MessageFormat2
} derive(Debug, Eq)

///|
/// 数字格式化样式，对应 `decimals.tsv` 的 `number_format` 列。
pub(all) enum NumberStyle {
  DecimalStyle
  PercentStyle
  ScientificStyle
  CurrencyStyle
} derive(Debug, Eq)

///|
/// 紧凑格式长度，对应 `decimals.tsv` 的 `format_length` 列（空值记为 `Standard`）。
pub(all) enum NumberLength {
  Standard
  Short
  Long
} derive(Debug, Eq)

///|
/// 失败归因分类。
///
/// 这是本项目相对「简单字符串 diff」的核心增量：报告要给出可行动的结论，
/// 而不是只丢一句 expected != actual（见 `DESIGN.md`）。
pub(all) enum FailReason {
  GroupingMismatch
  DigitSystemMismatch
  RoundingMismatch
  PluralCategoryMismatch
  BidiControlMissing
  CompactFormMismatch
  PatternSyntaxUnsupported
  Other
} derive(Debug, Eq)

///|
/// 单条用例的执行结果。
///
/// `Unsupported` 与 `Fail` 严格区分：被测实现没有该能力不算失败，
/// 单独统计，避免用缺失能力拉低一致率。
pub(all) enum CaseOutcome {
  Pass
  Fail(reason~ : FailReason, expected~ : String, actual~ : String)
  Unsupported(feature~ : String)
  NotInstalled
} derive(Debug, Eq)

///|
/// 被测实现需要实现的适配接口。
///
/// `value` 用 `String` 而非数值类型传入：生态内各 i18n 包的数值类型并不统一
/// （core 有 `Int`/`BigInt`/`Double`，但没有统一的十进制类型），
/// 用字符串是同时适配所有实现的唯一可行方案（取舍记录见 `DESIGN.md`）。
pub(open) trait FormatUnderTest {
  fn name(Self) -> String
  fn format_number(
    Self,
    locale : String,
    value : String,
    style~ : NumberStyle,
    length~ : NumberLength,
  ) -> String raise
}

///|
/// 全部套件，顺序即报告中的展示顺序。
pub fn Suite::all() -> Array[Suite] {
  [Decimal, Datetime, MessageFormat2]
}

///|
/// 套件在 CLI 与报告中的稳定标识（不要随展示文案改动）。
pub fn Suite::label(self : Suite) -> String {
  match self {
    Decimal => "decimal"
    Datetime => "datetime"
    MessageFormat2 => "message-format-2"
  }
}
