///|
/// `lampclaw/i18n@0.9.3` 的 MF2 适配器。
///
/// 这是生态里**唯一的原生 MF2 实现**（`Zhouz-z/moon_l10n` 实现的是 ICU MessageFormat，
/// 属不同标准，不可用 MF2 语法去判它——见 `可比性映射.md`）。
///
/// **错误类别对拍**：CLDR 的 `expErrors.type` 有 12 类；本实现的 `Mf2ErrorCode`
/// 有 18 个细分码，其中 11 个与 CLDR 词表精确对应（映射见 `error_type`）。
///
/// **工具链要求**：本库使用 `Int32`，需要 MoonBit `0.1.20261012` 及以上
/// （更早的核心库没有 `Int32`，编译 `runtime/catalog.mbt` 会报 4032）。
pub(all) struct LampclawMf2Adapter {
  label : String
} derive(Debug, Eq)

///|
pub fn LampclawMf2Adapter::new() -> LampclawMf2Adapter {
  { label: "lampclaw-i18n", }
}

///|
/// 适配器自身的错误（属于"无法执行该用例"，与"答错"不同）。
pub(all) suberror LampclawMf2AdapterError {
  /// locale 无法规范化
  BadLocale(locale~ : String)
} derive(Debug)

///|
/// 错误码 → CLDR 的 `expErrors.type` 词表。
///
/// 11 个精确对应；`data-model-error` / `resolution-error` 是 CLDR 词表里没有的
/// 兜底类别，`bad-variant-key` 归到 CLDR 的 `variant-key-mismatch`。
pub fn error_type(code : @mf2.Mf2ErrorCode) -> String {
  match code {
    @mf2.Mf2ErrorCode::Mf2SyntaxCode => "syntax-error"
    @mf2.Mf2ErrorCode::Mf2DataModelCode => "data-model-error"
    @mf2.Mf2ErrorCode::Mf2ResolutionCode => "resolution-error"
    @mf2.Mf2ErrorCode::Mf2VariantKeyMismatchCode => "variant-key-mismatch"
    @mf2.Mf2ErrorCode::Mf2MissingFallbackVariantCode =>
      "missing-fallback-variant"
    @mf2.Mf2ErrorCode::Mf2MissingSelectorAnnotationCode =>
      "missing-selector-annotation"
    @mf2.Mf2ErrorCode::Mf2DuplicateDeclarationCode => "duplicate-declaration"
    @mf2.Mf2ErrorCode::Mf2DuplicateOptionNameCode => "duplicate-option-name"
    @mf2.Mf2ErrorCode::Mf2DuplicateVariantCode => "duplicate-variant"
    @mf2.Mf2ErrorCode::Mf2UnresolvedVariableCode => "unresolved-variable"
    @mf2.Mf2ErrorCode::Mf2UnknownFunctionCode => "unknown-function"
    @mf2.Mf2ErrorCode::Mf2BadSelectorCode => "bad-selector"
    @mf2.Mf2ErrorCode::Mf2BadOperandCode => "bad-operand"
    @mf2.Mf2ErrorCode::Mf2BadOptionCode => "bad-option"
    @mf2.Mf2ErrorCode::Mf2BadVariantKeyCode => "variant-key-mismatch"
    @mf2.Mf2ErrorCode::Mf2UnsupportedOperationCode => "unsupported-operation"
    @mf2.Mf2ErrorCode::Mf2FormattingCode => "formatting-error"
    @mf2.Mf2ErrorCode::Mf2LimitCode => "limit-error"
  }
}

///|
/// CLDR 的 MF2 用例至多带一个具名参数，形如 `{"name": "x", "value": 1}`。
pub fn parse_arguments(params_json : String?) -> Array[@mf2.Mf2Input] {
  match params_json {
    None => []
    Some(json) =>
      match parse_name_value(json) {
        Some((name, value)) => [@mf2.Mf2Input::new(name, value)]
        None => []
      }
  }
}

///|
fn parse_name_value(json : String) -> (String, @mf2.MessageValue)? {
  let name = match extract_key_string(json, "\"name\"") {
    Some(name) => name
    None => return None
  }
  let value = match extract_key_value(json, "\"value\"") {
    Some(value) => value
    None => return None
  }
  Some((name, value))
}

///|
/// 找到 `key` 之后（冒号与空白之后）的字符串值。
fn extract_key_string(json : String, key : String) -> String? {
  let start = match find_key(json, key) {
    Some(start) => start
    None => return None
  }
  if start >= json.length() || unit_at(json, start) != 0x0022 {
    return None
  }
  parse_json_string_at(json, start)
}

///|
/// 找到 `key` 之后（冒号与空白之后）的标量值。
fn extract_key_value(json : String, key : String) -> @mf2.MessageValue? {
  let start = match find_key(json, key) {
    Some(start) => start
    None => return None
  }
  if start >= json.length() {
    return None
  }
  if unit_at(json, start) == 0x0022 {
    return match parse_json_string_at(json, start) {
      Some(text) => Some(@mf2.MessageValue::TextValue(text))
      None => None
    }
  }
  let mut end = start
  while end < json.length() {
    let unit = unit_at(json, end)
    if unit == 0x002C || unit == 0x007D || unit == 0x0020 || unit == 0x000A {
      break
    }
    end += 1
  }
  let raw = slice(json, start, end)
  if raw == "true" {
    return Some(@mf2.MessageValue::BoolValue(true))
  }
  if raw == "false" {
    return Some(@mf2.MessageValue::BoolValue(false))
  }
  if raw.contains(".") || raw.contains("e") || raw.contains("E") {
    return match parse_double(raw) {
      Some(number) => Some(@mf2.MessageValue::DoubleValue(number))
      None => None
    }
  }
  match parse_int32(raw) {
    Some(number) => Some(@mf2.MessageValue::IntValue(number))
    None => None
  }
}

