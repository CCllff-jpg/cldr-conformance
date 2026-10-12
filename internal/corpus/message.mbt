///|
/// 解析 MF2 测试数据时的失败。
///
/// 与其它套件同一立场：结构或字段不符合预期就报错，不静默跳过。
/// `index` 为 -1 表示问题出在文件级（而不是某个 test 元素）。
pub(all) suberror MessageParseError {
  /// 结构问题（顶层不是对象、tests 不是数组、元素不是对象等）。
  Malformed(file~ : String, detail~ : String)
  MissingField(file~ : String, index~ : Int, name~ : String)
  /// 出现未建模的字段：上游加了新能力，必须让人看见，否则会静默漏测。
  UnknownField(file~ : String, index~ : Int, name~ : String)
  WrongType(file~ : String, index~ : Int, name~ : String)
} derive(Debug)

///|
/// 文件级字段（实测：`$schema` / `scenario` / `description` / `defaultTestProperties` / `tests`）。
fn known_file_field(name : String) -> Bool {
  match name {
    "$schema"
    | "scenario"
    | "description"
    | "defaultTestProperties"
    | "tests" => true
    _ => false
  }
}

///|
/// `defaultTestProperties` 里的字段（实测：`locale` / `bidiIsolation` / `expErrors`）。
fn known_default_field(name : String) -> Bool {
  match name {
    "locale" | "bidiIsolation" | "expErrors" => true
    _ => false
  }
}

///|
/// test 元素里的字段（实测并集，见 message_wbtest.mbt 的真实数据回归）。
fn known_test_field(name : String) -> Bool {
  match name {
    "src"
    | "exp"
    | "expErrors"
    | "expParts"
    | "params"
    | "description"
    | "locale"
    | "tags" => true
    _ => false
  }
}

///|
fn msg_required_string(
  fields : Map[String, Json],
  file : String,
  index : Int,
  name : String,
) -> String raise MessageParseError {
  match fields.get(name) {
    Some(Json::String(value)) => value
    Some(_) => raise MessageParseError::WrongType(file~, index~, name~)
    None => raise MessageParseError::MissingField(file~, index~, name~)
  }
}

///|
fn msg_optional_string(
  fields : Map[String, Json],
  file : String,
  index : Int,
  name : String,
) -> String? raise MessageParseError {
  match fields.get(name) {
    None => None
    Some(Json::String(value)) => Some(value)
    Some(_) => raise MessageParseError::WrongType(file~, index~, name~)
  }
}

///|
fn msg_string_array(
  fields : Map[String, Json],
  file : String,
  index : Int,
  name : String,
) -> Array[String] raise MessageParseError {
  let values : Array[String] = []
  match fields.get(name) {
    None => ()
    Some(value) =>
      match value {
        Json::Array(items) =>
          for item in items {
            match item {
              Json::String(text) => values.push(text)
              _ => raise MessageParseError::WrongType(file~, index~, name~)
            }
          }
        _ => raise MessageParseError::WrongType(file~, index~, name~)
      }
  }
  values
}

///|
/// 解析 `expErrors`：形如 `[{"type":"syntax-error"}]`，只允许 `type` 一个键。
fn msg_error_types(
  value : Json,
  file : String,
  index : Int,
  name : String,
) -> Array[String] raise MessageParseError {
  let items = match value {
    Json::Array(items) => items
    _ => raise MessageParseError::WrongType(file~, index~, name~)
  }
  let types : Array[String] = []
  for item in items {
    let fields = match item {
      Json::Object(fields) => fields
      _ => raise MessageParseError::WrongType(file~, index~, name~)
    }
    for key, _ in fields {
      if key != "type" {
        raise MessageParseError::Malformed(
          file~,
          detail="\{name} 条目出现未建模的键 \{key}",
        )
      }
    }
    types.push(msg_required_string(fields, file, index, "type"))
  }
  types
}

///|
fn copy_strings(source : Array[String]) -> Array[String] {
  let copy : Array[String] = []
  for item in source {
    copy.push(item)
  }
  copy
}

