///|
/// 真实的网络集成测试：下载一个 CLDR 官方文件并校验摘要与磁盘内容一致。
///
/// **默认跳过**，避免离线环境或 CI 无网络时误报失败。启用方式：
///
/// ```bash
/// # PowerShell
/// $env:CLDR_NET_TEST="1"; moon test internal/source --target native
/// # bash
/// CLDR_NET_TEST=1 moon test internal/source --target native
/// ```
///
/// 之所以默认关闭：本项目的其他测试都必须是离线可复现的（见 开发方案.md §5），
/// 网络不确定性不应该污染常规测试结果。
async test "真实下载 CLDR 文件并校验摘要（需 CLDR_NET_TEST=1）" {
  match @env.get_env_var("CLDR_NET_TEST") {
    None => return
    Some(_) => ()
  }
  let dir = @fs.tmpdir(prefix="cldr-conformance-")
  defer @fs.rmdir(dir, recursive=true)
  let dest = "\{dir}/decimal-README.md"
  let result = fetch_to_file(
    "https://raw.githubusercontent.com/unicode-org/cldr/main/common/testData/decimal/README.md",
    dest,
  )
  assert_true(result.bytes > 0)
  assert_eq(result.sha256.length(), 64)
  // 关键断言：记录下来的摘要必须与磁盘上真实内容一致，
  // 否则 SOURCES.json 的校验意义就没了。
  assert_eq(sha256_hex(@fs.read_file(dest).binary()), result.sha256)
}
