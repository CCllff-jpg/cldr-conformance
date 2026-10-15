///|
/// 失败标签的稳定标识（用于 JSON 与报告，不要随展示文案改动）。
pub fn FailReason::label(self : FailReason) -> String {
  match self {
    GroupingMismatch => "grouping-mismatch"
    DigitSystemMismatch => "digit-system-mismatch"
    RoundingMismatch => "rounding-mismatch"
    PluralCategoryMismatch => "plural-category-mismatch"
    BidiControlMissing => "bidi-control-missing"
    CompactFormMismatch => "compact-form-mismatch"
    PatternSyntaxUnsupported => "pattern-syntax-unsupported"
    Other => "other"
  }
}

///|
/// 全部归因类别，顺序即报告中的展示顺序（分组类在前、兜底在后）。
pub fn FailReason::all() -> Array[FailReason] {
  [
    GroupingMismatch,
    DigitSystemMismatch,
    RoundingMismatch,
    PluralCategoryMismatch,
    BidiControlMissing,
    CompactFormMismatch,
    PatternSyntaxUnsupported,
    Other,
  ]
}

///|
/// 字符级最小差异：首个不同码元的位置与两侧片段。
///
/// 报告要给的是"一眼看出差在哪"，而不是让人自己 diff 两串长文本。
pub(all) struct CharDiff {
  /// 首个不同码元的下标（0 起）；两串完全相同时为 -1。
  index : Int
  /// 差异位置附近的期望片段（截断处用 `…` 标记）。
  expected_snippet : String
  actual_snippet : String
  expected_length : Int
  actual_length : Int
} derive(Debug, Eq)

///|
/// 逐码元比较，找出首个差异位置，并给出该位置两侧的片段。
///
/// 窗口半径固定为 14 个码元：足够看清差异，又不至于把整串塞进报告。
pub fn char_diff(expected : String, actual : String) -> CharDiff {
  let expected_length = expected.length()
  let actual_length = actual.length()
  let limit = if expected_length < actual_length {
    expected_length
  } else {
    actual_length
  }
  let mut index = 0
  while index < limit {
    if expected[index] != actual[index] {
      break
    }
    index += 1
  }
  if index == expected_length && index == actual_length {
    return {
      index: -1,
      expected_snippet: "",
      actual_snippet: "",
      expected_length,
      actual_length,
    }
  }
  let start = if index > 14 { index - 14 } else { 0 }
  let end = index + 14
  {
    index,
    expected_snippet: snippet(expected, start, end),
    actual_snippet: snippet(actual, start, end),
    expected_length,
    actual_length,
  }
}

///|
fn snippet(text : String, start : Int, end : Int) -> String {
  let prefix = if start > 0 { "…" } else { "" }
  let suffix = if end < text.length() { "…" } else { "" }
  prefix + text.clamped_view(start~, end~).to_owned() + suffix
}

///|
/// 按套件拆分的小计。
pub(all) struct SuiteSummary {
  suite : Suite
  summary : RunSummary
} derive(Debug, Eq)

///|
/// 某个失败原因的计数。
pub(all) struct ReasonCount {
  reason : FailReason
  count : Int
} derive(Debug, Eq)

///|
/// 一条「答错」的明细：报告里最有价值的部分。
pub(all) struct FailureDetail {
  suite : Suite
  source : String
  location : String
  reason : FailReason
  expected : String
  actual : String
  diff : CharDiff
} derive(Debug, Eq)

///|
/// 一条「抛异常」的明细。
///
/// 与答错分列存放：**抛异常与答错是两类缺陷**，混在一起会掩盖实现崩溃的问题。
pub(all) struct ErrorDetail {
  suite : Suite
  source : String
  location : String
  detail : String
} derive(Debug, Eq)

///|
/// 单个适配器的报告。
pub(all) struct AdapterReport {
  adapter_id : String
  summary : RunSummary
  by_suite : Array[SuiteSummary]
  by_reason : Array[ReasonCount]
  /// 失败的**样例**（上限见 `failure_sample_limit`）；计数仍是完整的。
  failures : Array[FailureDetail]
  errors : Array[ErrorDetail]
} derive(Debug, Eq)

///|
/// 一次运行的完整报告。
pub(all) struct Report {
  /// CLDR 数据基线（不可变 tag）。报告脱离基线就没有意义。
  baseline : String
  adapters : Array[AdapterReport]
  summary : RunSummary
} derive(Debug, Eq)

