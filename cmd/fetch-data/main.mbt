///|
/// D2：CLDR 数据资产工具。
///
/// 同步官方数据（F3）：
///   moon run cmd/fetch-data -- --sync [--full] [--manifest <path>]
/// 离线校验（F2）：
///   moon run cmd/fetch-data -- --verify [--manifest <path>]
/// 下载单个文件（F1）：
///   moon run cmd/fetch-data -- --url <url> --out <path>
///
/// 清单默认落在 `fixtures/SOURCES.json`；任何失败都以非 0 退出码结束（CI 可用）。
async fn main {
  let args = @env.args()
  let manifest_path = match flag_value(args, "--manifest") {
    Some(path) => path
    None => "fixtures/SOURCES.json"
  }
  if has_flag(args, "--verify") {
    let manifest = @source.load_manifest(manifest_path)
    let entries = @source.verify_manifest(manifest)
    println(@source.render_verify_report(manifest_path, manifest, entries))
    let failures = @source.count_failures(entries)
    if failures > 0 {
      raise @source.SourceError::VerificationFailed(mismatches=failures)
    }
  } else if has_flag(args, "--sync") {
    let entries = if has_flag(args, "--full") {
      @source.catalog_full()
    } else {
      @source.catalog_fast()
    }
    let previous = @source.load_manifest_or_empty(manifest_path)
    let results = @source.sync_all(
      entries,
      previous,
      @source.RetryPolicy::default(),
    )
    println(@source.render_sync_report(manifest_path, results))
    // 先把「已经拿到手」的部分写进清单，再按失败数决定退出码：
    // 部分成功时清单仍然如实反映磁盘现状，随后可以直接 --verify。
    @source.save_manifest(
      manifest_path,
      @source.manifest_of(@source.cldr_ref(), results),
    )
    let failed = @source.count_failed(results)
    if failed > 0 {
      raise @source.SourceError::SyncFailed(failures=failed)
    }
  } else {
    match (flag_value(args, "--url"), flag_value(args, "--out")) {
      (Some(url), Some(out)) => {
        println("GET \{url}")
        let result = @source.fetch_to_file(url, out)
        println("  → \{result.path}")
        println("  字节数: \{result.bytes}")
        println("  SHA256: \{result.sha256}")
      }
      _ => {
        println("用法：")
        println(
          "  moon run cmd/fetch-data -- --sync [--full] [--manifest <path>]  # 同步官方数据",
        )
        println(
          "  moon run cmd/fetch-data -- --verify [--manifest <path>]         # 离线校验清单",
        )
        println(
          "  moon run cmd/fetch-data -- --url <url> --out <path>             # 下载单个文件",
        )
      }
    }
  }
}
