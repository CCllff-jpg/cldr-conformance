///|
/// 主 CLI：清点数据 → 跑套件 → 输出报告。
///
/// 当前（D4）做到「清点」：把 fixtures 里的官方数据解析成用例并打印规模。
/// 执行与报告在 D6–D7 接入：
///   moon run cmd/conform -- --suite decimal --format markdown
async fn main {
  let manifest = @source.load_manifest("fixtures/SOURCES.json")
  println("cldr-conformance · conform")
  println(
    "数据基线 \{manifest.cldr_version}（\{manifest.files.length()} 个文件）",
  )
  let decimal = @corpus.decimal_corpus_from_tsv(
    @fs.read_file("fixtures/decimal/decimals.tsv").text(),
  )
  println(
    "  数字套件  decimals.tsv                \{decimal.length()} 条用例 / \{decimal.locales().length()} 个语言",
  )
  let modern = @corpus.decimal_corpus_from_tsv(
    @fs.read_file("fixtures/decimal/decimals_modern_locales.tsv").text(),
  )
  println(
    "  数字套件  decimals_modern_locales.tsv \{modern.length()} 条用例 / \{modern.locales().length()} 个语言",
  )
  println("  日期套件与 MF2 套件：D4-F2 / D4-F3 接入")
  println(
    "  待实现：适配器执行、失败归因与报告输出（D6–D7）",
  )
}
