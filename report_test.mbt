///|
test "char_diff：定位首个差异并给出两侧片段" {
  let diff = @cldr-conformance.char_diff("1,234", "1234")
  assert_eq(diff.index, 1)
  assert_eq(diff.expected_snippet, "1,234")
  assert_eq(diff.actual_snippet, "1234")
  assert_eq(diff.expected_length, 5)
  assert_eq(diff.actual_length, 4)
}

///|
test "char_diff：相同时 index 为 -1；前缀关系定位到短串末尾" {
  assert_eq(@cldr-conformance.char_diff("abc", "abc").index, -1)
  assert_eq(@cldr-conformance.char_diff("1.2", "1.23").index, 3)
  assert_eq(@cldr-conformance.char_diff("", "").index, -1)
  assert_eq(@cldr-conformance.char_diff("", "x").index, 0)
}

///|
test "char_diff：长串截断为窗口片段并带省略号" {
  let head = "abcdefghijklmnopqrstuvwxyz0123456789"
  let diff = @cldr-conformance.char_diff(head + "A", head + "B")
  assert_eq(diff.index, 36)
  assert_true(diff.expected_snippet.has_prefix("…"))
  assert_true(diff.expected_snippet.has_suffix("A"))
  assert_true(diff.actual_snippet.has_suffix("B"))
  // 片段必须比原文短，否则报告里会塞进整串
  assert_true(diff.expected_snippet.length() < diff.expected_length + 2)
}

///|
test "FailReason 的稳定标识互不重复" {
  let labels : Array[String] = []
  for reason in @cldr-conformance.FailReason::all() {
    let label = reason.label()
    assert_false(labels.contains(label))
    labels.push(label)
  }
  assert_eq(labels.length(), 13)
  assert_eq(
    @cldr-conformance.FailReason::GroupingMismatch.label(),
    "grouping-mismatch",
  )
  assert_eq(@cldr-conformance.FailReason::Other.label(), "other")
}

///|
fn failing(
  adapter : String,
  suite : @cldr-conformance.Suite,
  location : String,
  expected : String,
  actual : String,
) -> @cldr-conformance.CaseResult {
  {
    suite,
    adapter_id: adapter,
    source: "decimals.tsv",
    location,
    outcome: @cldr-conformance.CaseOutcome::Fail(
      reason=@cldr-conformance.FailReason::GroupingMismatch,
      expected~,
      actual~,
    ),
    elapsed_ms: 1,
  }
}

///|
fn passing(
  adapter : String,
  suite : @cldr-conformance.Suite,
) -> @cldr-conformance.CaseResult {
  {
    suite,
    adapter_id: adapter,
    source: "decimals.tsv",
    location: "L1",
    outcome: @cldr-conformance.CaseOutcome::Pass,
    elapsed_ms: 1,
  }
}

///|
/// 关键性质：明细有上限，但**计数与归因分布始终完整**。
test "报告：明细受上限截断，计数不受影响" {
  let results : Array[@cldr-conformance.CaseResult] = [
    passing("a", @cldr-conformance.Suite::Decimal),
  ]
  let mut index = 0
  while index < 25 {
    results.push(
      failing(
        "a",
        @cldr-conformance.Suite::Decimal,
        "L\{index + 2}",
        "1,234",
        "1234",
      ),
    )
    index += 1
  }
  let report = @cldr-conformance.Report::from_results("tag", ["a"], results)
  assert_eq(report.summary.total, 26)
  assert_eq(report.summary.passed, 1)
  assert_eq(report.summary.failed, 25)
  let adapter = report.adapters[0]
  assert_eq(adapter.failures.length(), @cldr-conformance.failure_sample_limit())
  // 归因计数仍然是全部 25 条
  assert_eq(adapter.by_reason.length(), 1)
  assert_eq(
    adapter.by_reason[0].reason,
    @cldr-conformance.FailReason::GroupingMismatch,
  )
  assert_eq(adapter.by_reason[0].count, 25)
  // 按套件拆分
  assert_eq(adapter.by_suite.length(), 1)
  assert_eq(adapter.by_suite[0].summary.failed, 25)
}

