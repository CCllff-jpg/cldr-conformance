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
/// 先判定可用性（未选入 → `NotInstalled`、未声明能力 → `Unsupported`，两者都不算失败），
/// 再执行并**隔离异常**：单条用例抛异常只记为 `Errored`，不中断整轮。
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
  capability : @conformance.AdapterCapability,
  config : EngineConfig,
  evaluate_case : () -> @conformance.CaseOutcome raise,
) -> @conformance.CaseResult raise @adapter.AdapterRegistryError {
  match registry.unavailable_outcome(adapter_id, selected_ids, capability) {
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
  expected : String,
  run : () -> String raise,
) -> @conformance.CaseOutcome raise {
  let actual = run()
  if actual == expected {
    @conformance.CaseOutcome::Pass
  } else {
    @conformance.CaseOutcome::Fail(
      reason=@conformance.FailReason::Other,
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
            @conformance.CaseOutcome::Fail(
              reason=@conformance.FailReason::Other,
              expected~,
              actual=text,
            )
          }
        None =>
          if case.expects_parts && case.expected_errors.length() == 0 {
            @conformance.CaseOutcome::Unsupported(feature="exp-parts")
          } else {
            @conformance.CaseOutcome::Fail(
              reason=@conformance.FailReason::Other,
              expected=join_strings(case.expected_errors),
              actual="格式化成功（期望报错）",
            )
          }
      }
    Errors(types) =>
      match case.exp {
        Some(expected) =>
          @conformance.CaseOutcome::Fail(
            reason=@conformance.FailReason::Other,
            expected~,
            actual="报错：\{join_strings(types)}",
          )
        None =>
          if errors_match(case.expected_errors, types) {
            @conformance.CaseOutcome::Pass
          } else {
            @conformance.CaseOutcome::Fail(
              reason=@conformance.FailReason::Other,
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
      results.push(
        dispatch(
          @conformance.Suite::Decimal,
          adapter_id,
          source,
          "L\{case.line}",
          registry,
          selected_ids,
          @conformance.AdapterCapability::Decimal,
          config,
          () => {
            match registry.number_adapter(adapter_id) {
              Some(adapter) =>
                evaluate(case.expected, () => {
                  adapter.format_number(
                    case.locale,
                    case.input,
                    style=case.style,
                    length=case.length,
                  )
                })
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
          @conformance.AdapterCapability::DatetimeSkeleton,
          config,
          () => {
            match registry.datetime_adapter(adapter_id) {
              Some(adapter) =>
                evaluate(case.pattern, () => {
                  adapter.format_skeleton(
                    case.locale,
                    case.calendar,
                    case.skeleton,
                  )
                })
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
          @conformance.AdapterCapability::DatetimeFormat,
          config,
          () => {
            match registry.datetime_adapter(adapter_id) {
              Some(adapter) =>
                evaluate(case.expected, () => {
                  adapter.format_datetime(case.format_input())
                })
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
          @conformance.AdapterCapability::MessageFormat2,
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