///|
/// 解析一个 MF2 测试文件（`messageFormat/tests/*.json`）。
///
/// 关键语义：上游用「**文件级默认值 + 用例级覆盖**」表达期望。
/// 例如 `syntax-errors.json` 的 `defaultTestProperties` 里有
/// `expErrors: [{"type":"syntax-error"}]`，其 133 个用例只写 `src` 就继承了它——
/// 若不合并默认值，这些用例会被误读成「没有期望」。
pub fn parse_message_tests(
  file_name : String,
  text : StringView,
) -> Array[@conformance.MessageCase] raise {
  let root = match @json.parse(text) {
    Json::Object(fields) => fields
    _ =>
      raise MessageParseError::Malformed(
        file=file_name,
        detail="顶层不是对象",
      )
  }
  for name, _ in root {
    if !known_file_field(name) {
      raise MessageParseError::UnknownField(file=file_name, index=-1, name~)
    }
  }
  let scenario = msg_required_string(root, file_name, -1, "scenario")
  let mut default_locale : String? = None
  let mut default_bidi : String? = None
  let default_errors : Array[String] = []
  match root.get("defaultTestProperties") {
    None => ()
    Some(value) =>
      match value {
        Json::Object(fields) => {
          for name, _ in fields {
            if !known_default_field(name) {
              raise MessageParseError::UnknownField(
                file=file_name,
                index=-1,
                name~,
              )
            }
          }
          default_locale = msg_optional_string(fields, file_name, -1, "locale")
          default_bidi = msg_optional_string(
            fields, file_name, -1, "bidiIsolation",
          )
          match fields.get("expErrors") {
            None => ()
            Some(errors) => {
              let parsed = msg_error_types(errors, file_name, -1, "expErrors")
              for item in parsed {
                default_errors.push(item)
              }
            }
          }
        }
        _ =>
          raise MessageParseError::WrongType(
            file=file_name,
            index=-1,
            name="defaultTestProperties",
          )
      }
  }
  let tests = match root.get("tests") {
    Some(Json::Array(items)) => items
    Some(_) =>
      raise MessageParseError::WrongType(file=file_name, index=-1, name="tests")
    None =>
      raise MessageParseError::MissingField(
        file=file_name,
        index=-1,
        name="tests",
      )
  }
  let cases : Array[@conformance.MessageCase] = []
  for index, item in tests {
    let fields = match item {
      Json::Object(fields) => fields
      _ =>
        raise MessageParseError::Malformed(
          file=file_name,
          detail="第 \{index} 个 test 不是对象",
        )
    }
    for name, _ in fields {
      if !known_test_field(name) {
        raise MessageParseError::UnknownField(file=file_name, index~, name~)
      }
    }
    let locale = match
      (msg_optional_string(fields, file_name, index, "locale"), default_locale) {
      (Some(value), _) => value
      (None, Some(value)) => value
      (None, None) =>
        raise MessageParseError::MissingField(
          file=file_name,
          index~,
          name="locale",
        )
    }
    let bidi = match
      msg_optional_string(fields, file_name, index, "bidiIsolation") {
      Some(value) => Some(value)
      None => default_bidi
    }
    let errors = match fields.get("expErrors") {
      Some(value) => msg_error_types(value, file_name, index, "expErrors")
      None => copy_strings(default_errors)
    }
    let params_json = match fields.get("params") {
      Some(value) => Some(value.stringify())
      None => None
    }
    cases.push({
      file: file_name,
      scenario,
      index,
      description: msg_optional_string(fields, file_name, index, "description"),
      src: msg_required_string(fields, file_name, index, "src"),
      locale,
      bidi_isolation: bidi,
      exp: msg_optional_string(fields, file_name, index, "exp"),
      expected_errors: errors,
      expects_parts: fields.contains("expParts"),
      tags: msg_string_array(fields, file_name, index, "tags"),
      params_json,
    })
  }
  cases
}
