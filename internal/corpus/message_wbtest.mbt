///|
test "合并文件级默认值：继承 expErrors 与 locale" {
  let text =
    #|{"scenario":"Syntax errors","defaultTestProperties":{"locale":"en-US","expErrors":[{"type":"syntax-error"}]},"tests":[{"src":"."},{"src":"{","locale":"de","expErrors":[{"type":"bad-operand"}]}]}
    #|
  let cases = parse_message_tests("syntax-errors.json", text)
  assert_eq(cases.length(), 2)
  // 第 1 条：完全继承默认值
  assert_eq(cases[0].file, "syntax-errors.json")
  assert_eq(cases[0].scenario, "Syntax errors")
  assert_eq(cases[0].locale, "en-US")
  assert_eq(cases[0].expected_errors, ["syntax-error"])
  assert_eq(cases[0].exp, None)
  assert_eq(cases[0].index, 0)
  // 第 2 条：用例级覆盖 locale 与 expErrors
  assert_eq(cases[1].locale, "de")
  assert_eq(cases[1].expected_errors, ["bad-operand"])
  // 默认值必须被复制而不是共享（否则改一条会影响另一条）
  assert_true(cases[0].expected_errors != cases[1].expected_errors)
}

///|
test "可选字段：exp / description / params / expParts / tags" {
  let text =
    #|{"scenario":"Syntax","defaultTestProperties":{"locale":"en-US","bidiIsolation":"none"},"tests":[{"src":"{1}","exp":"1","description":"d","params":{"x":1},"expParts":[{"type":"text"}],"tags":["u:id"]}]}
    #|
  let cases = parse_message_tests("syntax.json", text)
  assert_eq(cases.length(), 1)
  assert_eq(cases[0].exp, Some("1"))
  assert_eq(cases[0].description, Some("d"))
  assert_eq(cases[0].bidi_isolation, Some("none"))
  assert_eq(cases[0].expects_parts, true)
  assert_eq(cases[0].tags, ["u:id"])
  assert_true(cases[0].params_json is Some(_))
}

///|
test "未知字段必须报错（文件级 / 默认值级 / 用例级 / 错误条目级）" {
  // 注意：`locale` 是必需字段，且解析器**先校验它**。要触达更深的检查（如 expErrors
  // 内部结构），样例必须自带 locale，否则会先报 MissingField(locale)。
  let samples = [
    (
      "syntax.json", "{\"scenario\":\"S\",\"unexpected\":1,\"tests\":[]}", "UnknownField",
    ),
    (
      "syntax.json", "{\"scenario\":\"S\",\"defaultTestProperties\":{\"locale\":\"en\",\"newOption\":1},\"tests\":[]}",
      "UnknownField",
    ),
    (
      "syntax.json", "{\"scenario\":\"S\",\"tests\":[{\"src\":\"x\",\"newField\":1}]}",
      "UnknownField",
    ),
    (
      "syntax.json", "{\"scenario\":\"S\",\"tests\":[{\"src\":\"x\",\"locale\":\"en\",\"expErrors\":[{\"type\":\"t\",\"extra\":1}]}]}",
      "Malformed",
    ),
  ]
  for sample in samples {
    let (file, text, expected) = sample
    let mut caught = ""
    try parse_message_tests(file, text) catch {
      err => caught = error_text(err)
    } noraise {
      _ => ()
    }
    if !caught.contains(expected) {
      fail(
        "样例未按预期报错：期望含 \{expected}，实际 \{caught}",
      )
    }
  }
}

///|
test "缺字段与类型错误都要报错" {
  let samples = [
    ("syntax.json", "{\"tests\":[]}", "MissingField"),
    ("syntax.json", "{\"scenario\":\"S\"}", "MissingField"),
    ("syntax.json", "{\"scenario\":\"S\",\"tests\":[{}]}", "MissingField"),
    // 用例既没写 locale，默认值里也没有 → 必须报缺 locale
    (
      "syntax.json", "{\"scenario\":\"S\",\"tests\":[{\"src\":\"x\"}]}", "MissingField",
    ),
    ("syntax.json", "{\"scenario\":\"S\",\"tests\":{}}", "WrongType"),
    ("syntax.json", "{\"scenario\":\"S\",\"tests\":[1]}", "Malformed"),
    (
      "syntax.json", "{\"scenario\":\"S\",\"tests\":[{\"src\":1,\"locale\":\"en\"}]}",
      "WrongType",
    ),
    (
      "syntax.json", "{\"scenario\":\"S\",\"tests\":[{\"src\":\"x\",\"locale\":\"en\",\"tags\":[1]}]}",
      "WrongType",
    ),
    (
      "syntax.json", "{\"scenario\":\"S\",\"defaultTestProperties\":{\"expErrors\":{}},\"tests\":[]}",
      "WrongType",
    ),
  ]
  for sample in samples {
    let (file, text, expected) = sample
    let mut caught = ""
    try parse_message_tests(file, text) catch {
      err => caught = error_text(err)
    } noraise {
      _ => ()
    }
    if !caught.contains(expected) {
      fail(
        "样例未按预期报错：期望含 \{expected}，实际 \{caught}",
      )
    }
  }
}

///|
/// 真实数据回归：7 个文件、337 条用例，规模与分布绑定于固定数据基线 tag。
async test "真实文件：7 个 MF2 文件共 337 条用例" {
  let dir = "fixtures/messageFormat/tests"
  let expected_counts = [
    ("syntax.json", 114),
    ("syntax-errors.json", 133),
    ("data-model-errors.json", 23),
    ("pattern-selection.json", 22),
    ("fallback.json", 8),
    ("bidi.json", 27),
    ("u-options.json", 10),
  ]
  let all : Array[@conformance.MessageCase] = []
  for entry in expected_counts {
    let (file, expected) = entry
    let cases = parse_message_tests(
      file,
      @fs.read_file("\{dir}/\{file}").text(),
    )
    assert_eq(cases.length(), expected)
    for item in cases {
      all.push(item)
    }
  }
  let corpus = @conformance.MessageCorpus::new(all)
  assert_eq(corpus.length(), 337)
  assert_eq(corpus.files().length(), 7)
  assert_eq(corpus.scenarios().length(), 7)
  assert_eq(corpus.of_scenario("Syntax").length(), 114)
}

///|
/// 默认值合并的真实证据：`syntax-errors.json` 的 133 条**全部**靠继承拿到期望错误。
async test "真实文件：syntax-errors.json 的 133 条全部继承默认 expErrors" {
  let cases = parse_message_tests(
    "syntax-errors.json",
    @fs.read_file("fixtures/messageFormat/tests/syntax-errors.json").text(),
  )
  assert_eq(cases.length(), 133)
  assert_true(cases.all(c => c.expected_errors == ["syntax-error"]))
  assert_true(cases.all(c => c.exp == None))
  assert_true(cases.all(c => c.locale == "en-US"))
}

///|
async test "真实文件：u-options 的 tags 与 bidi 的隔离设置" {
  let u = parse_message_tests(
    "u-options.json",
    @fs.read_file("fixtures/messageFormat/tests/u-options.json").text(),
  )
  assert_eq(u.filter(c => c.tags.length() > 0).length(), 9)
  assert_true(u.all(c => c.bidi_isolation == Some("default")))
  let bidi = parse_message_tests(
    "bidi.json",
    @fs.read_file("fixtures/messageFormat/tests/bidi.json").text(),
  )
  assert_eq(bidi.length(), 27)
  assert_true(bidi.all(c => c.bidi_isolation == Some("default")))
}
