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
    ValueMismatch => "value-mismatch"
    UnexpectedError => "unexpected-error"
    MissingError => "missing-error"
    WrongErrorClass => "wrong-error-class"
    MessageTextMismatch => "message-text-mismatch"
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
    ValueMismatch,
    UnexpectedError,
    MissingError,
    WrongErrorClass,
    MessageTextMismatch,
    Other,
  ]
}

///|
/// 字符级最小差异：首个不同码元的位置与两侧片段。
///
/// 报告要给的是"一眼看出差在哪"，而不是让人自己 diff 两串长文本。
pub(all) struct CharDiff {
  /// 首个不同码元的下标（0 起）；两串完全相同时为 -1。
  index : Int32
  /// 差异位置附近的期望片段（截断处用 `…` 标记）。
  expected_snippet : String
  actual_snippet : String
  expected_length : Int32
  actual_length : Int32
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
fn snippet(text : String, start : Int32, end : Int32) -> String {
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
  count : Int32
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
pub fn failure_sample_limit() -> Int32 {
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
///
/// `limit` 为负时采用 `failure_sample_limit()`；需要看全部样例时传一个很大的数
/// （CLI 的 `--all-samples` 就是这么用的）。
pub fn AdapterReport::from_results(
  adapter_id : String,
  results : Array[CaseResult],
  limit~ : Int32 = -1,
) -> AdapterReport {
  let cap = if limit < 0 { failure_sample_limit() } else { limit }
  let mine = results.filter(result => result.adapter_id == adapter_id)
  let failures : Array[FailureDetail] = []
  let errors : Array[ErrorDetail] = []
  for result in mine {
    match result.outcome {
      Fail(reason~, expected~, actual~) =>
        if failures.length() < cap {
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
        if errors.length() < cap {
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
  limit~ : Int32 = -1,
) -> Report {
  let adapters : Array[AdapterReport] = []
  for adapter_id in adapter_ids {
    adapters.push(AdapterReport::from_results(adapter_id, results, limit~))
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

///|
/// HTML 转义（`<`, `>`, `&`, `"`）。
fn html_escape(text : String) -> String {
  let out = StringBuilder()
  let mut index = 0
  while index < text.length() {
    let unit = text[index].to_int()
    if unit == 0x0026 {
      out.write_string("&amp;")
    } else if unit == 0x003C {
      out.write_string("&lt;")
    } else if unit == 0x003E {
      out.write_string("&gt;")
    } else if unit == 0x0022 {
      out.write_string("&quot;")
    } else {
      out.write_substring(text, index, 1)
    }
    index += 1
  }
  out.to_string()
}

///|
/// 把双向控制符渲染成可见标记，避免 RTL 文本把页面排版带乱。
///
/// 这是本项目的一个实际需求：CLDR 的期望值里大量出现 U+200E/U+200F/U+061C，
/// 直接输出会让人看不出差异在哪里。
fn html_visible_controls(text : String) -> String {
  let out = StringBuilder()
  let mut index = 0
  while index < text.length() {
    let unit = text[index].to_int()
    if unit == 0x200E || unit == 0x200F || unit == 0x061C || unit == 0x200B {
      out.write_string("<span class=\"ctrl\">U+")
      out.write_string(hex4(unit))
      out.write_string("</span>")
    } else if unit >= 0x2066 && unit <= 0x2069 {
      out.write_string("<span class=\"ctrl\">U+")
      out.write_string(hex4(unit))
      out.write_string("</span>")
    } else if unit == 0x0026 {
      out.write_string("&amp;")
    } else if unit == 0x003C {
      out.write_string("&lt;")
    } else if unit == 0x003E {
      out.write_string("&gt;")
    } else if unit == 0x0022 {
      out.write_string("&quot;")
    } else {
      out.write_substring(text, index, 1)
    }
    index += 1
  }
  out.to_string()
}

///|
fn hex4(unit : Int32) -> String {
  let digits = "0123456789ABCDEF"
  let out = StringBuilder()
  let mut shift = 12
  while shift >= 0 {
    let digit = (unit >> shift) & 0xF
    out.write_substring(digits, digit, 1)
    shift -= 4
  }
  out.to_string()
}

///|
fn html_bar(rate : Double) -> String {
  let percent = if rate < 0.0 { 0.0 } else if rate > 1.0 { 1.0 } else { rate }
  let width = (percent * 100.0).to_int()
  "<div class=\"bar\"><span style=\"width:\{width}%\"></span></div>"
}

///|
fn html_style() -> String {
  let out = StringBuilder()
  out.write_string("<style>\n")
  out.write_string(
    ":root{--fg:#1a1a1a;--mute:#6b7280;--line:#e5e7eb;--bg:#fff;--soft:#f9fafb;--ok:#16a34a;--bad:#dc2626;--warn:#d97706}\n",
  )
  out.write_string("*{box-sizing:border-box}\n")
  out.write_string(
    "body{margin:0;padding:32px 20px 64px;background:var(--bg);color:var(--fg);font:15px/1.6 -apple-system,BlinkMacSystemFont,'Segoe UI','Noto Sans CJK SC',sans-serif}\n",
  )
  out.write_string("main{max-width:1040px;margin:0 auto}\n")
  out.write_string("h1{font-size:24px;margin:0 0 4px}\n")
  out.write_string(
    "h2{font-size:18px;margin:36px 0 12px;padding-bottom:6px;border-bottom:2px solid var(--line)}\n",
  )
  out.write_string("h3{font-size:15px;margin:20px 0 6px}\n")
  out.write_string(".meta{color:var(--mute);font-size:13px;margin:0 0 8px}\n")
  out.write_string(
    "code{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:13px;background:var(--soft);padding:1px 5px;border-radius:4px}\n",
  )
  out.write_string(
    "table{width:100%;border-collapse:collapse;margin:8px 0 4px;font-size:14px}\n",
  )
  out.write_string(
    "th,td{text-align:left;padding:7px 10px;border-bottom:1px solid var(--line);vertical-align:middle}\n",
  )
  out.write_string(
    "th{color:var(--mute);font-weight:600;font-size:12px;text-transform:uppercase;letter-spacing:.04em}\n",
  )
  out.write_string(
    "td.num,th.num{text-align:right;font-variant-numeric:tabular-nums}\n",
  )
  out.write_string(
    ".bar{width:92px;height:6px;background:var(--line);border-radius:3px;overflow:hidden;display:inline-block;vertical-align:middle}\n",
  )
  out.write_string(
    ".bar span{display:block;height:100%;background:var(--ok)}\n",
  )
  out.write_string(".bar.bad span{background:var(--bad)}\n")
  out.write_string(
    ".ctrl{color:var(--warn);border:1px dashed var(--warn);border-radius:3px;padding:0 3px;font-size:11px;font-family:ui-monospace,monospace}\n",
  )
  out.write_string(
    "details{border:1px solid var(--line);border-radius:8px;padding:10px 14px;margin:8px 0;background:var(--soft)}\n",
  )
  out.write_string("details summary{cursor:pointer;font-size:13px}\n")
  out.write_string("details .row{margin:8px 0 0;font-size:13px}\n")
  out.write_string(
    "details .lbl{color:var(--mute);display:inline-block;width:56px}\n",
  )
  out.write_string(
    "pre{margin:6px 0 0;padding:10px 12px;background:var(--bg);border:1px solid var(--line);border-radius:6px;overflow-x:auto;font-size:13px}\n",
  )
  out.write_string(
    "footer{margin-top:48px;padding-top:16px;border-top:1px solid var(--line);color:var(--mute);font-size:12px}\n",
  )
  out.write_string("</style>\n")
  out.to_string()
}

///|
/// 渲染为**自包含**的静态 HTML（无外部资源），可直接发布为静态页面。
///
/// 与 `to_markdown` 的信息量一致，但多了两点：一致率用条形直观显示；
/// 双向控制符渲染成可见标记（`U+200E` 之类），否则 RTL 期望值会把页面排版带乱、
/// 也看不出差异在哪。
pub fn Report::to_html(self : Report) -> String {
  self.render_html(None)
}

///|
/// 带**差分视图**的 HTML：需要原始结果才能算出两两分歧。
pub fn Report::to_html_with(
  self : Report,
  results : Array[CaseResult],
) -> String {
  self.render_html(Some(results))
}

///|
fn Report::render_html(self : Report, results : Array[CaseResult]?) -> String {
  let out = StringBuilder()
  out.write_string("<!DOCTYPE html>\n<html lang=\"zh-CN\">\n<head>\n")
  out.write_string("<meta charset=\"utf-8\">\n")
  out.write_string(
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n",
  )
  out.write_string("<title>CLDR 一致性报告</title>\n")
  out.write_string(html_style())
  out.write_string("\n</head>\n<body>\n<main>\n")
  out.write_string("<h1>CLDR 一致性报告</h1>\n")
  out.write_string(
    "<p class=\"meta\">数据基线 <code>\{html_escape(self.baseline)}</code> · 用例总数 \{self.summary.total} · 适配器 \{self.adapters.length()} 个</p>\n",
  )
  out.write_string(
    "<p class=\"meta\">一致率分母只含**可比**用例：<code>unsupported</code>（实现无此能力）与 <code>not-installed</code> 不计入。</p>\n",
  )
  // 1) 一致率矩阵
  out.write_string("<h2>一致率矩阵</h2>\n<table>\n<thead><tr>")
  out.write_string(
    "<th>适配器</th><th>套件</th><th class=\"num\">用例</th><th>一致率</th><th class=\"num\">pass</th><th class=\"num\">fail</th><th class=\"num\">errored</th><th class=\"num\">unsupported</th>",
  )
  out.write_string("</tr></thead>\n<tbody>\n")
  for adapter in self.adapters {
    for row in adapter.by_suite {
      render_suite_row(out, adapter.adapter_id, row.suite.label(), row.summary)
    }
    render_suite_row(out, adapter.adapter_id, "合计", adapter.summary)
  }
  out.write_string("</tbody>\n</table>\n")
  // 2) 归因分布
  out.write_string("<h2>失败归因分布</h2>\n")
  for adapter in self.adapters {
    if adapter.by_reason.is_empty() {
      continue
    }
    out.write_string(
      "<h3>\{html_escape(adapter.adapter_id)}</h3>\n<table>\n<thead><tr><th>原因</th><th class=\"num\">次数</th><th>占比</th></tr></thead>\n<tbody>\n",
    )
    let total = adapter.summary.failed
    for entry in adapter.by_reason {
      let share = if total > 0 {
        entry.count.to_double() / total.to_double()
      } else {
        0.0
      }
      out.write_string(
        "<tr><td><code>\{html_escape(entry.reason.label())}</code></td>",
      )
      out.write_string("<td class=\"num\">\{entry.count}</td>")
      out.write_string("<td>\{html_bar(share)}</td></tr>\n")
    }
    out.write_string("</tbody>\n</table>\n")
  }
  // 3) 失败样例
  out.write_string("<h2>失败样例</h2>\n")
  out.write_string(
    "<p class=\"meta\">每个适配器最多展示 \{failure_sample_limit()} 条；计数与分布始终是完整的。控制符以标记形式显示。</p>\n",
  )
  for adapter in self.adapters {
    if adapter.failures.is_empty() {
      continue
    }
    for detail in adapter.failures {
      let summary = "\{html_escape(detail.source)} \{html_escape(detail.location)} · \{html_escape(detail.reason.label())}"
      out.write_string("<details><summary>\{summary}</summary>\n")
      out.write_string(
        "<div class=\"row\"><span class=\"lbl\">期望</span><code>\{html_visible_controls(detail.expected)}</code></div>\n",
      )
      out.write_string(
        "<div class=\"row\"><span class=\"lbl\">实际</span><code>\{html_visible_controls(detail.actual)}</code></div>\n",
      )
      if detail.diff.index >= 0 {
        out.write_string(
          "<div class=\"row\"><span class=\"lbl\">首个差异</span>第 \{detail.diff.index} 个码元<br>期望片段 <code>\{html_visible_controls(detail.diff.expected_snippet)}</code><br>实际片段 <code>\{html_visible_controls(detail.diff.actual_snippet)}</code></div>\n",
        )
      }
      out.write_string("</details>\n")
    }
  }
  // 3.5) 差分视图：两两比较选中适配器的分歧
  match results {
    Some(items) =>
      if self.adapters.length() >= 2 {
        out.write_string("<h2>差分视图</h2>\n")
        out.write_string(
          "<p class=\"meta\">同一个输入下两个实现的行为差异。只统计两边都能判定的用例——能力差异不算分歧。</p>\n",
        )
        let mut index = 0
        while index + 1 < self.adapters.length() {
          let left = self.adapters[index].adapter_id
          let right = self.adapters[index + 1].adapter_id
          let pairs = disagreements(items, left, right, limit=20)
          out.write_string(html_disagreements(pairs, left, right))
          index += 2
        }
      }
    None => ()
  }
  // 4) 复现
  out.write_string("<h2>复现</h2>\n<pre>")
  out.write_string(
    "git clone https://github.com/CCllff-jpg/cldr-conformance &amp;&amp; cd cldr-conformance\nmoon test\nmoon run cmd/conform -- --impls &lt;id&gt; --format html &gt; report.html",
  )
  out.write_string("</pre>\n")
  out.write_string(
    "<footer>数据来自 CLDR 官方测试数据（Unicode License v3），逐文件 SHA256 记录在 <code>DATA-SOURCES.json</code>；本项目只通过公开 API 调用被测实现，不改其源码。<br>本页面由 <code>cldr-conformance</code> 生成，自包含、无外部依赖。</footer>\n",
  )
  out.write_string("</main>\n</body>\n</html>\n")
  out.to_string()
}

///|
fn render_suite_row(
  out : StringBuilder,
  adapter_id : String,
  suite : String,
  summary : RunSummary,
) -> Unit {
  let rate = summary.pass_rate()
  let judged = summary.total - summary.unsupported - summary.not_installed
  let bar_class = if judged == 0 {
    "bar"
  } else if rate < 0.5 {
    "bar bad"
  } else {
    "bar"
  }
  out.write_string(
    "<tr><td><code>\{html_escape(adapter_id)}</code></td><td>\{html_escape(suite)}</td>",
  )
  out.write_string("<td class=\"num\">\{summary.total}</td>")
  out.write_string(
    "<td><div class=\"\{bar_class}\"><span style=\"width:\{(rate * 100.0).to_int()}%\"></span></div> \{summary.pass_rate_text()}</td>",
  )
  out.write_string("<td class=\"num\">\{summary.passed}</td>")
  out.write_string("<td class=\"num\">\{summary.failed}</td>")
  out.write_string("<td class=\"num\">\{summary.errored}</td>")
  out.write_string("<td class=\"num\">\{summary.unsupported}</td></tr>\n")
}

///|
/// 两个适配器在**同一条用例**上的分歧：一边通过、另一边没通过。
///
/// 这是"差分对拍"的直接产物：报告里"库 A 42%、库 B 85%"只能说明各自水平，
/// 而分歧清单指出的是**同一个输入下两者行为不同**——这才是"差在哪里"。
pub(all) struct Disagreement {
  suite : Suite
  source : String
  location : String
  expected : String
  left : CaseOutcome
  right : CaseOutcome
} derive(Debug, Eq)

///|
fn outcome_passed(outcome : CaseOutcome) -> Bool {
  outcome is Pass
}

///|
/// 只有"两边都能判定"的用例才算分歧；能力差异（`unsupported` / `not-installed`）不算。
fn outcome_comparable(outcome : CaseOutcome) -> Bool {
  match outcome {
    Unsupported(_) | NotInstalled => false
    _ => true
  }
}

///|
/// 找出两个适配器在同一条用例上的分歧。
///
/// 用例身份用 `suite + source + location` 三元组（与报告里的定位一致）。
pub fn disagreements(
  results : Array[CaseResult],
  left_id : String,
  right_id : String,
  limit~ : Int32 = -1,
) -> Array[Disagreement] {
  let cap = if limit < 0 { failure_sample_limit() } else { limit }
  let index : Map[String, (Suite, String, String, CaseOutcome)] = Map([])
  for result in results {
    if result.adapter_id == left_id {
      index[case_key(result.suite, result.source, result.location)] = (
        result.suite,
        result.source,
        result.location,
        result.outcome,
      )
    }
  }
  let out : Array[Disagreement] = []
  for result in results {
    if result.adapter_id != right_id || out.length() >= cap {
      continue
    }
    match index.get(case_key(result.suite, result.source, result.location)) {
      Some((suite, source, location, left_outcome)) => {
        let right_outcome = result.outcome
        if outcome_comparable(left_outcome) &&
          outcome_comparable(right_outcome) &&
          outcome_passed(left_outcome) != outcome_passed(right_outcome) {
          out.push({
            suite,
            source,
            location,
            expected: expected_of(right_outcome, left_outcome),
            left: left_outcome,
            right: right_outcome,
          })
        }
      }
      None => ()
    }
  }
  out
}

///|
/// 取两侧的期望值（`Pass` 没有期望值，用另一侧或空串）。
fn expected_of(primary : CaseOutcome, fallback : CaseOutcome) -> String {
  match primary {
    Fail(expected~, ..) => expected
    _ =>
      match fallback {
        Fail(expected~, ..) => expected
        _ => ""
      }
  }
}

///|
fn case_key(suite : Suite, source : String, location : String) -> String {
  "\{suite.label()}|\{source}|\{location}"
}

///|
/// 渲染分歧清单（Markdown）。
pub fn render_disagreements(
  items : Array[Disagreement],
  left_id : String,
  right_id : String,
) -> String {
  let out = StringBuilder()
  out.write_string(
    "### `\{left_id}` 与 `\{right_id}` 的分歧：\{items.length()} 条\n\n",
  )
  if items.is_empty() {
    out.write_string("两边在所有共同可比的用例上结论一致。\n")
    return out.to_string()
  }
  out.write_string(
    "> 只统计两边都能判定的用例；能力差异（unsupported）不算分歧。\n\n",
  )
  out.write_string("| 用例 | 期望 | 结果 |\n|---|---|---|\n")
  for item in items {
    let left = outcome_brief(item.left)
    let right = outcome_brief(item.right)
    out.write_string(
      "| `\{item.source}` \{item.location} | `\{item.expected}` | \{left} · \{right} |\n",
    )
  }
  out.to_string()
}

///|
fn outcome_brief(outcome : CaseOutcome) -> String {
  match outcome {
    Pass => "通过"
    Fail(actual~, ..) => "失败 `\{actual}`"
    Errored(detail~) => "异常 `\{detail}`"
    Unsupported(feature~) => "不支持 \{feature}"
    NotInstalled => "未安装"
  }
}

///|
/// 渲染一对适配器的分歧（HTML）。
fn html_disagreements(
  items : Array[Disagreement],
  left_id : String,
  right_id : String,
) -> String {
  let out = StringBuilder()
  out.write_string(
    "<h3><code>\{html_escape(left_id)}</code> 与 <code>\{html_escape(right_id)}</code> 的分歧：\{items.length()} 条</h3>\n",
  )
  if items.is_empty() {
    out.write_string(
      "<p class=\"meta\">两边在共同可比的用例上结论一致。</p>\n",
    )
    return out.to_string()
  }
  out.write_string(
    "<table><thead><tr><th>用例</th><th>期望</th><th>结论（左 · 右）</th></tr></thead>\n<tbody>\n",
  )
  for item in items {
    out.write_string(
      "<tr><td><code>\{html_escape(item.source)}</code> \{html_escape(item.location)}</td>",
    )
    out.write_string(
      "<td><code>\{html_visible_controls(item.expected)}</code></td>",
    )
    out.write_string(
      "<td>\{html_escape(outcome_brief(item.left))} · \{html_escape(outcome_brief(item.right))}</td></tr>\n",
    )
  }
  out.write_string("</tbody></table>\n")
  out.to_string()
}