///|
/// 每个适配器在报告里最多保留多少条明细。
///
/// 4714 条用例 × N 个适配器全量塞进 JSON 会有数 MB，而人看前几条就能定位问题；
/// 计数与归因分布始终是完整的，不受这个上限影响。
pub fn failure_sample_limit() -> Int {
  20
}

///|
/// 统计各原因的失败数（原因顺序稳定，只列入出现过的）。
fn reason_counts(results : Array[CaseResult]) -> Array[ReasonCount] {
  let counts : Array[ReasonCount] = []
  for target in FailReason::all() {
    let mut count = 0
    for result in results {
      match result.outcome {
        Fail(reason~, ..) => if reason == target { count += 1 }
        _ => ()
      }
    }
    if count > 0 {
      counts.push({ reason: target, count, })
    }
  }
  counts
}

///|
/// 按套件拆分统计（只列入出现过的套件）。
fn suite_summaries(results : Array[CaseResult]) -> Array[SuiteSummary] {
  let summaries : Array[SuiteSummary] = []
  for suite in Suite::all() {
    let mine = results.filter(result => result.suite == suite)
    if mine.length() > 0 {
      summaries.push({ suite, summary: RunSummary::from_results(mine), })
    }
  }
  summaries
}

///|
/// 从执行结果构建单个适配器的报告。
pub fn AdapterReport::from_results(
  adapter_id : String,
  results : Array[CaseResult],
) -> AdapterReport {
  let mine = results.filter(result => result.adapter_id == adapter_id)
  let failures : Array[FailureDetail] = []
  let errors : Array[ErrorDetail] = []
  for result in mine {
    match result.outcome {
      Fail(reason~, expected~, actual~) =>
        if failures.length() < failure_sample_limit() {
          failures.push({
            suite: result.suite,
            source: result.source,
            location: result.location,
            reason,
            expected,
            actual,
            diff: char_diff(expected, actual),
          })
        }
      Errored(detail~) =>
        if errors.length() < failure_sample_limit() {
          errors.push({
            suite: result.suite,
            source: result.source,
            location: result.location,
            detail,
          })
        }
      _ => ()
    }
  }
  {
    adapter_id,
    summary: RunSummary::from_results(mine),
    by_suite: suite_summaries(mine),
    by_reason: reason_counts(mine),
    failures,
    errors,
  }
}

///|
/// 从一次运行的全部结果构建报告。`adapter_ids` 决定顺序（即报告中的展示顺序）。
pub fn Report::from_results(
  baseline : String,
  adapter_ids : Array[String],
  results : Array[CaseResult],
) -> Report {
  let adapters : Array[AdapterReport] = []
  for adapter_id in adapter_ids {
    adapters.push(AdapterReport::from_results(adapter_id, results))
  }
  { baseline, adapters, summary: RunSummary::from_results(results), }
}

///|
fn json_summary(summary : RunSummary) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["total"] = Json::number(summary.total.to_double())
  fields["passed"] = Json::number(summary.passed.to_double())
  fields["failed"] = Json::number(summary.failed.to_double())
  fields["errored"] = Json::number(summary.errored.to_double())
  fields["unsupported"] = Json::number(summary.unsupported.to_double())
  fields["not_installed"] = Json::number(summary.not_installed.to_double())
  fields["pass_rate"] = Json::string(summary.pass_rate_text())
  Json::object(fields)
}

///|
fn json_adapter(adapter : AdapterReport) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["adapter_id"] = Json::string(adapter.adapter_id)
  fields["summary"] = json_summary(adapter.summary)
  let suites : Array[Json] = []
  for entry in adapter.by_suite {
    let item : Map[String, Json] = Map([])
    item["suite"] = Json::string(entry.suite.label())
    item["summary"] = json_summary(entry.summary)
    suites.push(Json::object(item))
  }
  fields["by_suite"] = Json::array(suites)
  let reasons : Array[Json] = []
  for entry in adapter.by_reason {
    let item : Map[String, Json] = Map([])
    item["reason"] = Json::string(entry.reason.label())
    item["count"] = Json::number(entry.count.to_double())
    reasons.push(Json::object(item))
  }
  fields["by_reason"] = Json::array(reasons)
  let failures : Array[Json] = []
  for failure in adapter.failures {
    let item : Map[String, Json] = Map([])
    item["suite"] = Json::string(failure.suite.label())
    item["source"] = Json::string(failure.source)
    item["location"] = Json::string(failure.location)
    item["reason"] = Json::string(failure.reason.label())
    item["expected"] = Json::string(failure.expected)
    item["actual"] = Json::string(failure.actual)
    let diff : Map[String, Json] = Map([])
    diff["index"] = Json::number(failure.diff.index.to_double())
    diff["expected_snippet"] = Json::string(failure.diff.expected_snippet)
    diff["actual_snippet"] = Json::string(failure.diff.actual_snippet)
    item["diff"] = Json::object(diff)
    failures.push(Json::object(item))
  }
  fields["failures"] = Json::array(failures)
  let errors : Array[Json] = []
  for error in adapter.errors {
    let item : Map[String, Json] = Map([])
    item["suite"] = Json::string(error.suite.label())
    item["source"] = Json::string(error.source)
    item["location"] = Json::string(error.location)
    item["detail"] = Json::string(error.detail)
    errors.push(Json::object(item))
  }
  fields["errors"] = Json::array(errors)
  Json::object(fields)
}

