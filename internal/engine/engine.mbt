///|
/// 执行引擎配置。
pub(all) struct EngineConfig {
  /// 是否启用扩展数据档（见 开发方案.md §3.1）。
  full : Bool
  /// 是否记录单用例耗时（毫秒）。定位异常慢的实现用。
  measure : Bool
} derive(Debug, Eq)

///|
pub fn EngineConfig::default() -> EngineConfig {
  { full: false, measure: true, }
}

///|
/// 一条用例 × 一个适配器的执行骨架。
///
/// 先判定可用性（未选入 → `NotInstalled`、缺少任一所需能力 → `Unsupported`，
/// 两者都不算失败），再执行并**隔离异常**：单条用例抛异常只记为 `Errored`，不中断整轮。
///
/// `required` 是这条用例**所需的能力集合**：例如科学计数法用例同时需要
/// `Decimal` + `DecimalScientific`。能力模型按"库可能只做其中一部分"切分，
/// 于是"没有这个能力"不会被算成"做错"（依据见 `可比性映射.md`）。
///
/// 关于超时：这里**不做硬超时**。适配器方法是同步调用，单进程内无法安全打断
/// （`@async.with_timeout` 需要可让出的 async 体，同步阻塞时定时器无法触发）。
/// 实际防线是 CLI 的 `--impls` 单实现运行 + CI 逐实现 job 超时（见 开发方案.md §4.4）。
fn dispatch(
  suite : @conformance.Suite,
  adapter_id : String,
  source : String,
  location : String,
  registry : @adapter.AdapterRegistry,
  selected_ids : Array[String],
  required : Array[@conformance.AdapterCapability],
  config : EngineConfig,
  evaluate_case : () -> @conformance.CaseOutcome raise,
) -> @conformance.CaseResult raise @adapter.AdapterRegistryError {
  let mut unavailable : @conformance.CaseOutcome? = None
  for capability in required {
    match registry.unavailable_outcome(adapter_id, selected_ids, capability) {
      Some(outcome) => {
        unavailable = Some(outcome)
        break
      }
      None => ()
    }
  }
  match unavailable {
    Some(outcome) =>
      { suite, adapter_id, source, location, outcome, elapsed_ms: 0, }
    None => {
      let started = if config.measure { @async.now() } else { 0L }
      let mut outcome = @conformance.CaseOutcome::Errored(
        detail="适配器既未返回结果也未抛出异常",
      )
      try evaluate_case() catch {
        err => outcome = @conformance.CaseOutcome::Errored(detail="\{err}")
      } noraise {
        value => outcome = value
      }
      let elapsed_ms = if config.measure {
        (@async.now() - started).to_int()
      } else {
        0
      }
      { suite, adapter_id, source, location, outcome, elapsed_ms, }
    }
  }
}

///|
/// 比较期望字符串与实际输出。
fn evaluate(
  context : AttributionContext,
  expected : String,
  run : () -> String raise,
) -> @conformance.CaseOutcome raise {
  let actual = run()
  if actual == expected {
    @conformance.CaseOutcome::Pass
  } else {
    @conformance.CaseOutcome::Fail(
      reason=attribute(context, expected, actual),
      expected~,
      actual~,
    )
  }
}

///|
fn join_strings(values : Array[String]) -> String {
  let mut out = ""
  for value in values {
    if out != "" {
      out = out + ", "
    }
    out = out + value
  }
  out
}

///|
/// 错误类别是否被期望集合覆盖。
fn errors_match(expected : Array[String], actual : Array[String]) -> Bool {
  expected.length() > 0 && expected.all(item => actual.contains(item))
}

///|
/// MF2 结果的判定。
///
/// 首版规则（M5 再细化）：有 `exp` 就比较格式化输出；否则比较错误类别集合。
/// 只期望结构化 `expParts` 的用例记为 `Unsupported`——**不比较 parts 不等于通过**。
fn compare_message(
  case : @conformance.MessageCase,
  result : @conformance.MessageFormat2Result,
) -> @conformance.CaseOutcome {
  match result {
    Formatted(text) =>
      match case.exp {
        Some(expected) =>
          if text == expected {
            @conformance.CaseOutcome::Pass
          } else {
            // 两边都给出文本，但内容不同：格式走通了，渲染结果不对
            @conformance.CaseOutcome::Fail(
              reason=@conformance.FailReason::MessageTextMismatch,
              expected~,
              actual=text,
            )
          }
        None =>
          if case.expects_parts && case.expected_errors.length() == 0 {
            @conformance.CaseOutcome::Unsupported(feature="exp-parts")
          } else {
            // 规范要求报错，实现却成功格式化
            @conformance.CaseOutcome::Fail(
              reason=@conformance.FailReason::MissingError,
              expected=join_strings(case.expected_errors),
              actual="格式化成功（期望报错）",
            )
          }
      }
    Errors(types) =>
      match case.exp {
        Some(expected) =>
          // 规范要求输出文本，实现却报错（例如未解析变量应回退为原文而非报错）
          @conformance.CaseOutcome::Fail(
            reason=@conformance.FailReason::UnexpectedError,
            expected~,
            actual="报错：\{join_strings(types)}",
          )
        None =>
          if errors_match(case.expected_errors, types) {
            @conformance.CaseOutcome::Pass
          } else {
            // 都报错了，但类别不同——有映射表（见 adapters/lampclaw）才可能对上
            @conformance.CaseOutcome::Fail(
              reason=@conformance.FailReason::WrongErrorClass,
              expected=join_strings(case.expected_errors),
              actual=join_strings(types),
            )
          }
      }
  }
}