///|
test "报告：多个适配器各自统计，顺序由 adapter_ids 决定" {
  let results = [
    passing("first", @cldr-conformance.Suite::Decimal),
    failing("second", @cldr-conformance.Suite::Decimal, "L2", "1,234", "1234"),
  ]
  let report = @cldr-conformance.Report::from_results(
    "tag",
    ["second", "first"],
    results,
  )
  assert_eq(report.adapters.map(a => a.adapter_id), ["second", "first"])
  assert_eq(report.adapters[0].summary.failed, 1)
  assert_eq(report.adapters[0].summary.passed, 0)
  assert_eq(report.adapters[1].summary.passed, 1)
}

///|
test "一致率：分母排除 unsupported 与 not-installed" {
  let summary = @cldr-conformance.RunSummary::{
    total: 4,
    passed: 1,
    failed: 1,
    errored: 0,
    unsupported: 1,
    not_installed: 1,
  }
  // 分母 = 4 - 1 - 1 = 2，其中 1 条通过 → 50%
  assert_eq(summary.pass_rate_text(), "50%")
  assert_eq(
    @cldr-conformance.RunSummary::{
      total: 0,
      passed: 0,
      failed: 0,
      errored: 0,
      unsupported: 0,
      not_installed: 0,
    }.pass_rate_text(),
    "0%",
  )
  assert_eq(
    @cldr-conformance.RunSummary::{
      total: 2,
      passed: 2,
      failed: 0,
      errored: 0,
      unsupported: 0,
      not_installed: 0,
    }.pass_rate_text(),
    "100%",
  )
}

///|
test "JSON 报告：可被解析且含稳定键" {
  let results = [
    failing(
      "adapter-a",
      @cldr-conformance.Suite::Decimal,
      "L2",
      "1,234",
      "1234",
    ),
    @cldr-conformance.CaseResult::{
      suite: @cldr-conformance.Suite::Datetime,
      adapter_id: "adapter-a",
      source: "datetime.json",
      location: "#7",
      outcome: @cldr-conformance.CaseOutcome::Errored(detail="boom"),
      elapsed_ms: 3,
    },
  ]
  let report = @cldr-conformance.Report::from_results(
    "release-49-beta3",
    ["adapter-a"],
    results,
  )
  let json = report.to_json()
  // 能被解析（结构合法）
  ignore(@json.parse(json))
  assert_true(json.contains("\"baseline\": \"release-49-beta3\""))
  assert_true(json.contains("\"adapter_id\": \"adapter-a\""))
  assert_true(json.contains("\"reason\": \"grouping-mismatch\""))
  assert_true(json.contains("\"by_suite\""))
  assert_true(json.contains("\"pass_rate\""))
  assert_true(json.contains("boom"))
  // errored 与 fail 分列
  assert_true(json.contains("\"errors\""))
}

///|
test "Markdown 报告：含矩阵、归因分布与字符级差异" {
  let results = [
    failing(
      "adapter-a",
      @cldr-conformance.Suite::Decimal,
      "L2",
      "1,234",
      "1234",
    ),
    @cldr-conformance.CaseResult::{
      suite: @cldr-conformance.Suite::MessageFormat2,
      adapter_id: "adapter-a",
      source: "syntax.json",
      location: "#3",
      outcome: @cldr-conformance.CaseOutcome::Errored(detail="崩溃"),
      elapsed_ms: 0,
    },
  ]
  let report = @cldr-conformance.Report::from_results(
    "release-49-beta3",
    ["adapter-a"],
    results,
  )
  let md = report.to_markdown()
  assert_true(md.contains("# CLDR 一致性报告"))
  assert_true(md.contains("release-49-beta3"))
  assert_true(md.contains("## 一致率矩阵"))
  assert_true(md.contains("| 适配器 | 套件 | 用例 | 一致率 |"))
  assert_true(md.contains("## 失败归因分布"))
  assert_true(md.contains("grouping-mismatch"))
  assert_true(md.contains("## 失败样例"))
  assert_true(md.contains("首个差异在第 1 个码元"))
  assert_true(md.contains("errored"))
  assert_true(md.contains("崩溃"))
}