///|
/// 渲染为 JSON（缩进 2 空格，键名稳定）。
///
/// schema 顶层：`baseline` / `summary` / `adapters[]`，
/// 每个适配器含 `adapter_id` / `summary` / `by_suite[]` / `by_reason[]` /
/// `failures[]`（样例）/ `errors[]`（样例）。
pub fn Report::to_json(self : Report) -> String {
  let root : Map[String, Json] = Map([])
  root["baseline"] = Json::string(self.baseline)
  root["summary"] = json_summary(self.summary)
  let adapters : Array[Json] = []
  for adapter in self.adapters {
    adapters.push(json_adapter(adapter))
  }
  root["adapters"] = Json::array(adapters)
  Json::object(root).stringify(indent=2)
}

///|
/// 渲染为 Markdown：矩阵 + 归因分布 + 失败样例（带字符级差异）。
pub fn Report::to_markdown(self : Report) -> String {
  let out = StringBuilder()
  out.write_string("# CLDR 一致性报告\n\n")
  out.write_string(
    "数据基线 `\{self.baseline}`；用例总数 \{self.summary.total}。\n\n",
  )
  out.write_string("## 一致率矩阵\n\n")
  out.write_string(
    "| 适配器 | 套件 | 用例 | 一致率 | pass | fail | errored | unsupported | not-installed |\n",
  )
  out.write_string("|---|---|---|---|---|---|---|---|---|\n")
  for adapter in self.adapters {
    for entry in adapter.by_suite {
      let summary = entry.summary
      out.write_string(
        "| `\{adapter.adapter_id}` | \{entry.suite.label()} | \{summary.total} | \{summary.pass_rate_text()} | \{summary.passed} | \{summary.failed} | \{summary.errored} | \{summary.unsupported} | \{summary.not_installed} |\n",
      )
    }
    let summary = adapter.summary
    out.write_string(
      "| **`\{adapter.adapter_id}`** | **合计** | **\{summary.total}** | **\{summary.pass_rate_text()}** | **\{summary.passed}** | **\{summary.failed}** | **\{summary.errored}** | **\{summary.unsupported}** | **\{summary.not_installed}** |\n",
    )
  }
  out.write_string("\n## 失败归因分布\n\n")
  for adapter in self.adapters {
    out.write_string("### `\{adapter.adapter_id}`\n\n")
    if adapter.by_reason.length() == 0 {
      out.write_string("无失败。\n\n")
      continue
    }
    out.write_string("| 原因 | 次数 |\n|---|---|\n")
    for entry in adapter.by_reason {
      out.write_string("| \{entry.reason.label()} | \{entry.count} |\n")
    }
    out.write_string("\n")
  }
  out.write_string("## 失败样例\n\n")
  out.write_string(
    "> 每个适配器最多展示 \{failure_sample_limit()} 条；计数与分布始终是完整的。\n\n",
  )
  for adapter in self.adapters {
    out.write_string("### `\{adapter.adapter_id}`\n\n")
    if adapter.failures.length() == 0 && adapter.errors.length() == 0 {
      out.write_string("无失败样例。\n\n")
      continue
    }
    for failure in adapter.failures {
      out.write_string(
        "- `\{failure.source}` \{failure.location} · **\{failure.reason.label()}**\n",
      )
      out.write_string("  - 期望 `\{failure.expected}`\n")
      out.write_string("  - 实际 `\{failure.actual}`\n")
      out.write_string(
        "  - 首个差异在第 \{failure.diff.index} 个码元：`\{failure.diff.expected_snippet}` → `\{failure.diff.actual_snippet}`\n",
      )
    }
    for error in adapter.errors {
      out.write_string(
        "- `\{error.source}` \{error.location} · **errored**：\{error.detail}\n",
      )
    }
    out.write_string("\n")
  }
  out.to_string()
}