///|
/// 跑数字套件（`decimals*.tsv`）。
pub fn run_number(
  registry : @adapter.AdapterRegistry,
  selected_ids : Array[String],
  source : String,
  cases : Array[@conformance.DecimalCase],
  config : EngineConfig,
) -> Array[@conformance.CaseResult] raise @adapter.AdapterRegistryError {
  let results : Array[@conformance.CaseResult] = []
  for case in cases {
    for adapter_id in selected_ids {
      // 这条用例需要哪些能力：普通数字 + （科学计数法 / 紧凑格式）
      let required : Array[@conformance.AdapterCapability] = [
        @conformance.AdapterCapability::Decimal,
      ]
      if case.style == @conformance.NumberStyle::ScientificStyle {
        required.push(@conformance.AdapterCapability::DecimalScientific)
      }
      if case.length != @conformance.NumberLength::Standard {
        required.push(@conformance.AdapterCapability::DecimalCompact)
      }
      results.push(
        dispatch(
          @conformance.Suite::Decimal,
          adapter_id,
          source,
          "L\{case.line}",
          registry,
          selected_ids,
          required,
          config,
          () => {
            match registry.number_adapter(adapter_id) {
              Some(adapter) =>
                evaluate(
                  AttributionContext::new(
                    @conformance.Suite::Decimal,
                    compact=case.length != @conformance.NumberLength::Standard,
                  ),
                  case.expected,
                  () => {
                    adapter.format_number(
                      case.locale,
                      case.input,
                      style=case.style,
                      length=case.length,
                    )
                  },
                )
              None =>
                @conformance.CaseOutcome::Errored(
                  detail="适配器未登记数字 handler",
                )
            }
          },
        ),
      )
    }
  }
  results
}

///|
/// 跑日期骨架套件（`skeletons*.tsv`）：骨架 → 模式。
pub fn run_skeleton(
  registry : @adapter.AdapterRegistry,
  selected_ids : Array[String],
  source : String,
  cases : Array[@conformance.SkeletonCase],
  config : EngineConfig,
) -> Array[@conformance.CaseResult] raise @adapter.AdapterRegistryError {
  let results : Array[@conformance.CaseResult] = []
  for case in cases {
    for adapter_id in selected_ids {
      results.push(
        dispatch(
          @conformance.Suite::Datetime,
          adapter_id,
          source,
          "L\{case.line}",
          registry,
          selected_ids,
          [@conformance.AdapterCapability::DatetimeSkeleton],
          config,
          () => {
            match registry.datetime_adapter(adapter_id) {
              Some(adapter) =>
                evaluate(
                  AttributionContext::new(@conformance.Suite::Datetime),
                  case.pattern,
                  () => {
                    adapter.format_skeleton(
                      case.locale,
                      case.calendar,
                      case.skeleton,
                    )
                  },
                )
              None =>
                @conformance.CaseOutcome::Errored(
                  detail="适配器未登记日期 handler",
                )
            }
          },
        ),
      )
    }
  }
  results
}

///|
/// 跑日期格式化套件（`datetime.json`）。
pub fn run_datetime(
  registry : @adapter.AdapterRegistry,
  selected_ids : Array[String],
  source : String,
  cases : Array[@conformance.DatetimeCase],
  config : EngineConfig,
) -> Array[@conformance.CaseResult] raise @adapter.AdapterRegistryError {
  let results : Array[@conformance.CaseResult] = []
  for case in cases {
    for adapter_id in selected_ids {
      results.push(
        dispatch(
          @conformance.Suite::Datetime,
          adapter_id,
          source,
          "#\{case.index}",
          registry,
          selected_ids,
          [@conformance.AdapterCapability::DatetimeFormat],
          config,
          () => {
            match registry.datetime_adapter(adapter_id) {
              Some(adapter) =>
                evaluate(
                  AttributionContext::new(@conformance.Suite::Datetime),
                  case.expected,
                  () => adapter.format_datetime(case.format_input()),
                )
              None =>
                @conformance.CaseOutcome::Errored(
                  detail="适配器未登记日期 handler",
                )
            }
          },
        ),
      )
    }
  }
  results
}

///|
/// 跑 MF2 套件（`messageFormat/tests/*.json`）。
pub fn run_message(
  registry : @adapter.AdapterRegistry,
  selected_ids : Array[String],
  cases : Array[@conformance.MessageCase],
  config : EngineConfig,
) -> Array[@conformance.CaseResult] raise @adapter.AdapterRegistryError {
  let results : Array[@conformance.CaseResult] = []
  for case in cases {
    for adapter_id in selected_ids {
      results.push(
        dispatch(
          @conformance.Suite::MessageFormat2,
          adapter_id,
          case.file,
          "#\{case.index}",
          registry,
          selected_ids,
          [@conformance.AdapterCapability::MessageFormat2],
          config,
          () => {
            match registry.message_format_2_adapter(adapter_id) {
              Some(adapter) =>
                compare_message(
                  case,
                  adapter.format_message(case.format_input()),
                )
              None =>
                @conformance.CaseOutcome::Errored(
                  detail="适配器未登记 MF2 handler",
                )
            }
          },
        ),
      )
    }
  }
  results
}
