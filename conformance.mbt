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
  /// **数值本身**不同（不是格式层面）：例如百分比计算溢出、符号反了、量级错。
  /// 与"格式差异"分开，是因为修复方向完全不同——这是**算错了**，不是**排版错了**。
  ValueMismatch
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
  /// 被测实现抛出异常。与 `Fail` 分开记录：**抛异常与答错是两类不同的缺陷**。
  Errored(detail~ : String)
  Unsupported(feature~ : String)
  NotInstalled
} derive(Debug, Eq)

///|
/// 适配器可声明的能力。
///
/// 粒度按"**一个库可能只做其中一部分**"来切：
/// - 日期骨架查询与日期格式化分开声明；
/// - 数字套件内部再分 `Decimal`（普通/百分比）、`DecimalScientific`、`DecimalCompact`。
///
/// 这样"没有这个能力"会记为 `unsupported`（不进一致率分母），
/// 而不是被算成"做错了"——见 `可比性映射.md` 的实测依据
/// （例如 `zlhahaha/moonlocale` 没有 scientific 与 compact 数字 API）。
pub(all) enum AdapterCapability {
  Decimal
  DecimalScientific
  DecimalCompact
  DatetimeSkeleton
  DatetimeFormat
  MessageFormat2
} derive(Debug, Eq)

///|
/// 所有可声明的能力，顺序稳定。
pub fn AdapterCapability::all() -> Array[AdapterCapability] {
  [
    Decimal,
    DecimalScientific,
    DecimalCompact,
    DatetimeSkeleton,
    DatetimeFormat,
    MessageFormat2,
  ]
}

///|
/// 能力在 CLI 和报告中的稳定标识。
pub fn AdapterCapability::label(self : AdapterCapability) -> String {
  match self {
    Decimal => "decimal"
    DecimalScientific => "decimal-scientific"
    DecimalCompact => "decimal-compact"
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

///|
/// 结果的稳定标签（报告与 CLI 共用）。
pub fn CaseOutcome::label(self : CaseOutcome) -> String {
  match self {
    Pass => "pass"
    Fail(_) => "fail"
    Errored(_) => "errored"
    Unsupported(_) => "unsupported"
    NotInstalled => "not-installed"
  }
}

///|
/// 是否属于**真正的一致性失败**（答错或抛异常）。
/// `unsupported` 与 `not-installed` 不算失败——没有能力不等于做错了（见 `DESIGN.md` D3）。
pub fn CaseOutcome::is_failure(self : CaseOutcome) -> Bool {
  match self {
    Fail(_) => true
    Errored(_) => true
    _ => false
  }
}

///|
/// 失败原因的稳定标识；不是 `Fail` 时返回 `None`。
pub fn CaseOutcome::reason_label(self : CaseOutcome) -> String? {
  match self {
    Fail(reason~, ..) => Some(reason.label())
    _ => None
  }
}

///|
/// 单条用例在某个适配器上的执行结果，是报告的最小单元。
pub(all) struct CaseResult {
  suite : Suite
  /// 适配器的稳定 ID（不是展示名）。
  adapter_id : String
  /// 数据来源文件，例如 `decimals.tsv`、`syntax.json`。
  source : String
  /// 在来源中的位置，例如 `L87`、`#12`。
  location : String
  outcome : CaseOutcome
  /// 单用例耗时（毫秒）。
  elapsed_ms : Int32
} derive(Debug, Eq)

///|
/// 一次运行的计数汇总。
pub(all) struct RunSummary {
  total : Int32
  passed : Int32
  failed : Int32
  unsupported : Int32
  not_installed : Int32
  errored : Int32
} derive(Debug, Eq)

///|
pub fn RunSummary::empty() -> RunSummary {
  {
    total: 0,
    passed: 0,
    failed: 0,
    unsupported: 0,
    not_installed: 0,
    errored: 0,
  }
}

///|
/// 统计一批结果。
pub fn RunSummary::from_results(results : Array[CaseResult]) -> RunSummary {
  let mut total = 0
  let mut passed = 0
  let mut failed = 0
  let mut unsupported = 0
  let mut not_installed = 0
  let mut errored = 0
  for result in results {
    total += 1
    match result.outcome {
      Pass => passed += 1
      Fail(_) => failed += 1
      Errored(_) => errored += 1
      Unsupported(_) => unsupported += 1
      NotInstalled => not_installed += 1
    }
  }
  { total, passed, failed, unsupported, not_installed, errored, }
}

///|
/// 真正的一致性失败数 = 答错 + 抛异常。
pub fn RunSummary::failures(self : RunSummary) -> Int32 {
  self.failed + self.errored
}

///|
/// 是否没有任何一致性失败。
pub fn RunSummary::is_clean(self : RunSummary) -> Bool {
  self.failures() == 0
}

///|
/// 不参与一致性统计的用例数（无能力 + 未选入）。
pub fn RunSummary::excluded(self : RunSummary) -> Int32 {
  self.unsupported + self.not_installed
}

///|
/// 一致率 = pass /（总数 − unsupported − not-installed）。
///
/// 分母排除"没这个能力"与"未安装"：它们不是失败，也不该把一致率算低
/// （见 `DESIGN.md` D3）。评审看的就是这个数字。
pub fn RunSummary::pass_rate(self : RunSummary) -> Double {
  let judged = self.total - self.unsupported - self.not_installed
  if judged <= 0 {
    0.0
  } else {
    self.passed.to_double() / judged.to_double()
  }
}

///|
/// 一致率的展示形式（截断到整数百分比）。
pub fn RunSummary::pass_rate_text(self : RunSummary) -> String {
  "\{(self.pass_rate() * 100.0).to_int()}%"
}

///|
/// 一行文本，供 CLI 与日志展示。
pub fn RunSummary::render(self : RunSummary) -> String {
  "共 \{self.total} · pass \{self.passed} · fail \{self.failed} · errored \{self.errored} · unsupported \{self.unsupported} · not-installed \{self.not_installed}"
}

///|
/// 日期用例 → 适配器输入。**不含期望值与来源信息**，适配器在类型上就拿不到答案
/// （见 `DESIGN.md` D1「只做裁判，不做选手」）。
pub fn DatetimeCase::format_input(self : DatetimeCase) -> DatetimeFormatInput {
  {
    locale: self.locale,
    calendar: self.calendar,
    input: self.input,
    semantic_skeleton: self.semantic_skeleton,
    classical_skeleton: self.classical_skeleton,
    semantic_skeleton_length: self.semantic_skeleton_length,
    zone_style: self.zone_style,
    time_length: self.time_length,
    date_length: self.date_length,
    hour_cycle: self.hour_cycle,
    year_style: self.year_style,
    date_time_format_type: self.date_time_format_type,
  }
}

///|
/// MF2 用例 → 适配器输入。**不含期望输出与期望错误**。
pub fn MessageCase::format_input(self : MessageCase) -> MessageFormat2Input {
  {
    locale: self.locale,
    source: self.src,
    bidi_isolation: self.bidi_isolation,
    tags: self.tags,
    params_json: self.params_json,
  }
}