///|
test "to_html：自包含、转义、控制符可视化" {
  let results : Array[@cldr-conformance.CaseResult] = [
    {
      suite: @cldr-conformance.Suite::Decimal,
      adapter_id: "demo",
      source: "decimals.tsv",
      location: "L3",
      outcome: @cldr-conformance.CaseOutcome::Fail(
        reason=@cldr-conformance.FailReason::GroupingMismatch,
        expected="1,234",
        actual="1 234",
      ),
      elapsed_ms: 0,
    },
    {
      suite: @cldr-conformance.Suite::Decimal,
      adapter_id: "demo",
      source: "decimals.tsv",
      location: "L4",
      outcome: @cldr-conformance.CaseOutcome::Fail(
        reason=@cldr-conformance.FailReason::BidiControlMissing,
        expected="0\u{200E}%\u{200E}",
        actual="0%",
      ),
      elapsed_ms: 0,
    },
    {
      suite: @cldr-conformance.Suite::Decimal,
      adapter_id: "demo",
      source: "decimals.tsv",
      location: "L5",
      outcome: @cldr-conformance.CaseOutcome::Fail(
        reason=@cldr-conformance.FailReason::ValueMismatch,
        expected="a<b & c",
        actual="a>b",
      ),
      elapsed_ms: 0,
    },
  ]
  let report = @cldr-conformance.Report::from_results(
    "release-49-beta3",
    ["demo"],
    results,
  )
  let html = report.to_html()
  // 基本结构
  assert_true(html.contains("<!DOCTYPE html>"))
  assert_true(html.contains("<style>"))
  assert_true(html.contains("一致率矩阵"))
  assert_true(html.contains("失败归因分布"))
  // **自包含**：没有脚本、没有外链（可直接发布为静态页）
  assert_false(html.contains("<script"))
  assert_false(html.contains("http://"))
  // 控制符可视化：不留裸控制符，改为标记
  assert_false(html.contains("\u{200E}"))
  assert_true(html.contains("U+200E"))
  // HTML 转义：期望值里的 < > & 不能原样进文档
  assert_false(html.contains("a<b & c"))
  assert_true(html.contains("a&lt;b &amp; c"))
}

///|
test "disagreements：只算两边都能判定的分歧" {
  let pass : @cldr-conformance.CaseOutcome = @cldr-conformance.CaseOutcome::Pass
  let results : Array[@cldr-conformance.CaseResult] = [
    // 一致通过：不算分歧
    {
      suite: @cldr-conformance.Suite::Plural,
      adapter_id: "a",
      source: "plurals.xml",
      location: "L1",
      outcome: pass,
      elapsed_ms: 0,
    },
    {
      suite: @cldr-conformance.Suite::Plural,
      adapter_id: "b",
      source: "plurals.xml",
      location: "L1",
      outcome: pass,
      elapsed_ms: 0,
    },
    // 分歧：a 通过、b 失败
    {
      suite: @cldr-conformance.Suite::Plural,
      adapter_id: "a",
      source: "plurals.xml",
      location: "L2",
      outcome: pass,
      elapsed_ms: 0,
    },
    {
      suite: @cldr-conformance.Suite::Plural,
      adapter_id: "b",
      source: "plurals.xml",
      location: "L2",
      outcome: @cldr-conformance.CaseOutcome::Fail(
        reason=@cldr-conformance.FailReason::PluralCategoryMismatch,
        expected="other",
        actual="one",
      ),
      elapsed_ms: 0,
    },
    // 能力差异：不算分歧
    {
      suite: @cldr-conformance.Suite::Plural,
      adapter_id: "a",
      source: "plurals.xml",
      location: "L3",
      outcome: pass,
      elapsed_ms: 0,
    },
    {
      suite: @cldr-conformance.Suite::Plural,
      adapter_id: "b",
      source: "plurals.xml",
      location: "L3",
      outcome: @cldr-conformance.CaseOutcome::Unsupported(feature="plural"),
      elapsed_ms: 0,
    },
  ]
  let items = @cldr-conformance.disagreements(results, "a", "b", limit=10)
  assert_eq(items.length(), 1)
  assert_eq(items[0].location, "L2")
  assert_eq(items[0].expected, "other")
  // 渲染里应当同时给出两边的结论
  let markdown = @cldr-conformance.render_disagreements(items, "a", "b")
  assert_true(markdown.contains("分歧：1 条"))
  assert_true(markdown.contains("通过 · 失败"))
}
