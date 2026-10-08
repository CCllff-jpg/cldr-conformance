///|
test "verify_bytes：内容与清单一致时 Match" {
  let data = b"abc"
  let expected : SourceFile = {
    suite: "decimal",
    path: "fixtures/decimal/x.tsv",
    url: "https://example.com/x.tsv",
    sha256: sha256_hex(data),
    bytes: data.length(),
    tier: Fast,
  }
  assert_eq(verify_bytes(data, expected), VerifyOutcome::Match)
  assert_true(verify_bytes(data, expected).is_ok())
}

///|
test "verify_bytes：长度不符时报 SizeMismatch（先于摘要比对）" {
  let data = b"abc"
  let expected : SourceFile = {
    suite: "decimal",
    path: "p",
    url: "u",
    sha256: "whatever",
    bytes: 99,
    tier: Fast,
  }
  assert_eq(
    verify_bytes(data, expected),
    VerifyOutcome::SizeMismatch(expected=99, actual=3),
  )
}

///|
test "verify_bytes：长度相同但内容不同时报 Mismatch" {
  let data = b"abc"
  let expected : SourceFile = {
    suite: "decimal",
    path: "p",
    url: "u",
    sha256: sha256_hex(b"abd"),
    bytes: 3,
    tier: Fast,
  }
  assert_eq(
    verify_bytes(data, expected),
    VerifyOutcome::Mismatch(
      expected=sha256_hex(b"abd"),
      actual=sha256_hex(b"abc"),
    ),
  )
  assert_false(verify_bytes(data, expected).is_ok())
}

///|
async test "verify_file：文件不存在时返回 Missing" {
  let expected : SourceFile = {
    suite: "decimal",
    path: "fixtures/decimal/绝对不存在的文件.tsv",
    url: "u",
    sha256: "x",
    bytes: 1,
    tier: Fast,
  }
  assert_eq(verify_file(expected), VerifyOutcome::Missing)
}

///|
/// F2 的核心验收：篡改一个字节**必须**被检出。
async test "verify_file：未篡改通过，篡改一个字节必须检出" {
  let dir = @fs.tmpdir(prefix="cldr-verify-")
  defer @fs.rmdir(dir, recursive=true)
  let path = "\{dir}/sample.tsv"
  let original = b"locale\tinput\texpected\nen\t1.2\t1.2\n"
  @fs.write_file(path, original)
  let expected : SourceFile = {
    suite: "decimal",
    path,
    url: "https://example.com/sample.tsv",
    sha256: sha256_hex(original),
    bytes: original.length(),
    tier: Fast,
  }
  assert_eq(verify_file(expected), VerifyOutcome::Match)
  // 等长篡改：把 1.2 改成 1.3，长度不变，只有摘要会变
  let tampered = b"locale\tinput\texpected\nen\t1.3\t1.2\n"
  if tampered.length() != original.length() {
    fail(
      "测试数据设计错误：篡改前后长度必须相同，才能验证摘要比对",
    )
  }
  @fs.write_file(path, tampered)
  assert_eq(
    verify_file(expected),
    VerifyOutcome::Mismatch(
      expected=sha256_hex(original),
      actual=sha256_hex(tampered),
    ),
  )
}

///|
async test "verify_manifest 与报告：区分通过与缺失" {
  let dir = @fs.tmpdir(prefix="cldr-manifest-")
  defer @fs.rmdir(dir, recursive=true)
  let good_path = "\{dir}/good.tsv"
  let data = b"a\tb\n"
  @fs.write_file(good_path, data)
  let good : SourceFile = {
    suite: "decimal",
    path: good_path,
    url: "https://example.com/good.tsv",
    sha256: sha256_hex(data),
    bytes: data.length(),
    tier: Fast,
  }
  let missing : SourceFile = {
    suite: "datetime",
    path: "\{dir}/missing.json",
    url: "https://example.com/missing.json",
    sha256: "x",
    bytes: 1,
    tier: Full,
  }
  let manifest : Manifest = { cldr_version: "main", files: [good, missing], }
  let entries = verify_manifest(manifest)
  assert_eq(entries.length(), 2)
  assert_true(entries[0].outcome.is_ok())
  assert_eq(entries[1].outcome, VerifyOutcome::Missing)
  assert_eq(count_failures(entries), 1)
  let report = render_verify_report("fixtures/SOURCES.json", manifest, entries)
  assert_true(report.contains("✓"))
  assert_true(report.contains("文件缺失"))
  assert_true(report.contains("CLDR main"))
  assert_true(report.contains("共 2 个文件，1 个不一致"))
}

///|
test "全部通过时失败计数为 0" {
  let entry : VerifyEntry = {
    file: {
      suite: "decimal",
      path: "p",
      url: "u",
      sha256: "s",
      bytes: 0,
      tier: Fast,
    },
    outcome: VerifyOutcome::Match,
  }
  assert_eq(count_failures([entry]), 0)
}
