///|
test "骨架 TSV：字段与行号映射正确" {
  let text =
    #|locale	calendar	skeleton	pattern
    #|en_US	gregorian	yMd	M/d/y
    #|en_US	coptic	yMd	M/d/y G
    #|
  let cases = parse_skeleton_cases(parse_tsv(text))
  assert_eq(cases.length(), 2)
  assert_eq(cases[0].locale, "en_US")
  assert_eq(cases[0].calendar, "gregorian")
  assert_eq(cases[0].skeleton, "yMd")
  assert_eq(cases[0].pattern, "M/d/y")
  assert_eq(cases[0].line, 2)
  assert_eq(cases[1].pattern, "M/d/y G")
}

///|
test "骨架 TSV：缺列与列数不一致都要报错" {
  let mut missing = ""
  try
    parse_skeleton_cases(
      parse_tsv("locale\tcalendar\tskeleton\nen\tgregorian\tyMd\n"),
    )
  catch {
    err => missing = error_text(err)
  } noraise {
    _ => ()
  }
  assert_true(missing.contains("MissingColumn"))

  let mut ragged = ""
  try
    parse_skeleton_cases(
      parse_tsv("locale\tcalendar\tskeleton\tpattern\nen\tgregorian\tyMd\n"),
    )
  catch {
    err => ragged = error_text(err)
  } noraise {
    _ => ()
  }
  assert_true(ragged.contains("RaggedRow"))
}

///|
test "datetime.json：必填字段与可选字段都正确映射" {
  let text =
    #|[{"locale":"en","calendar":"gregorian","input":"2000-01-01T00:00Z[Etc/GMT]","expected":"12:00 AM","timeLength":"short"},{"locale":"ja-JP","calendar":"japanese","input":"2024-07-01T08:50:07Z[Etc/GMT]","expected":"8:50","semanticSkeleton":"Hm","zoneStyle":"short"}]
    #|
  let cases = parse_datetime_json(text)
  assert_eq(cases.length(), 2)
  assert_eq(cases[0].locale, "en")
  assert_eq(cases[0].input, "2000-01-01T00:00Z[Etc/GMT]")
  assert_eq(cases[0].expected, "12:00 AM")
  assert_eq(cases[0].time_length, Some("short"))
  assert_eq(cases[0].semantic_skeleton, None)
  assert_eq(cases[0].index, 0)
  assert_eq(cases[1].calendar, "japanese")
  assert_eq(cases[1].semantic_skeleton, Some("Hm"))
  assert_eq(cases[1].zone_style, Some("short"))
  assert_eq(cases[1].index, 1)
}

///|
test "datetime.json：未知字段必须报错（否则会静默漏测新能力）" {
  let text =
    #|[{"locale":"en","calendar":"gregorian","input":"x","expected":"y","dayPeriodStyle":"wide"}]
    #|
  let mut caught = ""
  try parse_datetime_json(text) catch {
    err => caught = error_text(err)
  } noraise {
    _ => ()
  }
  assert_true(caught.contains("UnknownField"))
}

///|
test "datetime.json：缺字段 / 类型不对 / 非数组 / 元素非对象都要报错" {
  let cases = [
    (
      "[{\"locale\":\"en\",\"calendar\":\"gregorian\",\"input\":\"x\"}]", "MissingField",
    ),
    (
      "[{\"locale\":1,\"calendar\":\"gregorian\",\"input\":\"x\",\"expected\":\"y\"}]",
      "WrongType",
    ),
    ("{\"locale\":\"en\"}", "NotAnArray"),
    ("[\"not an object\"]", "NotAnObject"),
  ]
  for entry in cases {
    let (text, expected) = entry
    let mut caught = ""
    try parse_datetime_json(text) catch {
      err => caught = error_text(err)
    } noraise {
      _ => ()
    }
    assert_true(caught.contains(expected))
  }
}

///|
test "DatetimeCorpus：两个来源的语言与日历会合并去重" {
  let skeletons =
    #|locale	calendar	skeleton	pattern
    #|en_US	gregorian	yMd	M/d/y
    #|fr	hebrew	yMd	M/d/y
    #|
  let formattedText =
    #|[{"locale":"ja-JP","calendar":"japanese","input":"x","expected":"y"}]
    #|
  let empty = "locale\tcalendar\tskeleton\tpattern\n"
  let corpus = datetime_corpus_from_text(skeletons, empty, formattedText)
  assert_eq(corpus.length(), 3)
  assert_eq(corpus.locales(), ["en_US", "fr", "ja-JP"])
  assert_eq(corpus.calendars(), ["gregorian", "hebrew", "japanese"])
}

///|
/// 真实数据回归：规模、语言、日历与可选字段分布都绑定于固定数据基线 tag。
async test "真实文件：skeletons.tsv 360 条 / all_calendars 1080 条" {
  let skeletons = parse_skeleton_cases(
    parse_tsv(@fs.read_file("fixtures/datetime/skeletons.tsv").text()),
  )
  assert_eq(skeletons.length(), 360)
  let calendars : Map[String, Unit] = Map([])
  for item in skeletons {
    calendars[item.calendar] = ()
  }
  assert_eq(calendars.length(), 4)
  assert_true(calendars.contains("gregorian"))
  assert_true(calendars.contains("chinese"))

  let all = parse_skeleton_cases(
    parse_tsv(
      @fs.read_file("fixtures/datetime/skeletons_all_calendars.tsv").text(),
    ),
  )
  assert_eq(all.length(), 1080)
  let all_calendars : Map[String, Unit] = Map([])
  for item in all {
    all_calendars[item.calendar] = ()
  }
  assert_eq(all_calendars.length(), 12)
  assert_true(all_calendars.contains("islamic-umalqura"))
}

///|
async test "真实文件 datetime.json：312 条 / 4 语言 / 4 日历 / 可选字段分布" {
  let cases = parse_datetime_json(
    @fs.read_file("fixtures/datetime/datetime.json").text(),
  )
  assert_eq(cases.length(), 312)
  let corpus = @conformance.DatetimeCorpus::new([], cases)
  assert_eq(corpus.locales(), ["ar-SA", "en", "ja-JP", "th-TH"])
  assert_eq(corpus.calendars(), [
    "buddhist", "gregorian", "islamic-civil", "japanese",
  ])
  // 可选字段的出现次数（上游数据基线固定，因此这些数字是稳定的）
  assert_eq(cases.filter(c => c.semantic_skeleton is Some(_)).length(), 240)
  assert_eq(cases.filter(c => c.classical_skeleton is Some(_)).length(), 240)
  assert_eq(
    cases.filter(c => c.semantic_skeleton_length is Some(_)).length(),
    224,
  )
  assert_eq(cases.filter(c => c.zone_style is Some(_)).length(), 96)
  assert_eq(cases.filter(c => c.time_length is Some(_)).length(), 60)
  assert_eq(cases.filter(c => c.date_length is Some(_)).length(), 60)
  assert_eq(cases.filter(c => c.hour_cycle is Some(_)).length(), 48)
  assert_eq(cases.filter(c => c.year_style is Some(_)).length(), 36)
  assert_eq(cases.filter(c => c.date_time_format_type is Some(_)).length(), 12)
  // 每条都必须有输入与期望值
  assert_true(cases.all(c => c.input != "" && c.expected != ""))
}
