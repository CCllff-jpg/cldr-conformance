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
  assert_eq(labels.length(), 8)
  assert_eq(
    @cldr-conformance.FailReason::GroupingMismatch.label(),
    "grouping-mismatch",
  )
  assert_eq(@cldr-conformance.FailReason::Other.label(), "other")
}
