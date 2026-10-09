///|
/// 重试策略：最多尝试 `max_attempts` 次，固定退避 `backoff_ms` 毫秒。
///
/// `backoff_ms = 0` 时退化为立即重试——测试用它避免真实等待。
pub(all) struct RetryPolicy {
  max_attempts : Int
  backoff_ms : Int
} derive(Debug, Eq)

///|
pub fn RetryPolicy::default() -> RetryPolicy {
  { max_attempts: 3, backoff_ms: 500, }
}

///|
/// 映射到 `@async.retry` 的退避方式（`sleep` 的单位是毫秒）。
pub fn RetryPolicy::retry_method(self : RetryPolicy) -> @async.RetryMethod {
  if self.backoff_ms <= 0 {
    @async.Immediate
  } else {
    @async.FixedDelay(self.backoff_ms)
  }
}

///|
/// `@async.retry` 的 `max_retry` 是「首次尝试之外的重试次数」，所以减一。
pub fn RetryPolicy::max_retry(self : RetryPolicy) -> Int {
  if self.max_attempts <= 1 {
    0
  } else {
    self.max_attempts - 1
  }
}

///|
/// 带重试地执行 `f`；重试耗尽后抛 `FetchError::ExhaustedRetries`。
///
/// 刻意做成泛型：测试可以传入「必然失败」的闭包来验证尝试次数与重试行为，
/// 从而**完全离线**地覆盖重试逻辑，不需要真实网络（见 `sync_wbtest.mbt`）。
pub async fn[T] with_retry(
  url : String,
  policy : RetryPolicy,
  f : async () -> T,
) -> T {
  let mut attempts = 0
  // 让错误自然冒泡给 `@async.retry` 去决定是否重试；耗尽后由外层统一转成
  // `ExhaustedRetries`。不在闭包内 catch，既避免 fragile_catch_all 警告，
  // 也让「重试」与「最终归因」两件事各自只有一处。
  let attempt = () => {
    attempts = attempts + 1
    f()
  }
  @async.retry(policy.retry_method(), max_retry=policy.max_retry(), attempt) catch {
    err => raise FetchError::ExhaustedRetries(url~, attempts~, reason="\{err}")
  }
}

///|
/// 下载单个文件，带重试。
pub async fn fetch_with_retry(
  url : String,
  dest : String,
  policy : RetryPolicy,
) -> FetchResult {
  with_retry(url, policy, () => fetch_to_file(url, dest))
}

///|
/// 单个文件的同步结论。
pub(all) enum SyncOutcome {
  /// 本地文件已存在且与上次清单一致：沿用旧记录，不重新下载。
  Skipped(file~ : SourceFile)
  Downloaded(file~ : SourceFile)
  Failed(reason~ : String)
} derive(Debug, Eq)

///|
/// 一条目录条目的同步结果。
pub(all) struct SyncEntry {
  entry : CatalogEntry
  outcome : SyncOutcome
} derive(Debug, Eq)

///|
/// 是否失败。单独抽出来，避免调用方到处写模式匹配。
pub fn SyncOutcome::is_failure(self : SyncOutcome) -> Bool {
  match self {
    Failed(_) => true
    _ => false
  }
}

///|
/// 能否直接复用本地文件（幂等判断）。纯函数，便于离线覆盖全部分支。
pub fn can_reuse(
  entry : CatalogEntry,
  previous : SourceFile?,
  verified : VerifyOutcome,
) -> Bool {
  match previous {
    Some(prev) => prev.url == entry.url && verified.is_ok()
    None => false
  }
}

///|
/// 真正下载一个条目（含重试），并把结果转成清单记录。
async fn download_entry(
  entry : CatalogEntry,
  policy : RetryPolicy,
) -> SyncEntry {
  let mut fetched : FetchResult? = None
  let mut failure = ""
  try {
    fetched = Some(fetch_with_retry(entry.url, entry.path, policy))
  } catch {
    err => failure = "\{err}"
  }
  match fetched {
    Some(result) =>
      {
        entry,
        outcome: Downloaded(file={
          suite: entry.suite,
          path: entry.path,
          url: entry.url,
          sha256: result.sha256,
          bytes: result.bytes,
          tier: entry.tier,
        }),
      }
    None => { entry, outcome: Failed(reason=failure), }
  }
}

///|
/// 同步一个条目：本地已是最新则跳过，否则下载。
pub async fn sync_entry(
  entry : CatalogEntry,
  previous : SourceFile?,
  policy : RetryPolicy,
) -> SyncEntry {
  match previous {
    Some(prev) =>
      if can_reuse(entry, previous, verify_file(prev)) {
        { entry, outcome: Skipped(file=prev), }
      } else {
        download_entry(entry, policy)
      }
    None => download_entry(entry, policy)
  }
}

///|
/// 按目录顺序同步一批条目。
pub async fn sync_all(
  entries : Array[CatalogEntry],
  previous : Manifest,
  policy : RetryPolicy,
) -> Array[SyncEntry] {
  let results = []
  for entry in entries {
    results.push(sync_entry(entry, previous.find(entry.path), policy))
  }
  results
}

///|
/// 由同步结果构造新清单：只收录成功的条目（跳过或下载），保持目录顺序。
pub fn manifest_of(
  cldr_version : String,
  results : Array[SyncEntry],
) -> Manifest {
  let files = []
  for result in results {
    match result.outcome {
      Skipped(file~) => files.push(file)
      Downloaded(file~) => files.push(file)
      Failed(_) => ()
    }
  }
  { cldr_version, files, }
}

///|
/// 失败的条目数（CI 用它决定退出码）。
pub fn count_failed(results : Array[SyncEntry]) -> Int {
  results.filter(result => result.outcome.is_failure()).length()
}

///|
/// 渲染同步报告（纯函数，可离线测）。
pub fn render_sync_report(
  manifest_path : String,
  results : Array[SyncEntry],
) -> String {
  let out = StringBuilder()
  out <+ "同步 CLDR 数据（ref \{cldr_ref()}）→ \{manifest_path}\n"
  for result in results {
    match result.outcome {
      Skipped(file~) =>
        out <+
          "  = \{result.entry.path}  \{file.bytes} 字节（本地已是最新）\n"
      Downloaded(file~) =>
        out <+ "  + \{result.entry.path}  \{file.bytes} 字节\n"
      Failed(reason~) => out <+ "  ✗ \{result.entry.path}  \{reason}\n"
    }
  }
  let failed = count_failed(results)
  out <+
    "共 \{results.length()} 个文件：成功 \{results.length() - failed}，失败 \{failed}"
  out.to_string()
}
