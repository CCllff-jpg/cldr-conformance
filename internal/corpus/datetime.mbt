///|
/// 解析日期套件数据时的失败。
///
/// 与数字套件同样的立场：格式或取值不符合预期时**直接报错**，
/// 不做静默跳过——那意味着数据基线变了（见 开发方案.md §5 数据自检）。
pub(all) suberror DatetimeParseError {
  MissingColumn(column~ : String)
  RaggedRow(line~ : Int)
  /// `datetime.json` 顶层不是数组。
  NotAnArray
  /// 数组元素不是对象。
  NotAnObject(index~ : Int)
  MissingField(index~ : Int, field~ : String)
  /// 出现了未建模的字段：上游加了新能力，必须让人看见，否则会「漏测」而不自知。
  UnknownField(index~ : Int, field~ : String)
  WrongType(index~ : Int, field~ : String)
} derive(Debug)

///|
fn require_dt_column(
  table : TsvTable,
  column : String,
) -> Int raise DatetimeParseError {
  match table.column_index(column) {
    Some(index) => index
    None => raise DatetimeParseError::MissingColumn(column~)
  }
}

///|
/// 把骨架 TSV（`skeletons.tsv` / `skeletons_all_calendars.tsv`）解析成用例。
pub fn parse_skeleton_cases(
  table : TsvTable,
) -> Array[@conformance.SkeletonCase] raise DatetimeParseError {
  let locale_col = require_dt_column(table, "locale")
  let calendar_col = require_dt_column(table, "calendar")
  let skeleton_col = require_dt_column(table, "skeleton")
  let pattern_col = require_dt_column(table, "pattern")
  let width = table.header.length()
  let cases : Array[@conformance.SkeletonCase] = []
  for i, fields in table.rows {
    let line = i + 2
    if fields.length() != width {
      raise DatetimeParseError::RaggedRow(line~)
    }
    cases.push({
      locale: fields[locale_col],
      calendar: fields[calendar_col],
      skeleton: fields[skeleton_col],
      pattern: fields[pattern_col],
      line,
    })
  }
  cases
}

///|
/// `datetime.json` 里已建模的字段集合。
fn is_known_datetime_field(name : String) -> Bool {
  match name {
    "locale"
    | "calendar"
    | "input"
    | "expected"
    | "semanticSkeleton"
    | "classicalSkeleton"
    | "semanticSkeletonLength"
    | "zoneStyle"
    | "timeLength"
    | "dateLength"
    | "hourCycle"
    | "yearStyle"
    | "dateTimeFormatType" => true
    _ => false
  }
}

///|
fn json_string(
  fields : Map[String, Json],
  index : Int,
  field : String,
) -> String raise DatetimeParseError {
  match fields.get(field) {
    Some(Json::String(value)) => value
    Some(_) => raise DatetimeParseError::WrongType(index~, field~)
    None => raise DatetimeParseError::MissingField(index~, field~)
  }
}

///|
fn json_optional_string(
  fields : Map[String, Json],
  index : Int,
  field : String,
) -> String? raise DatetimeParseError {
  match fields.get(field) {
    None => None
    Some(Json::String(value)) => Some(value)
    Some(_) => raise DatetimeParseError::WrongType(index~, field~)
  }
}

///|
/// 解析 `datetime.json`。
///
/// 上游用的是 camelCase 键，而 MoonBit 侧是 snake_case 字段，
/// 因此这里手写映射（顺带获得「未知字段即报错」的能力）。
pub fn parse_datetime_json(
  text : StringView,
) -> Array[@conformance.DatetimeCase] raise {
  let items = match @json.parse(text) {
    Json::Array(items) => items
    _ => raise DatetimeParseError::NotAnArray
  }
  let cases : Array[@conformance.DatetimeCase] = []
  for index, item in items {
    let fields = match item {
      Json::Object(fields) => fields
      _ => raise DatetimeParseError::NotAnObject(index~)
    }
    for name, _ in fields {
      if !is_known_datetime_field(name) {
        raise DatetimeParseError::UnknownField(index~, field=name)
      }
    }
    cases.push({
      locale: json_string(fields, index, "locale"),
      calendar: json_string(fields, index, "calendar"),
      input: json_string(fields, index, "input"),
      expected: json_string(fields, index, "expected"),
      semantic_skeleton: json_optional_string(fields, index, "semanticSkeleton"),
      classical_skeleton: json_optional_string(
        fields, index, "classicalSkeleton",
      ),
      semantic_skeleton_length: json_optional_string(
        fields, index, "semanticSkeletonLength",
      ),
      zone_style: json_optional_string(fields, index, "zoneStyle"),
      time_length: json_optional_string(fields, index, "timeLength"),
      date_length: json_optional_string(fields, index, "dateLength"),
      hour_cycle: json_optional_string(fields, index, "hourCycle"),
      year_style: json_optional_string(fields, index, "yearStyle"),
      date_time_format_type: json_optional_string(
        fields, index, "dateTimeFormatType",
      ),
      index,
    })
  }
  cases
}

///|
/// 便捷入口：从两个骨架 TSV 与 `datetime.json` 文本组装日期套件。
pub fn datetime_corpus_from_text(
  skeletons_tsv : StringView,
  all_calendars_tsv : StringView,
  datetime_json : StringView,
) -> @conformance.DatetimeCorpus raise {
  @conformance.DatetimeCorpus::new(
    parse_skeleton_cases(parse_tsv(skeletons_tsv)) +
    parse_skeleton_cases(parse_tsv(all_calendars_tsv)),
    parse_datetime_json(datetime_json),
  )
}
