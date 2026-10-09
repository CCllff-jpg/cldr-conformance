///|
/// CLDR 测试数据的 ref。
///
/// 当前指向 `main`（对应上游 `common/testData`）。F4 会把它钉到具体发布 tag，
/// 使报告里的「CLDR 版本」可以长期复核。
pub fn cldr_ref() -> String {
  "main"
}

///|
/// 上游测试数据的基础 URL。
fn cldr_base() -> String {
  "https://raw.githubusercontent.com/unicode-org/cldr/\{cldr_ref()}/common/testData"
}

///|
/// 一个待拉取的官方文件：只描述「要什么」，不含摘要。
///
/// 摘要由同步结果产生（见 `SyncOutcome`），因此目录本身是稳定的常量。
pub(all) struct CatalogEntry {
  suite : String
  path : String
  url : String
  tier : Tier
} derive(Debug, Eq)

///|
fn entry(
  suite : String,
  rel : String,
  base : String,
  tier : Tier,
) -> CatalogEntry {
  { suite, path: "fixtures/\{rel}", url: "\{base}/\{rel}", tier, }
}

///|
/// 内置目录：16 个 CLDR 官方文件。
///
/// 本地路径刻意与上游目录结构保持一致（`common/testData/<x>` → `fixtures/<x>`），
/// 便于逐条追溯来源。
///
/// 分档依据见 `DATA-SOURCES.md`：
/// - `Fast`（12 个）：体积小、是各套件的主数据，入库以保证**离线可复现**
/// - `Full`（4 个）：体积大（合计约 740 KB），仅在 `--full` 时下载
pub fn catalog_all() -> Array[CatalogEntry] {
  let base = cldr_base()
  [
    // decimal
    entry("decimal", "decimal/decimals.tsv", base, Fast),
    entry("decimal", "decimal/decimals_modern_locales.tsv", base, Fast),
    entry("decimal", "decimal/decimals_extended_numbers.tsv", base, Full),
    // datetime
    entry("datetime", "datetime/datetime.json", base, Fast),
    entry("datetime", "datetime/skeletons.tsv", base, Fast),
    entry("datetime", "datetime/skeletons_all_calendars.tsv", base, Fast),
    entry("datetime", "datetime/skeletons_all_locales.tsv", base, Full),
    entry("datetime", "datetime/skeletons_all_skeletons.tsv", base, Full),
    entry("datetime", "datetime/skeletons_random_5percent.tsv", base, Full),
    // message-format-2
    entry("message-format-2", "messageFormat/tests/syntax.json", base, Fast),
    entry(
      "message-format-2",
      "messageFormat/tests/syntax-errors.json",
      base,
      Fast,
    ),
    entry(
      "message-format-2",
      "messageFormat/tests/data-model-errors.json",
      base,
      Fast,
    ),
    entry(
      "message-format-2",
      "messageFormat/tests/pattern-selection.json",
      base,
      Fast,
    ),
    entry("message-format-2", "messageFormat/tests/fallback.json", base, Fast),
    entry("message-format-2", "messageFormat/tests/bidi.json", base, Fast),
    entry("message-format-2", "messageFormat/tests/u-options.json", base, Fast),
  ]
}

///|
/// 快速档：默认同步这 12 个文件。
pub fn catalog_fast() -> Array[CatalogEntry] {
  catalog_all().filter(item => item.tier == Fast)
}

///|
/// 全量档：`--full` 时同步全部 16 个文件。
pub fn catalog_full() -> Array[CatalogEntry] {
  catalog_all()
}
