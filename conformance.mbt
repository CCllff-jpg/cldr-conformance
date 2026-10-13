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
/// 适配器可声明的能力。日期骨架查询和日期格式化分别声明，
/// 以便只支持其中一项的实现可以如实返回 `Unsupported`。
pub(all) enum AdapterCapability {
  Decimal
  DatetimeSkeleton
  DatetimeFormat
  MessageFormat2
} derive(Debug, Eq)

///|
/// 所有可声明的能力，顺序稳定。
pub fn AdapterCapability::all() -> Array[AdapterCapability] {
  [Decimal, DatetimeSkeleton, DatetimeFormat, MessageFormat2]
}

///|
/// 能力在 CLI 和报告中的稳定标识。
pub fn AdapterCapability::label(self : AdapterCapability) -> String {
  match self {
    Decimal => "decimal"
    DatetimeSkeleton => "datetime-skeleton"
    DatetimeFormat => "datetime-format"
    MessageFormat2 => "message-format-2"
  }
}

///|
/// 适配器声明的一组能力。构造时按首次出现顺序去重。
pub struct AdapterCapabilities {
  capabilities : Array[AdapterCapability]
} derive(Debug, Eq)

///|
pub fn AdapterCapabilities::new(
  capabilities : Array[AdapterCapability],
) -> AdapterCapabilities {
  let unique : Array[AdapterCapability] = []
  for capability in capabilities {
    if !unique.contains(capability) {
      unique.push(capability)
    }
  }
  { capabilities: unique, }
}

///|
pub fn AdapterCapabilities::all() -> AdapterCapabilities {
  AdapterCapabilities::new(AdapterCapability::all())
}

///|
pub fn AdapterCapabilities::contains(
  self : AdapterCapabilities,
  capability : AdapterCapability,
) -> Bool {
  self.capabilities.contains(capability)
}

///|
/// 日期格式化的输入参数，不包含 CLDR 的期望结果和来源行号。
pub(all) struct DatetimeFormatInput {
  locale : String
  calendar : String
  input : String
  semantic_skeleton : String?
  classical_skeleton : String?
  semantic_skeleton_length : String?
  zone_style : String?
  time_length : String?
  date_length : String?
  hour_cycle : String?
  year_style : String?
  date_time_format_type : String?
} derive(Debug, Eq)

///|
/// MF2 格式化的输入参数，不包含 CLDR 的期望输出或期望错误。
pub(all) struct MessageFormat2Input {
  locale : String
  source : String
  bidi_isolation : String?
  tags : Array[String]
  params_json : String?
} derive(Debug, Eq)

///|
/// MF2 适配器的实际结果。错误按 CLDR 测试数据中的类别返回。
pub(all) enum MessageFormat2Result {
  Formatted(String)
  Errors(Array[String])
} derive(Debug, Eq)

///|
/// 数字格式化适配器。
///
/// `value` 用 `String` 而非数值类型传入：生态内各 i18n 包的数值类型并不统一，
/// 用字符串可以避免浮点转换引入额外舍入误差（见 `DESIGN.md` D2）。
pub(open) trait NumberAdapter {
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
/// 日期格式化适配器。
pub(open) trait DatetimeAdapter {
  fn name(Self) -> String
  fn format_skeleton(
    Self,
    locale : String,
    calendar : String,
    skeleton : String,
  ) -> String raise
  fn format_datetime(Self, input : DatetimeFormatInput) -> String raise
}

///|
/// MessageFormat 2 适配器。
pub(open) trait MessageFormat2Adapter {
  fn name(Self) -> String
  fn format_message(Self, input : MessageFormat2Input) -> MessageFormat2Result raise
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
