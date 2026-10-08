///|
/// D2-F1：把单个 URL 下载到指定路径，并输出字节数与 SHA-256。
///
/// 用法：
///   moon run cmd/fetch-data -- --url <url> --out <path>
///
/// 本功能只负责「取回 + 摘要」；清单（SOURCES.json）、`--verify` 离线校验、
/// `--full` 分档与失败重试在 D2-F2 / D2-F3 实现。
async fn main {
  let args = @env.args()
  match (flag_value(args, "--url"), flag_value(args, "--out")) {
    (Some(url), Some(out)) => {
      println("GET \{url}")
      let result = @source.fetch_to_file(url, out)
      println("  → \{result.path}")
      println("  字节数: \{result.bytes}")
      println("  SHA256: \{result.sha256}")
    }
    _ => println("用法: moon run cmd/fetch-data -- --url <url> --out <path>")
  }
}
