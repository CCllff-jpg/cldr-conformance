///|
test "整数字符串解析" {
  assert_eq(parse_count("0"), Some(0))
  assert_eq(parse_count("17"), Some(17))
  assert_eq(parse_count("1000000"), Some(1000000))
  assert_eq(parse_count("-1"), Some(-1))
  assert_eq(parse_count("1.5"), None)
  assert_eq(parse_count(""), None)
  assert_eq(parse_count("abc"), None)
}

///|
/// 真实调用：英语对 1 是 one、对 2 是 other（CLDR 的 cardinal 规则）。
test "调用 moon_l10n 取复数类别" {
  let adapter = MoonL10nPluralAdapter::new()
  let one = try adapter.plural_category("en", "1") catch {
    _ => "<raised>"
  } noraise {
    value => value
  }
  assert_eq(one, "one")
  let other = try adapter.plural_category("en", "2") catch {
    _ => "<raised>"
  } noraise {
    value => value
  }
  assert_eq(other, "other")
}
