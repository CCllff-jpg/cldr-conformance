// 测试用假适配器：只验证引擎行为，不实现任何格式化逻辑。

///|
pub(all) struct ThrowingAdapter {
  label : String
} derive(Debug, Eq)

///|
pub(all) suberror EngineTestError {
  Boom(detail~ : String)
} derive(Debug)

///|
pub impl @conformance.NumberAdapter for ThrowingAdapter with fn name(self) {
  self.label
}

///|
pub impl @conformance.NumberAdapter for ThrowingAdapter with fn format_number(
  self,
  locale,
  value,
  style~,
  length~,
) {
  ignore(self)
  ignore(locale)
  ignore(value)
  ignore(style)
  ignore(length)
  raise EngineTestError::Boom(detail="故意抛异常")
}

///|
pub extend ThrowingAdapter with @conformance.NumberAdapter::{
  name,
  format_number,
}

///|
pub extend ThrowingAdapter with @debug.Debug::{to_repr}

///|
pub extend ThrowingAdapter with Eq::{equal, not_equal}

///|
pub extend EngineTestError with @debug.Debug::{to_repr}

///|
/// 按脚本返回固定 MF2 结果的假适配器。
pub(all) struct ScriptedMessageAdapter {
  result : @conformance.MessageFormat2Result
} derive(Debug, Eq)

///|
pub impl @conformance.MessageFormat2Adapter for ScriptedMessageAdapter with fn name(
  self,
) {
  ignore(self)
  "scripted"
}

///|
pub impl @conformance.MessageFormat2Adapter for ScriptedMessageAdapter with fn format_message(
  self,
  input,
) {
  ignore(input)
  self.result
}

///|
pub extend ScriptedMessageAdapter with @conformance.MessageFormat2Adapter::{
  name,
  format_message,
}

///|
pub extend ScriptedMessageAdapter with @debug.Debug::{to_repr}

///|
pub extend ScriptedMessageAdapter with Eq::{equal, not_equal}

///|
fn decimal_case(
  locale : String,
  input : String,
  expected : String,
) -> @conformance.DecimalCase {
  {
    locale,
    style: @conformance.NumberStyle::DecimalStyle,
    length: @conformance.NumberLength::Standard,
    input,
    expected,
    line: 2,
  }
}

///|
fn skeleton_case(
  locale : String,
  skeleton : String,
  pattern : String,
) -> @conformance.SkeletonCase {
  { locale, calendar: "gregorian", skeleton, pattern, line: 2, }
}

///|
fn message_case(
  exp : String?,
  errors : Array[String],
  expects_parts : Bool,
) -> @conformance.MessageCase {
  {
    file: "inline.json",
    scenario: "Syntax",
    index: 0,
    description: None,
    src: "{1}",
    locale: "en-US",
    bidi_isolation: None,
    exp,
    expected_errors: errors,
    expects_parts,
    tags: [],
    params_json: None,
  }
}

///|
fn decimal_only_registry() -> @adapter.AdapterRegistry raise @adapter.AdapterRegistryError {
  let registry = @adapter.AdapterRegistry::new()
  registry.register(
    @adapter.AdapterInfo::new(
      id="decimal_only",
      name="只声明数字能力",
      capabilities=@conformance.AdapterCapabilities::new([
        @conformance.AdapterCapability::Decimal,
      ]),
    ),
    number=Some(
      ThrowingAdapter::{ label: "decimal_only", } as &@conformance.NumberAdapter,
    ),
  )
  registry
}

///|
/// M2 的核心验收：单条用例抛异常只记为 `Errored`，**整轮不中断**。
test "单条用例抛异常被隔离，全部记为 Errored 且整轮跑完" {
  let registry = decimal_only_registry()
  let cases = [
    decimal_case("en", "1.2", "1.2"),
    decimal_case("de", "1,5", "1,5"),
    decimal_case("fr", "3", "3"),
  ]
  let results = run_number(
    registry,
    ["decimal_only"],
    "inline.tsv",
    cases,
    EngineConfig::default(),
  )
  assert_eq(results.length(), 3)
  assert_true(
    results.all(result => result.outcome is @conformance.CaseOutcome::Errored(_)),
  )
  let summary = @conformance.RunSummary::from_results(results)
  assert_eq(summary.total, 3)
  assert_eq(summary.errored, 3)
  assert_eq(summary.failures(), 3)
  assert_false(summary.is_clean())
}

