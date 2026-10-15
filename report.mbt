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
