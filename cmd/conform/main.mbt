///|
/// 主 CLI：跑套件、输出报告（阶段 2 起逐步实现，见 开发方案.md §4.0 D6–D7）。
///
/// 目标形态：
///   moon run cmd/conform -- --suite decimal --format markdown
///   moon run cmd/conform -- --suite all --full --format json > report.json
fn main {
  println("cldr-conformance · conform (skeleton)")
  println("  已登记套件：")
  for suite in @conformance.Suite::all() {
    println("    - \{suite.label()}")
  }
  println(
    "  待实现：--suite / --impls / --full / --format 参数与报告输出",
  )
}