///|
/// 两种「不参与一致性统计」的情形：
/// 声明了但没实现该能力 → `Unsupported`；被选入但本环境没装 → `NotInstalled`。
/// 两者都不算失败（见 `DESIGN.md` D3）。
test "未声明能力记为 Unsupported；被选入但未安装记为 NotInstalled" {
  let registry = decimal_only_registry()
  let cases = [skeleton_case("en", "yMd", "M/d/y")]
  let unsupported = run_skeleton(
    registry,
    ["decimal_only"],
    "inline.tsv",
    cases,
    EngineConfig::default(),
  )
  assert_eq(
    unsupported[0].outcome,
    @conformance.CaseOutcome::Unsupported(feature="datetime-skeleton"),
  )

  // 注：`selected_ids` 为空时不会有任何结果行（结果 = 用例 × 已选适配器），
  // 所以"未选入"不是用空选择表达的，而是下面这条路径：被选入但 installed = false。
  let registry2 = @adapter.AdapterRegistry::new()
  registry2.register(
    @adapter.AdapterInfo::new(
      id="missing",
      name="被选入但未安装",
      capabilities=@conformance.AdapterCapabilities::new([]),
      installed=false,
    ),
  )
  let not_installed = run_skeleton(
    registry2,
    ["missing"],
    "inline.tsv",
    cases,
    EngineConfig::default(),
  )
  assert_eq(not_installed[0].outcome, @conformance.CaseOutcome::NotInstalled)

  let summary = @conformance.RunSummary::from_results(
    unsupported + not_installed,
  )
  assert_eq(summary.excluded(), 2)
  assert_true(summary.is_clean())
}

///|
test "结果能定位到来源与位置，并记录耗时" {
  let registry = decimal_only_registry()
  let results = run_number(
    registry,
    ["decimal_only"],
    "decimals.tsv",
    [decimal_case("en", "1.2", "1.2")],
    EngineConfig::default(),
  )
  assert_eq(results[0].source, "decimals.tsv")
  assert_eq(results[0].location, "L2")
  assert_eq(results[0].adapter_id, "decimal_only")
  assert_true(results[0].elapsed_ms >= 0)
  // 关闭计时后不再记录
  let unmeasured = run_number(
    registry,
    ["decimal_only"],
    "decimals.tsv",
    [decimal_case("en", "1.2", "1.2")],
    { full: false, measure: false, },
  )
  assert_eq(unmeasured[0].elapsed_ms, 0)
}

///|
test "空用例列表产出空结果" {
  let registry = decimal_only_registry()
  let results = run_number(
    registry,
    ["decimal_only"],
    "inline.tsv",
    [],
    EngineConfig::default(),
  )
  assert_eq(results.length(), 0)
  assert_eq(
    @conformance.RunSummary::from_results(results),
    @conformance.RunSummary::empty(),
  )
}

///|
fn message_registry(
  id : String,
  result : @conformance.MessageFormat2Result,
) -> @adapter.AdapterRegistry raise @adapter.AdapterRegistryError {
  let registry = @adapter.AdapterRegistry::new()
  registry.register(
    @adapter.AdapterInfo::new(
      id~,
      name=id,
      capabilities=@conformance.AdapterCapabilities::new([
        @conformance.AdapterCapability::MessageFormat2,
      ]),
    ),
    message_format_2=Some(
      ScriptedMessageAdapter::{ result, } as &@conformance.MessageFormat2Adapter,
    ),
  )
  registry
}

///|
test "MF2：有期望输出时比对字符串，期望报错时比对错误类别" {
  let formatted = message_registry(
    "formatted",
    @conformance.MessageFormat2Result::Formatted("1"),
  )
  let config = EngineConfig::default()
  let pass = run_message(
    formatted,
    ["formatted"],
    [message_case(Some("1"), [], false)],
    config,
  )
  assert_true(pass[0].outcome is @conformance.CaseOutcome::Pass)
  let fail = run_message(
    formatted,
    ["formatted"],
    [message_case(Some("2"), [], false)],
    config,
  )
  assert_true(fail[0].outcome is @conformance.CaseOutcome::Fail(_))
  // 期望报错却格式化成功 → 失败
  let silent = run_message(
    formatted,
    ["formatted"],
    [message_case(None, ["syntax-error"], false)],
    config,
  )
  assert_true(silent[0].outcome is @conformance.CaseOutcome::Fail(_))
  // 只期望结构化 parts：不比较不等于通过，如实记为不支持
  let parts = run_message(
    formatted,
    ["formatted"],
    [message_case(None, [], true)],
    config,
  )
  assert_eq(
    parts[0].outcome,
    @conformance.CaseOutcome::Unsupported(feature="exp-parts"),
  )
  // 返回了期望的错误类别 → 通过
  let errors = message_registry(
    "errors",
    @conformance.MessageFormat2Result::Errors(["syntax-error"]),
  )
  let matched = run_message(
    errors,
    ["errors"],
    [message_case(None, ["syntax-error"], false)],
    config,
  )
  assert_true(matched[0].outcome is @conformance.CaseOutcome::Pass)
}

