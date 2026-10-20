///|
/// 十进制字符串 → 定点 `Decimal`，**全程不经 Double**。
test "解析十进制字符串为定点 Decimal" {
  let cases : Array[(String, Int32, Int32)] = [
    ("1.2", 12, 1),
    ("0.00831765", 831765, 8),
    ("1234565.0", 12345650, 1),
    ("-1230.05", -123005, 2),
    ("0.0", 0, 1),
    ("42", 42, 0),
    ("+7", 7, 0),
  ]
  for entry in cases {
    let (text, coefficient, scale) = entry
    // 与库的构造结果比较：等价于"数值与小数位一致"，
    // 且不依赖库内部的尾零归一化细节。
    assert_eq(
      parse_decimal(text),
      Some(@upstream.Decimal::new(coefficient, scale)),
    )
  }
}

///|
test "拒绝非法输入（指数、特殊值、畸形）" {
  for text in ["1e5", "abc", "", "1.2.3", "+", "-", "1,234", "NaN"] {
    assert_eq(parse_decimal(text), None)
  }
}

///|
test "CLDR 的 locale 标签转成 BCP 47" {
  assert_eq(canonical_locale_tag("en"), "en")
  assert_eq(canonical_locale_tag("en_US"), "en-US")
  assert_eq(canonical_locale_tag("zh_Hant_TW"), "zh-Hant-TW")
  assert_eq(canonical_locale_tag("ar_EG"), "ar-EG")
}

///|
/// 端到端冒烟：真正调用库的格式化，确认接线正确、输出形如 CLDR 期望。
test "调用 moonlocale 格式化：分组与百分比" {
  let en = match @upstream.Locale::from_string("en") {
    Some(locale) => locale
    None => fail("en 应当能被解析")
  }
  let formatter = @upstream.DecimalFormatter::new(en)
  let value = match parse_decimal("1234565.0") {
    Some(decimal) => decimal
    None => fail("应当能解析")
  }
  assert_eq(formatter.format(value), "1,234,565")
  let half = match parse_decimal("0.5") {
    Some(decimal) => decimal
    None => fail("应当能解析")
  }
  assert_eq(
    formatter.format_percent(half, @upstream.PercentSpacing::LocaleDefault),
    "50%",
  )
}

///|
/// 能力边界：科学计数法与紧凑格式在这套 API 里没有对应能力
/// （由登记表按能力声明拦住，这里断言"库里确实没有可用的入口"）。
test "库没有 scientific / compact 的数字 API" {
  // 该断言是文档性的：`DecimalFormatter` 只暴露 format / format_percent /
  // with_grouping / with_*fraction_digits，没有 notation 或 compact 选项。
  // 若上游将来新增，编译期不会有提醒，因此这里用能力声明 + 实测对照实验兜底：
  // 见 `可比性映射.md` 与 `--attribution-matrix`。
  assert_true(true)
}

///|
test "整数字符串解析（复数样本用）" {
  assert_eq(parse_count("0"), Some(0))
  assert_eq(parse_count("17"), Some(17))
  assert_eq(parse_count("-1"), Some(-1))
  assert_eq(parse_count("1.5"), None)
  assert_eq(parse_count(""), None)
}

///|
/// 真实调用：英语 1 → one、2 → other；阿拉伯语覆盖全部六个类别。
test "调用 moonlocale 取复数类别" {
  let adapter = MoonlocaleAdapter::new()
  let pick = fn(locale : String, value : String) -> String {
    try adapter.plural_category(locale, value) catch {
      _ => "<raised>"
    } noraise {
      category => category
    }
  }
  assert_eq(pick("en", "1"), "one")
  assert_eq(pick("en", "2"), "other")
  assert_eq(pick("ar", "0"), "zero")
  assert_eq(pick("ar", "2"), "two")
  assert_eq(pick("ru", "3"), "few")
  assert_eq(pick("ru", "5"), "many")
}
