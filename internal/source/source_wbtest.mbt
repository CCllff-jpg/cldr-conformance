///|
/// SHA-256 的标准测试向量（离线，永远执行）。
test "sha256_hex 与标准向量一致" {
  assert_eq(
    sha256_hex(b""),
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  )
  assert_eq(
    sha256_hex(b"abc"),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
}

///|
test "sha256_hex 对不同内容给出不同摘要" {
  assert_true(sha256_hex(b"a") != sha256_hex(b"b"))
  assert_eq(sha256_hex(b"a").length(), 64)
}

///|
test "parent_dir 处理常见路径形式" {
  assert_eq(
    parent_dir("fixtures/decimal/decimals.tsv"),
    Some("fixtures/decimal"),
  )
  assert_eq(parent_dir("fixtures/decimal"), Some("fixtures"))
  assert_eq(parent_dir("decimals.tsv"), None)
  assert_eq(parent_dir("/tmp/x"), Some("/tmp"))
  // 分隔符就是第一个字符时，父目录是根
  assert_eq(parent_dir("/x"), Some("/"))
}

///|
test "parent_dir 同时接受 Windows 分隔符" {
  assert_eq(
    parent_dir("fixtures\\decimal\\decimals.tsv"),
    Some("fixtures\\decimal"),
  )
  assert_eq(parent_dir("fixtures\\a/b"), Some("fixtures\\a"))
}

///|
test "parent_dir 对含非 ASCII 的路径也正确（本项目根目录含中文）" {
  assert_eq(
    parent_dir(
      "E:/javacode/moonbit十月黑客松/cldr-conformance/fixtures/x.tsv",
    ),
    Some("E:/javacode/moonbit十月黑客松/cldr-conformance/fixtures"),
  )
}
