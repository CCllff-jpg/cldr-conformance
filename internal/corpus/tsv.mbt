///|
/// 一张解析好的 TSV 表：保留表头与全部数据行。
///
/// 刻意**不做 trim、也不做转义处理**：CLDR 测试数据的字段本身承载语义
/// （空格、以及 RTL/格式控制符如 U+200E、U+061C），任何"顺手清洗"都会让
/// `expected` 失真。实测 `fixtures/decimal/decimals.tsv` 含 27 个此类控制符。
pub(all) struct TsvTable {
  header : Array[String]
  rows : Array[Array[String]]
} derive(Debug, Eq)

///|
/// 去掉行尾的 `\r`（CRLF 兼容），其余内容一律不动。
fn strip_trailing_cr(line : StringView) -> StringView {
  if line.has_suffix("\r") {
    line[:line.length() - 1]
  } else {
    line
  }
}

///|
/// 解析 TSV 文本。
///
/// 约定（依据 `fixtures/` 下真实文件实测得到）：
/// - 行分隔符接受 `\n` 与 `\r\n`
/// - 末尾换行不产生空行；真正的空行跳过
/// - **空字段按空字符串保留**（`decimals.tsv` 有 135 个空字段，主要是 `format_length`）
/// - 第一行视为表头
pub fn parse_tsv(text : StringView) -> TsvTable {
  let mut header : Array[String] = []
  let rows : Array[Array[String]] = []
  let mut is_header = true
  // 先 to_owned 一次：String::split 的接收者是 String，避免对大文件反复做视图转换
  for raw_line in text.to_owned().split("\n") {
    let line = strip_trailing_cr(raw_line)
    if line.length() == 0 {
      continue
    }
    let fields = []
    for field in line.split("\t") {
      fields.push(field.to_owned())
    }
    if is_header {
      header = fields
      is_header = false
    } else {
      rows.push(fields)
    }
  }
  { header, rows, }
}

///|
/// 数据行数（不含表头）。
pub fn TsvTable::row_count(self : TsvTable) -> Int {
  self.rows.length()
}

///|
/// 按表头名取列下标；表头里没有该列时返回 `None`。
pub fn TsvTable::column_index(self : TsvTable, column : String) -> Int? {
  let mut found : Int? = None
  for i, name in self.header {
    if found is None && name == column {
      found = Some(i)
    }
  }
  found
}

///|
/// 按「行号 + 列名」取值；列名不存在或该行字段不足时返回 `None`。
pub fn TsvTable::get(self : TsvTable, row : Int, column : String) -> String? {
  match self.rows.get(row) {
    None => None
    Some(fields) =>
      match self.column_index(column) {
        None => None
        Some(index) => fields.get(index)
      }
  }
}

///|
/// 某列的全部取值（保持行序，含重复与空值）。
pub fn TsvTable::column_values(
  self : TsvTable,
  column : String,
) -> Array[String] {
  let values = []
  match self.column_index(column) {
    None => ()
    Some(index) =>
      for fields in self.rows {
        match fields.get(index) {
          Some(value) => values.push(value)
          None => ()
        }
      }
  }
  values
}

///|
/// 字段数与表头不一致的行号。
///
/// 用途是**数据自检**：上游若改了格式（多/少一列），这里会立刻暴露，
/// 而不是让解析结果静默丢字段（见 开发方案.md §5 测试策略）。
pub fn TsvTable::ragged_rows(self : TsvTable) -> Array[Int] {
  let bad = []
  let expected = self.header.length()
  for i, fields in self.rows {
    if fields.length() != expected {
      bad.push(i)
    }
  }
  bad
}

///|
/// 重新拼回 TSV 文本（行尾 `\n`）。
///
/// 用途是 **round-trip 校验**：解析后再拼回若与原文逐字符一致，
/// 就同时证明了「没有丢字段、没有 trim、控制符没被破坏」。
pub fn render_tsv(table : TsvTable) -> String {
  let out = StringBuilder()
  out <+ "\{table.header.join("\t")}\n"
  for fields in table.rows {
    out <+ "\{fields.join("\t")}\n"
  }
  out.to_string()
}

///|
/// 所有数据字段中落在 RTL / 格式控制区的字符数（U+2000–U+206F 与 U+061C）。
///
/// 用途：数据质量自检与报告展示——这些字符正是手写实现最容易丢掉的东西。
pub fn TsvTable::control_char_count(self : TsvTable) -> Int {
  let mut count = 0
  for fields in self.rows {
    for field in fields {
      for ch in field {
        let code = ch.to_int()
        if (code >= 0x2000 && code <= 0x206F) || code == 0x061C {
          count = count + 1
        }
      }
    }
  }
  count
}