///|
/// `index` 指向开引号，返回解析出的字符串内容。
fn parse_json_string_at(json : String, index : Int32) -> String? {
  let mut cursor = index + 1
  let out = StringBuilder()
  while cursor < json.length() {
    let unit = unit_at(json, cursor)
    if unit == 0x0022 {
      return Some(out.to_string())
    }
    if unit == 0x005C && cursor + 1 < json.length() {
      let next = unit_at(json, cursor + 1)
      if next == 0x0022 {
        out.write_string("\"")
      } else if next == 0x005C {
        out.write_string("\\")
      } else if next == 0x006E {
        out.write_string("\n")
      } else {
        out.write_string("\\")
      }
      cursor += 2
      continue
    }
    out.write_substring(json, cursor, 1)
    cursor += 1
  }
  None
}

///|
/// 找到 `"key"` 之后的位置（冒号之后、跳过空白），找不到返回 `None`。
fn find_key(json : String, key : String) -> Int32? {
  let mut index = 0
  while index + key.length() <= json.length() {
    if slice(json, index, index + key.length()) == key {
      let cursor = skip_ws(json, index + key.length())
      if cursor < json.length() && unit_at(json, cursor) == 0x003A {
        return Some(skip_ws(json, cursor + 1))
      }
    }
    index += 1
  }
  None
}

///|
fn skip_ws(text : String, index : Int32) -> Int32 {
  let mut cursor = index
  while cursor < text.length() {
    let unit = unit_at(text, cursor)
    if unit != 0x0020 && unit != 0x000A && unit != 0x000D && unit != 0x0009 {
      break
    }
    cursor += 1
  }
  cursor
}

///|
fn slice(text : String, start : Int32, end : Int32) -> String {
  text.clamped_view(start~, end~).to_owned()
}

///|
fn unit_at(text : String, index : Int32) -> Int32 {
  text[index].to_int()
}

///|
/// 把十进制整数字符串解析成 `Int32`（CLDR 用例里的计数都很小）。
fn parse_int32(raw : String) -> Int32? {
  if raw.length() == 0 {
    return None
  }
  let mut index = 0
  let mut negative = false
  if unit_at(raw, 0) == 0x002D {
    negative = true
    index = 1
  } else if unit_at(raw, 0) == 0x002B {
    index = 1
  }
  let mut value : Int32 = 0
  let mut digits = 0
  while index < raw.length() {
    let unit = unit_at(raw, index)
    if unit < 0x0030 || unit > 0x0039 {
      return None
    }
    value = value * 10 + digit_to_int32(unit - 0x0030)
    digits += 1
    index += 1
  }
  if digits == 0 {
    return None
  }
  Some(if negative { -value } else { value })
}

///|
/// 极简十进制小数解析（CLDR 用例里只有 `1.0` 这类简单值）。
fn parse_double(raw : String) -> Double? {
  if raw.length() == 0 {
    return None
  }
  let mut index = 0
  let mut negative = false
  if unit_at(raw, 0) == 0x002D {
    negative = true
    index = 1
  }
  let mut integral : Int32 = 0
  let mut seen_digits = 0
  while index < raw.length() {
    let unit = unit_at(raw, index)
    if unit == 0x002E {
      break
    }
    if unit < 0x0030 || unit > 0x0039 {
      return None
    }
    integral = integral * 10 + digit_to_int32(unit - 0x0030)
    seen_digits += 1
    index += 1
  }
  if seen_digits == 0 {
    return None
  }
  if index < raw.length() {
    index += 1
  }
  let mut value = integral.to_double()
  let mut scale = 1.0
  while index < raw.length() {
    let unit = unit_at(raw, index)
    if unit < 0x0030 || unit > 0x0039 {
      return None
    }
    scale = scale * 10.0
    value = value + digit_to_int32(unit - 0x0030).to_double() / scale
    index += 1
  }
  Some(if negative { -value } else { value })
}

///|
/// 用字面量映射把 0-9 转成 `Int32`（避免依赖 `Int` 到 `Int32` 的转换函数）。
fn digit_to_int32(digit : Int32) -> Int32 {
  match digit {
    0 => 0
    1 => 1
    2 => 2
    3 => 3
    4 => 4
    5 => 5
    6 => 6
    7 => 7
    8 => 8
    9 => 9
    _ => 0
  }
}

///|
/// CLDR 用例在**文件级**声明 `bidiIsolation`（`none` / `default`）。
/// 缺省按 `none` 处理：用例的期望输出里没有隔离符。
fn bidi_isolation_of(value : String?) -> @mf2.Mf2BidiIsolation {
  match value {
    Some("default") => @mf2.Mf2DefaultBidiIsolation
    _ => @mf2.Mf2NoBidiIsolation
  }
}

///|
pub impl @conformance.MessageFormat2Adapter for LampclawMf2Adapter with fn name(
  self,
) {
  self.label
}

///|
pub impl @conformance.MessageFormat2Adapter for LampclawMf2Adapter with fn format_message(
  self,
  input,
) {
  ignore(self)
  let context = match
    @mf2.Mf2FormattingContext::new(
      locale=input.locale,
      inputs=parse_arguments(input.params_json),
      bidi_isolation=bidi_isolation_of(input.bidi_isolation),
    ) {
    Ok(context) => context
    Err(_) => raise LampclawMf2AdapterError::BadLocale(locale=input.locale)
  }
  let result = @mf2.format_mf2_standalone(input.source, context)
  if result.errors.length() > 0 {
    return @conformance.MessageFormat2Result::Errors(
      result.errors.map(error => error_type(error.code)),
    )
  }
  @conformance.MessageFormat2Result::Formatted(result.value)
}
