///|
/// D2：CLDR 数据资产工具。
///
/// 下载（F1）：
///   moon run cmd/fetch-data -- --url <url> --out <path>
/// 离线校验（F2）：
///   moon run cmd/fetch-data -- --verify [--manifest <path>]
///
/// 校验默认读取 `fixtures/SOURCES.json`，有任何不一致时以非 0 退出码结束（CI 可用）。
/// 分档、幂等与重试在 D2-F3 落地。
async fn main {
  let args = @env.args()
  if has_flag(args, "--verify") {
    let manifest_path = match flag_value(args, "--manifest") {
      Some(path) => path
      None => "fixtures/SOURCES.json"
    }
    let manifest = @source.load_manifest(manifest_path)
    let entries = @source.verify_manifest(manifest)
    println(@source.render_verify_report(manifest_path, manifest, entries))
    let failures = @source.count_failures(entries)
    if failures > 0 {
      raise @source.SourceError::VerificationFailed(mismatches=failures)
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
          "  moon run cmd/fetch-data -- --url <url> --out <path>      # 下载单个文件",
        )
        println(
          "  moon run cmd/fetch-data -- --verify [--manifest <path>]  # 离线校验清单",
        )
      }
    }
  }
}
