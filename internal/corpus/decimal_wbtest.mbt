///|
/// 把错误渲染成文本用于断言。
///
/// 参数类型写成 `Error`（而不是具体的 `DecimalParseError`）是必要的：
/// 具体 suberror 不实现 `Show`，只有基类型 `Error` 可以插值。
fn error_text(err : Error) -> String {
  "\{err}"
}

///|
test "解析：样式/长度/行号映射正确，且保留空 format_length" {
  let text =
    #|locale	number_format	format_length	input	expected
    #|en	decimal		1.2	1.2
    #|en	decimal	short	1234565.0	1.2M
    #|en	percent		0.5	50%
    #|
  let cases = parse_decimal_cases(parse_tsv(text))
  assert_eq(cases.length(), 3)
  assert_eq(cases[0].locale, "en")
  assert_eq(cases[0].style, @conformance.NumberStyle::DecimalStyle)
  assert_eq(cases[0].length, @conformance.NumberLength::Standard)
  assert_eq(cases[0].input, "1.2")
  assert_eq(cases[0].expected, "1.2")
  assert_eq(cases[0].line, 2)
  assert_eq(cases[1].length, @conformance.NumberLength::Short)
  assert_eq(cases[1].line, 3)
  assert_eq(cases[2].style, @conformance.NumberStyle::PercentStyle)
}

///|
test "解析：long 紧凑格式与 scientific 都能识别" {
  let text =
    #|locale	number_format	format_length	input	expected
    #|de	decimal	long	1234565.0	1,2 Millionen
    #|de	scientific		1234565.0	1,234565E6
    #|
  let cases = parse_decimal_cases(parse_tsv(text))
  assert_eq(cases[0].length, @conformance.NumberLength::Long)
  assert_eq(cases[1].style, @conformance.NumberStyle::ScientificStyle)
}

///|
test "未知 number_format 必须报错，而不是静默跳过" {
  let text = "locale\tnumber_format\tformat_length\tinput\texpected\nen\tordinal\t\t1\t1\n"
  let mut caught = ""
  try parse_decimal_cases(parse_tsv(text)) catch {
    err => caught = error_text(err)
  } noraise {
    _ => ()
  }
  assert_true(caught.contains("UnknownStyle"))
}

///|
test "未知 format_length 必须报错" {
  let text = "locale\tnumber_format\tformat_length\tinput\texpected\nen\tdecimal\tmedium\t1\t1\n"
  let mut caught = ""
  try parse_decimal_cases(parse_tsv(text)) catch {
    err => caught = error_text(err)
  } noraise {
    _ => ()
  }
  assert_true(caught.contains("UnknownLength"))
}

///|
test "缺列与列数不一致都要报错" {
  let mut missing = ""
  try
    parse_decimal_cases(
      parse_tsv("locale\tnumber_format\tinput\texpected\nen\tdecimal\t1\t1\n"),
    )
  catch {
    err => missing = error_text(err)
  } noraise {
    _ => ()
  }
  assert_true(missing.contains("MissingColumn"))

  let mut ragged = ""
  try
    parse_decimal_cases(
      parse_tsv(
        "locale\tnumber_format\tformat_length\tinput\texpected\nen\tdecimal\t\t1\n",
      ),
    )
  catch {
    err => ragged = error_text(err)
  } noraise {
    _ => ()
  }
  assert_true(ragged.contains("RaggedRow"))
}

///|
test "DecimalCorpus：去重排序、按语言过滤" {
  let text =
    #|locale	number_format	format_length	input	expected
    #|ja	decimal		1	1
    #|en	decimal		2	2
    #|ja	percent		3	3
    #|
  let corpus = decimal_corpus_from_tsv(text)
  assert_eq(corpus.length(), 3)
  assert_eq(corpus.locales(), ["en", "ja"])
  assert_eq(corpus.of_locale("ja").length(), 2)
  assert_eq(corpus.of_locale("fr").length(), 0)
}

///|
/// 真实数据回归：`decimals.tsv` 的规模与取值分布在固定数据基线 tag 下是稳定的。
async test "真实文件 decimals.tsv：225 条用例、9 个语言、样式分布正确" {
  let text = @fs.read_file("fixtures/decimal/decimals.tsv").text()
  let corpus = decimal_corpus_from_tsv(text)
  assert_eq(corpus.length(), 225)
  let locales = corpus.locales()
  assert_eq(locales.length(), 9)
  assert_true(locales.contains("ar_EG"))
  assert_true(locales.contains("ru"))
  // 样式分布：decimal 135 / percent 45 / scientific 45
  assert_eq(
    corpus.cases
    .filter(c => c.style == @conformance.NumberStyle::DecimalStyle)
    .length(),
    135,
  )
  assert_eq(
    corpus.cases
    .filter(c => c.style == @conformance.NumberStyle::PercentStyle)
    .length(),
    45,
  )
  assert_eq(
    corpus.cases
    .filter(c => c.style == @conformance.NumberStyle::ScientificStyle)
    .length(),
    45,
  )
  // 紧凑格式分布：未指定 135 / short 45 / long 45
  assert_eq(
    corpus.cases
    .filter(c => c.length == @conformance.NumberLength::Standard)
    .length(),
    135,
  )
  assert_eq(
    corpus.cases
    .filter(c => c.length == @conformance.NumberLength::Short)
    .length(),
    45,
  )
  assert_eq(
    corpus.cases
    .filter(c => c.length == @conformance.NumberLength::Long)
    .length(),
    45,
  )
  // 每行都必须有输入与期望值
  assert_true(corpus.cases.all(c => c.input != "" && c.expected != ""))
  // 行号连续覆盖源文件（表头是第 1 行）
  assert_eq(corpus.cases[0].line, 2)
  assert_eq(corpus.cases[224].line, 226)
}

///|
async test "真实文件 decimals_modern_locales.tsv：2400 条用例、96 个语言" {
  let text = @fs.read_file("fixtures/decimal/decimals_modern_locales.tsv").text()
  let corpus = decimal_corpus_from_tsv(text)
  assert_eq(corpus.length(), 2400)
  assert_eq(corpus.locales().length(), 96)
}
