///|
/// CLDR 用例的参数形如 `{"name": "x", "value": 1}`，这里覆盖四种取值形态。
test "参数解析：字符串 / 整数 / 小数 / 布尔 / 缺省" {
  assert_eq(
    parse_arguments(Some("{\"name\":\"place\",\"value\":\"world\"}")).length(),
    1,
  )
  assert_eq(parse_arguments(Some("{\"name\":\"x\",\"value\":1}")).length(), 1)
  assert_eq(parse_arguments(Some("{\"name\":\"x\",\"value\":1.0}")).length(), 1)
  assert_eq(
    parse_arguments(Some("{\"name\":\"x\",\"value\":true}")).length(),
    1,
  )
  // 无参数 / 解析失败都退化为空数组，不抛异常
  assert_eq(parse_arguments(None).length(), 0)
  assert_eq(parse_arguments(Some("not json")).length(), 0)
  assert_eq(parse_arguments(Some("")).length(), 0)
}

///|
test "错误码映射到 CLDR 的 expErrors 词表" {
  assert_eq(error_type(@mf2.Mf2ErrorCode::Mf2SyntaxCode), "syntax-error")
  assert_eq(
    error_type(@mf2.Mf2ErrorCode::Mf2UnresolvedVariableCode),
    "unresolved-variable",
  )
  assert_eq(
    error_type(@mf2.Mf2ErrorCode::Mf2UnknownFunctionCode),
    "unknown-function",
  )
  assert_eq(error_type(@mf2.Mf2ErrorCode::Mf2BadOperandCode), "bad-operand")
  assert_eq(
    error_type(@mf2.Mf2ErrorCode::Mf2MissingFallbackVariantCode),
    "missing-fallback-variant",
  )
}

///|
fn run_case(
  adapter : LampclawMf2Adapter,
  input : @conformance.MessageFormat2Input,
) -> @conformance.MessageFormat2Result {
  try adapter.format_message(input) catch {
    _ => @conformance.MessageFormat2Result::Formatted("<raised>")
  } noraise {
    value => value
  }
}

///|
/// 端到端：这是 CLDR syntax.json 里的一条真实用例
/// （`src=[hello {$place}]`, `params={"name":"place","value":"world"}`, `exp=[hello world]`）。
test "真实用例：带字符串参数的消息" {
  let adapter = LampclawMf2Adapter::new()
  let input : @conformance.MessageFormat2Input = {
    locale: "en",
    source: "hello {$place}",
    bidi_isolation: None,
    tags: [],
    params_json: Some("{\"name\":\"place\",\"value\":\"world\"}"),
  }
  assert_eq(
    run_case(adapter, input),
    @conformance.MessageFormat2Result::Formatted("hello world"),
  )
}

///|
test "真实用例：纯文本消息原样输出" {
  let adapter = LampclawMf2Adapter::new()
  let input : @conformance.MessageFormat2Input = {
    locale: "en",
    source: "hello",
    bidi_isolation: None,
    tags: [],
    params_json: None,
  }
  assert_eq(
    run_case(adapter, input),
    @conformance.MessageFormat2Result::Formatted("hello"),
  )
}
