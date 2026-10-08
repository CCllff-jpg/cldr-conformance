///|
test "Suite::all 覆盖全部套件且顺序稳定" {
  let suites = @cldr-conformance.Suite::all()
  assert_eq(suites.length(), 3)
  assert_eq(suites[0], @cldr-conformance.Suite::Decimal)
  assert_eq(suites[2], @cldr-conformance.Suite::MessageFormat2)
}

///|
test "Suite::label 是报告中的稳定标识" {
  assert_eq(@cldr-conformance.Suite::Decimal.label(), "decimal")
  assert_eq(@cldr-conformance.Suite::Datetime.label(), "datetime")
  assert_eq(@cldr-conformance.Suite::MessageFormat2.label(), "message-format-2")
}

///|
test "CaseOutcome 区分失败与不支持能力" {
  let failed = @cldr-conformance.CaseOutcome::Fail(
    reason=@cldr-conformance.FailReason::GroupingMismatch,
    expected="১২,৩৪,৫৬৫",
    actual="১২৩,৪৫৬৫",
  )
  let unsupported = @cldr-conformance.CaseOutcome::Unsupported(
    feature="compact short",
  )
  assert_true(failed != unsupported)
  debug_inspect(
    failed,
    content="Fail(reason=GroupingMismatch, expected=\"১২,৩৪,৫৬৫\", actual=\"১২৩,৪৫৬৫\")",
  )
}
