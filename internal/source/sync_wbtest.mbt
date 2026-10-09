///|
test "默认重试策略：3 次尝试、500ms 固定退避" {
  let policy = RetryPolicy::default()
  assert_eq(policy.max_attempts, 3)
  assert_eq(policy.backoff_ms, 500)
  assert_eq(policy.max_retry(), 2)
}

///|
test "退避为 0 时退化为立即重试（测试友好）" {
  let policy : RetryPolicy = { max_attempts: 3, backoff_ms: 0, }
  assert_true(policy.retry_method() is @async.Immediate)
  assert_true(RetryPolicy::default().retry_method() is @async.FixedDelay(_))
}

///|
test "max_retry 在边界上不为负" {
  assert_eq(RetryPolicy::{ max_attempts: 1, backoff_ms: 0, }.max_retry(), 0)
  assert_eq(RetryPolicy::{ max_attempts: 0, backoff_ms: 0, }.max_retry(), 0)
}

///|
async test "with_retry：一次成功就不重试" {
  let policy : RetryPolicy = { max_attempts: 3, backoff_ms: 0, }
  let mut tries = 0
  with_retry("https://example.com/x", policy, () => tries = tries + 1)
  assert_eq(tries, 1)
}

///|
async test "with_retry：中途失败会重试并最终成功" {
  let policy : RetryPolicy = { max_attempts: 3, backoff_ms: 0, }
  let mut tries = 0
  with_retry("https://example.com/x", policy, () => {
    tries = tries + 1
    if tries < 2 {
      raise Failure::Failure("首次尝试失败")
    }
  })
  assert_eq(tries, 2)
}

///|
async test "with_retry：耗尽重试后抛 ExhaustedRetries，次数与策略一致" {
  let policy : RetryPolicy = { max_attempts: 2, backoff_ms: 0, }
  let mut tries = 0
  let mut caught = ""
  with_retry("https://example.com/x", policy, () => {
    tries = tries + 1
    if tries >= 1 {
      raise Failure::Failure("总是失败")
    }
  }) catch {
    err => caught = "\{err}"
  }
  assert_eq(tries, 2)
  assert_true(caught.contains("ExhaustedRetries"))
}

///|
test "can_reuse：只有 URL 一致且本地校验通过才复用" {
  let entry : CatalogEntry = {
    suite: "decimal",
    path: "fixtures/decimal/x.tsv",
    url: "https://example.com/x.tsv",
    tier: Fast,
  }
  let prev : SourceFile = {
    suite: "decimal",
    path: "fixtures/decimal/x.tsv",
    url: "https://example.com/x.tsv",
    sha256: "abc",
    bytes: 1,
    tier: Fast,
  }
  // 没有上次记录 → 必须下载
  assert_false(can_reuse(entry, None, VerifyOutcome::Match))
  // 记录存在但本地文件不一致 → 必须重新下载
  assert_false(can_reuse(entry, Some(prev), VerifyOutcome::Missing))
  assert_false(
    can_reuse(
      entry,
      Some(prev),
      VerifyOutcome::Mismatch(expected="abc", actual="def"),
    ),
  )
  // URL 变了（例如 CLDR ref 升级）→ 必须重新下载
  let changed : CatalogEntry = { ..entry, url: "https://example.com/v2/x.tsv", }
  assert_false(can_reuse(changed, Some(prev), VerifyOutcome::Match))
  // 全对 → 复用
  assert_true(can_reuse(entry, Some(prev), VerifyOutcome::Match))
}

///|
test "manifest_of：只收录成功条目并保持目录顺序" {
  let a : SourceFile = {
    suite: "decimal",
    path: "a.tsv",
    url: "u",
    sha256: "s",
    bytes: 1,
    tier: Fast,
  }
  let b : SourceFile = { ..a, path: "b.tsv", }
  let entry_a : CatalogEntry = {
    suite: "decimal",
    path: "a.tsv",
    url: "u",
    tier: Fast,
  }
  let entry_b : CatalogEntry = { ..entry_a, path: "b.tsv", }
  let entry_c : CatalogEntry = { ..entry_a, path: "c.tsv", }
  let results : Array[SyncEntry] = [
    { entry: entry_a, outcome: Downloaded(file=a), },
    { entry: entry_c, outcome: Failed(reason="boom"), },
    { entry: entry_b, outcome: Skipped(file=b), },
  ]
  let manifest = manifest_of("main", results)
  assert_eq(manifest.cldr_version, "main")
  assert_eq(manifest.files.length(), 2)
  assert_eq(manifest.files[0].path, "a.tsv")
  assert_eq(manifest.files[1].path, "b.tsv")
  assert_eq(count_failed(results), 1)
}

///|
test "render_sync_report：三种状态各有符号，并给出汇总" {
  let file : SourceFile = {
    suite: "decimal",
    path: "fixtures/x.tsv",
    url: "u",
    sha256: "s",
    bytes: 10,
    tier: Fast,
  }
  let entry : CatalogEntry = {
    suite: "decimal",
    path: "fixtures/x.tsv",
    url: "u",
    tier: Fast,
  }
  let results : Array[SyncEntry] = [
    { entry, outcome: Downloaded(file~), },
    { entry, outcome: Skipped(file~), },
    { entry, outcome: Failed(reason="网络不可达"), },
  ]
  let report = render_sync_report("fixtures/SOURCES.json", results)
  assert_true(report.contains("+ fixtures/x.tsv"))
  assert_true(report.contains("= fixtures/x.tsv"))
  assert_true(report.contains("✗ fixtures/x.tsv"))
  assert_true(report.contains("网络不可达"))
  assert_true(report.contains("共 3 个文件：成功 2，失败 1"))
}

///|
async test "sync_entry：本地文件与清单一致时不重新下载（幂等）" {
  let dir = @fs.tmpdir(prefix="cldr-sync-")
  defer @fs.rmdir(dir, recursive=true)
  let path = "\{dir}/decimals.tsv"
  let data = b"locale\tinput\texpected\nen\t1.2\t1.2\n"
  @fs.write_file(path, data)
  let url = "https://example.invalid/decimals.tsv"
  let previous : SourceFile = {
    suite: "decimal",
    path,
    url,
    sha256: sha256_hex(data),
    bytes: data.length(),
    tier: Fast,
  }
  let item : CatalogEntry = { suite: "decimal", path, url, tier: Fast, }
  // 故意用一个不可达域名：若逻辑正确，根本不会发起请求
  let result = sync_entry(item, Some(previous), {
    max_attempts: 1,
    backoff_ms: 0,
  })
  match result.outcome {
    Skipped(file~) => assert_eq(file, previous)
    _ => fail("期望跳过（幂等），实际却尝试下载或失败")
  }
}