///|
test "RunSummary 逐项计数与守恒" {
  let results = [
    @conformance.CaseResult::{
      suite: @conformance.Suite::Decimal,
      adapter_id: "a",
      source: "s.tsv",
      location: "L1",
      outcome: @conformance.CaseOutcome::Pass,
      elapsed_ms: 0,
    },
    @conformance.CaseResult::{
      suite: @conformance.Suite::Decimal,
      adapter_id: "a",
      source: "s.tsv",
      location: "L2",
      outcome: @conformance.CaseOutcome::Fail(
        reason=@conformance.FailReason::GroupingMismatch,
        expected="1,234",
        actual="1234",
      ),
      elapsed_ms: 1,
    },
    @conformance.CaseResult::{
      suite: @conformance.Suite::Datetime,
      adapter_id: "a",
      source: "s.tsv",
      location: "L3",
      outcome: @conformance.CaseOutcome::Unsupported(
        feature="datetime-skeleton",
      ),
      elapsed_ms: 0,
    },
    @conformance.CaseResult::{
      suite: @conformance.Suite::Datetime,
      adapter_id: "a",
      source: "s.tsv",
      location: "L4",
      outcome: @conformance.CaseOutcome::NotInstalled,
      elapsed_ms: 0,
    },
    @conformance.CaseResult::{
      suite: @conformance.Suite::MessageFormat2,
      adapter_id: "a",
      source: "s.json",
      location: "#1",
      outcome: @conformance.CaseOutcome::Errored(detail="boom"),
      elapsed_ms: 2,
    },
  ]
  let summary = @conformance.RunSummary::from_results(results)
  assert_eq(summary.total, 5)
  assert_eq(summary.passed, 1)
  assert_eq(summary.failed, 1)
  assert_eq(summary.errored, 1)
  assert_eq(summary.unsupported, 1)
  assert_eq(summary.not_installed, 1)
  assert_eq(summary.failures(), 2)
  assert_eq(summary.excluded(), 2)
  assert_eq(
    summary.total,
    summary.passed +
    summary.failed +
    summary.errored +
    summary.unsupported +
    summary.not_installed,
  )
}

///|
/// 端到端：用 reference-null 跑完全部 4714 条真实用例。
/// 断言的是**计数守恒与分类正确**，不是一致率（reference-null 什么都不做）。
async test "端到端：reference-null 跑完全部真实用例且计数守恒" {
  let registry = @adapter.AdapterRegistry::new()
  let reference_null = @reference_null.ReferenceNull::new()
  registry.register(
    @adapter.AdapterInfo::new(
      id="reference_null",
      name="reference-null",
      capabilities=@conformance.AdapterCapabilities::all(),
    ),
    number=Some(reference_null as &@conformance.NumberAdapter),
    datetime=Some(reference_null as &@conformance.DatetimeAdapter),
    message_format_2=Some(reference_null as &@conformance.MessageFormat2Adapter),
  )
  let ids = ["reference_null"]
  let config = EngineConfig::default()
  let decimal = @corpus.decimal_corpus_from_tsv(
    @fs.read_file("fixtures/decimal/decimals.tsv").text(),
  )
  let modern = @corpus.decimal_corpus_from_tsv(
    @fs.read_file("fixtures/decimal/decimals_modern_locales.tsv").text(),
  )
  let skeletons = @corpus.parse_skeleton_cases(
    @corpus.parse_tsv(@fs.read_file("fixtures/datetime/skeletons.tsv").text()),
  )
  let all_calendars = @corpus.parse_skeleton_cases(
    @corpus.parse_tsv(
      @fs.read_file("fixtures/datetime/skeletons_all_calendars.tsv").text(),
    ),
  )
  let formatted = @corpus.parse_datetime_json(
    @fs.read_file("fixtures/datetime/datetime.json").text(),
  )
  let mut message_cases : Array[@conformance.MessageCase] = []
  for
    name in [
      "syntax", "syntax-errors", "data-model-errors", "pattern-selection", "fallback",
      "bidi", "u-options",
    ] {
    let file = "\{name}.json"
    message_cases = message_cases +
      @corpus.parse_message_tests(
        file,
        @fs.read_file("fixtures/messageFormat/tests/\{file}").text(),
      )
  }

  let mut results : Array[@conformance.CaseResult] = []
  results = results +
    run_number(registry, ids, "decimals.tsv", decimal.cases, config)
  results = results +
    run_number(
      registry,
      ids,
      "decimals_modern_locales.tsv",
      modern.cases,
      config,
    )
  results = results +
    run_skeleton(registry, ids, "skeletons.tsv", skeletons, config)
  results = results +
    run_skeleton(
      registry, ids, "skeletons_all_calendars.tsv", all_calendars, config,
    )
  results = results +
    run_datetime(registry, ids, "datetime.json", formatted, config)
  results = results + run_message(registry, ids, message_cases, config)

  let summary = @conformance.RunSummary::from_results(results)
  assert_eq(summary.total, 4714)
  // reference-null 声明了全部能力且被选入，因此不应出现这两类
  assert_eq(summary.unsupported, 0)
  assert_eq(summary.not_installed, 0)
  assert_eq(summary.failures(), summary.failed + summary.errored)
  assert_eq(summary.total, summary.passed + summary.failed + summary.errored)
  // 结果是可定位的
  let failures = results.filter(result => result.outcome.is_failure())
  assert_eq(failures.length(), summary.failures())
  assert_true(
    failures.all(result => result.source != "" && result.location != ""),
  )
}
