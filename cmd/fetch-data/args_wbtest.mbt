///|
test "flag_value 取到紧跟的值" {
  let args = ["--url", "https://example.com/x", "--out", "fixtures/x"]
  assert_eq(flag_value(args, "--url"), Some("https://example.com/x"))
  assert_eq(flag_value(args, "--out"), Some("fixtures/x"))
}

///|
test "flag_value 缺值或参数缺失时返回 None" {
  assert_eq(flag_value(["--url"], "--url"), None)
  assert_eq(flag_value([], "--url"), None)
  assert_eq(flag_value(["--other", "v"], "--url"), None)
}

///|
test "flag_value 只取第一个匹配，避免被后续同名的值覆盖" {
  assert_eq(
    flag_value(["--url", "first", "--url", "second"], "--url"),
    Some("first"),
  )
}

///|
test "has_flag 识别无值开关" {
  assert_true(has_flag(["--verify"], "--verify"))
  assert_true(has_flag(["--verify", "--manifest", "m.json"], "--verify"))
  assert_false(has_flag(["--manifest", "m.json"], "--verify"))
  assert_false(has_flag([], "--verify"))
}

///|
test "has_flag 不会把值当成开关" {
  // 值里出现同名文本不算开关（只做整参数匹配）
  assert_false(has_flag(["--out", "verify"], "--verify"))
}
