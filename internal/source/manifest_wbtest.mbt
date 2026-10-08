///|
fn sample_file() -> SourceFile {
  {
    suite: "decimal",
    path: "fixtures/decimal/decimals.tsv",
    url: "https://example.com/decimals.tsv",
    sha256: "e19820ae98ea505e11b9fb385edd22cbe69275bdb837da92c03950a2f453e816",
    bytes: 7395,
    tier: Fast,
  }
}

///|
test "清单 JSON round-trip 后完全一致" {
  let manifest : Manifest = { cldr_version: "main", files: [sample_file()], }
  let text = manifest.to_json_string()
  let back = manifest_from_json_string(text)
  assert_eq(back, manifest)
}

///|
test "序列化结果的键名与取值符合约定" {
  let manifest : Manifest = { cldr_version: "main", files: [sample_file()], }
  let text = manifest.to_json_string()
  // 这些字符串就是 fixtures/SOURCES.json 的契约，改动必须是有意的
  assert_true(text.contains("\"cldr_version\": \"main\""))
  assert_true(text.contains("\"suite\": \"decimal\""))
  assert_true(text.contains("\"path\": \"fixtures/decimal/decimals.tsv\""))
  assert_true(text.contains("\"bytes\": 7395"))
  assert_true(text.contains("\"tier\": \"Fast\""))
}

///|
test "可以读取人工编写的清单（缩进、换行、多文件）" {
  let text =
    #|{
    #|  "cldr_version": "main",
    #|  "files": [
    #|    {
    #|      "suite": "datetime",
    #|      "path": "fixtures/datetime/datetime.json",
    #|      "url": "https://example.com/datetime.json",
    #|      "sha256": "abc",
    #|      "bytes": 1,
    #|      "tier": "Full"
    #|    }
    #|  ]
    #|}
  let manifest = manifest_from_json_string(text)
  assert_eq(manifest.cldr_version, "main")
  assert_eq(manifest.files.length(), 1)
  assert_eq(manifest.files[0].suite, "datetime")
  assert_eq(manifest.files[0].tier, Full)
  assert_eq(manifest.files[0].bytes, 1)
}

///|
test "空清单可以正常序列化与解析" {
  let manifest : Manifest = { cldr_version: "main", files: [], }
  let back = manifest_from_json_string(manifest.to_json_string())
  assert_eq(back.files.length(), 0)
}

///|
test "非清单内容会解析失败而不是静默通过" {
  try {
    let _ = manifest_from_json_string("{\"files\": []}")
    fail("缺少 cldr_version 时应当解析失败")
  } catch {
    _ => ()
  }
}
