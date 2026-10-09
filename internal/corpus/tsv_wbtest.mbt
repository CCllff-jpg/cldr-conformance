///|
test "解析：表头 + 数据行，空字段按空串保留" {
  let table = parse_tsv("a\tb\tc\n1\t\t3\n")
  assert_eq(table.header, ["a", "b", "c"])
  assert_eq(table.row_count(), 1)
  assert_eq(table.get(0, "a"), Some("1"))
  assert_eq(table.get(0, "b"), Some(""))
  assert_eq(table.get(0, "c"), Some("3"))
}

///|
test "解析：CRLF 与 LF 解析结果相同，末尾换行不产生多余行" {
  let lf = parse_tsv("h\n1\n2\n")
  let crlf = parse_tsv("h\r\n1\r\n2\r\n")
  assert_eq(lf.row_count(), 2)
  assert_eq(crlf.row_count(), 2)
  assert_eq(lf, crlf)
}

///|
test "解析：不做 trim，字段里的空格原样保留" {
  let table = parse_tsv("k\n  x  \n")
  assert_eq(table.get(0, "k"), Some("  x  "))
  assert_eq(render_tsv(table), "k\n  x  \n")
}

///|
test "解析：多字节字符原样保留（round-trip 一致）" {
  let source = "locale\texpected\nar\t1.2 مليون\nbn\t১২,৩৪,৫৬৫\nzh\t1,234\nja\t123万\n"
  let table = parse_tsv(source)
  assert_eq(table.row_count(), 4)
  assert_eq(table.get(0, "expected"), Some("1.2 مليون"))
  assert_eq(table.get(1, "expected"), Some("১২,৩৪,৫৬৫"))
  assert_eq(table.get(3, "expected"), Some("123万"))
  assert_eq(render_tsv(table), source)
}

///|
test "解析：行尾空字段不丢失（round-trip 一致）" {
  let source = "a\tb\tc\n1\t\t\n"
  let table = parse_tsv(source)
  assert_eq(table.get(0, "c"), Some(""))
  assert_eq(render_tsv(table), source)
}

///|
test "ragged_rows 能发现列数不一致的行" {
  let table = parse_tsv("a\tb\n1\t2\n3\n4\t5\t6\n")
  assert_eq(table.row_count(), 3)
  assert_eq(table.ragged_rows(), [1, 2])
}

///|
test "column_index / column_values / 越界访问" {
  let table = parse_tsv("locale\tkind\nen\ta\nde\tb\nfr\ta\n")
  assert_eq(table.column_index("kind"), Some(1))
  assert_eq(table.column_index("missing"), None)
  assert_eq(table.get(99, "kind"), None)
  assert_eq(table.get(0, "missing"), None)
  assert_eq(table.column_values("locale"), ["en", "de", "fr"])
}

///|
test "空输入与只有表头的输入" {
  let empty = parse_tsv("")
  assert_eq(empty.header, [])
  assert_eq(empty.row_count(), 0)
  let only_header = parse_tsv("a\tb\n")
  assert_eq(only_header.header, ["a", "b"])
  assert_eq(only_header.row_count(), 0)
}

///|
test "空行被跳过，不会变成数据行" {
  let table = parse_tsv("a\n1\n\n2\n\n")
  assert_eq(table.row_count(), 2)
  assert_eq(table.column_values("a"), ["1", "2"])
}

///|
/// 真实数据回归：解析 `fixtures/decimal/decimals.tsv`，验证结构、控制符与可逆性。
///
/// 断言里的行数（225）与控制符数（27）**绑定于固定数据基线 tag**
/// （当前 `release-49-beta3`）。若将来换基线，这两个数字需要一并复核。
async test "真实文件 decimals.tsv：结构、控制符与 round-trip" {
  let text = @fs.read_file("fixtures/decimal/decimals.tsv").text()
  let table = parse_tsv(text)
  assert_eq(table.header, [
    "locale", "number_format", "format_length", "input", "expected",
  ])
  assert_eq(table.row_count(), 225)
  assert_eq(table.ragged_rows().length(), 0)
  // 真实文件也必须能逐字符拼回：证明空字段与控制符都没被破坏
  assert_eq(render_tsv(table), text)
  // U+200E ×16 + U+061C ×11
  assert_eq(table.control_char_count(), 27)
}
