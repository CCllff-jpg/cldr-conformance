///|
/// 解析数字套件 TSV 时的失败。
///
/// 上游的取值集合是封闭的（实测只有 `decimal`/`percent`/`scientific` 与 空/`short`/`long`），
/// 所以遇到未知取值**直接报错**而不是静默跳过：那意味着数据基线变了，
/// 必须让人看见（见 开发方案.md §5 数据自检）。
pub(all) suberror DecimalParseError {
  MissingColumn(column~ : String)
  RaggedRow(line~ : Int)
  UnknownStyle(line~ : Int, value~ : String)
  UnknownLength(line~ : Int, value~ : String)
} derive(Debug)

///|
fn require_column(
  table : TsvTable,
  column : String,
) -> Int raise DecimalParseError {
  match table.column_index(column) {
    Some(index) => index
    None => raise DecimalParseError::MissingColumn(column~)
  }
}

///|
/// `number_format` 列 → `NumberStyle`。`currency` 目前未出现在测试数据里，
/// 但保留映射，以便上游将来加入时不至于直接失败。
fn style_of(
  value : String,
  line~ : Int,
) -> @conformance.NumberStyle raise DecimalParseError {
  match value {
    "decimal" => @conformance.NumberStyle::DecimalStyle
    "percent" => @conformance.NumberStyle::PercentStyle
    "scientific" => @conformance.NumberStyle::ScientificStyle
    "currency" => @conformance.NumberStyle::CurrencyStyle
    _ => raise DecimalParseError::UnknownStyle(line~, value~)
  }
}

///|
/// `format_length` 列 → `NumberLength`（空值表示未指定紧凑格式）。
fn length_of(
  value : String,
  line~ : Int,
) -> @conformance.NumberLength raise DecimalParseError {
  match value {
    "" => @conformance.NumberLength::Standard
    "short" => @conformance.NumberLength::Short
    "long" => @conformance.NumberLength::Long
    _ => raise DecimalParseError::UnknownLength(line~, value~)
  }
}

///|
/// 把数字套件 TSV 解析成用例。
///
/// 行号按「表头是第 1 行」计算。解析器会跳过空行，而 CLDR 的数据文件里没有空行
/// （实测），所以行号能直接对应回源文件。
pub fn parse_decimal_cases(
  table : TsvTable,
) -> Array[@conformance.DecimalCase] raise DecimalParseError {
  let locale_col = require_column(table, "locale")
  let style_col = require_column(table, "number_format")
  let length_col = require_column(table, "format_length")
  let input_col = require_column(table, "input")
  let expected_col = require_column(table, "expected")
  let width = table.header.length()
  let cases : Array[@conformance.DecimalCase] = []
  for i, fields in table.rows {
    let line = i + 2
    if fields.length() != width {
      raise DecimalParseError::RaggedRow(line~)
    }
    cases.push({
      locale: fields[locale_col],
      style: style_of(fields[style_col], line~),
      length: length_of(fields[length_col], line~),
      input: fields[input_col],
      expected: fields[expected_col],
      line,
    })
  }
  cases
}

///|
/// 便捷入口：从 TSV 文本直接得到用例集合。
pub fn decimal_corpus_from_tsv(
  text : StringView,
) -> @conformance.DecimalCorpus raise {
  @conformance.DecimalCorpus::new(parse_decimal_cases(parse_tsv(text)))
}
